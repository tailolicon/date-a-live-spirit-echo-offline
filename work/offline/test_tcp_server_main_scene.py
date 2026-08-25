#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from tcp_server_main_scene import (  # noqa: E402
    FIRST_PLOT_LEVEL,
    encode_dungeon_level_info,
)


class MainSceneDungeonStateTests(unittest.TestCase):
    def test_default_response_marks_first_plot_won(self) -> None:
        body = encode_dungeon_level_info({})
        # s2c 1796:
        # response.levelInfos.levelInfos[1] =
        #   {cid=101101, fightCount=1, win=true, buyCount=0, freeCount=0}
        self.assertEqual(
            body.hex(),
            "0a100a0e0a0c08ed95061801200128003000",
        )

    def test_explicit_empty_passed_levels_can_disable_bootstrap(self) -> None:
        self.assertEqual(encode_dungeon_level_info({"passedLevels": []}), b"")

    def test_custom_passed_levels_are_encoded(self) -> None:
        body = encode_dungeon_level_info({"passedLevels": [FIRST_PLOT_LEVEL, 101102]})
        self.assertIn(bytes.fromhex("08ed9506"), body)
        self.assertIn(bytes.fromhex("08ee9506"), body)


if __name__ == "__main__":
    unittest.main()
