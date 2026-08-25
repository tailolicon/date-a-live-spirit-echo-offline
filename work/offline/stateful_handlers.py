#!/usr/bin/env python3
"""State-backed protocol handlers for the offline single-player server."""
from __future__ import annotations

from copy import deepcopy
from typing import Any

from player_save import FIRST_PLOT_LEVEL, save as persist
from proto_codec import enc_bool_field, enc_msg_field, enc_varint_field
from protocol_schema import decode_request, encode_response

ITEM_GET_ITEMS = 515
HERO_GET_HEROS = 1025
PLAYER_OPERATE_FORMATION = 264
PLAYER_GET_FORMATIONS = 265
MAIL_GET_MAILS = 772
TASK_REQ_TASKS = 4097
DUNGEON_GET_LEVEL_INFO = 1796

STATEFUL_PROTOCOLS = frozenset({
    ITEM_GET_ITEMS,
    HERO_GET_HEROS,
    PLAYER_OPERATE_FORMATION,
    PLAYER_GET_FORMATIONS,
    MAIL_GET_MAILS,
    TASK_REQ_TASKS,
    DUNGEON_GET_LEVEL_INFO,
})


def inventory_records(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("items", {})
    if isinstance(raw, dict):
        return [deepcopy(v) for v in raw.values() if isinstance(v, dict)]
    if isinstance(raw, list):
        return [deepcopy(v) for v in raw if isinstance(v, dict)]
    return []


def hero_records(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("heroes", [])
    return [deepcopy(v) for v in raw if isinstance(v, dict)] if isinstance(raw, list) else []


def formation_records(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("formations", [])
    return [deepcopy(v) for v in raw if isinstance(v, dict)] if isinstance(raw, list) else []


def encode_dungeon_level_info(state: dict[str, Any]) -> bytes:
    passed = state.get("passedLevels") or [FIRST_PLOT_LEVEL]
    records = bytearray()
    for raw_cid in passed:
        try:
            cid = int(raw_cid)
        except (TypeError, ValueError):
            continue
        if cid <= 0:
            continue
        info = enc_varint_field(1, cid)
        info += enc_varint_field(3, 1)
        info += enc_bool_field(4, True)
        info += enc_varint_field(5, 0)
        info += enc_varint_field(6, 0)
        records += enc_msg_field(1, info)
    if not records:
        return encode_dungeon_level_info({"passedLevels": [FIRST_PLOT_LEVEL]})
    level_infos = enc_msg_field(1, bytes(records))
    return enc_msg_field(1, level_infos)


def _formation_by_type(state: dict[str, Any], formation_type: int) -> dict[str, Any]:
    formations = state.setdefault("formations", [])
    for formation in formations:
        if isinstance(formation, dict) and int(formation.get("type", 0)) == formation_type:
            formation.setdefault("ct", 0)
            formation.setdefault("status", 1)
            formation.setdefault("stance", [])
            return formation
    formation = {"ct": 0, "type": formation_type, "status": 1, "stance": []}
    formations.append(formation)
    return formation


def _owned_hero_ids(state: dict[str, Any]) -> set[str]:
    result: set[str] = set()
    for hero in hero_records(state):
        for key in ("id", "sid"):
            value = str(hero.get(key, "") or "")
            if value:
                result.add(value)
    return result


def operate_formation(state: dict[str, Any], request: dict[str, Any]) -> dict[str, Any]:
    formation_type = int(request.get("formationType", 1) or 1)
    if formation_type not in (1, 2, 3):
        formation_type = 1
    formation = _formation_by_type(state, formation_type)
    stance = [str(v) for v in formation.get("stance", []) if str(v)]
    source = str(request.get("sourceHeroId", "") or "")
    target = str(request.get("targetHeroId", "") or "")
    owned = _owned_hero_ids(state)
    if target and target not in owned:
        return deepcopy(formation)
    if source:
        try:
            idx = stance.index(source)
        except ValueError:
            idx = -1
        if target:
            if idx >= 0:
                stance[idx] = target
            elif target not in stance:
                stance.append(target)
        elif idx >= 0:
            stance.pop(idx)
    elif target and target not in stance:
        stance.append(target)
    clean: list[str] = []
    for hero_id in stance:
        if hero_id and hero_id not in clean:
            clean.append(hero_id)
    formation["stance"] = clean[:3]
    formation["ct"] = 0
    formation["status"] = 1
    return deepcopy(formation)


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto == ITEM_GET_ITEMS:
        return encode_response(proto, {"items": inventory_records(state)}), False
    if proto == HERO_GET_HEROS:
        return encode_response(proto, {"heros": hero_records(state)}), False
    if proto == PLAYER_GET_FORMATIONS:
        return encode_response(proto, {"formations": formation_records(state)}), False
    if proto == MAIL_GET_MAILS:
        return encode_response(proto, {"mails": state.get("mails", []) or []}), False
    if proto == TASK_REQ_TASKS:
        return encode_response(proto, {"taks": state.get("tasks", []) or []}), False
    if proto == DUNGEON_GET_LEVEL_INFO:
        return encode_dungeon_level_info(state), False
    if proto == PLAYER_OPERATE_FORMATION:
        request = decode_request(proto, body)
        formation = operate_formation(state, request)
        return encode_response(proto, formation), True
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
