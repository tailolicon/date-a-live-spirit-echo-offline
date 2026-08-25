#!/usr/bin/env python3
from __future__ import annotations

import unittest

from game_static_config import GameStaticConfig


class StaticProgressionParsingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.cfg = GameStaticConfig(tables={
            "Hero": """return {
    [110101] = {
        attribute = 1011,
        quality = 4,
        defaultSkin = 1101011,
        AngelLevelId = 1011,
        openAngelStrengthen = 1,
        angelWakeCons = {
            [1] = {[570018] = 100,},
        },
    },
}""",
            "AngelSkillTree": """return {
    [1001] = {
        id = 1001, heroId = 110101, skillType = 1, pos = 1, lvl = 1,
        skillId = {[1] = 2001,}, needSkillPiont = 2, needHeroLvl = 1, needAngelLvl = 1,
        frontCondition = {},
    },
    [1002] = {
        id = 1002, heroId = 110101, skillType = 1, pos = 1, lvl = 2,
        skillId = {[1] = 2002,}, needSkillPiont = 3, needHeroLvl = 2, needAngelLvl = 1,
        frontCondition = {[1] = 1001,},
    },
    [9001] = {
        id = 9001, heroId = 110101, skillType = 10, pos = 3, lvl = 1,
        skillId = {}, needSkillPiont = 0, needHeroLvl = 1, needAngelLvl = 2,
        frontCondition = {},
    },
}""",
            "AngelPassiveSkillGrooves": """return {
    [1] = {id = 1, AngelLvl = 2, needHeroLvl = 0,},
}""",
            "AngelStrengthen": """return {
    [501] = {
        id = 501, heroId = 110101, skillType = 1, lvl = 1,
        needCost = {[1] = {[1] = 510301, [2] = 2,},},
        needCost2 = {[1] = {[1] = 667005, [2] = 3,},},
        frontCondition = {},
    },
}""",
            "AngelBreakthrough": """return {
    [1011001] = {
        id = 1011001, AngelLevel = 1,
        BreakCost = {
            [1] = {[510301] = 25,},
            [2] = {[570002] = 300,},
        },
        BreakReward = {[13] = 500,},
    },
}""",
            "DungeonLevel": """return {
    [101101] = {
        id = 101101, playerLv = 1, fightCount = 99, isFree = false,
        cost = {[1] = {[1] = 500004, [2] = 6,},},
        reward = 60210101, firstReward = 60110101, rewardMultiple = 60810101,
        preLevelId = {},
    },
    [101102] = {
        id = 101102, playerLv = 2, fightCount = 99, isFree = true,
        cost = {}, reward = 0, firstReward = 60110102, rewardMultiple = 0,
        preLevelId = {[1] = 101101,},
    },
}""",
            "Drop": """return {
    [60110101] = {
        useProfit = {fix = {items = {
            [1] = {min = 60, max = 60, id = 500001,},
            [2] = {min = 6, max = 6, id = 500005,},
        },},},
    },
    [60210101] = {
        useProfit = {
            basic = {items = {
                [1] = {min = 1, num = 0, weight = 10000, max = 1, id = 510201,},
                [2] = {min = 1, num = 0, weight = 5000, max = 1, id = 510101,},
            },},
            fix = {items = {
                [1] = {min = 60, max = 60, id = 500001,},
            },},
        },
    },
}""",
            "HeroSkin": "return {}",
            "HeroProgress": "return {}",
            "LevelUp": "return {[1]={heroExp=1,}}",
            "Item": "return {}",
        })

    def test_angel_awake_skill_passive_and_strengthen(self) -> None:
        hero = self.cfg.hero(110101)
        self.assertEqual(hero["angelLevelId"], 1011)
        self.assertEqual(hero["openAngelStrengthen"], 1)
        self.assertEqual(self.cfg.angel_awake_cost(110101, 1), [{"id": 570018, "num": 100}])
        node = self.cfg.angel_skill(110101, 1, 1, 2)
        self.assertEqual(node["id"], 1002)
        self.assertEqual(node["skillIds"], [2002])
        self.assertEqual(node["frontCondition"], [1001])
        self.assertEqual(self.cfg.angel_skill_by_id(9001)["skillType"], 10)
        self.assertEqual(self.cfg.passive_slot(1), {"pos": 1, "needAngelLvl": 2, "needHeroLvl": 0})
        self.assertEqual(self.cfg.angel_strengthen_cost(110101, 1, 1, 1), [{"id": 510301, "num": 2}])
        self.assertEqual(self.cfg.angel_strengthen_cost(110101, 1, 1, 2), [{"id": 667005, "num": 3}])

    def test_breakthrough_parses_alternative_cost_maps(self) -> None:
        stage = self.cfg.angel_break_stage(110101, 1)
        self.assertEqual(stage["level"], 1)
        self.assertEqual(stage["costOptions"], [
            [{"id": 510301, "num": 25}],
            [{"id": 570002, "num": 300}],
        ])
        self.assertEqual(stage["reward"], [{"id": 13, "num": 500}])

    def test_dungeon_definition_and_drop_shapes(self) -> None:
        dungeon = self.cfg.dungeon_definition(101101)
        self.assertEqual(dungeon["playerLvl"], 1)
        self.assertEqual(dungeon["cost"], [{"id": 500004, "num": 6}])
        self.assertEqual(dungeon["rewardDrop"], 60210101)
        self.assertEqual(dungeon["firstRewardDrop"], 60110101)
        self.assertEqual(dungeon["nextLevelCid"], 101102)

        first = self.cfg.dungeon_drop(60110101)
        self.assertEqual(first["fixed"], [
            {"id": 500001, "min": 60, "max": 60, "weight": 10000},
            {"id": 500005, "min": 6, "max": 6, "weight": 10000},
        ])
        regular = self.cfg.dungeon_drop(60210101)
        self.assertEqual(regular["fixed"][0]["id"], 500001)
        self.assertEqual(regular["basic"], [
            {"id": 510201, "min": 1, "max": 1, "weight": 10000},
            {"id": 510101, "min": 1, "max": 1, "weight": 5000},
        ])


if __name__ == "__main__":
    unittest.main()
