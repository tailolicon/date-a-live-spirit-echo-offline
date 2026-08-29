#!/usr/bin/env python3
"""Progress the client reports must come back on the next login.

`GuideDataMgr:onLogin` sends `{-1}` and assigns `__step` from whatever s2c 278
answers, so the reply is the single source of truth for where the tutorial
resumes. Answering with a zero-filled body says "step 0, unfinished", and the
player replays the whole new-player guide every session.
"""
from __future__ import annotations

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import player_handlers as player  # noqa: E402
import proto_validate  # noqa: E402
from game_static_config import StaticConfigUnavailable, config as static_config  # noqa: E402
from protocol_schema import decode_fields, encode_fields, registry  # noqa: E402

# GuideDataMgr sends -1; the field is a v4, so it arrives at the top of the range.
QUERY = 0xFFFFFFFF


def tables_available() -> bool:
    try:
        static_config().new_guide_step_count()
    except StaticConfigUnavailable:
        return False
    return True


def request(proto: int, values: dict) -> bytes:
    return encode_fields(registry().c2s[proto], values)


def response(proto: int, body: bytes) -> dict:
    return decode_fields(registry().s2c[proto], body)


def ask(state: dict, guide_id: int) -> dict:
    body, _ = player.response_for(
        player.PLAYER_REQ_NEW_PLAYER_GUIDE, state,
        request(player.PLAYER_REQ_NEW_PLAYER_GUIDE, {"guideId": guide_id}))
    assert proto_validate.validate(player.PLAYER_REQ_NEW_PLAYER_GUIDE, body).ok
    return response(player.PLAYER_REQ_NEW_PLAYER_GUIDE, body)


class NewPlayerGuideTests(unittest.TestCase):
    def test_a_fresh_save_starts_the_guide(self) -> None:
        self.assertEqual(ask({}, QUERY), {"guideId": player.FIRST_GUIDE_STEP, "finish": False})

    def test_a_reported_step_is_remembered_across_a_relog(self) -> None:
        state: dict = {}
        ask(state, 1)
        ask(state, 2)
        self.assertEqual(ask(state, QUERY)["guideId"], 3,
                         "the query must resume where the reports left off")

    @unittest.skipUnless(tables_available(), "needs work/apk/base-offline.apk")
    def test_a_step_that_jumps_resumes_where_the_client_lands(self) -> None:
        """`Guide.stepId` skips ahead at 20 of the 79 new-player rows.

        Adding one there sends the player back through a step the guide meant
        to skip, which is a shorter replay of the same bug.
        """
        cfg = static_config()
        jumped = next((step for step in range(1, cfg.new_guide_step_count())
                       if cfg.new_guide_next_step(step) > step + 1), None)
        self.assertIsNotNone(jumped, "the shipped table has jump rows")
        state: dict = {}
        self.assertEqual(ask(state, jumped)["guideId"], cfg.new_guide_next_step(jumped))

    def test_the_cursor_only_moves_forward(self) -> None:
        """A guide step whose config jumps ahead reports the larger id later."""
        state: dict = {}
        ask(state, 40)
        self.assertEqual(ask(state, 3)["guideId"], 41)

    def test_a_query_does_not_advance_the_cursor(self) -> None:
        state: dict = {}
        ask(state, 5)
        before = dict(state)
        ask(state, QUERY)
        self.assertEqual(state, before)

    @unittest.skipUnless(tables_available(), "needs work/apk/base-offline.apk")
    def test_finishing_the_last_step_ends_the_guide_for_good(self) -> None:
        state: dict = {}
        last = static_config().new_guide_step_count()
        self.assertGreater(last, 0)
        self.assertFalse(ask(state, last - 1)["finish"])
        self.assertTrue(ask(state, last)["finish"], "skipping reports the final step")
        self.assertTrue(ask(state, QUERY)["finish"], "and it has to stay finished")


class GuideGroupTests(unittest.TestCase):
    """One-off group guides are recorded the same way, on their own protocol."""

    def test_a_played_group_is_reported_back(self) -> None:
        state: dict = {}
        _, changed = player.response_for(
            player.EXPLORE_REQ_ADD_GUIDE_STEP, state,
            request(player.EXPLORE_REQ_ADD_GUIDE_STEP, {"stepId": 5}))
        self.assertTrue(changed)
        body, _ = player.response_for(player.EXPLORE_REQ_GUIDE_INFO, state, b"")
        self.assertTrue(proto_validate.validate(player.EXPLORE_REQ_GUIDE_INFO, body).ok)
        self.assertEqual(response(player.EXPLORE_REQ_GUIDE_INFO, body)["stepInfo"], [5])

    def test_the_same_group_is_not_recorded_twice(self) -> None:
        state: dict = {}
        for _ in range(2):
            _, changed = player.response_for(
                player.EXPLORE_REQ_ADD_GUIDE_STEP, state,
                request(player.EXPLORE_REQ_ADD_GUIDE_STEP, {"stepId": 5}))
        self.assertFalse(changed)
        self.assertEqual(state["guideGroupsDone"], [5])


class PlayerNameTests(unittest.TestCase):
    def test_the_prologue_rename_is_persisted(self) -> None:
        state: dict = {"name": "Shido"}
        _, changed = player.response_for(
            player.PLAYER_SET_PLAYER_INFO, state,
            request(player.PLAYER_SET_PLAYER_INFO, {"playerName": "Itsuka", "remark": ""}))
        self.assertTrue(changed)
        self.assertEqual(state["name"], "Itsuka")

    def test_renaming_to_the_same_name_changes_nothing(self) -> None:
        state: dict = {"name": "Itsuka", "remark": ""}
        _, changed = player.response_for(
            player.PLAYER_SET_PLAYER_INFO, state,
            request(player.PLAYER_SET_PLAYER_INFO, {"playerName": "Itsuka", "remark": ""}))
        self.assertFalse(changed)


if __name__ == "__main__":
    unittest.main()
