#!/usr/bin/env python3
"""Entering a stage must work for every kind of stage the story uses.

`FubenDataMgr:onRecvFightStart` branches on `DungeonLevel.dungeonType`, and
each branch waits on a different reply. Every one of those branches has failed
the same way at some point: the server answered with a structurally valid but
empty body, the client took its "nothing here" path, and the stage silently
refused to open. None of that shows up as a protocol error, so it is asserted
here instead - one case per branch, driven by the real shipped tables.
"""
from __future__ import annotations

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import city_dating_handlers as city  # noqa: E402
import combat_handlers as combat  # noqa: E402
import dating_handlers as dating  # noqa: E402
import dungeon_handlers as dungeon  # noqa: E402
import proto_validate  # noqa: E402
import role_handlers as role  # noqa: E402
from game_static_config import StaticConfigUnavailable, config as static_config  # noqa: E402
from hero_stats import battle_attributes  # noqa: E402
from player_save import default_save  # noqa: E402
from protocol_schema import decode_fields, encode_fields, registry  # noqa: E402

# EC_FBLevelType
FIGHTING, DATING, CITYDATING = 1, 2, 3
# EC_Attr.HP - a hero with no max HP is dead on the first frame of the fight.
ATTR_HP = 1

VOLUME_ONE = (101101, 101102, 101103, 101104, 101105, 101206)


def request(proto: int, values: dict) -> bytes:
    return encode_fields(registry().c2s[proto], values)


def response(proto: int, body: bytes) -> dict:
    return decode_fields(registry().s2c[proto], body)


def apk_available() -> bool:
    try:
        static_config().dungeon_definition(101101)
    except StaticConfigUnavailable:
        return False
    return True


@unittest.skipUnless(apk_available(), "needs work/apk/base-offline.apk")
class StageEntryTests(unittest.TestCase):
    def setUp(self) -> None:
        self.cfg = static_config()
        self.state = default_save()

    # -- the stage list itself ------------------------------------------------

    def test_volume_one_only_uses_stage_types_we_implement(self) -> None:
        """A new dungeonType in the story path is a stage nobody can enter."""
        supported = {FIGHTING, DATING, CITYDATING}
        unsupported = {}
        for cid in VOLUME_ONE:
            definition = self.cfg.dungeon_definition(cid) or {}
            kind = int(definition.get("dungeonType", 0))
            if kind not in supported:
                unsupported[cid] = kind
        self.assertEqual(unsupported, {})

    # -- dungeonType 1: a fight ----------------------------------------------

    def test_limit_hero_stage_hands_out_a_usable_team(self) -> None:
        """s2c 1808 with no `heros` is dropped by onRecvLimitHeros.

        FubenSquadView then has an empty formationData_ and the Fight button
        only shows "no spirit in the lineup".
        """
        body, _ = dungeon.response_for(
            dungeon.DUNGEON_LIMIT_HERO_DUNGEON, self.state,
            request(dungeon.DUNGEON_LIMIT_HERO_DUNGEON, {"levelId": 101101}))
        self.assertTrue(proto_validate.validate(1808, body).ok)
        data = response(1808, body)
        self.assertEqual(data["leveId"], 101101)
        self.assertTrue(data["heros"], "stage 1-1 lends a spirit; the list must not be empty")
        self.assertTrue(data["limitFormation"]["stance"])
        lent = data["heros"][0]["heros"]
        attrs = {row["type"]: row["val"] for row in lent["attr"]}
        self.assertGreater(attrs.get(ATTR_HP, 0), 0, "a lent spirit needs max HP to survive a frame")

    def test_own_formation_stage_has_hero_stats(self) -> None:
        """Property:init reads a hero's stats verbatim; an empty attr is 0 HP."""
        hero = self.state["heroes"][0]
        attrs = {row["type"]: row["val"] for row in battle_attributes(hero)}
        self.assertGreater(attrs.get(ATTR_HP, 0), 0)

    def test_fight_start_omits_the_assist_when_there_is_none(self) -> None:
        """`if serverData.hero then` treats a zero-filled submessage as real.

        transData then clones Hero[0], which does not exist, and the battle
        scene dies on entry.
        """
        body = request(1793, {"levelCid": 101101,
                              "limitHeros": [{"limitType": 2, "limitCid": 1000}]})
        payload, _ = combat.response_for(1793, self.state, body)
        self.assertTrue(proto_validate.validate(1793, payload).ok)
        data = response(1793, payload)
        self.assertNotIn("hero", data)
        self.assertEqual(data["levelCid"], 101101)
        self.assertTrue(data["fightId"])
        self.assertGreater(data["randomSeed"], 0)

    def test_clearing_a_stage_pays_the_player_level_it_gates_on(self) -> None:
        """1-2 needs Lv.2 and FubenLevelView makes a locked node untouchable."""
        start = request(1793, {"levelCid": 101101})
        combat.response_for(1793, self.state, start)
        finish = request(1794, {"levelCid": 101101, "isWin": True, "goals": [1, 2, 3]})
        payload, changed = combat.response_for(1794, self.state, finish)
        self.assertTrue(changed)
        self.assertTrue(proto_validate.validate(1794, payload).ok)
        self.assertIn(101101, self.state["passedLevels"])
        next_cid = (self.cfg.dungeon_definition(101101) or {}).get("nextLevelCid")
        needed = (self.cfg.dungeon_definition(next_cid) or {}).get("playerLvl", 0)
        self.assertGreaterEqual(self.state["lvl"], needed)

    # -- dungeonType 2: a visual-novel stage ---------------------------------

    def test_story_stage_gets_its_script_pushed(self) -> None:
        """The reply to c2s 1537 is empty; the script rides on s2c 1542."""
        dating_ids = self.cfg.dungeon_dating_ids(101102)
        self.assertTrue(dating_ids)
        body = request(1537, {"scriptType": dating.FUBEN_SCRIPT, "scriptId": dating_ids[0]})
        extras = dating.extra_packets(self.state, 1537, body)
        self.assertEqual([proto for proto, _ in extras], [dating.DATING_DATING_SCRIPT])
        payload = extras[0][1]
        self.assertTrue(proto_validate.validate(1542, payload).ok)
        self.assertEqual(response(1542, payload)["datingRuleCid"], dating_ids[0])

    def test_story_stage_settles_on_its_last_node(self) -> None:
        """Without s2c 1540 the script stops dead on its final line."""
        dating_ids = self.cfg.dungeon_dating_ids(101102)
        dating.extra_packets(self.state, 1537, request(
            1537, {"scriptType": dating.FUBEN_SCRIPT, "scriptId": dating_ids[0]}))
        mid = request(1538, {"selectedNodeId": 1011002, "isLastNode": False,
                             "datingType": dating.FUBEN_SCRIPT})
        self.assertEqual(dating.extra_packets(self.state, 1538, mid), ())
        last = request(1538, {"selectedNodeId": 1011103, "isLastNode": True,
                              "datingType": dating.FUBEN_SCRIPT})
        extras = dating.extra_packets(self.state, 1538, last)
        self.assertEqual([proto for proto, _ in extras], [dating.DATING_DATING_SETTLEMENT])
        payload = extras[0][1]
        self.assertTrue(proto_validate.validate(1540, payload).ok)
        # datingSettlementMsgHandle indexes datingRuleTable[scriptId].type.
        self.assertIsNotNone(self.cfg.dating_rule(response(1540, payload)["scriptId"]))

    def test_a_settlement_needs_a_board_girl_to_land_on(self) -> None:
        """It calls setMainLiveStateByRuleCid, which indexes roleTable[curId]."""
        body, _ = role.response_for(role.ROLE_GET_ROLE, self.state)
        self.assertTrue(proto_validate.validate(1281, body).ok)
        roles = response(1281, body)["roles"]
        self.assertTrue(roles)
        on_duty = [row for row in roles if row.get("status") == role.ROLE_STATUS_ON_DUTY]
        self.assertTrue(on_duty, "roleHandle only sets useId from a status==1 row")
        self.assertTrue(on_duty[0]["isShow"])

    # -- dungeonType 3: a town stage -----------------------------------------

    def test_town_stage_gets_entrances_to_index(self) -> None:
        """onRespDatingMainInfo reads entrances[1].entranceId with no guard."""
        dating_ids = self.cfg.dungeon_dating_ids(101206)
        self.assertTrue(dating_ids)
        body = request(5633, {"datingType": city.NEW_CITY_FUBEN,
                              "datingValue": dating_ids[0], "roleId": 105})
        result = city.response_for(5633, self.state, body)
        self.assertIsNotNone(result, "a town stage with no info never draws its map")
        payload, _ = result
        self.assertTrue(proto_validate.validate(5633, payload).ok)
        info = response(5633, payload)["info"]
        self.assertTrue(info["entrances"])
        entrance = info["entrances"][0]["entranceId"]
        # The client turns that id straight into the step it builds the town from.
        event = self.cfg.city_event(city.NEW_CITY_FUBEN, entrance)
        self.assertIsNotNone(event)
        self.assertIsNotNone(self.cfg.city_step(
            city.NEW_CITY_FUBEN, dating_ids[0], event["stepId"]))

    def test_clearing_a_town_stage_advances_its_line(self) -> None:
        dating_ids = self.cfg.dungeon_dating_ids(101206)
        city.dating_info(self.state, city.NEW_CITY_FUBEN, dating_ids[0])
        before = self.state["cityDatings"][f"{city.NEW_CITY_FUBEN}:{dating_ids[0]}"]["stepId"]
        self.assertTrue(city.advance_line(self.state, city.NEW_CITY_FUBEN, dating_ids[0]))
        after = self.state["cityDatings"][f"{city.NEW_CITY_FUBEN}:{dating_ids[0]}"]["stepId"]
        self.assertNotEqual(before, after)


if __name__ == "__main__":
    unittest.main()
