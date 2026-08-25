#!/usr/bin/env python3
from __future__ import annotations

import copy
import unittest

import hero_progression_handlers as hp
from protocol_schema import decode_fields, encode_fields, registry


def request(proto: int, values: dict) -> bytes:
    return encode_fields(registry().c2s[proto], values)


def response(proto: int, body: bytes) -> dict:
    return decode_fields(registry().s2c[proto], body)


class FakeConfig:
    def hero(self, cid: int):
        if int(cid) != 110101:
            return None
        return {
            "attribute": 1011,
            "baseQuality": 4,
            "expItems": [510101],
            "defaultSkin": 1101011,
            "optionalSkins": [1101011, 1101012],
            "paint": 1101099,
            "conditionHeroQuality": 5,
        }

    def max_level(self) -> int:
        return 10

    def level_exp(self, level: int):
        return {1: 100, 2: 200, 3: 300, 4: 400, 5: 500, 6: 600, 7: 700, 8: 800, 9: 900}.get(level)

    def exp_item_value(self, cid: int):
        return 200 if int(cid) == 510101 else None

    def advance_cost(self, cid: int, advanced_level: int):
        if int(cid) != 110101:
            return None
        return {0: [], 1: [{"id": 510301, "num": 5}]}.get(int(advanced_level))

    def quality_cost(self, cid: int, next_quality: int):
        if int(cid) == 110101 and int(next_quality) == 5:
            return [{"id": 510301, "num": 60}]
        return None

    def allowed_skins(self, cid: int):
        return {1101011, 1101012, 1101099} if int(cid) == 110101 else set()

    def skin_exists(self, cid: int) -> bool:
        return int(cid) in {1101011, 1101012, 1101099}


class HeroProgressionHandlerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.cfg = FakeConfig()

    def hero(self, **overrides):
        value = {
            "id": "hero-1", "cid": 110101, "lvl": 1, "exp": 0,
            "advancedLvl": 0, "quality": 4, "skinCid": 1101011,
            "skillStrategyInfo": [{"id": 1, "name": "Default", "alreadyUseSkillPiont": 0,
                                   "angeSkillInfos": [], "passiveSkillInfo": []}],
            "useSkillStrategy": 1,
        }
        value.update(overrides)
        return value

    def test_protocols_exist_in_shipped_descriptors(self) -> None:
        reg = registry()
        for proto in hp.HERO_PROGRESSION_PROTOCOLS:
            self.assertIn(proto, reg.c2s)
            self.assertIn(proto, reg.s2c)
        self.assertIn(hp.HERO_HERO_INFO, reg.s2c)
        self.assertIn(hp.HERO_HERO_EXP_INFO, reg.s2c)

    def test_level_up_consumes_exp_item_and_pushes_hero_then_exp(self) -> None:
        state = {
            "lvl": 10,
            "heroes": [self.hero()],
            "items": {"510101": {"id": "510101", "cid": 510101, "num": 2, "ct": 0, "outTime": 0}},
        }
        body = request(hp.HERO_HERO_UPGRADE, {
            "heroId": "hero-1", "items": [{"itemId": 510101, "num": 1}],
        })
        result = hp.response_for(hp.HERO_HERO_UPGRADE, state, body, self.cfg)
        self.assertTrue(result.mutated)
        self.assertEqual(state["items"]["510101"]["num"], 1)
        self.assertEqual(state["heroes"][0]["lvl"], 2)
        self.assertEqual(state["heroes"][0]["exp"], 100)
        self.assertEqual([proto for proto, _ in result.extra_packets], [hp.HERO_HERO_INFO, hp.HERO_HERO_EXP_INFO])
        hero_push = response(hp.HERO_HERO_INFO, result.extra_packets[0][1])
        self.assertEqual(hero_push["id"], "hero-1")
        self.assertEqual(hero_push["lvl"], 2)
        exp_push = response(hp.HERO_HERO_EXP_INFO, result.extra_packets[1][1])
        self.assertEqual(exp_push, {"id": "hero-1", "exp": 100, "cid": 110101})
        self.assertEqual(response(hp.HERO_HERO_UPGRADE, result.body).get("rewards", []), [])

    def test_level_up_invalid_or_insufficient_request_is_atomic(self) -> None:
        state = {
            "lvl": 10,
            "heroes": [self.hero()],
            "items": {"510101": {"id": "510101", "cid": 510101, "num": 1}},
        }
        before = copy.deepcopy(state)
        bad = request(hp.HERO_HERO_UPGRADE, {
            "heroId": "hero-1", "items": [{"itemId": 510101, "num": 2}],
        })
        result = hp.response_for(hp.HERO_HERO_UPGRADE, state, bad, self.cfg)
        self.assertFalse(result.mutated)
        self.assertEqual(state, before)
        self.assertEqual(result.extra_packets, ())

    def test_advance_uses_exact_progress_cost_and_free_first_step(self) -> None:
        state = {"heroes": [self.hero()], "items": {}}
        body = request(hp.HERO_HERO_ADVANCE, {"heroId": "hero-1"})
        first = hp.response_for(hp.HERO_HERO_ADVANCE, state, body, self.cfg)
        self.assertTrue(first.mutated)
        self.assertEqual(state["heroes"][0]["advancedLvl"], 1)
        self.assertEqual(response(hp.HERO_HERO_ADVANCE, first.body)["hero"]["advancedLvl"], 1)

        state["items"] = {"510301": {"id": "510301", "cid": 510301, "num": 5}}
        second = hp.response_for(hp.HERO_HERO_ADVANCE, state, body, self.cfg)
        self.assertTrue(second.mutated)
        self.assertEqual(state["heroes"][0]["advancedLvl"], 2)
        self.assertEqual(state["items"]["510301"]["num"], 0)

    def test_quality_consumes_fragments_once(self) -> None:
        state = {
            "heroes": [self.hero()],
            "items": {"510301": {"id": "510301", "cid": 510301, "num": 60}},
        }
        body = request(hp.HERO_REQ_UP_QUALITY, {"heroId": "hero-1"})
        result = hp.response_for(hp.HERO_REQ_UP_QUALITY, state, body, self.cfg)
        self.assertTrue(result.mutated)
        self.assertEqual(state["heroes"][0]["quality"], 5)
        self.assertEqual(state["items"]["510301"]["num"], 0)
        again = hp.response_for(hp.HERO_REQ_UP_QUALITY, state, body, self.cfg)
        self.assertFalse(again.mutated)
        self.assertEqual(state["heroes"][0]["quality"], 5)

    def test_skin_requires_default_owned_item_or_quality_unlock(self) -> None:
        state = {
            "heroes": [self.hero()],
            "items": {"skin-instance": {"id": "skin-instance", "cid": 1101012, "num": 1}},
        }
        change = request(hp.HERO_REQ_CHANGE_HERO_SKIN, {
            "heroId": "hero-1", "skinId": "skin-instance", "isSwitch": False,
        })
        result = hp.response_for(hp.HERO_REQ_CHANGE_HERO_SKIN, state, change, self.cfg)
        self.assertTrue(result.mutated)
        self.assertEqual(state["heroes"][0]["skinCid"], 1101012)

        unowned = request(hp.HERO_REQ_CHANGE_HERO_SKIN, {
            "heroId": "hero-1", "skinId": "1101099", "isSwitch": False,
        })
        snapshot = copy.deepcopy(state)
        denied = hp.response_for(hp.HERO_REQ_CHANGE_HERO_SKIN, state, unowned, self.cfg)
        self.assertFalse(denied.mutated)
        self.assertEqual(state, snapshot)

        state["heroes"][0]["quality"] = 5
        super_skin = request(hp.HERO_REQ_CHANGE_HERO_SKIN, {
            "heroId": "hero-1", "skinId": "1101099", "isSwitch": True,
        })
        unlocked = hp.response_for(hp.HERO_REQ_CHANGE_HERO_SKIN, state, super_skin, self.cfg)
        self.assertTrue(unlocked.mutated)
        self.assertEqual(state["heroes"][0]["skinCid"], 1101099)

    def test_default_skin_can_be_restored_without_inventory_instance(self) -> None:
        state = {"heroes": [self.hero(skinCid=1101012)], "items": {}}
        body = request(hp.HERO_REQ_CHANGE_HERO_SKIN, {
            "heroId": "hero-1", "skinId": "1101011", "isSwitch": False,
        })
        result = hp.response_for(hp.HERO_REQ_CHANGE_HERO_SKIN, state, body, self.cfg)
        self.assertTrue(result.mutated)
        self.assertEqual(state["heroes"][0]["skinCid"], 1101011)


if __name__ == "__main__":
    unittest.main()
