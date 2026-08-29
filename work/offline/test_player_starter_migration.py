#!/usr/bin/env python3
from __future__ import annotations

import unittest

import player_save
import stateful_handlers as sh
from protocol_schema import decode_fields, registry


class StarterSaveMigrationTests(unittest.TestCase):
    def test_new_save_is_playable(self) -> None:
        state = player_save.default_save()
        self.assertEqual(state["schemaVersion"], player_save.SCHEMA_VERSION)
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
        self.assertEqual(state["schemaVersion"], player_save.SCHEMA_VERSION)
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
        self.assertEqual(state["schemaVersion"], player_save.SCHEMA_VERSION)
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


class CurrencyStockTests(unittest.TestCase):
    """The currencies a feature prices itself in have to exist to reach it."""

    def test_every_stocked_currency_is_present(self) -> None:
        state = player_save.normalize_save({"schemaVersion": 5, "items": {}})
        by_cid = {int(row["cid"]): int(row["num"]) for row in state["items"].values()}
        for cid in player_save.STOCKED_CIDS:
            self.assertEqual(by_cid.get(cid), player_save.TEST_CURRENCY_STOCK,
                             f"currency {cid} not stocked")

    def test_a_richer_balance_survives(self) -> None:
        cid = player_save.STOCKED_CIDS[0]
        rich = player_save.TEST_CURRENCY_STOCK * 2
        state = player_save.normalize_save({
            "schemaVersion": 5,
            "items": {str(cid): {"id": str(cid), "cid": cid, "num": rich}},
        })
        by_cid = {int(row["cid"]): int(row["num"]) for row in state["items"].values()}
        self.assertEqual(by_cid[cid], rich)

    def test_stocking_runs_once(self) -> None:
        state = player_save.normalize_save({"schemaVersion": 5, "items": {}})
        cid = player_save.STOCKED_CIDS[0]
        row = next(r for r in state["items"].values() if int(r["cid"]) == cid)
        row["num"] = 0
        again = player_save.normalize_save(state)
        by_cid = {int(r["cid"]): int(r["num"]) for r in again["items"].values()}
        self.assertEqual(by_cid[cid], 0, "an already-migrated save is left alone")


class GuideProgressMigrationTests(unittest.TestCase):
    """A save with progress must not be sent back through the tutorial."""

    def test_a_played_save_is_marked_past_the_guide(self) -> None:
        state = player_save.normalize_save({
            "schemaVersion": 5, "lvl": 3, "passedLevels": [101101, 101102],
        })
        self.assertGreater(state.get("newPlayerGuideStep", 0), 79)

    def test_a_fresh_save_still_gets_the_tutorial(self) -> None:
        self.assertNotIn("newPlayerGuideStep", player_save.default_save())

    def test_a_recorded_step_is_left_alone(self) -> None:
        state = player_save.normalize_save({
            "schemaVersion": 5, "lvl": 9, "newPlayerGuideStep": 12,
        })
        self.assertEqual(state["newPlayerGuideStep"], 12)


if __name__ == "__main__":
    unittest.main()
