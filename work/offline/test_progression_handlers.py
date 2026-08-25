#!/usr/bin/env python3
from __future__ import annotations

import copy
import unittest

import progression_handlers as ph
from protocol_schema import decode_fields, encode_fields, registry


def request(proto: int, values: dict) -> bytes:
    return encode_fields(registry().c2s[proto], values)


def response(proto: int, body: bytes) -> dict:
    return decode_fields(registry().s2c[proto], body)


class ProgressionHandlerTests(unittest.TestCase):
    def test_protocols_exist_in_real_client_descriptors(self) -> None:
        reg = registry()
        for proto in ph.PROGRESSION_PROTOCOLS:
            self.assertIn(proto, reg.c2s)
            self.assertIn(proto, reg.s2c)

    def test_spirit_login_response_is_semantic_and_persistent(self) -> None:
        state: dict = {}
        result = ph.response_for(ph.HERO_SPIRIT_REQ_NEW_SPIRIT_INFO, state)
        self.assertIsNotNone(result)
        payload, changed = result
        self.assertTrue(changed)
        data = response(ph.HERO_SPIRIT_REQ_NEW_SPIRIT_INFO, payload)
        self.assertIn("spirits", data)
        spirit = data["spirits"]
        self.assertEqual(spirit["level"], 1)
        self.assertEqual(spirit["maxLv"], 1)
        self.assertEqual(spirit["spiritPoints"], 0)
        # Empty repeated protobuf fields are absent on the wire by design.
        # The persisted semantic state still keeps concrete empty lists.
        self.assertEqual(spirit.get("specialism", []), [])
        self.assertEqual(spirit.get("angleSpirits", []), [])
        self.assertEqual(state["spiritInfo"]["specialism"], [])
        self.assertEqual(state["spiritInfo"]["angleSpirits"], [])
        self.assertEqual(state["spiritInfo"]["level"], 1)

        payload2, changed2 = ph.response_for(ph.HERO_SPIRIT_REQ_NEW_SPIRIT_INFO, state)
        self.assertFalse(changed2)
        self.assertEqual(response(ph.HERO_SPIRIT_REQ_NEW_SPIRIT_INFO, payload2)["spirits"], spirit)

    def test_spirit_normalizes_invalid_values_without_losing_valid_rows(self) -> None:
        state = {"spiritInfo": {
            "spiritPoints": -10,
            "grade": 2,
            "level": 0,
            "exp": 9,
            "specialism": [{"cid": 1001, "num": 3}, {"cid": 0, "num": 99}],
            "angleSpirits": [{"heroCid": 110101, "lv": 4}],
            "maxLv": 0,
        }}
        payload, changed = ph.response_for(ph.HERO_SPIRIT_REQ_NEW_SPIRIT_INFO, state)
        self.assertTrue(changed)
        spirit = response(ph.HERO_SPIRIT_REQ_NEW_SPIRIT_INFO, payload)["spirits"]
        self.assertEqual(spirit["spiritPoints"], 0)
        self.assertEqual(spirit["level"], 1)
        self.assertEqual(spirit["maxLv"], 1)
        self.assertEqual(spirit["specialism"], [{"cid": 1001, "num": 3}])
        self.assertEqual(spirit["angleSpirits"], [{"heroCid": 110101, "lv": 4}])

    def test_skill_strategy_mutates_owned_hero_and_mirrors_response(self) -> None:
        state = {"heroes": [{"id": "hero-1", "cid": 110101, "useSkillStrategy": 1}]}
        body = request(ph.HERO_REQ_USE_SKILL_STRATEGY, {"heroId": "hero-1", "skillStrategyId": 3})
        payload, changed = ph.response_for(ph.HERO_REQ_USE_SKILL_STRATEGY, state, body)
        self.assertTrue(changed)
        self.assertEqual(state["heroes"][0]["useSkillStrategy"], 3)
        self.assertEqual(response(ph.HERO_REQ_USE_SKILL_STRATEGY, payload), {
            "heroId": "hero-1", "skillStrategyId": 3,
        })

    def test_skill_strategy_unknown_hero_is_non_mutating(self) -> None:
        state = {"heroes": [{"id": "hero-1", "cid": 110101}]}
        before = copy.deepcopy(state)
        body = request(ph.HERO_REQ_USE_SKILL_STRATEGY, {"heroId": "missing", "skillStrategyId": 2})
        _, changed = ph.response_for(ph.HERO_REQ_USE_SKILL_STRATEGY, state, body)
        self.assertFalse(changed)
        self.assertEqual(state, before)

    def test_friend_delete_block_unblock_accept_and_refuse(self) -> None:
        state = {
            "pid": 10001,
            "friends": [
                {"pid": 1, "status": ph.FRIEND},
                {"pid": 2, "status": ph.APPLY},
                {"pid": 3, "status": ph.APPLY},
            ],
        }
        payload, changed = ph.response_for(
            ph.FRIEND_REQ_OPERATE, state,
            request(ph.FRIEND_REQ_OPERATE, {"type": ph.SHIELD_PLAYER, "targets": [1]}),
        )
        self.assertTrue(changed)
        self.assertEqual(state["friends"][0]["status"], ph.SHIELDING)
        self.assertEqual(state["friends"][0]["previousStatus"], ph.FRIEND)
        self.assertEqual(response(ph.FRIEND_REQ_OPERATE, payload), {"type": ph.SHIELD_PLAYER, "targets": [1]})

        _, changed = ph.response_for(
            ph.FRIEND_REQ_OPERATE, state,
            request(ph.FRIEND_REQ_OPERATE, {"type": ph.LIFTED_SHIELD, "targets": [1]}),
        )
        self.assertTrue(changed)
        restored = next(row for row in state["friends"] if row["pid"] == 1)
        self.assertEqual(restored["status"], ph.FRIEND)
        self.assertNotIn("previousStatus", restored)

        _, changed = ph.response_for(
            ph.FRIEND_REQ_OPERATE, state,
            request(ph.FRIEND_REQ_OPERATE, {"type": ph.AGREE_APPLY, "targets": [2]}),
        )
        self.assertTrue(changed)
        self.assertEqual(next(row for row in state["friends"] if row["pid"] == 2)["status"], ph.FRIEND)

        _, changed = ph.response_for(
            ph.FRIEND_REQ_OPERATE, state,
            request(ph.FRIEND_REQ_OPERATE, {"type": ph.REFUSE_APPLY, "targets": [3]}),
        )
        self.assertTrue(changed)
        self.assertNotIn(3, [row["pid"] for row in state["friends"]])

        for pid in (1, 2):
            _, changed = ph.response_for(
                ph.FRIEND_REQ_OPERATE, state,
                request(ph.FRIEND_REQ_OPERATE, {"type": ph.DELETE_FRIEND, "targets": [pid]}),
            )
            self.assertTrue(changed)
        self.assertEqual(state["friends"], [])

    def test_friend_gifts_are_idempotent_and_ignore_self(self) -> None:
        state = {
            "pid": 10001,
            "friendReceiveCount": 0,
            "friends": [{"pid": 42, "status": ph.FRIEND, "canSend": True, "receive": True}],
        }
        give = request(ph.FRIEND_REQ_OPERATE, {"type": ph.GIVE_GIFT, "targets": [42, 10001]})
        _, changed = ph.response_for(ph.FRIEND_REQ_OPERATE, state, give)
        self.assertTrue(changed)
        self.assertFalse(state["friends"][0]["canSend"])
        _, changed = ph.response_for(ph.FRIEND_REQ_OPERATE, state, give)
        self.assertFalse(changed)

        receive_body = request(ph.FRIEND_REQ_OPERATE, {"type": ph.RECEIVE_GIFT, "targets": [42]})
        _, changed = ph.response_for(ph.FRIEND_REQ_OPERATE, state, receive_body)
        self.assertTrue(changed)
        self.assertFalse(state["friends"][0]["receive"])
        self.assertEqual(state["friendReceiveCount"], 1)
        _, changed = ph.response_for(ph.FRIEND_REQ_OPERATE, state, receive_body)
        self.assertFalse(changed)
        self.assertEqual(state["friendReceiveCount"], 1)


if __name__ == "__main__":
    unittest.main()
