#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
sys.path.insert(0, TOOLS)

import hotpatch_main_scene as target  # noqa: E402


class MainSceneHotpatchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        path = os.path.join(REPO, "reference", "lua", "lua", "net", "NetWork.lua")
        with open(path, encoding="utf-8") as f:
            cls.source = f.read()
        cls.patched = target.patch_network(cls.source)

    def test_all_observed_nil_lists_are_normalized(self) -> None:
        expected = {
            280: "switchs",
            5663: "favorList",
            4869: "eTypes",
            5145: "configList",
            5120: "mainAdBoardInfo",
            3010: "uiChange",
        }
        for proto, field in expected.items():
            self.assertIn(f"[{proto}]", self.patched)
            self.assertIn(f'{{"{field}"}}', self.patched)

    def test_invalid_zero_ids_are_neutralized(self) -> None:
        self.assertIn("tTemp.wearId = 100001", self.patched)
        self.assertIn("nType == 6824 and tTemp.roomType == 0", self.patched)
        self.assertIn("nType == 8501 and tTemp.curBoss", self.patched)
        self.assertIn("skip invalid HuntingDungeonInfo curDungeon=0", self.patched)

    def test_existing_network_tracing_is_preserved(self) -> None:
        self.assertIn("[DAL-WAIT] pending:", self.patched)

    def test_patch_is_idempotent(self) -> None:
        self.assertEqual(target.patch_network(self.patched), self.patched)
        self.assertEqual(self.patched.count(target.MARKER), 1)

    def test_dispatch_survives_for_normal_messages(self) -> None:
        self.assertEqual(
            self.patched.count("TFDirector:dispatchProtocolWith(nType, tTemp)"), 1
        )


if __name__ == "__main__":
    unittest.main()
