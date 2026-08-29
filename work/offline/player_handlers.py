#!/usr/bin/env python3
"""Player profile and tutorial progress - the bits that must survive a relog.

Two things here are the same mistake in different clothes: the client reports
progress to the server and then trusts the server to hand it back next login,
so acknowledging without recording makes the player redo it every session.

* c2s 260 carries the prologue's Rename. s2c 260 is an empty ack - the client
  only fires EV_CHANGE_NAME_OK off it - so the name reaches the UI on the next
  PlayerInfo push, and the next *session* only if it was written down.

* c2s 278 carries the new-player guide. `GuideDataMgr:onLogin` opens with
  `{-1}`, meaning "which step am I on?", and takes `__step` straight from the
  reply; every completed step is then reported the same way. A zero-filled
  answer says "step 0, not finished", which is the entire tutorial, from the
  top, on every single login.
"""
from __future__ import annotations

from typing import Any

from game_static_config import StaticConfigUnavailable, config as static_config
from player_info import encode_player_info
from player_save import save as persist
from protocol_schema import decode_request, encode_response

PLAYER_SET_PLAYER_INFO = 260
PLAYER_PLAYER_INFO = 267
PLAYER_REQ_NEW_PLAYER_GUIDE = 278
EXPLORE_REQ_ADD_GUIDE_STEP = 7838
EXPLORE_REQ_GUIDE_INFO = 7839

PLAYER_PROTOCOLS = frozenset({
    PLAYER_SET_PLAYER_INFO,
    PLAYER_REQ_NEW_PLAYER_GUIDE,
    EXPLORE_REQ_ADD_GUIDE_STEP,
    EXPLORE_REQ_GUIDE_INFO,
})

# `guideId` is a v4 on the wire, so the client's "just tell me where I am"
# sentinel of -1 arrives as an unsigned varint at the top of the range.
GUIDE_QUERY_THRESHOLD = 0x7FFFFFFF
FIRST_GUIDE_STEP = 1

NAME_MAX_LEN = 32
REMARK_MAX_LEN = 128


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _clean(value: Any, limit: int) -> str:
    text = str(value or "").strip()
    return text[:limit]


def set_player_info(state: dict[str, Any], request: dict[str, Any]) -> bool:
    changed = False
    name = _clean(request.get("playerName"), NAME_MAX_LEN)
    if name and name != state.get("name"):
        state["name"] = name
        changed = True
    # An empty remark is a real value - the player can clear their bio - so it
    # is only compared, never treated as "not supplied".
    if "remark" in request:
        remark = _clean(request.get("remark"), REMARK_MAX_LEN)
        if remark != state.get("remark", ""):
            state["remark"] = remark
            changed = True
    return changed


def _max_guide_step() -> int:
    """How many steps the new-player guide has, per the shipped Guide table."""
    try:
        return static_config().new_guide_step_count()
    except StaticConfigUnavailable:
        # Without the tables there is no way to know when the guide ends.
        # Reporting it finished is the safe direction: a tutorial replayed on
        # every login is worse than one the player can choose to replay.
        return 0


def _next_guide_step(reported: int) -> int:
    try:
        return static_config().new_guide_next_step(reported)
    except StaticConfigUnavailable:
        return reported + 1


def guide_progress(state: dict[str, Any], request: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    """s2c 278: the step the client resumes at, and whether the guide is over."""
    step = max(FIRST_GUIDE_STEP, _as_int(state.get("newPlayerGuideStep"), FIRST_GUIDE_STEP))
    reported = _as_int(request.get("guideId"), -1)
    changed = False
    if 0 <= reported <= GUIDE_QUERY_THRESHOLD:
        # A completed step. Follow the client's own cursor rule - `Guide.stepId`
        # skips ahead at 20 of the 79 rows - and only ever move forwards.
        following = _next_guide_step(reported)
        if following > step:
            state["newPlayerGuideStep"] = step = following
            changed = True
    return {"guideId": step, "finish": step > _max_guide_step()}, changed


def _guide_groups(state: dict[str, Any]) -> list[int]:
    raw = state.setdefault("guideGroupsDone", [])
    if not isinstance(raw, list):
        state["guideGroupsDone"] = raw = []
    return raw


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto not in PLAYER_PROTOCOLS:
        return None
    if proto == PLAYER_SET_PLAYER_INFO:
        changed = set_player_info(state, decode_request(proto, body))
        return encode_response(proto), changed
    if proto == PLAYER_REQ_NEW_PLAYER_GUIDE:
        values, changed = guide_progress(state, decode_request(proto, body))
        return encode_response(proto, values), changed
    if proto == EXPLORE_REQ_GUIDE_INFO:
        return encode_response(proto, {"stepInfo": _guide_groups(state)}), False
    # EXPLORE_REQ_ADD_GUIDE_STEP: a one-off group guide the client just played.
    step = _as_int(decode_request(proto, body).get("stepId"))
    done = _guide_groups(state)
    changed = step > 0 and step not in [_as_int(value) for value in done]
    if changed:
        done.append(step)
    return encode_response(proto), changed


def dispatch(client: Any, proto: int, body: bytes) -> bool:
    result = response_for(proto, client.save, body)
    if result is None:
        return False
    payload, changed = result
    if changed:
        persist(client.save)
    client.send_pkt(proto, payload)
    if changed and proto == PLAYER_SET_PLAYER_INFO:
        client.send_pkt(PLAYER_PLAYER_INFO, encode_player_info(client.save))
    return True
