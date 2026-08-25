#!/usr/bin/env python3
from __future__ import annotations

import copy
import unittest

import sign_handlers as sign
from protocol_schema import decode_fields, encode_fields, registry


def request(proto: int, *values) -> bytes:
    fields = registry().c2s[proto]
    return encode_fields(fields, {fields[i].name: value for i, value in enumerate(values) if i < len(fields)})


def response(proto: int, body: bytes) -> dict:
    return decode_fields(registry().s2c[proto], body)


class SignHandlerTests(unittest.TestCase):
    def test_protocols_exist_in_real_descriptors(self) -> None:
        reg = registry()
        for proto in sign.SIGN_PROTOCOLS:
            self.assertIn(proto, reg.c2s)
            self.assertIn(proto, reg.s2c)

    def test_sign_info_defaults_are_present_but_disabled_without_reward_config(self) -> None:
        state = {}
        payload, changed = sign.response_for(sign.SIGN_REQ_SIGN_INFOS, state)
        self.assertTrue(changed)
        root = registry().s2c[sign.SIGN_REQ_SIGN_INFOS][0].name
        infos = response(sign.SIGN_REQ_SIGN_INFOS, payload)[root]
        self.assertEqual([row["id"] for row in infos], [1, 2, 3, 4])
        self.assertTrue(all(row["awardType"] == [sign.CANNOT_SIGN] for row in infos))
        # Empty repeated protobuf fields are intentionally omitted on the wire;
        # the save still retains concrete empty lists for local state logic.
        self.assertTrue(all(row.get("supplyDays", []) == [] for row in infos))
        self.assertTrue(all(row["supplyDays"] == [] for row in state["signInfos"]))
        for persisted, decoded in zip(state["signInfos"], infos):
            self.assertEqual({k: v for k, v in persisted.items() if k != "supplyDays"}, decoded)

    def test_configured_sign_is_claimable_and_reward_is_idempotent(self) -> None:
        state = {
            "items": {},
            "signRewards": {"1": [{"id": 500001, "num": 50}, {"id": 500002, "num": 2}]},
        }
        sign.response_for(sign.SIGN_REQ_SIGN_INFOS, state)
        self.assertEqual(state["signInfos"][0]["awardType"], [sign.CAN_SIGN])

        body = request(sign.SIGN_SUBMIT_SIGN, 1)
        payload, changed = sign.response_for(sign.SIGN_SUBMIT_SIGN, state, body)
        self.assertTrue(changed)
        fields = registry().s2c[sign.SIGN_SUBMIT_SIGN]
        data = response(sign.SIGN_SUBMIT_SIGN, payload)
        self.assertEqual(data[fields[0].name], 1)
        self.assertEqual(data[fields[1].name], [{"id": 500001, "num": 50}, {"id": 500002, "num": 2}])
        self.assertEqual(state["signInfos"][0]["awardType"], [sign.SIGNED])
        self.assertEqual(state["items"]["500001"]["num"], 50)
        self.assertEqual(state["items"]["500002"]["num"], 2)

        snapshot = copy.deepcopy(state)
        payload2, changed2 = sign.response_for(sign.SIGN_SUBMIT_SIGN, state, body)
        self.assertFalse(changed2)
        self.assertEqual(state, snapshot)
        data2 = response(sign.SIGN_SUBMIT_SIGN, payload2)
        self.assertEqual(data2.get(fields[1].name, []), [])

    def test_disabled_or_unknown_sign_never_mints_rewards(self) -> None:
        state = {"items": {}, "signRewards": {}}
        sign.response_for(sign.SIGN_REQ_SIGN_INFOS, state)
        before = copy.deepcopy(state)
        _, changed = sign.response_for(sign.SIGN_SUBMIT_SIGN, state, request(sign.SIGN_SUBMIT_SIGN, 1))
        self.assertFalse(changed)
        self.assertEqual(state, before)

        state2 = {"items": {}, "signRewards": {"99": [{"id": 500002, "num": 999}]}}
        before2 = copy.deepcopy(state2)
        _, changed2 = sign.response_for(sign.SIGN_SUBMIT_SIGN, state2, request(sign.SIGN_SUBMIT_SIGN, 99))
        # Normalizing the four supported sign rows is allowed; the unknown ID
        # itself must not grant any configured reward.
        self.assertNotIn("500002", state2["items"])
        self.assertTrue(changed2 or state2 == before2)

    def test_monthly_claim_advances_index_to_claimed_position(self) -> None:
        state = {
            "items": {},
            "signRewards": {"1": [{"id": 500001, "num": 1}]},
            "signInfos": [{
                "id": 1, "index": 4, "extendData": "8", "awardType": [0, 0, 1, 2],
                "supplyLimit": 0, "supplyDays": [],
            }],
        }
        sign.response_for(sign.SIGN_SUBMIT_SIGN, state, request(sign.SIGN_SUBMIT_SIGN, 1))
        info = state["signInfos"][0]
        self.assertEqual(info["awardType"], [0, 0, 0, 2])
        self.assertEqual(info["index"], 4)

    def test_language_selection_persists_only_supported_values(self) -> None:
        state = {"language": 1}
        payload, changed = sign.response_for(sign.SIGN_REQ_LANGUGE_SIGN, state, request(sign.SIGN_REQ_LANGUGE_SIGN, 2))
        self.assertTrue(changed)
        self.assertEqual(state["language"], 2)
        field = registry().s2c[sign.SIGN_REQ_LANGUGE_SIGN][0].name
        self.assertEqual(response(sign.SIGN_REQ_LANGUGE_SIGN, payload)[field], 2)

        before = copy.deepcopy(state)
        payload2, changed2 = sign.response_for(sign.SIGN_REQ_LANGUGE_SIGN, state, request(sign.SIGN_REQ_LANGUGE_SIGN, 99))
        self.assertFalse(changed2)
        self.assertEqual(state, before)
        self.assertEqual(response(sign.SIGN_REQ_LANGUGE_SIGN, payload2)[field], 2)


if __name__ == "__main__":
    unittest.main()
