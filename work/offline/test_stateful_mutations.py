#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import player_save
import state_transactions as tx
import stateful_handlers as sh
from protocol_schema import decode_fields, encode_fields, registry


class InventoryTransactionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.state = player_save.default_save()

    def test_consume_cids_is_atomic(self) -> None:
        before_gold = tx.item_count(self.state, cid=player_save.GOLD_CID)
        before_diamond = tx.item_count(self.state, cid=player_save.DIAMOND_CID)
        ok = tx.consume_cids(self.state, [
            {"id": player_save.GOLD_CID, "num": 100},
            {"id": player_save.DIAMOND_CID, "num": before_diamond + 1},
        ])
        self.assertFalse(ok)
        self.assertEqual(tx.item_count(self.state, cid=player_save.GOLD_CID), before_gold)
        self.assertEqual(tx.item_count(self.state, cid=player_save.DIAMOND_CID), before_diamond)

    def test_grant_rewards_updates_currency_mirror(self) -> None:
        before = self.state["gold"]
        tx.grant_rewards(self.state, [{"id": player_save.GOLD_CID, "num": 25}])
        self.assertEqual(self.state["gold"], before + 25)


class StatefulMutationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.state = player_save.default_save()
        self.reg = registry()

    def request_body(self, proto: int, values: dict) -> bytes:
        return encode_fields(self.reg.c2s[proto], values)

    def response(self, proto: int, body: bytes) -> tuple[dict, bool]:
        payload, changed = sh.response_for(proto, self.state, body)
        return decode_fields(self.reg.s2c[proto], payload), changed

    def test_new_protocol_descriptors_exist(self) -> None:
        for proto in (
            sh.ITEM_USE_ITEM, sh.MAIL_MAIL_HANDLE,
            sh.TASK_SUBMIT_TASK_LIST, sh.TASK_SUBMIT_TASK,
            sh.STORE_BUY_GOODS, sh.STORE_REFRESH_STORE,
            sh.STORE_GET_COMMODITY_BUY_LOG, sh.STORE_SELL_INFO,
            sh.STORE_SELL_GOODS_PREVIEW, sh.STORE_GET_STORE_INFO,
            sh.FRIEND_REQ_FRIENDS, sh.FRIEND_REQ_RECOMMEND,
            sh.SIGN_REQ_SEVEN_CARNIVAL,
        ):
            self.assertIn(proto, self.reg.c2s)
            self.assertIn(proto, self.reg.s2c)

    def test_item_use_consumes_configured_item_and_grants_reward(self) -> None:
        self.state["items"]["box-1"] = {
            "ct": 0, "id": "box-1", "cid": 600001, "num": 3, "outTime": 0,
            "useRewards": [{"id": player_save.GOLD_CID, "num": 10}],
        }
        before_gold = self.state["gold"]
        body = self.request_body(sh.ITEM_USE_ITEM, {
            "items": [{"itemId": "box-1", "num": 2}],
            "heroId": "", "roleId": "", "customParame": [],
        })
        data, changed = self.response(sh.ITEM_USE_ITEM, body)
        self.assertTrue(changed)
        self.assertEqual(self.state["items"]["box-1"]["num"], 1)
        self.assertEqual(self.state["gold"], before_gold + 20)
        self.assertEqual(data["items"], [{"id": player_save.GOLD_CID, "num": 20}])

    def test_item_use_rejects_unconfigured_item_without_consuming(self) -> None:
        self.state["items"]["plain"] = {
            "ct": 0, "id": "plain", "cid": 600002, "num": 2, "outTime": 0,
        }
        body = self.request_body(sh.ITEM_USE_ITEM, {"items": [{"itemId": "plain", "num": 1}]})
        data, changed = self.response(sh.ITEM_USE_ITEM, body)
        self.assertFalse(changed)
        self.assertEqual(self.state["items"]["plain"]["num"], 2)
        self.assertEqual(data.get("items", []), [])

    def test_mail_claim_is_idempotent_then_delete_works(self) -> None:
        self.state["mails"] = [{
            "ct": 0, "id": "mail-1", "status": 0, "mailType": 1,
            "rewards": [{"id": player_save.DIAMOND_CID, "num": 7}],
        }]
        before = self.state["diamonds"]
        claim = self.request_body(sh.MAIL_MAIL_HANDLE, {"ids": ["mail-1"], "type": 2})
        data, changed = self.response(sh.MAIL_MAIL_HANDLE, claim)
        self.assertTrue(changed)
        self.assertEqual(self.state["mails"][0]["status"], 2)
        self.assertEqual(self.state["diamonds"], before + 7)
        self.assertEqual(data["rewards"], [{"id": player_save.DIAMOND_CID, "num": 7}])
        data2, changed2 = self.response(sh.MAIL_MAIL_HANDLE, claim)
        self.assertFalse(changed2)
        self.assertEqual(self.state["diamonds"], before + 7)
        self.assertEqual(data2.get("rewards", []), [])
        delete = self.request_body(sh.MAIL_MAIL_HANDLE, {"ids": ["mail-1"], "type": 3})
        _, deleted = self.response(sh.MAIL_MAIL_HANDLE, delete)
        self.assertTrue(deleted)
        self.assertEqual(self.state["mails"], [])

    def test_mail_read_does_not_claim_reward(self) -> None:
        self.state["mails"] = [{
            "ct": 0, "id": "mail-r", "status": 0,
            "rewards": [{"id": player_save.GOLD_CID, "num": 99}],
        }]
        before = self.state["gold"]
        body = self.request_body(sh.MAIL_MAIL_HANDLE, {"ids": ["mail-r"], "type": 1})
        _, changed = self.response(sh.MAIL_MAIL_HANDLE, body)
        self.assertTrue(changed)
        self.assertEqual(self.state["mails"][0]["status"], 1)
        self.assertEqual(self.state["gold"], before)

    def test_single_task_claim_is_idempotent(self) -> None:
        self.state["tasks"] = [{
            "ct": 0, "id": "db-10", "cid": 10, "progress": 1, "status": 1,
            "rewards": [{"id": player_save.GOLD_CID, "num": 50}],
        }]
        before = self.state["gold"]
        body = self.request_body(sh.TASK_SUBMIT_TASK, {"taskCid": 10})
        data, changed = self.response(sh.TASK_SUBMIT_TASK, body)
        self.assertTrue(changed)
        self.assertEqual(data["taskDbId"], "db-10")
        self.assertEqual(data["taskCid"], 10)
        self.assertEqual(data["rewards"], [{"id": player_save.GOLD_CID, "num": 50}])
        self.assertEqual(self.state["gold"], before + 50)
        self.assertEqual(self.state["tasks"][0]["status"], 2)
        _, changed2 = self.response(sh.TASK_SUBMIT_TASK, body)
        self.assertFalse(changed2)
        self.assertEqual(self.state["gold"], before + 50)

    def test_batch_task_claim_aggregates_rewards_once(self) -> None:
        self.state["tasks"] = [
            {"ct": 0, "id": "101", "cid": 11, "progress": 1, "status": 1,
             "rewards": [{"id": player_save.GOLD_CID, "num": 3}]},
            {"ct": 0, "id": "102", "cid": 12, "progress": 1, "status": 1,
             "rewards": [{"id": player_save.GOLD_CID, "num": 4}]},
        ]
        before = self.state["gold"]
        body = self.request_body(sh.TASK_SUBMIT_TASK_LIST, {"taskId": [101, 102, 101]})
        data, changed = self.response(sh.TASK_SUBMIT_TASK_LIST, body)
        self.assertTrue(changed)
        self.assertEqual(self.state["gold"], before + 7)
        self.assertEqual(len(data["result"]), 2)
        self.assertEqual(data["rewards"], [{"id": player_save.GOLD_CID, "num": 7}])

    def seed_store(self, limit_type: int = 3, limit_val: int = 2) -> None:
        self.state["stores"] = [{
            "storeId": 100,
            "store": {
                "icon": "", "name": 1, "roleSet": 0, "showCurrency": [player_save.GOLD_CID],
                "autoRefreshCorn": False, "manualRefresh": True,
                "refreshCostId": player_save.GOLD_CID, "refreshCostNum": [5],
                "openContVal": 0, "openContType": 1, "commoditySupplyType": 1,
                "showBeginTime": 0, "buyBeginTime": 0, "buyEndTime": 0,
                "showEndTime": 0, "rank": 1, "storeType": 1, "openTimeType": 0,
                "extra": "",
            },
            "commoditys": [{
                "id": 200, "grid": 1, "order": 1, "openContType": 1, "openContVal": 0,
                "buyBeginTime": 0, "buyEndTime": 0, "sellTimeType": 0,
                "limitType": limit_type, "batchBuy": 1, "serLimit": 0,
                "sellDescribtion": 0, "goodInfo": [{"id": 600100, "num": 2}],
                "priceType": [player_save.GOLD_CID], "priceVal": [10],
                "des": 0, "title": 0, "tag": 0, "autoRefreshCorn": False,
                "showBeginTime": 0, "showEndTime": 0, "limitVal": limit_val, "extra": "",
            }],
            "storeRefresh": {"todayRefreshCount": 0, "totalRefreshCount": 0, "nextRefreshTime": 0, "freeNum": 0},
            "pic": "", "groupRefreshTime": 0,
        }]

    def test_store_get_buy_logs_and_limit(self) -> None:
        self.seed_store()
        start_gold = self.state["gold"]
        get_data, get_changed = self.response(sh.STORE_GET_STORE_INFO, b"")
        self.assertFalse(get_changed)
        self.assertEqual(get_data["stores"][0]["storeId"], 100)
        buy = self.request_body(sh.STORE_BUY_GOODS, {"cid": 200, "num": 2})
        data, changed = self.response(sh.STORE_BUY_GOODS, buy)
        self.assertTrue(changed)
        self.assertEqual(data["goods"], [{"id": 600100, "num": 4}])
        self.assertEqual(self.state["gold"], start_gold - 20)
        self.assertEqual(tx.item_count(self.state, cid=600100), 4)
        data2, changed2 = self.response(sh.STORE_BUY_GOODS, self.request_body(sh.STORE_BUY_GOODS, {"cid": 200, "num": 1}))
        self.assertFalse(changed2)
        self.assertEqual(data2.get("goods", []), [])
        self.assertEqual(self.state["gold"], start_gold - 20)
        logs, _ = self.response(sh.STORE_GET_COMMODITY_BUY_LOG, b"")
        self.assertEqual(logs["buyLogs"][0]["totalBuyCount"], 2)

    def test_store_buy_insufficient_currency_is_atomic(self) -> None:
        self.seed_store(limit_type=0, limit_val=0)
        self.state["items"][str(player_save.GOLD_CID)]["num"] = 5
        self.state["gold"] = 5
        body = self.request_body(sh.STORE_BUY_GOODS, {"cid": 200, "num": 1})
        data, changed = self.response(sh.STORE_BUY_GOODS, body)
        self.assertFalse(changed)
        self.assertEqual(self.state["gold"], 5)
        self.assertEqual(tx.item_count(self.state, cid=600100), 0)
        self.assertEqual(data.get("goods", []), [])

    def test_store_refresh_charges_and_resets_cycle_limit(self) -> None:
        self.seed_store(limit_type=1, limit_val=2)
        sh._purchase_record(self.state, 200)["cycle"] = 2
        before = self.state["gold"]
        body = self.request_body(sh.STORE_REFRESH_STORE, {"cid": 100})
        data, changed = self.response(sh.STORE_REFRESH_STORE, body)
        self.assertTrue(changed)
        self.assertEqual(self.state["gold"], before - 5)
        self.assertEqual(sh._purchase_record(self.state, 200)["cycle"], 0)
        self.assertEqual(data["stores"][0]["storeRefresh"]["todayRefreshCount"], 1)

    def test_sell_preview_does_not_mutate_and_commit_does(self) -> None:
        self.state["items"]["loot"] = {
            "ct": 0, "id": "loot", "cid": 600200, "num": 3, "outTime": 0,
            "sellRewards": [{"id": player_save.GOLD_CID, "num": 6}],
        }
        before = self.state["gold"]
        req_values = {"goods": [{"id": "loot", "num": 2}]}
        data, changed = self.response(sh.STORE_SELL_GOODS_PREVIEW, self.request_body(sh.STORE_SELL_GOODS_PREVIEW, req_values))
        self.assertFalse(changed)
        self.assertEqual(self.state["items"]["loot"]["num"], 3)
        self.assertEqual(self.state["gold"], before)
        self.assertEqual(data["rewards"], [{"id": player_save.GOLD_CID, "num": 12}])
        data2, changed2 = self.response(sh.STORE_SELL_INFO, self.request_body(sh.STORE_SELL_INFO, req_values))
        self.assertTrue(changed2)
        self.assertTrue(data2["success"])
        self.assertEqual(self.state["items"]["loot"]["num"], 1)
        self.assertEqual(self.state["gold"], before + 12)

    def test_friend_and_seven_carnival_reads(self) -> None:
        self.state["friends"] = [{
            "pid": 9, "name": "Offline Friend", "fightPower": 1, "lvl": 1,
            "lastLoginTime": 0, "lastHandselTime": 0, "receive": False, "status": 1,
            "leaderCid": 0, "online": True, "ct": 0, "time": 0, "helpCDtime": 0,
            "canSend": True, "portraitCid": 0, "portraitFrameCid": 0, "groupGiftIds": [], "type": 1,
        }]
        self.state["sevenCarnival"] = {"day": 2, "storeList": [{"storeId": 100, "num": 1}], "state": 1}
        friends, changed = self.response(sh.FRIEND_REQ_FRIENDS, b"")
        self.assertFalse(changed)
        self.assertEqual(friends["friends"][0]["pid"], 9)
        sign, changed2 = self.response(sh.SIGN_REQ_SEVEN_CARNIVAL, b"")
        self.assertFalse(changed2)
        self.assertEqual(sign["day"], 2)
        self.assertEqual(sign["state"], 1)


if __name__ == "__main__":
    unittest.main()
