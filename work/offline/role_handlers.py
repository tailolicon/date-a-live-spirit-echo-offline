#!/usr/bin/env python3
"""The player's board girls - s2c 1281 ROLE_ROLE_INFO_LIST.

`RoleDataMgr` builds `roleTable` from the shipped Role table, but which rows
the player actually *has* - and which one is currently on duty - comes from the
server. `roleHandle` sets `useId` from the row whose `status == 1`, and
`getCurId()` falls back to it.

With an empty list `getCurId()` is nil, and every `self.roleTable[roleId]`
lookup indexes nil. That is what breaks story stages: the dating settlement
calls `RoleDataMgr:setMainLiveStateByRuleCid(scriptId, NORMAL)` with no roleId,
so the settlement handler throws half-way and the stage never reaches its
result view - the script plays to its last line and simply stops.
"""
from __future__ import annotations

from copy import deepcopy
from typing import Any

from protocol_schema import encode_response

ROLE_GET_ROLE = 1281

ROLE_PROTOCOLS = frozenset({ROLE_GET_ROLE})

# Kotori (Role 105) is the operator the prologue hands the player and the
# `dungeonRoleId` on Volume 1's story scripts, so she is the on-duty default.
DEFAULT_ROLE_CID = 105
ROLE_STATUS_ON_DUTY = 1


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def default_role(cid: int = DEFAULT_ROLE_CID) -> dict[str, Any]:
    return {
        "ct": 0,
        "id": f"local-role-{int(cid)}",
        "cid": int(cid),
        "favor": 0,
        "mood": 0,
        "status": ROLE_STATUS_ON_DUTY,
        "unlockGift": [],
        "unlockHobby": [],
        "roomId": 0,
        "favorCriticalPoint": False,
        "favoriteIds": [],
        "isShow": True,
    }


def role_records(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("roles")
    rows = [deepcopy(row) for row in raw if isinstance(row, dict)] if isinstance(raw, list) else []
    rows = [row for row in rows if _as_int(row.get("cid")) > 0]
    if not rows:
        rows = [default_role()]
    on_duty = next((row for row in rows if _as_int(row.get("status")) == ROLE_STATUS_ON_DUTY), None)
    if on_duty is None:
        rows[0]["status"] = ROLE_STATUS_ON_DUTY
    for row in rows:
        row.setdefault("ct", 0)
        row.setdefault("id", f"local-role-{_as_int(row.get('cid'))}")
        row.setdefault("favor", 0)
        row.setdefault("mood", 0)
        row.setdefault("status", 0)
        row.setdefault("unlockGift", [])
        row.setdefault("unlockHobby", [])
        row.setdefault("roomId", 0)
        row.setdefault("favorCriticalPoint", False)
        row.setdefault("favoriteIds", [])
        row["isShow"] = bool(row.get("isShow", True))
        # `dress` and `roleState` stay absent on purpose: roleInfoCopy reads a
        # present dress as an equipped one and feeds any roleState it is given
        # to addElvesState, which has no row for 0.
        row["dress"] = None
        row["roleState"] = None
    return rows


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto != ROLE_GET_ROLE:
        return None
    return encode_response(proto, {
        "roles": role_records(state),
        "rotationList": [],
        "rotationState": False,
    }), False


def dispatch(client: Any, proto: int, body: bytes) -> bool:
    result = response_for(proto, client.save, body)
    if result is None:
        return False
    payload, _ = result
    client.send_pkt(proto, payload)
    return True
