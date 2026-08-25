#!/usr/bin/env python3
from __future__ import annotations

import unittest

import hero_progression_handlers as hp
from protocol_schema import encode_fields, registry


class FakeConfig:
    def hero(self, cid: int):
        if int(cid) != 110101:
            return None
        return {
            "attribute": 1011,
            "baseQuality": 4,
            "expItems": [510101],
            "defaultSkin": 1101011,
            "optionalSkins": [1101011],
            "paint": 0,
            "conditionHeroQuality": 0,
        }

    def max_level(self) -> int:
        return 10

    def level_exp(self, level: int):
        return 100 if int(level) == 1 else 999999

    def exp_item_value(self, cid: int):
        return 200 if int(cid) == 510101 else None


class FakeClient:
    def __init__(self) -> None:
        self.save = {
            "lvl": 10,
            "heroes": [{
                "id": "hero-1", "cid": 110101, "lvl": 1, "exp": 0,
                "advancedLvl": 0, "quality": 4, "skinCid": 1101011,
            }],
            "items": {"510101": {"id": "510101", "cid": 510101, "num": 1}},
        }
        self.sent: list[tuple[int, bytes]] = []

    def send_pkt(self, proto: int, body: bytes = b"", error: int = 0) -> None:
        self.sent.append((proto, body))


class HeroProgressionDispatchTests(unittest.TestCase):
    def test_dispatch_sends_state_pushes_before_request_response(self) -> None:
        fields = registry().c2s[hp.HERO_HERO_UPGRADE]
        body = encode_fields(fields, {
            "heroId": "hero-1",
            "items": [{"itemId": 510101, "num": 1}],
        })
        client = FakeClient()
        old_static = hp.static_config
        old_persist = hp.persist
        persisted: list[dict] = []
        hp.static_config = lambda: FakeConfig()
        hp.persist = lambda state: persisted.append(state)
        try:
            self.assertTrue(hp.dispatch(client, hp.HERO_HERO_UPGRADE, body))
        finally:
            hp.static_config = old_static
            hp.persist = old_persist
        self.assertEqual([proto for proto, _ in client.sent], [
            hp.HERO_HERO_INFO, hp.HERO_HERO_EXP_INFO, hp.HERO_HERO_UPGRADE,
        ])
        self.assertEqual(client.save["heroes"][0]["lvl"], 2)
        self.assertEqual(client.save["heroes"][0]["exp"], 100)
        self.assertEqual(client.save["items"]["510101"]["num"], 0)
        self.assertEqual(len(persisted), 1)

    def test_non_hero_protocol_is_not_claimed(self) -> None:
        client = FakeClient()
        self.assertFalse(hp.dispatch(client, 515, b""))
        self.assertEqual(client.sent, [])


if __name__ == "__main__":
    unittest.main()
