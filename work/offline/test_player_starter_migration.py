#!/usr/bin/env python3
from __future__ import annotations

import unittest

import player_save
import stateful_handlers as sh
from protocol_schema import decode_fields, registry


class StarterSaveMigrationTests(unittest.TestCase):
    def test_new_save_is_playable(self) -> None:
        state = player_save.default_save()
        self.assertEqual(state["schemaVersion"], 4)
        self.assertEqual(len(state["heroes"]), 1)
        hero = state["heroes"][0]
        self.assertEqual(hero["id"], player_save.STARTER_HERO_SID)
        self.assertEqual(hero["cid"], player_save.STARTER_HERO_CID)
        self.assertEqual(hero["skinCid"], player_save.STARTER_HERO_SKIN)
        self.assertEqual(hero["quality"], player_save.STARTER_HERO_QUALITY)
        self.assertEqual(hero["angelLvl"], 1)
        self.assertEqual(hero["skillStrategyInfo"][0]["id"], 1)
        self.assertEqual(state["formations"][0]["stance"], [player_save.STARTER_HERO_SID])
        self.assertEqual(state["helpFightHeroCid"], player_save.STARTER_HERO_CID)

    def test_v2_empty_save_migrates_once_to_starter(self) -> None:
        state = player_save.normalize_save({
            "schemaVersion": 2,
            "pid": 7,
            "heroes": [],
            "formations": [
                {"ct": 0, "type": 1, "status": 1, "stance": []},
                {"ct": 0, "type": 2, "status": 1, "stance": []},
                {"ct": 0, "type": 3, "status": 1, "stance": []},
            ],
            "items": {},
        })
        self.assertEqual(state["schemaVersion"], 4)
        self.assertEqual([hero["cid"] for hero in state["heroes"]], [player_save.STARTER_HERO_CID])
        self.assertEqual(state["heroes"][0]["angelLvl"], 1)
        self.assertEqual(state["formations"][0]["stance"], [player_save.STARTER_HERO_SID])

        again = player_save.normalize_save(state)
        self.assertEqual(again["heroes"], state["heroes"])
        self.assertEqual(again["formations"], state["formations"])

    def test_v3_hero_gets_angel_baseline_without_replacing_roster(self) -> None:
        state = player_save.normalize_save({
            "schemaVersion": 3,
            "heroes": [{"id": "custom-hero", "cid": 110102, "lvl": 7, "quality": 5, "angelLvl": 0,
                        "skillStrategyInfo": []}],
            "formations": [{"ct": 0, "type": 1, "status": 1, "stance": ["custom-hero"]}],
            "items": {},
        })
        self.assertEqual(state["schemaVersion"], 4)
        self.assertEqual(len(state["heroes"]), 1)
        self.assertEqual(state["heroes"][0]["id"], "custom-hero")
        self.assertEqual(state["heroes"][0]["angelLvl"], 1)
        self.assertEqual(state["heroes"][0]["skillStrategyInfo"][0]["id"], 1)
        self.assertEqual(state["formations"][0]["stance"], ["custom-hero"])

    def test_v4_intentionally_empty_roster_stays_empty(self) -> None:
        state = player_save.normalize_save({
            "schemaVersion": 4,
            "heroes": [],
            "formations": [],
            "items": {},
        })
        self.assertEqual(state["heroes"], [])
        self.assertEqual(state["formations"][0]["stance"], [])

    def test_v4_state_is_not_rewritten_by_migration_rules(self) -> None:
        state = player_save.normalize_save({
            "schemaVersion": 4,
            "heroes": [{"id": "custom-hero", "cid": 110102, "lvl": 7, "quality": 5,
                        "angelLvl": 3, "skillStrategyInfo": [{"id": 2, "name": "Mine"}],
                        "useSkillStrategy": 2}],
            "formations": [],
            "items": {},
        })
        hero = state["heroes"][0]
        self.assertEqual(hero["angelLvl"], 3)
        self.assertEqual(hero["skillStrategyInfo"], [{"id": 2, "name": "Mine"}])
        self.assertEqual(hero["useSkillStrategy"], 2)
        self.assertEqual(state["formations"][0]["stance"], [])

    def test_existing_roster_is_never_replaced(self) -> None:
        state = player_save.normalize_save({
            "schemaVersion": 2,
            "heroes": [{"id": "custom-hero", "cid": 110102, "lvl": 7, "quality": 5}],
            "formations": [],
            "items": {},
        })
        self.assertEqual(len(state["heroes"]), 1)
        self.assertEqual(state["heroes"][0]["id"], "custom-hero")
        self.assertEqual(state["heroes"][0]["cid"], 110102)
        self.assertEqual(state["heroes"][0]["lvl"], 7)
        self.assertEqual(state["formations"][0]["stance"], ["custom-hero"])

    def test_starter_hero_round_trips_through_real_1025_descriptor(self) -> None:
        state = player_save.default_save()
        body, mutated = sh.response_for(sh.HERO_GET_HEROS, state)
        self.assertFalse(mutated)
        decoded = decode_fields(registry().s2c[sh.HERO_GET_HEROS], body)
        self.assertEqual(len(decoded["heros"]), 1)
        hero = decoded["heros"][0]
        self.assertEqual(hero["id"], player_save.STARTER_HERO_SID)
        self.assertEqual(hero["cid"], player_save.STARTER_HERO_CID)
        self.assertEqual(hero["lvl"], 1)
        self.assertEqual(hero["quality"], player_save.STARTER_HERO_QUALITY)
        self.assertEqual(hero["skinCid"], player_save.STARTER_HERO_SKIN)
        self.assertEqual(hero["angelLvl"], 1)


if __name__ == "__main__":
    unittest.main()
