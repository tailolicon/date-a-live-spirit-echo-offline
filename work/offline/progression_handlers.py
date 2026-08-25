#!/usr/bin/env python3
"""Stateful hero/social progression handlers for the offline server.

This module intentionally stays separate from ``stateful_handlers`` so the
startup-critical hero spirit and social write paths can evolve without
turning the generic login/state module into one large dispatcher.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any

from player_save import save as persist
from protocol_schema import decode_request, encode_response

HERO_SPIRIT_REQ_PUT_SPIRIT_POINTS = 8401
HERO_SPIRIT_REQ_SHOW_NEW_SPIRIT = 8406
HERO_SPIRIT_REQ_NEW_SPIRIT_INFO = 8407
HERO_REQ_USE_SKILL_STRATEGY = 1040
FRIEND_REQ_OPERATE = 3074

# Client EnumConfig.lua values.
FRIEND = 1
SHIELDING = 2
APPLY = 3
ADD = 4
INVITE = 5

APPLY_FRIEND = 1
DELETE_FRIEND = 2
SHIELD_PLAYER = 3
LIFTED_SHIELD = 4
AGREE_APPLY = 5
REFUSE_APPLY = 6
GIVE_GIFT = 7
RECEIVE_GIFT = 8

PROGRESSION_PROTOCOLS = frozenset({
    HERO_SPIRIT_REQ_PUT_SPIRIT_POINTS,
    HERO_SPIRIT_REQ_SHOW_NEW_SPIRIT,
    HERO_SPIRIT_REQ_NEW_SPIRIT_INFO,
    HERO_REQ_USE_SKILL_STRATEGY,
    FRIEND_REQ_OPERATE,
})


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _normalize_spirit(state: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    raw = state.get("spiritInfo")
    source = raw if isinstance(raw, dict) else {}

    specialism: list[dict[str, int]] = []
    for row in source.get("specialism", []) or []:
        if not isinstance(row, dict):
            continue
        cid = _as_int(row.get("cid"))
        num = max(0, _as_int(row.get("num")))
        if cid > 0 and num > 0:
            specialism.append({"cid": cid, "num": num})

    angle_spirits: list[dict[str, int]] = []
    for row in source.get("angleSpirits", []) or []:
        if not isinstance(row, dict):
            continue
        hero_cid = _as_int(row.get("heroCid"))
        level = max(0, _as_int(row.get("lv")))
        if hero_cid > 0:
            angle_spirits.append({"heroCid": hero_cid, "lv": level})

    level = max(1, _as_int(source.get("level"), 1))
    max_level = max(level, _as_int(source.get("maxLv"), level))
    value = {
        "spiritPoints": max(0, _as_int(source.get("spiritPoints"))),
        "grade": max(0, _as_int(source.get("grade"))),
        "level": level,
        "exp": max(0, _as_int(source.get("exp"))),
        "specialism": specialism,
        "firstShow": bool(source.get("firstShow", False)),
        "feedback": bool(source.get("feedback", False)),
        "angleSpirits": angle_spirits,
        "maxLv": max_level,
    }
    changed = raw != value
    if changed:
        state["spiritInfo"] = deepcopy(value)
    return value, changed


def _hero_rows(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("heroes", [])
    if isinstance(raw, list):
        return [row for row in raw if isinstance(row, dict)]
    if isinstance(raw, dict):
        return [row for row in raw.values() if isinstance(row, dict)]
    return []


def _find_hero_by_sid(state: dict[str, Any], sid: Any) -> dict[str, Any] | None:
    wanted = str(sid or "")
    if not wanted:
        return None
    for hero in _hero_rows(state):
        if str(hero.get("id", "")) == wanted:
            return hero
    return None


def _friend_rows(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("friends", [])
    if not isinstance(raw, list):
        state["friends"] = raw = []
    if any(not isinstance(row, dict) for row in raw):
        raw = [row for row in raw if isinstance(row, dict)]
        state["friends"] = raw
    return raw


def _friend_pid(row: dict[str, Any]) -> int:
    return _as_int(row.get("pid", row.get("playerId")))


def _friend_index(rows: list[dict[str, Any]], pid: int) -> int:
    for index, row in enumerate(rows):
        if _friend_pid(row) == pid:
            return index
    return -1


def _operate_friend(state: dict[str, Any], operation: int, targets: list[int]) -> bool:
    rows = _friend_rows(state)
    changed = False
    for pid in targets:
        if pid <= 0 or pid == _as_int(state.get("pid")):
            continue
        index = _friend_index(rows, pid)
        row = rows[index] if index >= 0 else None

        if operation == DELETE_FRIEND:
            if index >= 0:
                rows.pop(index)
                changed = True
        elif operation == SHIELD_PLAYER:
            if row is not None and _as_int(row.get("status")) != SHIELDING:
                previous = _as_int(row.get("status"))
                if previous in (FRIEND, APPLY, ADD, INVITE):
                    row["previousStatus"] = previous
                row["status"] = SHIELDING
                changed = True
        elif operation == LIFTED_SHIELD:
            if row is not None and _as_int(row.get("status")) == SHIELDING:
                previous = _as_int(row.get("previousStatus"))
                if previous in (FRIEND, APPLY, ADD, INVITE):
                    row["status"] = previous
                    row.pop("previousStatus", None)
                else:
                    rows.pop(index)
                changed = True
        elif operation == AGREE_APPLY:
            if row is not None and _as_int(row.get("status")) == APPLY:
                row["status"] = FRIEND
                row.pop("previousStatus", None)
                changed = True
        elif operation == REFUSE_APPLY:
            if row is not None and _as_int(row.get("status")) == APPLY:
                rows.pop(index)
                changed = True
        elif operation == APPLY_FRIEND:
            # Offline mode has no remote peer to accept the request. Preserve
            # an existing recommendation as a local outgoing request only;
            # never synthesize a fake player row without profile data.
            if row is not None and _as_int(row.get("status")) == ADD:
                row["status"] = APPLY
                changed = True
        elif operation == GIVE_GIFT:
            if row is not None and _as_int(row.get("status")) == FRIEND and bool(row.get("canSend", False)):
                row["canSend"] = False
                changed = True
        elif operation == RECEIVE_GIFT:
            if row is not None and _as_int(row.get("status")) == FRIEND and bool(row.get("receive", False)):
                row["receive"] = False
                state["friendReceiveCount"] = max(0, _as_int(state.get("friendReceiveCount"))) + 1
                changed = True

    return changed


def _request_rows(request: dict[str, Any]) -> list[dict[str, Any]]:
    for value in request.values():
        if isinstance(value, list):
            return [row for row in value if isinstance(row, dict)]
    return []


def _put_spirit_points(state: dict[str, Any], request: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    spirit, normalized = _normalize_spirit(state)
    requested: dict[int, int] = {}
    for row in _request_rows(request):
        cid = _as_int(row.get("cid"))
        num = _as_int(row.get("num"))
        if cid > 0 and num > 0:
            requested[cid] = requested.get(cid, 0) + num
    if not requested:
        return spirit, normalized

    allocated = sum(max(0, _as_int(row.get("num"))) for row in spirit.get("specialism", []))
    remaining = max(0, _as_int(spirit.get("spiritPoints")) - allocated)
    total_request = sum(requested.values())
    if total_request > remaining:
        return spirit, normalized

    by_cid = {row["cid"]: row for row in spirit["specialism"]}
    for cid, num in requested.items():
        row = by_cid.get(cid)
        if row is None:
            row = {"cid": cid, "num": 0}
            spirit["specialism"].append(row)
            by_cid[cid] = row
        row["num"] += num
    state["spiritInfo"] = deepcopy(spirit)
    return spirit, True


def _show_new_spirit(state: dict[str, Any]) -> bool:
    spirit, changed = _normalize_spirit(state)
    if spirit.get("firstShow", False):
        spirit["firstShow"] = False
        state["spiritInfo"] = deepcopy(spirit)
        changed = True
    for hero in _hero_rows(state):
        info = hero.get("spiritInfo")
        if isinstance(info, dict) and bool(info.get("firstShow", False)):
            info["firstShow"] = False
            changed = True
    return changed


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto == HERO_SPIRIT_REQ_PUT_SPIRIT_POINTS:
        spirit, changed = _put_spirit_points(state, decode_request(proto, body))
        return encode_response(proto, {"spirit": spirit}), changed

    if proto == HERO_SPIRIT_REQ_SHOW_NEW_SPIRIT:
        changed = _show_new_spirit(state)
        return encode_response(proto, {}), changed

    if proto == HERO_SPIRIT_REQ_NEW_SPIRIT_INFO:
        spirit, changed = _normalize_spirit(state)
        return encode_response(proto, {"spirits": spirit}), changed

    if proto == HERO_REQ_USE_SKILL_STRATEGY:
        request = decode_request(proto, body)
        hero_id = str(request.get("heroId", ""))
        strategy_id = _as_int(request.get("skillStrategyId"))
        hero = _find_hero_by_sid(state, hero_id)
        changed = False
        if hero is not None and strategy_id > 0 and _as_int(hero.get("useSkillStrategy"), 1) != strategy_id:
            hero["useSkillStrategy"] = strategy_id
            changed = True
        return encode_response(proto, {"heroId": hero_id, "skillStrategyId": strategy_id}), changed

    if proto == FRIEND_REQ_OPERATE:
        request = decode_request(proto, body)
        operation = _as_int(request.get("type"))
        targets = []
        for value in request.get("targets", []) or []:
            pid = _as_int(value)
            if pid > 0 and pid not in targets:
                targets.append(pid)
        changed = _operate_friend(state, operation, targets)
        return encode_response(proto, {"type": operation, "targets": targets}), changed

    return None


def dispatch(client: Any, proto: int, body: bytes) -> bool:
    result = response_for(proto, client.save, body)
    if result is None:
        return False
    payload, mutated = result
    if mutated:
        persist(client.save)
    client.send_pkt(proto, payload)
    return True
