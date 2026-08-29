#!/usr/bin/env python3
"""The relog check has to be able to see the bug it exists to catch.

A verifier that silently parses nothing reports success, which is worse than
having no verifier at all - this one did exactly that twice while being written
(wrong body offset, then a regex that tripped on the space inside the logged
peer tuple). So its parsing is pinned here, against lines built by the real
encoder and against a capture taken off the device.
"""
from __future__ import annotations

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import verify_relog  # noqa: E402
from protocol_schema import encode_fields, registry  # noqa: E402

PROTO = 278
QUERY = 0xFFFFFFFF


def request_line(guide_id: int) -> str:
    """The line tcp_server writes for an incoming c2s 278."""
    body = encode_fields(registry().c2s[PROTO], {"guideId": guide_id})
    return ("10:00:00 <- ('127.0.0.1', 53703) proto=278/PLAYER_REQ_NEW_PLAYER_GUIDE "
            f"x=0x0017 body={body[:96].hex()}")


class GuideRequestParsingTests(unittest.TestCase):
    def test_a_finished_guide_is_the_query_and_nothing_else(self) -> None:
        trace = "\n".join([
            request_line(QUERY),
            "10:00:00 -> ('127.0.0.1', 53703) [plain] proto=262/LOGIN_PONG err=0 body=0 hex=712b",
            "10:00:01    player handled 278/PLAYER_REQ_NEW_PLAYER_GUIDE",
        ])
        self.assertEqual(verify_relog.guide_requests(trace), (1, []))

    def test_a_replayed_tutorial_is_visible(self) -> None:
        """The failure the check exists for: steps reported after a relog."""
        trace = "\n".join([request_line(QUERY)] + [request_line(n) for n in (1, 2, 3, 4)])
        self.assertEqual(verify_relog.guide_requests(trace), (1, [1, 2, 3, 4]))

    def test_the_skip_button_reports_the_final_step(self) -> None:
        trace = "\n".join([request_line(QUERY), request_line(79)])
        self.assertEqual(verify_relog.guide_requests(trace), (1, [79]))

    def test_a_real_capture_parses(self) -> None:
        """Taken off the device: `body=0801` is guide step 1."""
        line = ("21:07:36 <- ('127.0.0.1', 53703) proto=278/PLAYER_REQ_NEW_PLAYER_GUIDE "
                "x=0x0017 body=0801")
        self.assertEqual(verify_relog.guide_requests(line), (0, [1]))

    def test_an_unrelated_trace_yields_nothing(self) -> None:
        self.assertEqual(verify_relog.guide_requests("nothing here"), (0, []))
        self.assertEqual(verify_relog.guide_requests(""), (0, []))


if __name__ == "__main__":
    unittest.main()
