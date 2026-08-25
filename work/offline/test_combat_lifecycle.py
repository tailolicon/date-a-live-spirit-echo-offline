#!/usr/bin/env python3
from __future__ import annotations

import copy
import unittest

import combat_handlers as combat
from protocol_schema import decode_fields, encode_fields, registry


def request(proto: int, values: dict) -> bytes:
    return encode_fields(registry().c2s[proto], values)


def response(proto: int, body: bytes) -> dict:
    return decode_fields(registry().s2c[proto], body)


class CombatLifecycleTests(unittest.TestCase):
    LEVEL = 101102

    def base_state(self) -> dict:
        return {
            "items": {"500001": {"id": "500001", "cid": 500001, "num": 10}},
            "passedLevels": [],
            "levelStates": {},
            "levelDefinitions": {
                str(self.LEVEL): {
                    "rewards": [{"id": 500001, "num": 100}],
                    "firstClearRewards": [{"id": 500002, "num": 5}],
                    "nextLevelCid": 101103,
                }
            },
        }

    def test_protocols_exist_in_real_descriptors(self) -> None:
        reg = registry()
        for proto in combat.COMBAT_PROTOCOLS:
            self.assertIn(proto, reg.c2s)
            self.assertIn(proto, reg.s2c)

    def test_start_creates_replayable_active_fight(self) -> None:
        state = self.base_state()
        body = request(combat.DUNGEON_FIGHT_START, {"levelCid": self.LEVEL})
        payload, changed = combat.response_for(combat.DUNGEON_FIGHT_START, state, body)
        self.assertTrue(changed)
        self.assertEqual(state["activeFight"]["levelCid"], self.LEVEL)
        self.assertGreater(state["activeFight"]["randomSeed"], 0)
        data = response(combat.DUNGEON_FIGHT_START, payload)
        self.assertEqual(data.get("levelCid"), self.LEVEL)
        self.assertTrue(data.get("fightId"))
        self.assertEqual(data.get("randomSeed"), state["activeFight"]["randomSeed"])

    def test_invalid_start_is_non_mutating(self) -> None:
        state = self.base_state()
        before = copy.deepcopy(state)
        body = request(combat.DUNGEON_FIGHT_START, {"levelCid": 0})
        _, changed = combat.response_for(combat.DUNGEON_FIGHT_START, state, body)
        self.assertFalse(changed)
        self.assertEqual(state, before)

    def test_first_clear_grants_rewards_once_and_unlocks_next_level(self) -> None:
        state = self.base_state()
        start = request(combat.DUNGEON_FIGHT_START, {"levelCid": self.LEVEL})
        combat.response_for(combat.DUNGEON_FIGHT_START, state, start)

        finish = request(combat.DUNGEON_FIGHT_OVER, {
            "levelCid": self.LEVEL,
            "isWin": True,
            "goals": [1, 2, 2],
        })
        payload, changed = combat.response_for(combat.DUNGEON_FIGHT_OVER, state, finish)
        self.assertTrue(changed)
        data = response(combat.DUNGEON_FIGHT_OVER, payload)
        self.assertTrue(data.get("win"))
        self.assertEqual(state["mainLineCid"], 101103)
        self.assertIn(self.LEVEL, state["passedLevels"])
        level = state["levelStates"][str(self.LEVEL)]
        self.assertTrue(level["win"])
        self.assertEqual(level["fightCount"], 1)
        self.assertEqual(level["goals"], [1, 2])
        self.assertEqual(state["items"]["500001"]["num"], 110)
        self.assertEqual(state["items"]["500002"]["num"], 5)

        # A retransmitted settlement after the response was lost must not
        # duplicate rewards or counters.
        snapshot = copy.deepcopy(state)
        payload2, changed2 = combat.response_for(combat.DUNGEON_FIGHT_OVER, state, finish)
        self.assertFalse(changed2)
        self.assertEqual(state, snapshot)
        self.assertEqual(response(combat.DUNGEON_FIGHT_OVER, payload2), data)

    def test_second_clear_only_grants_regular_reward(self) -> None:
        state = self.base_state()
        start = request(combat.DUNGEON_FIGHT_START, {"levelCid": self.LEVEL})
        win = request(combat.DUNGEON_FIGHT_OVER, {"levelCid": self.LEVEL, "isWin": True})
        combat.response_for(combat.DUNGEON_FIGHT_START, state, start)
        combat.response_for(combat.DUNGEON_FIGHT_OVER, state, win)
        self.assertEqual(state["items"]["500001"]["num"], 110)
        self.assertEqual(state["items"]["500002"]["num"], 5)

        combat.response_for(combat.DUNGEON_FIGHT_START, state, start)
        _, changed = combat.response_for(combat.DUNGEON_FIGHT_OVER, state, win)
        self.assertTrue(changed)
        self.assertEqual(state["items"]["500001"]["num"], 210)
        self.assertEqual(state["items"]["500002"]["num"], 5)
        self.assertEqual(state["levelStates"][str(self.LEVEL)]["fightCount"], 2)

    def test_loss_counts_attempt_but_grants_nothing(self) -> None:
        state = self.base_state()
        start = request(combat.DUNGEON_FIGHT_START, {"levelCid": self.LEVEL})
        lose = request(combat.DUNGEON_FIGHT_OVER, {"levelCid": self.LEVEL, "isWin": False, "goals": [1]})
        combat.response_for(combat.DUNGEON_FIGHT_START, state, start)
        payload, changed = combat.response_for(combat.DUNGEON_FIGHT_OVER, state, lose)
        self.assertTrue(changed)
        self.assertFalse(response(combat.DUNGEON_FIGHT_OVER, payload).get("win", False))
        self.assertEqual(state["items"]["500001"]["num"], 10)
        self.assertNotIn("500002", state["items"])
        level = state["levelStates"][str(self.LEVEL)]
        self.assertEqual(level["fightCount"], 1)
        self.assertFalse(level["win"])
        self.assertNotIn(self.LEVEL, state["passedLevels"])

    def test_unsolicited_settlement_never_grants_rewards(self) -> None:
        state = self.base_state()
        before_items = copy.deepcopy(state["items"])
        finish = request(combat.DUNGEON_FIGHT_OVER, {"levelCid": self.LEVEL, "isWin": True})
        payload, changed = combat.response_for(combat.DUNGEON_FIGHT_OVER, state, finish)
        self.assertFalse(changed)
        self.assertEqual(state["items"], before_items)
        self.assertFalse(response(combat.DUNGEON_FIGHT_OVER, payload).get("win", False))


if __name__ == "__main__":
    unittest.main()
