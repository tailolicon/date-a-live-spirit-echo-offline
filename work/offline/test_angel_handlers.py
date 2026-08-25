#!/usr/bin/env python3
from __future__ import annotations

import copy
import unittest

import angel_handlers as ah
from protocol_schema import decode_fields, encode_fields, registry


def req(proto: int, values: dict) -> bytes:
    return encode_fields(registry().c2s[proto], values)


def res(proto: int, body: bytes) -> dict:
    return decode_fields(registry().s2c[proto], body)


class FakeConfig:
    def block(self, table: str, key: int):
        if table == "AngelSkillPage" and key in (1, 2, 3, 4):
            return "ok"
        return None

    def hero(self, cid: int):
        if int(cid) != 110101:
            return None
        return {"baseQuality": 4, "defaultSkin": 1101011, "angelLevelId": 1011, "openAngelStrengthen": 1}

    def angel_awake_cost(self, cid: int, level: int):
        return [{"id": 570018, "num": 100}] if int(cid) == 110101 and int(level) == 1 else None

    def angel_skill(self, cid: int, skill_type: int, pos: int, lvl: int):
        rows = {
            (1, 1, 1): {"id": 1001, "heroId": 110101, "skillType": 1, "pos": 1, "lvl": 1,
                         "needSkillPoint": 2, "needHeroLvl": 1, "needAngelLvl": 1, "frontCondition": []},
            (1, 1, 2): {"id": 1002, "heroId": 110101, "skillType": 1, "pos": 1, "lvl": 2,
                         "needSkillPoint": 3, "needHeroLvl": 2, "needAngelLvl": 1, "frontCondition": [1001]},
        }
        return rows.get((int(skill_type), int(pos), int(lvl))) if int(cid) == 110101 else None

    def angel_skill_by_id(self, node_id: int):
        rows = {
            1001: {"id": 1001, "heroId": 110101, "skillType": 1, "pos": 1, "lvl": 1,
                   "needSkillPoint": 2, "needHeroLvl": 1, "needAngelLvl": 1, "frontCondition": []},
            1002: {"id": 1002, "heroId": 110101, "skillType": 1, "pos": 1, "lvl": 2,
                   "needSkillPoint": 3, "needHeroLvl": 2, "needAngelLvl": 1, "frontCondition": [1001]},
            9001: {"id": 9001, "heroId": 110101, "skillType": 10, "pos": 3, "lvl": 1,
                   "needSkillPoint": 0, "needHeroLvl": 1, "needAngelLvl": 2, "frontCondition": []},
        }
        return rows.get(int(node_id))

    def passive_slot(self, pos: int):
        return {"pos": int(pos), "needHeroLvl": 0, "needAngelLvl": 2} if int(pos) == 1 else None

    def angel_strengthen_cost(self, cid: int, skill_type: int, lvl: int, cost_type: int):
        if int(cid) == 110101 and int(skill_type) == 1 and int(lvl) == 1:
            return [{"id": 667005 if int(cost_type) == 2 else 510301, "num": 2}]
        return None

    def angel_break_stage(self, cid: int, level: int):
        if int(cid) == 110101 and int(level) == 1:
            return {
                "level": 1,
                "costOptions": [[{"id": 510301, "num": 25}], [{"id": 570002, "num": 300}]],
                "reward": [{"id": 13, "num": 500}],
            }
        return None


class AngelHandlerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.cfg = FakeConfig()
        self.hero = {
            "id": "h1", "cid": 110101, "lvl": 2, "exp": 0, "attr": [{"type": 13, "val": 500}],
            "advancedLvl": 0, "angelLvl": 1, "quality": 4, "skinCid": 1101011,
            "skillStrategyInfo": [{"id": 1, "name": "Default", "alreadyUseSkillPiont": 0,
                                   "angeSkillInfos": [], "passiveSkillInfo": []}],
            "useSkillStrategy": 1, "angelStrengthen": [], "fightPower": 0,
        }
        self.state = {"lvl": 10, "heroes": [self.hero], "items": {}, "spiritInfo": {"angleSpirits": []}}

    def test_protocols_exist_in_real_descriptors(self) -> None:
        reg = registry()
        for proto in ah.ANGEL_PROTOCOLS:
            self.assertIn(proto, reg.c2s)
            self.assertIn(proto, reg.s2c)
        for proto in (ah.HERO_HERO_INFO, ah.HERO_RES_PROPERTY_CHANGE, ah.HERO_SPIRIT_RSP_SPIRIT_REFRESH):
            self.assertIn(proto, reg.s2c)

    def test_awake_consumes_exact_cost_and_pushes_hero(self) -> None:
        self.state["items"] = {"570018": {"id": "570018", "cid": 570018, "num": 100}}
        result = ah.response_for(ah.HERO_REQ_AWAKE_ANGEL, self.state,
                                 req(ah.HERO_REQ_AWAKE_ANGEL, {"heroId": "h1"}), self.cfg)
        self.assertTrue(result.mutated)
        self.assertEqual(self.hero["angelLvl"], 2)
        self.assertEqual(self.state["items"]["570018"]["num"], 0)
        self.assertEqual(res(ah.HERO_REQ_AWAKE_ANGEL, result.body)["angelLvl"], 2)
        self.assertEqual([p for p, _ in result.extra_packets], [ah.HERO_HERO_INFO])

    def test_skill_upgrade_and_downgrade_use_page_points(self) -> None:
        up = ah.response_for(ah.HERO_REQ_UPGRADE_SKILL, self.state, req(ah.HERO_REQ_UPGRADE_SKILL, {
            "heroId": "h1", "type": 1, "pos": 1, "operation": 1,
        }), self.cfg)
        self.assertTrue(up.mutated)
        page = self.hero["skillStrategyInfo"][0]
        self.assertEqual(page["angeSkillInfos"], [{"type": 1, "pos": 1, "lvl": 1}])
        self.assertEqual(page["alreadyUseSkillPiont"], 2)
        self.assertEqual(res(ah.HERO_REQ_UPGRADE_SKILL, up.body)["useSkillPiont"], 2)

        down = ah.response_for(ah.HERO_REQ_UPGRADE_SKILL, self.state, req(ah.HERO_REQ_UPGRADE_SKILL, {
            "heroId": "h1", "type": 1, "pos": 1, "operation": 2,
        }), self.cfg)
        self.assertTrue(down.mutated)
        self.assertEqual(page["angeSkillInfos"], [])
        self.assertEqual(page["alreadyUseSkillPiont"], 0)

    def test_skill_upgrade_respects_point_budget_and_prerequisites(self) -> None:
        page = self.hero["skillStrategyInfo"][0]
        page["angeSkillInfos"] = [{"type": 1, "pos": 1, "lvl": 1}]
        page["alreadyUseSkillPiont"] = 4  # only one point remains; level 2 costs three
        before = copy.deepcopy(self.state)
        result = ah.response_for(ah.HERO_REQ_UPGRADE_SKILL, self.state, req(ah.HERO_REQ_UPGRADE_SKILL, {
            "heroId": "h1", "type": 1, "pos": 1, "operation": 1,
        }), self.cfg)
        self.assertFalse(result.mutated)
        self.assertEqual(self.state, before)

    def test_passive_equip_requires_unlocked_slot_and_can_unload(self) -> None:
        self.hero["angelLvl"] = 2
        equip = ah.response_for(ah.HERO_REQ_EQUIP_PASSIVE_SKILL, self.state, req(ah.HERO_REQ_EQUIP_PASSIVE_SKILL, {
            "heroId": "h1", "skillId": 9001, "pos": 1,
        }), self.cfg)
        self.assertTrue(equip.mutated)
        page = self.hero["skillStrategyInfo"][0]
        self.assertEqual(page["passiveSkillInfo"], [{"pos": 1, "skillId": 9001}])
        unload = ah.response_for(ah.HERO_REQ_EQUIP_PASSIVE_SKILL, self.state, req(ah.HERO_REQ_EQUIP_PASSIVE_SKILL, {
            "heroId": "h1", "skillId": 9001,
        }), self.cfg)
        self.assertTrue(unload.mutated)
        self.assertEqual(res(ah.HERO_REQ_EQUIP_PASSIVE_SKILL, unload.body)["passiveSkillInfo"], {"pos": 1, "skillId": 0})

    def test_reset_and_rename_preserve_strategy_identity(self) -> None:
        rename = ah.response_for(ah.HERO_REQ_MODIFY_STRATEGY_NAME, self.state,
                                 req(ah.HERO_REQ_MODIFY_STRATEGY_NAME, {
                                     "heroId": "h1", "skillStrategyId": 2, "name": "Boss",
                                 }), self.cfg)
        self.assertTrue(rename.mutated)
        page = next(row for row in self.hero["skillStrategyInfo"] if row["id"] == 2)
        page["angeSkillInfos"] = [{"type": 1, "pos": 1, "lvl": 1}]
        page["alreadyUseSkillPiont"] = 2
        reset = ah.response_for(ah.HERO_REQ_RESET_SKILL, self.state, req(ah.HERO_REQ_RESET_SKILL, {
            "heroId": "h1", "skillStrategyId": 2,
        }), self.cfg)
        self.assertTrue(reset.mutated)
        decoded = res(ah.HERO_REQ_RESET_SKILL, reset.body)["skillStrategy"]
        self.assertEqual(decoded["id"], 2)
        self.assertEqual(decoded["name"], "Boss")
        self.assertEqual(decoded["alreadyUseSkillPiont"], 0)

    def test_strengthen_uses_selected_cost_path(self) -> None:
        self.state["items"] = {"667005": {"id": "667005", "cid": 667005, "num": 2}}
        result = ah.response_for(ah.HERO_REQ_ANGEL_STRENGTHEN, self.state,
                                 req(ah.HERO_REQ_ANGEL_STRENGTHEN, {
                                     "heroId": "h1", "skillType": 1, "costType": 2,
                                 }), self.cfg)
        self.assertTrue(result.mutated)
        self.assertEqual(self.hero["angelStrengthen"], [{"skillType": 1, "lv": 1}])
        self.assertEqual(self.state["items"]["667005"]["num"], 0)

    def test_breakthrough_consumes_one_alternative_and_pushes_spirit_and_attr(self) -> None:
        self.state["items"] = {"570002": {"id": "570002", "cid": 570002, "num": 300}}
        result = ah.response_for(ah.HERO_SPIRIT_REQ_UPGRADE_ANGLE_SPIRIT, self.state,
                                 req(ah.HERO_SPIRIT_REQ_UPGRADE_ANGLE_SPIRIT, {
                                     "hero": 110101, "costId": 2,
                                 }), self.cfg)
        self.assertTrue(result.mutated)
        self.assertEqual(self.state["items"]["570002"]["num"], 0)
        self.assertEqual(self.state["spiritInfo"]["angleSpirits"], [{"heroCid": 110101, "lv": 1}])
        self.assertEqual(self.hero["breakLv"], 1)
        self.assertEqual(self.hero["attr"][0], {"type": 13, "val": 500})
        self.assertEqual([p for p, _ in result.extra_packets], [
            ah.HERO_SPIRIT_RSP_SPIRIT_REFRESH, ah.HERO_RES_PROPERTY_CHANGE, ah.HERO_HERO_INFO,
        ])
        spirit = res(ah.HERO_SPIRIT_RSP_SPIRIT_REFRESH, result.extra_packets[0][1])["spirits"]
        self.assertEqual(spirit["angleSpirits"][0]["lv"], 1)

    def test_invalid_costed_operations_are_atomic(self) -> None:
        before = copy.deepcopy(self.state)
        awake = ah.response_for(ah.HERO_REQ_AWAKE_ANGEL, self.state,
                                req(ah.HERO_REQ_AWAKE_ANGEL, {"heroId": "h1"}), self.cfg)
        self.assertFalse(awake.mutated)
        self.assertEqual(self.state, before)
        brk = ah.response_for(ah.HERO_SPIRIT_REQ_UPGRADE_ANGLE_SPIRIT, self.state,
                              req(ah.HERO_SPIRIT_REQ_UPGRADE_ANGLE_SPIRIT, {"hero": 110101, "costId": 1}), self.cfg)
        self.assertFalse(brk.mutated)
        self.assertEqual(self.state, before)


if __name__ == "__main__":
    unittest.main()
