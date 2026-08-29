#!/usr/bin/env python3
"""The PlayerInfo body, shared by the login reply and the s2c 267 push.

s2c 267 (PLAYER_PLAYER_INFO) *is* a PlayerInfo message, and LOGIN_ENTER nests
the same message at field 2, so both go through here - a level-up that reached
the client in a shape the login handshake never used would be a second, silent
wire format to keep in step.

MainPlayer:onRecvPlayerInfo merges whatever fields arrive over the cached info
and raises EV_PLAYINFO_CHANGE per changed key, so a full body is safe to resend.
"""
from __future__ import annotations

import time
from typing import Any

from proto_codec import enc_bool_field, enc_msg_field, enc_string_field, enc_varint_field


def encode_player_info(state: dict[str, Any]) -> bytes:
    body = b""
    body += enc_varint_field(1, int(state["pid"]))
    body += enc_string_field(2, state.get("name", "Shido"))
    body += enc_varint_field(3, int(state.get("lvl", 1)))
    body += enc_varint_field(4, int(state.get("exp", 0)))
    body += enc_varint_field(5, int(state.get("vip_lvl", 0)))
    body += enc_varint_field(6, int(state.get("vip_exp", 0)))
    body += enc_varint_field(7, int(state.get("language", 1)))
    body += enc_string_field(8, state.get("remark", ""))
    body += enc_varint_field(9, int(state.get("helpFightHeroCid", 0)))
    for attr in state.get("attr", []) or []:
        if not isinstance(attr, dict):
            continue
        sub = enc_varint_field(1, int(attr.get("type", 0)))
        sub += enc_varint_field(2, int(attr.get("val", 0)))
        body += enc_msg_field(10, sub)
    body += enc_bool_field(11, bool(state.get("isFirstLogin", False)))
    body += enc_string_field(12, state.get("clientDiscreteData", "{}"))
    body += enc_string_field(13, state.get("settings", ""))
    for value in state.get("recoverTimeList", []) or []:
        body += enc_varint_field(14, int(value))
    body += enc_varint_field(15, int(state.get("portraitCid", 0)))
    body += enc_varint_field(16, int(state.get("portraitFrameCid", 0)))
    # Field 17 is `element`; it stays absent so MainPlayer keeps its own copy
    # instead of adopting an all-zero one.
    body += enc_varint_field(18, int(state.get("unionId", 0)))
    body += enc_string_field(19, state.get("unionName", ""))
    body += enc_varint_field(20, int(state.get("titleId", 0)))
    body += enc_varint_field(21, int(state.get("createTime", int(time.time()))))
    body += enc_varint_field(22, int(state.get("famousExp", 0)))
    return body
