#!/usr/bin/env python3
"""Stateful compatibility layer for the offline TCP server.

The generic response for DUNGEON_GET_LEVEL_INFO (1796) contains no level
records.  FubenDataMgr therefore considers the hard-coded first plot level
101101 unfinished. MainScene:onEnter() then diverts into the first-plot path,
never creates MainLayer, and asks for DUNGEON_LIMIT_HERO_DUNGEON. The generic
reply to that request has levelCid=0, leaving the client on a black MainScene.

Seed a minimal persisted-looking level record for 101101 so an offline starter
account reaches the normal MainLayer.  The original TCP server remains the
transport implementation and fallback for every other protocol.
"""
from __future__ import annotations

import tcp_server as base
from proto_codec import enc_bool_field, enc_msg_field, enc_varint_field

DUNGEON_GET_LEVEL_INFO = 1796
FIRST_PLOT_LEVEL = 101101


def encode_dungeon_level_info(save: dict) -> bytes:
    """Encode s2c 1796 with the minimum levelInfo records needed by FubenDataMgr.

    Schema:
      field 1 levelInfos (message)
        field 1 repeated levelInfos
          1 cid, 2 goals(packed, optional), 3 fightCount, 4 win,
          5 buyCount, 6 freeCount
      field 2 groups (optional for the MainScene bootstrap)
    """
    passed = save.get("passedLevels")
    if passed is None:
        passed = [FIRST_PLOT_LEVEL]

    records = b""
    for raw_cid in passed:
        cid = int(raw_cid)
        if cid <= 0:
            continue
        info = enc_varint_field(1, cid)
        # goals (field 2) is a packed repeated value and may be absent.
        info += enc_varint_field(3, 1)       # fightCount
        info += enc_bool_field(4, True)      # win
        info += enc_varint_field(5, 0)       # buyCount
        info += enc_varint_field(6, 0)       # freeCount
        records += enc_msg_field(1, info)

    if not records:
        return b""
    level_infos = enc_msg_field(1, records)
    return enc_msg_field(1, level_infos)


def _handle(self: base.Client, proto: int, body: bytes) -> None:
    if proto == DUNGEON_GET_LEVEL_INFO:
        payload = encode_dungeon_level_info(self.save)
        base.log(
            f"   bootstrap dungeon progress: passed="
            f"{self.save.get('passedLevels', [FIRST_PLOT_LEVEL])}"
        )
        self.send_pkt(proto, payload)
        return
    _ORIGINAL_HANDLE(self, proto, body)


_ORIGINAL_HANDLE = base.Client.handle
base.Client.handle = _handle


if __name__ == "__main__":
    base.main()
