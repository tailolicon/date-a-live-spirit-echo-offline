#!/usr/bin/env python3
"""Single-player dungeon combat lifecycle for the offline preservation server.

Story/PVE battles are simulated by the original client. The server owns only
start authorization, persistent level state and settlement/rewards.  Keeping
that boundary lets the preserved client run its real battle code while making
settlement deterministic and idempotent offline.
"""
from __future__ import annotations

from copy import deepcopy
from random import randint
import time
from typing import Any

import city_dating_handlers
from game_static_config import StaticConfigUnavailable, config as static_config
from player_info import encode_player_info
from player_save import save as persist
from stateful_handlers import inventory_records as _inventory_records
from protocol_schema import decode_request, encode_response
from state_transactions import consume_cids, grant_rewards, normalize_rewards

DUNGEON_FIGHT_START = 1793
DUNGEON_FIGHT_OVER = 1794
PLAYER_PLAYER_INFO = 267
ITEM_ITEM_LIST = 515

# EC_FBLevelType.CITYDATING - a stage played out on the town map.
CITYDATING_DUNGEON_TYPE = 3

COMBAT_PROTOCOLS = frozenset({DUNGEON_FIGHT_START, DUNGEON_FIGHT_OVER})

# EC_Currency.PLAYEREXP: a drop row, but the player's level - not an item.
PLAYER_EXP_CID = 500005


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _drop_rewards(drop_id: int) -> list[dict[str, int]]:
    """Flatten one Drop row. `fixed` always drops; `basic` is a per-10000 roll.

    Rolling here rather than at grant time keeps a settlement idempotent: the
    result is recorded in `lastFightResult` and replayed verbatim if the client
    resends the settlement.
    """
    if drop_id <= 0:
        return []
    try:
        drop = static_config().dungeon_drop(drop_id)
    except StaticConfigUnavailable:
        return []
    if not drop:
        return []
    rows: list[dict[str, int]] = []
    for entry in drop.get("fixed", []):
        num = randint(_as_int(entry.get("min")), _as_int(entry.get("max")))
        if num > 0:
            rows.append({"id": _as_int(entry.get("id")), "num": num})
    for entry in drop.get("basic", []):
        weight = _as_int(entry.get("weight"))
        if weight <= 0 or randint(1, 10000) > weight:
            continue
        num = randint(_as_int(entry.get("min")), _as_int(entry.get("max")))
        if num > 0:
            rows.append({"id": _as_int(entry.get("id")), "num": num})
    return rows


def _static_definition(level_cid: int) -> dict[str, Any]:
    try:
        row = static_config().dungeon_definition(level_cid)
    except StaticConfigUnavailable:
        return {}
    if not row:
        return {}
    return {
        "cost": list(row.get("cost") or []),
        "dungeonType": _as_int(row.get("dungeonType")),
        "datingIds": list(row.get("datingIds") or []),
        "playerLvl": _as_int(row.get("playerLvl")),
        "nextLevelCid": _as_int(row.get("nextLevelCid")),
        "rewardDrop": _as_int(row.get("rewardDrop")),
        "firstRewardDrop": _as_int(row.get("firstRewardDrop")),
    }


def _definition(state: dict[str, Any], level_cid: int) -> dict[str, Any]:
    """Stage rules, read from the shipped tables and overridable per save.

    `levelDefinitions` in the save wins where it is set, so a hand-authored
    stage keeps working; everything it leaves out comes from DungeonLevel/Drop
    rather than being invented or silently empty.
    """
    definition = _static_definition(level_cid)
    raw = state.get("levelDefinitions", {})
    if isinstance(raw, dict):
        row = raw.get(str(level_cid), raw.get(level_cid))
        if isinstance(row, dict):
            definition.update(row)
    return definition


def _clear_rewards(definition: dict[str, Any], first_clear: bool) -> list[dict[str, int]]:
    """What a win pays out: the save's explicit lists, else the stage's drops."""
    key = "firstClearRewards" if first_clear else "rewards"
    configured = definition.get(key)
    if isinstance(configured, list):
        return normalize_rewards(configured)
    drop_key = "firstRewardDrop" if first_clear else "rewardDrop"
    return normalize_rewards(_drop_rewards(_as_int(definition.get(drop_key))))


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
            "hero": None,
            "fightId": "",
            "randomSeed": 0,
            "rewards": [],
            "helpPid": 0,
            "limitHeros": [],
            "isDuelMod": bool(request.get("isDuelMod", False)),
        }, False

    definition = _definition(state, level_cid)
    quick_count = max(0, _as_int(request.get("quickCount")))
    cost = normalize_rewards(definition.get("cost") or [], max(1, quick_count))
    if cost and not consume_cids(state, cost):
        # Out of stamina: acknowledge without opening a fight the client would
        # then settle for free.
        return {
            "levelCid": 0,
            "hero": None,
            "fightId": "",
            "randomSeed": 0,
            "rewards": [],
            "helpPid": 0,
            "limitHeros": [],
            "isDuelMod": bool(request.get("isDuelMod", False)),
        }, bool(cost)

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
    # BattleDataMgr:setServerData does `if self.serverData.hero then` and then
    # looks the assist up in the Hero table by cid, so an empty-but-present
    # submessage enters battle with a cid-0 spirit and takes the scene down.
    # No assist means the field must be absent, not zero-filled.
    helper = None
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
        "quickCount": quick_count,
        "settled": False,
    }
    state["activeFight"] = active

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


def _apply_player_exp(state: dict[str, Any], amount: int) -> bool:
    """Spend PLAYEREXP drops on the player's own level, per the LevelUp table.

    Story stages gate on `DungeonLevel.playerLv` (1-2 needs Lv.2, 1-3 Lv.3 ...)
    and `FubenLevelView` makes a locked node untouchable, so without this the
    map dead-ends after the very first stage - the new-player guide included,
    which points at 1-2 and lets nothing else through.
    """
    amount = max(0, _as_int(amount))
    if amount <= 0:
        return False
    cfg = static_config()
    try:
        max_level = cfg.max_level()
    except StaticConfigUnavailable:
        return False
    level = max(1, _as_int(state.get("lvl"), 1))
    exp = max(0, _as_int(state.get("exp"))) + amount
    while level < max_level:
        needed = cfg.player_level_exp(level)
        if not needed or exp < needed:
            break
        exp -= needed
        level += 1
    if level >= max_level:
        exp = 0
    state["lvl"] = level
    state["exp"] = exp
    return True


def _split_player_exp(state: dict[str, Any], rewards: list[dict[str, int]]) -> list[dict[str, int]]:
    """Grant a reward list, routing PLAYEREXP to the level instead of the bag."""
    items = [row for row in rewards if _as_int(row.get("id")) != PLAYER_EXP_CID]
    exp = sum(_as_int(row.get("num")) for row in rewards
              if _as_int(row.get("id")) == PLAYER_EXP_CID)
    granted = grant_rewards(state, items) if items else []
    if _apply_player_exp(state, exp):
        granted.append({"id": PLAYER_EXP_CID, "num": exp})
    return normalize_rewards(granted)


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
        original.extend(_clear_rewards(definition, first_clear=False))
        if not was_won:
            original.extend(_clear_rewards(definition, first_clear=True))
        rewards = _split_player_exp(state, normalize_rewards(original)) if original else []

        if _as_int(definition.get("dungeonType")) == CITYDATING_DUNGEON_TYPE:
            # A town line advances one step per stage cleared: the per-choice
            # traffic (c2s 5635) cannot be told apart from the final one, and
            # this is the boundary that actually means "done".
            for dating_id in definition.get("datingIds") or []:
                city_dating_handlers.advance_line(
                    state, city_dating_handlers.NEW_CITY_FUBEN, _as_int(dating_id))

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


def _player_progress(state: dict[str, Any]) -> tuple[int, int]:
    return max(1, _as_int(state.get("lvl"), 1)), max(0, _as_int(state.get("exp")))


def _inventory_totals(state: dict[str, Any]) -> dict[str, int]:
    raw = state.get("items", {})
    rows = raw.values() if isinstance(raw, dict) else (raw if isinstance(raw, list) else [])
    return {str(row.get("id")): _as_int(row.get("num")) for row in rows if isinstance(row, dict)}


def dispatch(client: Any, proto: int, body: bytes) -> bool:
    before_progress = _player_progress(client.save)
    before_items = _inventory_totals(client.save)
    result = response_for(proto, client.save, body)
    if result is None:
        return False
    payload, mutated = result
    if mutated:
        persist(client.save)
    # Both pushes go out ahead of the reply: FubenDataMgr:onRecvFightOver builds
    # BattleResultView straight away, and that view reads the live player level
    # (diffed against the snapshot taken at fight start) off MainPlayer.
    if _inventory_totals(client.save) != before_items:
        # Entry cost and drops are settled server-side; without this the client
        # keeps its own stale totals and slowly drifts out of sync with what the
        # server will actually let it spend.
        client.send_pkt(ITEM_ITEM_LIST, encode_response(
            ITEM_ITEM_LIST, {"items": _inventory_records(client.save)}))
    if _player_progress(client.save) != before_progress:
        client.send_pkt(PLAYER_PLAYER_INFO, encode_player_info(client.save))
    client.send_pkt(proto, payload)
    return True
