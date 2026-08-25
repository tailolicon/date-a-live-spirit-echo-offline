#!/usr/bin/env python3
"""Single-player dungeon combat lifecycle for the offline preservation server.

Story/PVE battles are simulated by the original client. The server owns only
start authorization, persistent level state and settlement/rewards.  Keeping
that boundary lets the preserved client run its real battle code while making
settlement deterministic and idempotent offline.
"""
from __future__ import annotations

from copy import deepcopy
import time
from typing import Any

from player_save import save as persist
from protocol_schema import decode_request, encode_response
from state_transactions import grant_rewards, normalize_rewards

DUNGEON_FIGHT_START = 1793
DUNGEON_FIGHT_OVER = 1794

COMBAT_PROTOCOLS = frozenset({DUNGEON_FIGHT_START, DUNGEON_FIGHT_OVER})


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _definition(state: dict[str, Any], level_cid: int) -> dict[str, Any]:
    raw = state.get("levelDefinitions", {})
    if not isinstance(raw, dict):
        return {}
    row = raw.get(str(level_cid), raw.get(level_cid, {}))
    return row if isinstance(row, dict) else {}


def _level_states(state: dict[str, Any]) -> dict[str, dict[str, Any]]:
    raw = state.setdefault("levelStates", {})
    if not isinstance(raw, dict):
        state["levelStates"] = raw = {}
    return raw


def _level_state(state: dict[str, Any], level_cid: int) -> dict[str, Any]:
    rows = _level_states(state)
    key = str(level_cid)
    row = rows.get(key)
    if not isinstance(row, dict):
        already_won = level_cid in [
            _as_int(value) for value in (state.get("passedLevels") or [])
        ]
        row = {
            "cid": level_cid,
            "goals": [],
            "fightCount": 0,
            "win": already_won,
            "buyCount": 0,
            "freeCount": 0,
        }
        rows[key] = row
    row["cid"] = level_cid
    row.setdefault("goals", [])
    row.setdefault("fightCount", 0)
    row.setdefault("win", False)
    row.setdefault("buyCount", 0)
    row.setdefault("freeCount", 0)
    return row


def _public_level_info(row: dict[str, Any]) -> dict[str, Any]:
    goals: list[int] = []
    for value in row.get("goals", []) or []:
        value = _as_int(value)
        if value > 0 and value not in goals:
            goals.append(value)
    return {
        "cid": max(0, _as_int(row.get("cid"))),
        "goals": goals,
        "fightCount": max(0, _as_int(row.get("fightCount"))),
        "win": bool(row.get("win", False)),
        "buyCount": max(0, _as_int(row.get("buyCount"))),
        "freeCount": max(0, _as_int(row.get("freeCount"))),
    }


def _next_fight_id(state: dict[str, Any], level_cid: int) -> tuple[int, str]:
    seq = max(0, _as_int(state.get("fightSequence"))) + 1
    state["fightSequence"] = seq
    return seq, f"offline-{level_cid}-{seq}"


def _start_fight(state: dict[str, Any], request: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    level_cid = _as_int(request.get("levelCid"))
    if level_cid <= 0:
        # Keep a wire-valid response but do not create/persist a bogus fight.
        return {
            "levelCid": 0,
            "hero": {},
            "fightId": "",
            "randomSeed": 0,
            "rewards": [],
            "helpPid": 0,
            "limitHeros": [],
            "isDuelMod": bool(request.get("isDuelMod", False)),
        }, False

    seq, fight_id = _next_fight_id(state, level_cid)
    # A deterministic non-zero seed is enough for the client's local RNG and
    # makes protocol replays reproducible for a given save/fight sequence.
    seed = ((level_cid * 1103515245) + seq * 12345) & 0x7FFFFFFF
    if seed == 0:
        seed = 1

    limit_heros = []
    for row in request.get("limitHeros", []) or []:
        if not isinstance(row, dict):
            continue
        limit_heros.append({
            "limitType": _as_int(row.get("limitType")),
            "limitCid": _as_int(row.get("limitCid")),
        })

    help_pid = _as_int(request.get("helpPlayerId"))
    helper = {}
    helpers = state.get("fightHelpers", {})
    if help_pid > 0 and isinstance(helpers, dict):
        candidate = helpers.get(str(help_pid), helpers.get(help_pid))
        if isinstance(candidate, dict):
            helper = deepcopy(candidate)
        else:
            help_pid = 0
    else:
        help_pid = 0

    active = {
        "fightId": fight_id,
        "sequence": seq,
        "levelCid": level_cid,
        "randomSeed": seed,
        "startedAt": int(time.time()),
        "isDuelMod": bool(request.get("isDuelMod", False)),
        "quickCount": max(0, _as_int(request.get("quickCount"))),
        "settled": False,
    }
    state["activeFight"] = active

    definition = _definition(state, level_cid)
    start_rewards = definition.get("startRewards", [])
    if not isinstance(start_rewards, list):
        start_rewards = []

    return {
        "levelCid": level_cid,
        "hero": helper,
        "fightId": fight_id,
        "randomSeed": seed,
        "rewards": normalize_rewards(start_rewards),
        "helpPid": help_pid,
        "limitHeros": limit_heros,
        "isDuelMod": bool(request.get("isDuelMod", False)),
    }, True


def _merge_goals(existing: Any, incoming: Any) -> list[int]:
    result: list[int] = []
    for source in (existing or [], incoming or []):
        for value in source:
            value = _as_int(value)
            if value > 0 and value not in result:
                result.append(value)
    return result


def _last_result(state: dict[str, Any], level_cid: int) -> dict[str, Any] | None:
    raw = state.get("lastFightResult")
    if not isinstance(raw, dict) or _as_int(raw.get("levelCid")) != level_cid:
        return None
    response = raw.get("response")
    return deepcopy(response) if isinstance(response, dict) else None


def _fight_over(state: dict[str, Any], request: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    level_cid = _as_int(request.get("levelCid"))
    current_win = bool(request.get("isWin", False))
    if level_cid <= 0:
        return {
            "levelInfo": _public_level_info({"cid": 0}),
            "rewards": [],
            "win": False,
            "additionAward": [],
            "original": [],
        }, False

    active = state.get("activeFight")
    if not isinstance(active, dict) or _as_int(active.get("levelCid")) != level_cid:
        # TCP retries can resend settlement after the first response was lost.
        # Return the previous response without mutating/granting a second time.
        previous = _last_result(state, level_cid)
        if previous is not None:
            return previous, False
        # Do not grant rewards for an unsolicited settlement, but return the
        # shape the Lua handler requires so the client does not crash.
        row = _level_state(state, level_cid)
        return {
            "levelInfo": _public_level_info(row),
            "rewards": [],
            "win": False,
            "additionAward": [],
            "original": [],
        }, False

    row = _level_state(state, level_cid)
    was_won = bool(row.get("win", False))
    row["fightCount"] = max(0, _as_int(row.get("fightCount"))) + 1
    row["goals"] = _merge_goals(row.get("goals", []), request.get("goals", []))

    rewards: list[dict[str, int]] = []
    original: list[dict[str, int]] = []
    definition = _definition(state, level_cid)
    if current_win:
        row["win"] = True
        configured = definition.get("rewards", [])
        if isinstance(configured, list):
            original.extend(normalize_rewards(configured))
        if not was_won:
            first_clear = definition.get("firstClearRewards", [])
            if isinstance(first_clear, list):
                original.extend(normalize_rewards(first_clear))
        rewards = grant_rewards(state, normalize_rewards(original)) if original else []

        passed = state.setdefault("passedLevels", [])
        if not isinstance(passed, list):
            state["passedLevels"] = passed = []
        if level_cid not in [_as_int(value) for value in passed]:
            passed.append(level_cid)
        next_level = _as_int(definition.get("nextLevelCid"))
        if next_level > 0:
            state["mainLineCid"] = next_level
        else:
            state["mainLineCid"] = max(_as_int(state.get("mainLineCid")), level_cid)

    response = {
        "levelInfo": _public_level_info(row),
        "rewards": rewards,
        "win": current_win,
        "additionAward": [],
        "original": normalize_rewards(original),
    }
    state["lastFightResult"] = {
        "fightId": str(active.get("fightId", "")),
        "levelCid": level_cid,
        "settledAt": int(time.time()),
        "response": deepcopy(response),
    }
    state.pop("activeFight", None)
    return response, True


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto == DUNGEON_FIGHT_START:
        values, changed = _start_fight(state, decode_request(proto, body))
        return encode_response(proto, values), changed
    if proto == DUNGEON_FIGHT_OVER:
        values, changed = _fight_over(state, decode_request(proto, body))
        return encode_response(proto, values), changed
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
