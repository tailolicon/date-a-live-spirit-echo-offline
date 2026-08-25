#!/usr/bin/env python3
from __future__ import annotations

import unittest

from game_static_config import GameStaticConfig


class GameStaticConfigTests(unittest.TestCase):
    def setUp(self) -> None:
        self.cfg = GameStaticConfig(tables={
            "LevelUp": """return {
[1]={heroExp=5,id=1},
[2]={heroExp=10,id=2},
}""",
            "Item": """return {
[510101]={
  useProfit={fix={items={
    [1]={id=500006,num=200,},
  },},},
  id=510101
},
[999]={
  useProfit={fix={items={
    [1]={id=500001,num=3,},
  },},},
  id=999
},
}""",
            "Hero": """return {
[110101]={attribute=1011,quality=4,expitem={[1]=510101,[2]=510102},defaultSkin=1101011,optionalSkin={[1]=1101011,[2]=1101012},paint=1101099,changeType=true,condition={heroQuality=5}},
}""",
            "HeroProgress": """return {
[101101]={id=101101,consume={}},
[101102]={id=101102,consume={[1]={[1]=510301,[2]=5},[2]={[1]=500001,[2]=100}}},
[101105]={id=101105,consume={[1]={[1]=510301,[2]=60}}},
}""",
            "HeroSkin": """return {
[1101011]={id=1101011},
[1101012]={id=1101012},
[1101099]={id=1101099},
}""",
        })

    def test_level_and_exp_item_values(self) -> None:
        self.assertEqual(self.cfg.max_level(), 2)
        self.assertEqual(self.cfg.level_exp(1), 5)
        self.assertEqual(self.cfg.exp_item_value(510101), 200)
        self.assertIsNone(self.cfg.exp_item_value(999))

    def test_hero_metadata_and_skins(self) -> None:
        hero = self.cfg.hero(110101)
        self.assertEqual(hero["attribute"], 1011)
        self.assertEqual(hero["baseQuality"], 4)
        self.assertEqual(hero["expItems"], [510101, 510102])
        self.assertEqual(hero["conditionHeroQuality"], 5)
        self.assertEqual(self.cfg.allowed_skins(110101), {1101011, 1101012, 1101099})
        self.assertTrue(self.cfg.skin_exists(1101099))
        self.assertFalse(self.cfg.skin_exists(123))

    def test_advance_and_quality_costs(self) -> None:
        self.assertEqual(self.cfg.advance_cost(110101, 0), [])
        self.assertEqual(self.cfg.advance_cost(110101, 1), [
            {"id": 510301, "num": 5}, {"id": 500001, "num": 100},
        ])
        self.assertEqual(self.cfg.quality_cost(110101, 5), [{"id": 510301, "num": 60}])
        self.assertIsNone(self.cfg.advance_cost(110101, 8))


if __name__ == "__main__":
    unittest.main()
