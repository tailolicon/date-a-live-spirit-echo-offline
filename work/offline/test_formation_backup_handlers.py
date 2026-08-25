#!/usr/bin/env python3
from __future__ import annotations

import copy
import unittest

import formation_backup_handlers as fb
from protocol_schema import decode_fields, encode_fields, registry


def request(proto: int, values: dict) -> bytes:
    return encode_fields(registry().c2s[proto], values)


def response(proto: int, body: bytes) -> dict:
    return decode_fields(registry().s2c[proto], body)


class FormationBackupTests(unittest.TestCase):
    def base_state(self) -> dict:
        return {
            "heroes": [
                {"id": "101", "cid": 110101},
                {"id": "102", "cid": 110102},
                {"id": "103", "cid": 110103},
                {"id": "104", "cid": 110104},
            ],
            "formations": [{"type": 1, "stance": ["101", "102"]}],
        }

    def test_protocols_exist_in_real_descriptors(self) -> None:
        reg = registry()
        for proto in fb.FORMATION_BACKUP_PROTOCOLS:
            self.assertIn(proto, reg.c2s)
            self.assertIn(proto, reg.s2c)

    def test_list_initializes_seven_presets_and_seeds_first(self) -> None:
        state = self.base_state()
        payload, changed = fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_LIST, state)
        self.assertTrue(changed)
        self.assertEqual(len(state["formationBackups"]), 7)
        self.assertEqual(state["formationBackups"][0]["base"]["stance"], ["101", "102"])
        data = response(fb.PLAYER_REQ_FORMATION_BACKUP_LIST, payload)
        self.assertEqual(len(data["formations"]), 7)
        self.assertEqual(data["formations"][0]["id"], 1)
        self.assertEqual(data["formations"][0]["base"]["stance"], ["101", "102"])

        _, changed2 = fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_LIST, state)
        self.assertFalse(changed2)

    def test_change_preset_add_swap_toggle_and_reject_unknown(self) -> None:
        state = self.base_state()
        fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_LIST, state)

        add = request(fb.PLAYER_REQ_FORMATION_BACKUP_HERO, {
            "id": 1, "sourceHeroId": "103", "targetHeroId": "",
        })
        payload, changed = fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_HERO, state, add)
        self.assertTrue(changed)
        self.assertEqual(state["formationBackups"][0]["base"]["stance"], ["101", "102", "103"])
        self.assertEqual(response(fb.PLAYER_REQ_FORMATION_BACKUP_HERO, payload)["formation"]["base"]["stance"], ["101", "102", "103"])

        swap = request(fb.PLAYER_REQ_FORMATION_BACKUP_HERO, {
            "id": 1, "sourceHeroId": "104", "targetHeroId": "102",
        })
        _, changed = fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_HERO, state, swap)
        self.assertTrue(changed)
        self.assertEqual(state["formationBackups"][0]["base"]["stance"], ["101", "104", "103"])

        before = copy.deepcopy(state)
        unknown = request(fb.PLAYER_REQ_FORMATION_BACKUP_HERO, {
            "id": 1, "sourceHeroId": "999", "targetHeroId": "104",
        })
        _, changed = fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_HERO, state, unknown)
        self.assertFalse(changed)
        self.assertEqual(state, before)

        toggle = request(fb.PLAYER_REQ_FORMATION_BACKUP_HERO, {
            "id": 1, "sourceHeroId": "103", "targetHeroId": "",
        })
        _, changed = fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_HERO, state, toggle)
        self.assertTrue(changed)
        self.assertEqual(state["formationBackups"][0]["base"]["stance"], ["101", "104"])

    def test_rename_is_persistent_and_length_bounded(self) -> None:
        state = self.base_state()
        fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_LIST, state)
        body = request(fb.PLAYER_REQ_FORMATION_BACKUP_DESC, {"id": 2, "desc": "X" * 100})
        payload, changed = fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_DESC, state, body)
        self.assertTrue(changed)
        self.assertEqual(state["formationBackups"][1]["desc"], "X" * 64)
        data = response(fb.PLAYER_REQ_FORMATION_BACKUP_DESC, payload)
        self.assertEqual(data["formation"]["id"], 2)
        self.assertEqual(data["formation"]["desc"], "X" * 64)

    def test_use_preset_replaces_selected_formation_type(self) -> None:
        state = self.base_state()
        fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_LIST, state)
        state["formationBackups"][0]["base"]["stance"] = ["103", "104"]
        body = request(fb.PLAYER_REQ_FORMATION_BACKUP_USE, {"id": 1, "formationType": 1})
        payload, changed = fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_USE, state, body)
        self.assertTrue(changed)
        self.assertEqual(state["formations"][0]["stance"], ["103", "104"])
        self.assertEqual(response(fb.PLAYER_REQ_FORMATION_BACKUP_USE, payload), {})

        before = copy.deepcopy(state)
        empty = request(fb.PLAYER_REQ_FORMATION_BACKUP_USE, {"id": 7, "formationType": 1})
        _, changed = fb.response_for(fb.PLAYER_REQ_FORMATION_BACKUP_USE, state, empty)
        self.assertFalse(changed)
        self.assertEqual(state, before)


if __name__ == "__main__":
    unittest.main()
