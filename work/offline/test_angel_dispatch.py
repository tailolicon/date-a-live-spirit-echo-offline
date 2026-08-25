#!/usr/bin/env python3
from __future__ import annotations

import unittest
from unittest.mock import patch

import angel_handlers as ah
from protocol_schema import encode_fields, registry


class FakeConfig:
    def hero(self, cid: int):
        return {"baseQuality": 4, "defaultSkin": 1101011} if int(cid) == 110101 else None

    def angel_awake_cost(self, cid: int, level: int):
        return [{"id": 570018, "num": 1}] if int(cid) == 110101 and int(level) == 1 else None


class FakeClient:
    def __init__(self) -> None:
        self.save = {
            "heroes": [{
                "id": "h1", "cid": 110101, "lvl": 1, "exp": 0, "attr": [],
                "advancedLvl": 0, "angelLvl": 1, "quality": 4, "skinCid": 1101011,
                "skillStrategyInfo": [{"id": 1, "name": "Default", "alreadyUseSkillPiont": 0,
                                       "angeSkillInfos": [], "passiveSkillInfo": []}],
                "useSkillStrategy": 1,
            }],
            "items": {"570018": {"id": "570018", "cid": 570018, "num": 1}},
        }
        self.sent: list[tuple[int, bytes]] = []

    def send_pkt(self, proto: int, body: bytes = b"", error: int = 0) -> None:
        self.sent.append((proto, body))


class AngelDispatchTests(unittest.TestCase):
    def test_dispatch_persists_then_sends_push_before_response(self) -> None:
        client = FakeClient()
        body = encode_fields(registry().c2s[ah.HERO_REQ_AWAKE_ANGEL], {"heroId": "h1"})
        with patch.object(ah, "static_config", return_value=FakeConfig()), patch.object(ah, "persist") as persist:
            self.assertTrue(ah.dispatch(client, ah.HERO_REQ_AWAKE_ANGEL, body))
        persist.assert_called_once_with(client.save)
        self.assertEqual([proto for proto, _ in client.sent], [ah.HERO_HERO_INFO, ah.HERO_REQ_AWAKE_ANGEL])
        self.assertEqual(client.save["heroes"][0]["angelLvl"], 2)

    def test_non_angel_protocol_is_not_claimed(self) -> None:
        client = FakeClient()
        self.assertFalse(ah.dispatch(client, 515, b""))
        self.assertEqual(client.sent, [])


if __name__ == "__main__":
    unittest.main()
