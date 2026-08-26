#!/usr/bin/env python3
"""Every body we put on the wire must survive the client's own decoder.

The client never rejects a malformed body outright: it NULLs the field it
could not match and carries on, so the damage shows up much later as a nil
index inside a DataMgr and, on screen, as a MainScene that never finishes
loading. proto_validate mirrors that decoder, which turns an invisible wire
bug into a failing assertion here.
"""
from __future__ import annotations

import copy
import importlib
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import proto_gen  # noqa: E402
import proto_validate  # noqa: E402
from player_save import load_save  # noqa: E402
from proto_codec import enc_msg_field  # noqa: E402
from stateful_handlers import encode_dungeon_level_info  # noqa: E402

HANDLER_MODULES = (
    "stateful_handlers",
    "combat_handlers",
    "formation_backup_handlers",
    "hero_progression_handlers",
    "angel_handlers",
    "progression_handlers",
    "sign_handlers",
)


def _unpack(result):
    """Handlers return either (body, mutated) or a HandlerResult."""
    if result is None:
        return None
    if isinstance(result, tuple):
        return result[0], ()
    return result.body, getattr(result, "extra_packets", ())


class GeneratedBodyTests(unittest.TestCase):
    def test_every_generated_minimal_body_decodes(self) -> None:
        bad = [str(r) for r in
               (proto_validate.validate(pid, body)
                for pid, body in sorted(proto_gen.build().items()))
               if not r.ok]
        self.assertEqual(bad, [])


class HandlerBodyTests(unittest.TestCase):
    def test_every_stateful_response_decodes(self) -> None:
        base = load_save()
        types = proto_validate.load_types()
        bad: list[str] = []
        for name in HANDLER_MODULES:
            module = importlib.import_module(name)
            protocols = next(v for k, v in vars(module).items()
                             if k.endswith("_PROTOCOLS"))
            for proto in sorted(protocols):
                got = _unpack(module.response_for(proto, copy.deepcopy(base), b""))
                if got is None:
                    continue
                body, extras = got
                for pid, payload in ((proto, body), *extras):
                    if pid not in types:
                        bad.append(f"{name} {pid}: no s2c descriptor")
                        continue
                    report = proto_validate.validate(pid, payload)
                    if not report.ok:
                        bad.append(f"{name} {report}")
        self.assertEqual(bad, [])


class ValidatorTests(unittest.TestCase):
    def test_dungeon_level_info_matches_the_descriptor(self) -> None:
        report = proto_validate.validate(1796, encode_dungeon_level_info({}))
        self.assertTrue(report.ok, str(report))

    def test_an_extra_submessage_wrap_is_caught(self) -> None:
        """The bug that black-screened MainScene, as the client saw it.

        s2c 1796 field 1 is {false,{{true,{...}}}}: a submessage whose single
        field is the repeated levelInfo list. Wrapping the list once more put a
        submessage where levelInfo.cid belongs, and the device printed
        "[error]not the same type at 1 v4 ... 10 8 14".
        """
        double_wrapped = enc_msg_field(1, encode_dungeon_level_info({}))
        report = proto_validate.validate(1796, double_wrapped)
        self.assertFalse(report.ok)
        self.assertTrue(any("field 1 expects wire 0" in m
                            for m in report.mismatches), str(report))


class HotSummonTests(unittest.TestCase):
    """s2c 3343 must name a real SummonLoop row, not order 0."""

    def test_orders_are_valid_loop_ids(self) -> None:
        import game_static_config
        from stateful_handlers import (
            SUMMON_LOOP_EQUIPMENT,
            SUMMON_LOOP_ROLE,
            hot_summon_info,
        )

        loops = game_static_config.config().summon_hot_loop_ids()
        self.assertGreaterEqual(loops.get(SUMMON_LOOP_ROLE, 0), 1)
        self.assertGreaterEqual(loops.get(SUMMON_LOOP_EQUIPMENT, 0), 1)

        info = hot_summon_info({})
        self.assertEqual(info["heroHotSummonOrder"], loops[SUMMON_LOOP_ROLE])
        self.assertEqual(info["equipHotSummonOrder"], loops[SUMMON_LOOP_EQUIPMENT])

    def test_falls_back_to_one_without_the_apk(self) -> None:
        import game_static_config
        from stateful_handlers import hot_summon_info

        original = game_static_config.config
        game_static_config.config = lambda: (_ for _ in ()).throw(
            game_static_config.StaticConfigUnavailable("no apk"))
        try:
            info = hot_summon_info({})
        finally:
            game_static_config.config = original
        self.assertEqual(info["heroHotSummonOrder"], 1)
        self.assertEqual(info["equipHotSummonOrder"], 1)

if __name__ == "__main__":
    unittest.main()
