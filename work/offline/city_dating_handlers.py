#!/usr/bin/env python3
"""City-dating stages - the third kind of story stage (s2c 5633 and friends).

`DungeonLevel.dungeonType = CITYDATING` stages send the player into the town
map instead of a battle or a straight visual novel:
`FubenDataMgr:onRecvFightStart` routes them to
`NewCityDataMgr:sendGetCitySetpData(NewCity_FuBen, datingID[1], curRoleId)`,
which is c2s 5633.

`onRespDatingMainInfo` needs `info.entrances` to be non-empty - it indexes
`entrances[1].entranceId` into the script table to find the step, then builds
the town from `NovelStep[stepId].basicCity`. An empty reply is an immediate nil
index, so the stage dies before the map is drawn.

Everything the town itself is made of (buildings, roles, dialogue) is static
data the client already ships. The server owns exactly one thing: how far
through the line the player is. That advances when the *stage* is cleared -
`SettlementLayer:close` sends DUNGEON_FIGHT_OVER for a fuben town, same as a
plain story stage - rather than on each mid-script choice, which the wire
cannot tell apart from the final one.
"""
from __future__ import annotations

from typing import Any

from game_static_config import GameStaticConfig, StaticConfigUnavailable, config as static_config
from player_save import save as persist
from protocol_schema import decode_request, encode_response

EXTRA_DATING_REQ_EXTRA_DATING_INFO = 5633
EXTRA_DATING_REQ_START_ENTRANCE_EVENT = 5634
EXTRA_DATING_REQ_CHOOSE_ENTRANCE_EVENT = 5635
EXTRA_DATING_SETTLE_INFO = 5637
EXTRA_DATING_REQ_GET_EVENT_CHOICES = 5640
EXTRA_DATING_REQ_ENTER = 5662

CITY_DATING_PROTOCOLS = frozenset({
    EXTRA_DATING_REQ_EXTRA_DATING_INFO,
    EXTRA_DATING_REQ_START_ENTRANCE_EVENT,
    EXTRA_DATING_REQ_CHOOSE_ENTRANCE_EVENT,
    EXTRA_DATING_REQ_GET_EVENT_CHOICES,
    EXTRA_DATING_REQ_ENTER,
})

# EC_NewCityType.NewCity_FuBen - a town opened from a story stage.
NEW_CITY_FUBEN = 3


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _lines(state: dict[str, Any]) -> dict[str, Any]:
    raw = state.setdefault("cityDatings", {})
    if not isinstance(raw, dict):
        state["cityDatings"] = raw = {}
    return raw


def _line(state: dict[str, Any], dating_type: int, dating_value: int) -> dict[str, Any]:
    key = f"{int(dating_type)}:{int(dating_value)}"
    rows = _lines(state)
    row = rows.get(key)
    if not isinstance(row, dict):
        row = {"datingType": int(dating_type), "datingValue": int(dating_value),
               "stepId": 0, "entrancesDone": []}
        rows[key] = row
    row.setdefault("stepId", 0)
    done = row.get("entrancesDone")
    if not isinstance(done, list):
        row["entrancesDone"] = []
    return row


def _current_step(cfg: GameStaticConfig, row: dict[str, Any]) -> dict[str, Any] | None:
    dating_type = _as_int(row.get("datingType"))
    dating_value = _as_int(row.get("datingValue"))
    steps = cfg.city_steps(dating_type, dating_value)
    if not steps:
        return None
    step_id = _as_int(row.get("stepId"))
    for step in steps:
        if step["stepId"] == step_id:
            return step
    # No progress yet (or a step id from a table that has since changed): start
    # the line at its first step.
    return steps[0]


def dating_info(state: dict[str, Any], dating_type: int, dating_value: int,
                cfg: GameStaticConfig | None = None) -> dict[str, Any] | None:
    """s2c 5633 / 5637 `info` for one city-dating line."""
    if dating_value <= 0:
        return None
    try:
        cfg = cfg or static_config()
        row = _line(state, dating_type, dating_value)
        step = _current_step(cfg, row)
    except StaticConfigUnavailable:
        return None
    if step is None:
        return None
    row["stepId"] = step["stepId"]

    entrances = []
    for event_id in step["events"]:
        event = cfg.city_event(dating_type, event_id)
        if event is None or not event["use"]:
            continue
        entrances.append({"entranceId": event_id, "guide": False})
    if not entrances:
        # onRespDatingMainInfo indexes entrances[1] with no guard.
        return None

    quality = row.get("quality")
    quality_rows = [{"qualityId": _as_int(key), "value": _as_int(value)}
                    for key, value in sorted((quality or {}).items())] if isinstance(quality, dict) else []
    return {
        "datingType": int(dating_type),
        "datingValue": int(dating_value),
        "bag": [],
        "endings": [_as_int(v) for v in (row.get("endings") or [])],
        "stepTime": _as_int(step.get("stepTime")),
        "entrances": entrances,
        "quality": quality_rows,
    }


def advance_line(state: dict[str, Any], dating_type: int, dating_value: int,
                 cfg: GameStaticConfig | None = None) -> bool:
    """Move a line to the step its finished entrance jumps to."""
    try:
        cfg = cfg or static_config()
        row = _line(state, dating_type, dating_value)
        step = _current_step(cfg, row)
    except StaticConfigUnavailable:
        return False
    if step is None:
        return False
    for event_id in step["events"]:
        event = cfg.city_event(dating_type, event_id)
        if event is None:
            continue
        done = row["entrancesDone"]
        if event_id not in done:
            done.append(event_id)
        jump = _as_int(event.get("stepJump"))
        if jump > 0 and jump != _as_int(row.get("stepId")):
            row["stepId"] = jump
            return True
    return False


def _entrance_first(state: dict[str, Any], dating_type: int, dating_value: int,
                    entrance_id: int) -> bool:
    row = _line(state, dating_type, dating_value)
    return entrance_id not in [_as_int(v) for v in row["entrancesDone"]]


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto not in CITY_DATING_PROTOCOLS:
        return None
    request = decode_request(proto, body)

    if proto == EXTRA_DATING_REQ_ENTER:
        return encode_response(proto, {"enter": True}), False

    dating_type = _as_int(request.get("datingType"), NEW_CITY_FUBEN)
    dating_value = _as_int(request.get("datingValue"))

    if proto == EXTRA_DATING_REQ_EXTRA_DATING_INFO:
        info = dating_info(state, dating_type, dating_value)
        if info is None:
            return None
        return encode_response(proto, {"info": info}), True

    if proto == EXTRA_DATING_REQ_START_ENTRANCE_EVENT:
        entrance_id = _as_int(request.get("entranceId"))
        return encode_response(proto, {
            "datingType": dating_type,
            "first": _entrance_first(state, dating_type, dating_value, entrance_id),
        }), False

    if proto == EXTRA_DATING_REQ_GET_EVENT_CHOICES:
        # The list is the choices already taken on this event; a fresh run has
        # none, and the client only uses it to grey options out.
        return encode_response(proto, {
            "datingType": dating_type,
            "datingValue": dating_value,
            "eventId": [],
        }), False

    # EXTRA_DATING_REQ_CHOOSE_ENTRANCE_EVENT
    return encode_response(proto, {
        "datingType": dating_type,
        "datingValue": dating_value,
        # A story town pays out through its stage's DUNGEON_FIGHT_OVER drop,
        # so no items change hands here.
        "items": [],
        "endItems": [],
        "costItems": [],
        "quality": [],
        "stepEnd": True,
        "endId": _as_int(request.get("eventId")),
    }), False


def dispatch(client: Any, proto: int, body: bytes) -> bool:
    result = response_for(proto, client.save, body)
    if result is None:
        return False
    payload, mutated = result
    if mutated:
        persist(client.save)
    client.send_pkt(proto, payload)
    return True
