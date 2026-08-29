#!/usr/bin/env python3
"""Summoning has to resolve a real banner, not a shaped blank.

`SummonDataMgr:onRecvSummon` reads `getSummonCfg(data.id).summonType` behind
scalar guards (`preciousCount`, `sixGuaranteesCount`, `wishId`) that a zero is
truthy for in Lua, so a zero-filled reply throws on every pull. That crash is
silent - it goes to Bugly - which is what kept it invisible.
"""
from __future__ import annotations

import os
import random
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import proto_validate  # noqa: E402
import summon_handlers as summon  # noqa: E402
from game_static_config import StaticConfigUnavailable, config as static_config  # noqa: E402
from hero_stats import battle_attributes  # noqa: E402
from player_save import default_save  # noqa: E402
from protocol_schema import decode_fields, encode_fields, registry  # noqa: E402
from state_transactions import item_count  # noqa: E402

BANNER = 1
ATTR_HP = 1


def request(values: dict) -> bytes:
    return encode_fields(registry().c2s[summon.SUMMON_SUMMON], values)


def apk_available() -> bool:
    try:
        static_config().summon(BANNER)
    except StaticConfigUnavailable:
        return False
    return True


@unittest.skipUnless(apk_available(), "needs work/apk/base-offline.apk")
class SummonTests(unittest.TestCase):
    def setUp(self) -> None:
        self.cfg = static_config()
        self.state = default_save()
        self.rng = random.Random(20260826)
        self.ticket = self.cfg.summon(BANNER)["costs"][0][0]["id"]

    def pull(self) -> dict | None:
        return summon.summon(self.state, {"cid": BANNER, "cost": 1}, rng=self.rng)

    def test_reply_names_a_real_banner(self) -> None:
        values = self.pull()
        self.assertIsNotNone(values)
        body = summon.encode_response(summon.SUMMON_SUMMON, values)
        self.assertTrue(proto_validate.validate(summon.SUMMON_SUMMON, body).ok)
        data = decode_fields(registry().s2c[summon.SUMMON_SUMMON], body)
        self.assertIsNotNone(self.cfg.summon(data["id"]),
                             "getSummonCfg(data.id) is indexed with no guard")
        self.assertTrue(data["item"], "onRecvSummon returns early without item")

    def test_optional_submessages_stay_absent(self) -> None:
        """A zero-filled noobInfo/freeInfo is a *present* table to the client."""
        values = self.pull()
        body = summon.encode_response(summon.SUMMON_SUMMON, values)
        data = decode_fields(registry().s2c[summon.SUMMON_SUMMON], body)
        for field in ("noobInfo", "freeInfo", "freeTime"):
            self.assertNotIn(field, data)

    def test_a_pull_is_paid_for(self) -> None:
        """The first pull may take the discounted `firstCost` currency instead."""
        prices = self.cfg.summon(BANNER)
        currencies = {row["id"] for option in prices["costs"] + prices["firstCosts"]
                      for row in option}
        before = sum(item_count(self.state, cid=cid) for cid in currencies)
        self.pull()
        after = sum(item_count(self.state, cid=cid) for cid in currencies)
        self.assertLess(after, before)

    def test_no_tickets_means_no_pull(self) -> None:
        for row in self.state["items"].values():
            row["num"] = 0
        self.assertIsNone(self.pull(), "a broke player must not get a free pull")

    def test_every_drawn_item_is_a_real_row(self) -> None:
        for _ in range(40):
            values = self.pull()
            self.assertIsNotNone(values)
            for row in values["item"]:
                cid = int(row["id"])
                known = (self.cfg.hero(cid) is not None
                         or self.cfg.equipment(cid) is not None
                         or self.cfg.block("Item", cid) is not None)
                self.assertTrue(known, f"pool handed out unknown id {cid}")

    def test_a_summoned_spirit_joins_the_roster_ready_to_fight(self) -> None:
        owned = {int(hero["cid"]) for hero in self.state["heroes"]}
        for _ in range(200):
            self.pull()
        new = [hero for hero in self.state["heroes"] if int(hero["cid"]) not in owned]
        self.assertTrue(new, "pool 1 contains spirits; 200 pulls should land one")
        for hero in new:
            self.assertIsNotNone(self.cfg.hero(int(hero["cid"])))
            attrs = {row["type"]: row["val"] for row in battle_attributes(hero)}
            self.assertGreater(attrs.get(ATTR_HP, 0), 0)

    def test_equipment_is_stocked_as_equipment_not_as_an_item(self) -> None:
        """__equipmentHandle and __itemHandle are different stores."""
        for _ in range(60):
            self.pull()
        equipment_cids = {int(row["cid"]) for row in self.state["equipments"]}
        self.assertTrue(equipment_cids, "pool 1 is mostly equipment")
        bag_cids = {int(row["cid"]) for row in self.state["items"].values()}
        self.assertEqual(equipment_cids & bag_cids, set())
        for cid in equipment_cids:
            self.assertIsNotNone(self.cfg.equipment(cid))

    def test_a_duplicate_spirit_is_not_added_twice(self) -> None:
        for _ in range(200):
            self.pull()
        cids = [int(hero["cid"]) for hero in self.state["heroes"]]
        self.assertEqual(len(cids), len(set(cids)))


@unittest.skipUnless(apk_available(), "needs work/apk/base-offline.apk")
class StoreCatalogueTests(unittest.TestCase):
    """SummonBuyResourceView prices the "+" button by commodity id.

    `StoreDataMgr.commodityMap_` is filled only from s2c 2569, so an empty
    store list makes `getCommodityCfg` nil and the popup throws on open.
    """

    def test_a_summon_ticket_can_be_priced(self) -> None:
        import stateful_handlers

        cfg = static_config()
        commodity_id = cfg.summon(BANNER)["costCommodity"]
        self.assertGreater(commodity_id, 0)
        body, _ = stateful_handlers.response_for(
            stateful_handlers.STORE_GET_STORE_INFO, default_save(), b"")
        self.assertTrue(proto_validate.validate(
            stateful_handlers.STORE_GET_STORE_INFO, body).ok)
        data = decode_fields(registry().s2c[stateful_handlers.STORE_GET_STORE_INFO], body)
        listed = {int(row["id"]): row
                  for store in data["stores"] for row in store["commoditys"]}
        self.assertIn(commodity_id, listed)
        row = listed[commodity_id]
        # initData reads goodInfo[1] and priceType[1]/priceVal[1] with no guard.
        self.assertTrue(row["goodInfo"])
        self.assertTrue(row["priceType"])
        self.assertTrue(row["priceVal"])

    def test_store_refresh_is_present_and_pic_is_not(self) -> None:
        """__handleStoreInfo seeds storeInfo_ from storeRefresh, then writes to it.

        Without the refresh block `storeInfo_[storeCid]` is nil and the next
        line indexes it; with an empty `pic` string that next line always runs,
        because "" is truthy in Lua.
        """
        import stateful_handlers

        body, _ = stateful_handlers.response_for(
            stateful_handlers.STORE_GET_STORE_INFO, default_save(), b"")
        data = decode_fields(registry().s2c[stateful_handlers.STORE_GET_STORE_INFO], body)
        self.assertTrue(data["stores"])
        for store in data["stores"]:
            self.assertIn("storeRefresh", store)
            self.assertNotIn("pic", store)

    def test_extra_is_absent_rather_than_an_empty_string(self) -> None:
        """`if cfg.extra then json.decode(cfg.extra)` - "" is truthy in Lua.

        StoreDataMgr:sortWithCommodity then indexes the nil decode result and
        every store screen throws.
        """
        import stateful_handlers

        body, _ = stateful_handlers.response_for(
            stateful_handlers.STORE_GET_STORE_INFO, default_save(), b"")
        data = decode_fields(registry().s2c[stateful_handlers.STORE_GET_STORE_INFO], body)
        for store in data["stores"]:
            self.assertNotIn("extra", store["store"])
            for row in store["commoditys"]:
                self.assertNotIn("extra", row)


if __name__ == "__main__":
    unittest.main()
