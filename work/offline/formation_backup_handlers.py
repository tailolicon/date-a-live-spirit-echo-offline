#!/usr/bin/env python3
"""Persistent formation preset/backup support for offline play."""
from __future__ import annotations

from copy import deepcopy
from typing import Any

from player_save import save as persist
from protocol_schema import decode_request, encode_response

PLAYER_REQ_FORMATION_BACKUP_LIST = 296
PLAYER_REQ_FORMATION_BACKUP_HERO = 297
PLAYER_REQ_FORMATION_BACKUP_USE = 298
PLAYER_REQ_FORMATION_BACKUP_DESC = 299
FORMATION_BACKUP_PROTOCOLS = frozenset({296, 297, 298, 299})
MAX_BACKUPS = 7  # client PreTeamSetView KVP fallback


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _hero_sids(state: dict[str, Any]) -> set[str]:
    raw = state.get("heroes", [])
    rows = raw.values() if isinstance(raw, dict) else raw if isinstance(raw, list) else []
    return {str(row.get("id")) for row in rows if isinstance(row, dict) and str(row.get("id", ""))}


def _main_stance(state: dict[str, Any]) -> list[str]:
    raw = state.get("formations", [])
    rows = raw.values() if isinstance(raw, dict) else raw if isinstance(raw, list) else []
    for row in rows:
        if isinstance(row, dict) and _as_int(row.get("type"), 1) == 1:
            return [str(v) for v in (row.get("stance", []) or []) if str(v)]
    return []


def _normalize_backup(row: dict[str, Any], backup_id: int) -> dict[str, Any]:
    base = row.get("base") if isinstance(row.get("base"), dict) else {}
    stance = []
    for sid in base.get("stance", row.get("stance", [])) or []:
        value = str(sid or "")
        if value and value not in stance:
            stance.append(value)
        if len(stance) >= 3:
            break
    return {
        "base": {"type": 1, "stance": stance},
        "id": backup_id,
        "desc": str(row.get("desc", "")),
    }


def _backups(state: dict[str, Any]) -> tuple[list[dict[str, Any]], bool]:
    raw = state.get("formationBackups")
    source = raw if isinstance(raw, list) else []
    by_id: dict[int, dict[str, Any]] = {}
    for row in source:
        if not isinstance(row, dict):
            continue
        backup_id = _as_int(row.get("id"))
        if 1 <= backup_id <= MAX_BACKUPS and backup_id not in by_id:
            by_id[backup_id] = row

    main = _main_stance(state)
    out: list[dict[str, Any]] = []
    for backup_id in range(1, MAX_BACKUPS + 1):
        seed = by_id.get(backup_id, {})
        normalized = _normalize_backup(seed, backup_id)
        # Seed only the first preset from the active main formation. Other
        # slots remain legitimate empty presets until edited by the player.
        if backup_id == 1 and not normalized["base"]["stance"] and main:
            normalized["base"]["stance"] = main[:3]
        out.append(normalized)
    changed = raw != out
    if changed:
        state["formationBackups"] = deepcopy(out)
    return out, changed


def _find_backup(backups: list[dict[str, Any]], backup_id: int) -> dict[str, Any] | None:
    for row in backups:
        if _as_int(row.get("id")) == backup_id:
            return row
    return None


def _change_backup_hero(state: dict[str, Any], request: dict[str, Any]) -> tuple[dict[str, Any] | None, bool]:
    backups, normalized = _backups(state)
    backup = _find_backup(backups, _as_int(request.get("id")))
    if backup is None:
        return None, normalized

    source = str(request.get("sourceHeroId", "") or "")
    target = str(request.get("targetHeroId", "") or "")
    owned = _hero_sids(state)
    stance = backup["base"]["stance"]
    before = list(stance)

    # HeroDataMgr sends the newly selected hero as source and the hero being
    # replaced as target. Empty target means append/toggle the source.
    if source and source not in owned:
        return backup, normalized
    if target and target not in stance:
        return backup, normalized

    if target:
        target_index = stance.index(target)
        if source:
            if source in stance:
                source_index = stance.index(source)
                stance[source_index], stance[target_index] = stance[target_index], stance[source_index]
            else:
                stance[target_index] = source
        else:
            stance.pop(target_index)
    elif source:
        if source in stance:
            stance.remove(source)
        elif len(stance) < 3:
            stance.append(source)

    changed = before != stance
    if changed:
        state["formationBackups"] = deepcopy(backups)
    return backup, normalized or changed


def _rename_backup(state: dict[str, Any], request: dict[str, Any]) -> tuple[dict[str, Any] | None, bool]:
    backups, normalized = _backups(state)
    backup = _find_backup(backups, _as_int(request.get("id")))
    if backup is None:
        return None, normalized
    desc = str(request.get("desc", ""))[:64]
    changed = backup.get("desc", "") != desc
    if changed:
        backup["desc"] = desc
        state["formationBackups"] = deepcopy(backups)
    return backup, normalized or changed


def _apply_backup(state: dict[str, Any], request: dict[str, Any]) -> bool:
    backups, normalized = _backups(state)
    backup = _find_backup(backups, _as_int(request.get("id")))
    formation_type = _as_int(request.get("formationType"), 1)
    if backup is None or formation_type not in (1, 2, 3):
        return normalized
    stance = list(backup["base"]["stance"])
    if not stance:
        return normalized

    raw = state.get("formations")
    if not isinstance(raw, list):
        state["formations"] = raw = []
    target = None
    for row in raw:
        if isinstance(row, dict) and _as_int(row.get("type")) == formation_type:
            target = row
            break
    if target is None:
        target = {"type": formation_type, "stance": []}
        raw.append(target)
    before = [str(v) for v in target.get("stance", []) or []]
    target["stance"] = stance
    return normalized or before != stance


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto == PLAYER_REQ_FORMATION_BACKUP_LIST:
        backups, changed = _backups(state)
        return encode_response(proto, {"formations": backups}), changed

    request = decode_request(proto, body)
    if proto == PLAYER_REQ_FORMATION_BACKUP_HERO:
        backup, changed = _change_backup_hero(state, request)
        return encode_response(proto, {"formation": backup or {}}), changed
    if proto == PLAYER_REQ_FORMATION_BACKUP_DESC:
        backup, changed = _rename_backup(state, request)
        return encode_response(proto, {"formation": backup or {}}), changed
    if proto == PLAYER_REQ_FORMATION_BACKUP_USE:
        changed = _apply_backup(state, request)
        return encode_response(proto, {}), changed
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
