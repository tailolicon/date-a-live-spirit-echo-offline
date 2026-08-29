#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import struct
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import player_save
import stateful_handlers as sh
import tcp_server
from protocol_schema import ProtocolRegistry, decode_fields, encode_fields, registry


class ProtocolSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.registry = ProtocolRegistry()

    def test_core_protocol_names_are_loaded(self) -> None:
        self.assertEqual(self.registry.c2s_by_name["ITEM_GET_ITEMS"], 515)
        self.assertEqual(self.registry.s2c_by_name["ITEM_ITEM_LIST"], 515)
        self.assertEqual(self.registry.c2s_by_name["HERO_GET_HEROS"], 1025)
        self.assertEqual(self.registry.s2c_by_name["HERO_HERO_INFO_LIST"], 1025)

    def test_core_response_fields_match_client_managers(self) -> None:
        expected = {
            515: "items",
            1025: "heros",
            265: "formations",
            772: "mails",
            4097: "taks",
        }
        for proto, field_name in expected.items():
            self.assertIn(field_name, {field.name for field in self.registry.s2c[proto]})

    def test_item_list_round_trip(self) -> None:
        body = self.registry.encode_response(515, {
            "items": [{"ct": 0, "id": "500001", "cid": 500001, "num": 123456}]
        })
        decoded = decode_fields(self.registry.s2c[515], body)
        self.assertEqual(decoded["items"][0]["id"], "500001")
        self.assertEqual(decoded["items"][0]["cid"], 500001)
        self.assertEqual(decoded["items"][0]["num"], 123456)

    def test_formation_request_decoder(self) -> None:
        request = {"formationType": 1, "sourceHeroId": "hero-old", "targetHeroId": "hero-new"}
        body = encode_fields(self.registry.c2s[264], request)
        self.assertEqual(self.registry.decode_request(264, body), request)

    def test_a_supplied_nested_message_is_emitted_at_its_own_tag(self) -> None:
        body = self.registry.encode_response(1795, {"group": {"id": "g", "cid": 7}})
        self.assertTrue(body)
        self.assertEqual(body[0] >> 3, 1)
        self.assertEqual(decode_fields(self.registry.s2c[1795], body)["group"]["cid"], 7)

    def test_an_unsupplied_nested_message_is_absent(self) -> None:
        """Absent, not zero-filled: the client tells the two apart.

        NetOP:UnpackSingleVaule leaves an unmatched field as NULL -> nil, which
        every `if data.x then` guard reads as "no value". A submessage emitted
        with default contents is instead a table full of zeros, and the ids in
        it get looked up in static tables that have no row 0.
        """
        self.assertEqual(self.registry.encode_response(1795, {}), b"")


class PlayerSaveMigrationTests(unittest.TestCase):
    def test_sparse_legacy_save_gets_core_state(self) -> None:
        state = player_save.normalize_save({"pid": 42, "items": {}, "heroes": [], "gold": 123, "diamonds": 456})
        self.assertEqual(state["schemaVersion"], player_save.SCHEMA_VERSION)
        self.assertIn(player_save.FIRST_PLOT_LEVEL, state["passedLevels"])
        self.assertEqual({f["type"] for f in state["formations"]}, {1, 2, 3})
        by_cid = {item["cid"]: item for item in state["items"].values()}
        # A legacy gold/diamond field is still read across, then the stocked
        # float is applied on top of it - never below what the save held.
        self.assertGreaterEqual(by_cid[player_save.GOLD_CID]["num"], 123)
        self.assertGreaterEqual(by_cid[player_save.DIAMOND_CID]["num"], 456)
        self.assertGreater(by_cid[player_save.POWER_CID]["num"], 0)

    def test_a_non_currency_item_quantity_is_not_clobbered(self) -> None:
        """Stocking is for the currencies only; drops and materials are state."""
        material = 510105
        self.assertNotIn(material, player_save.STOCKED_CIDS)
        state = player_save.normalize_save({
            "items": {str(material): {"ct": 0, "id": str(material), "cid": material, "num": 7}},
            "passedLevels": [101102],
        })
        self.assertEqual(state["items"][str(material)]["num"], 7)
        self.assertEqual(state["passedLevels"][:2], [player_save.FIRST_PLOT_LEVEL, 101102])

    def test_stocking_never_lowers_a_richer_balance(self) -> None:
        rich = player_save.TEST_CURRENCY_STOCK * 3
        state = player_save.normalize_save({
            "items": {"500001": {"ct": 0, "id": "500001", "cid": 500001, "num": rich}},
        })
        self.assertEqual(state["items"]["500001"]["num"], rich)
        self.assertEqual(state["gold"], rich)

    def test_stocking_runs_once(self) -> None:
        """The float is a migration, not a standing refill of every save."""
        state = player_save.normalize_save({"items": {}})
        spent = next(row for row in state["items"].values()
                     if int(row["cid"]) == player_save.GOLD_CID)
        spent["num"] = 12
        again = player_save.normalize_save(state)
        by_cid = {int(row["cid"]): row for row in again["items"].values()}
        self.assertEqual(by_cid[player_save.GOLD_CID]["num"], 12)

    def test_save_load_is_atomic_and_migrated(self) -> None:
        old_path = player_save.SAVE_PATH
        with tempfile.TemporaryDirectory() as td:
            player_save.SAVE_PATH = os.path.join(td, "player.json")
            try:
                player_save.save({"pid": 77, "items": {}, "heroes": []})
                loaded = player_save.load_save()
                self.assertEqual(loaded["pid"], 77)
                self.assertEqual(loaded["schemaVersion"], player_save.SCHEMA_VERSION)
                with open(player_save.SAVE_PATH, encoding="utf-8") as f:
                    disk = json.load(f)
                self.assertEqual(disk["schemaVersion"], player_save.SCHEMA_VERSION)
            finally:
                player_save.SAVE_PATH = old_path


class StatefulHandlerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.state = player_save.default_save()
        self.reg = registry()

    def decode(self, proto: int, body: bytes) -> dict:
        return decode_fields(self.reg.s2c[proto], body)

    def test_inventory_comes_from_save(self) -> None:
        body, mutated = sh.response_for(515, self.state)
        data = self.decode(515, body)
        by_cid = {row["cid"]: row for row in data["items"]}
        self.assertFalse(mutated)
        self.assertEqual(by_cid[500001]["num"], self.state["gold"])

    def test_hero_mail_task_and_formation_reads(self) -> None:
        self.state["heroes"] = [{"ct": 0, "id": "h1", "cid": 110101, "level": 1}]
        hero_body, _ = sh.response_for(1025, self.state)
        hero = self.decode(1025, hero_body)["heros"][0]
        self.assertEqual(hero["id"], "h1")
        self.assertEqual(hero["cid"], 110101)
        formation_body, _ = sh.response_for(265, self.state)
        formations = self.decode(265, formation_body)["formations"]
        self.assertEqual({row["type"] for row in formations}, {1, 2, 3})
        mail_body, _ = sh.response_for(772, self.state)
        task_body, _ = sh.response_for(4097, self.state)
        self.assertIsInstance(mail_body, bytes)
        self.assertIsInstance(task_body, bytes)

    def test_formation_mutation_swaps_owned_hero(self) -> None:
        self.state["heroes"] = [
            {"ct": 0, "id": "h1", "cid": 110101},
            {"ct": 0, "id": "h2", "cid": 110102},
        ]
        self.state["formations"][0]["stance"] = ["h1"]
        request = {"formationType": 1, "sourceHeroId": "h1", "targetHeroId": "h2"}
        request_body = encode_fields(self.reg.c2s[264], request)
        response, mutated = sh.response_for(264, self.state, request_body)
        self.assertTrue(mutated)
        self.assertEqual(self.state["formations"][0]["stance"], ["h2"])
        self.assertEqual(self.decode(264, response)["stance"], ["h2"])

    def test_formation_rejects_unknown_hero(self) -> None:
        self.state["heroes"] = [{"ct": 0, "id": "h1", "cid": 110101}]
        self.state["formations"][0]["stance"] = ["h1"]
        changed = sh.operate_formation(self.state, {"formationType": 1, "sourceHeroId": "h1", "targetHeroId": "missing"})
        self.assertEqual(changed["stance"], ["h1"])

    def test_dungeon_bootstrap_stays_byte_compatible(self) -> None:
        self.assertEqual(sh.encode_dungeon_level_info({}).hex(), "0a0e0a0c08ed95061801200128003000")


class TcpServerCoreTests(unittest.TestCase):
    def test_pack_keeps_plaintext_receive_workaround(self) -> None:
        frame = tcp_server.pack(515, b"abc")
        token, total = struct.unpack(">HI", frame[:6])
        self.assertEqual(token, tcp_server.HEAD_TOKEN)
        self.assertEqual(total, len(frame))
        self.assertEqual(total % tcp_server.PAD_UNIT, 0)
        self.assertEqual(struct.unpack(">H", frame[8:10])[0], 515)

    def test_all_stateful_protocols_have_s2c_descriptors(self) -> None:
        self.assertTrue(sh.STATEFUL_PROTOCOLS <= set(tcp_server.MINIMAL))


if __name__ == "__main__":
    unittest.main()
