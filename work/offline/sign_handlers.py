#!/usr/bin/env python3
"""Persistent, config-driven sign-in support for offline play.

The retail client owns the calendar/reward tables.  The offline server keeps
claim state in the player save and only grants rewards explicitly present in
``signRewards``; missing configuration is represented as a disabled sign entry
rather than inventing premium rewards.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any

from player_save import save as persist
from protocol_schema import decode_request, encode_response, registry
from state_transactions import grant_rewards, normalize_rewards

SIGN_REQ_SIGN_INFOS = 5121
SIGN_SUBMIT_SIGN = 5122
SIGN_REQ_LANGUGE_SIGN = 5162
SIGN_PROTOCOLS = frozenset({SIGN_REQ_SIGN_INFOS, SIGN_SUBMIT_SIGN, SIGN_REQ_LANGUGE_SIGN})

SIGNED = 0
CAN_SIGN = 1
CANNOT_SIGN = 2


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _response_values(proto: int, *values: Any) -> dict[str, Any]:
    """Map positional semantic values to the exact shipped descriptor names."""
    fields = registry().s2c.get(proto, ())
    return {fields[i].name: value for i, value in enumerate(values) if i < len(fields)}


def _reward_config(state: dict[str, Any], sign_id: int) -> list[dict[str, int]]:
    raw = state.get("signRewards", {})
    if not isinstance(raw, dict):
        return []
    value = raw.get(str(sign_id), raw.get(sign_id, []))
    if isinstance(value, dict):
        value = value.get("rewards", [])
    return normalize_rewards(value if isinstance(value, list) else [])


def _normalize_award_types(raw: Any, configured: bool) -> list[int]:
    if isinstance(raw, list):
        out = []
        for value in raw:
            status = _as_int(value, CANNOT_SIGN)
            out.append(status if status in (SIGNED, CAN_SIGN, CANNOT_SIGN) else CANNOT_SIGN)
        if out:
            return out
    return [CAN_SIGN if configured else CANNOT_SIGN]


def _normalize_sign_infos(state: dict[str, Any]) -> tuple[list[dict[str, Any]], bool]:
    raw = state.get("signInfos")
    source = raw if isinstance(raw, list) else []
    by_id: dict[int, dict[str, Any]] = {}
    for row in source:
        if not isinstance(row, dict):
            continue
        sign_id = _as_int(row.get("id"))
        if 1 <= sign_id <= 4 and sign_id not in by_id:
            by_id[sign_id] = row

    normalized: list[dict[str, Any]] = []
    for sign_id in range(1, 5):
        row = by_id.get(sign_id, {})
        configured = bool(_reward_config(state, sign_id))
        supply_days = []
        for value in row.get("supplyDays", []) or []:
            day = _as_int(value)
            if day > 0 and day not in supply_days:
                supply_days.append(day)
        normalized.append({
            "id": sign_id,
            "index": max(0, _as_int(row.get("index"))),
            "extendData": str(row.get("extendData", "")),
            "awardType": _normalize_award_types(row.get("awardType"), configured),
            "supplyLimit": max(0, _as_int(row.get("supplyLimit"))),
            "supplyDays": supply_days,
        })

    changed = raw != normalized
    if changed:
        state["signInfos"] = deepcopy(normalized)
    return normalized, changed


def _find_info(infos: list[dict[str, Any]], sign_id: int) -> dict[str, Any] | None:
    for row in infos:
        if _as_int(row.get("id")) == sign_id:
            return row
    return None


def _claim(state: dict[str, Any], sign_id: int) -> tuple[list[dict[str, int]], bool]:
    infos, normalized = _normalize_sign_infos(state)
    info = _find_info(infos, sign_id)
    rewards = _reward_config(state, sign_id)
    if info is None or not rewards:
        return [], normalized

    statuses = list(info.get("awardType", []))
    try:
        claim_index = statuses.index(CAN_SIGN)
    except ValueError:
        return [], normalized

    # Grant and state transition are performed together in the in-memory save;
    # dispatch persists once afterwards, so a repeated request is idempotent.
    granted = grant_rewards(state, rewards)
    if not granted:
        return [], normalized
    statuses[claim_index] = SIGNED
    info["awardType"] = statuses
    if sign_id == 1:
        info["index"] = max(_as_int(info.get("index")), claim_index + 1)
    state["signInfos"] = deepcopy(infos)
    return granted, True


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto == SIGN_REQ_SIGN_INFOS:
        infos, changed = _normalize_sign_infos(state)
        return encode_response(proto, _response_values(proto, infos)), changed

    if proto == SIGN_SUBMIT_SIGN:
        request = decode_request(proto, body)
        fields = registry().c2s.get(proto, ())
        sign_id = _as_int(request.get(fields[0].name)) if fields else 0
        rewards, changed = _claim(state, sign_id)
        return encode_response(proto, _response_values(proto, sign_id, rewards)), changed

    if proto == SIGN_REQ_LANGUGE_SIGN:
        request = decode_request(proto, body)
        fields = registry().c2s.get(proto, ())
        language = _as_int(request.get(fields[0].name), _as_int(state.get("language"), 1)) if fields else 1
        if language not in (1, 2):
            language = _as_int(state.get("language"), 1)
            if language not in (1, 2):
                language = 1
        changed = _as_int(state.get("language"), 1) != language
        if changed:
            state["language"] = language
        return encode_response(proto, _response_values(proto, language)), changed

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
