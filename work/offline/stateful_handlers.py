#!/usr/bin/env python3
"""State-backed protocol handlers for the offline single-player server.

The generic protobuf fallback is intentionally kept for unknown/live-service
features. Protocols in this module are transactional and persist meaningful
single-player state.
"""
from __future__ import annotations

from copy import deepcopy
import time
from typing import Any

import game_static_config
from hero_stats import battle_attributes
from player_save import FIRST_PLOT_LEVEL, save as persist
from proto_codec import enc_bool_field, enc_msg_field, enc_varint_field, uvarint
from protocol_schema import decode_request, encode_response
from state_transactions import consume_cids, consume_items, grant_rewards, normalize_rewards

ITEM_USE_ITEM = 514
ITEM_GET_ITEMS = 515
HERO_GET_HEROS = 1025
PLAYER_OPERATE_FORMATION = 264
PLAYER_GET_FORMATIONS = 265
MAIL_MAIL_HANDLE = 769
MAIL_GET_MAILS = 772
FRIEND_REQ_FRIENDS = 3073
FRIEND_REQ_RECOMMEND = 3075
TASK_SUBMIT_TASK_LIST = 4096
TASK_REQ_TASKS = 4097
TASK_SUBMIT_TASK = 4098
SIGN_REQ_SEVEN_CARNIVAL = 5160
STORE_BUY_GOODS = 2562
STORE_REFRESH_STORE = 2563
STORE_GET_COMMODITY_BUY_LOG = 2564
STORE_SELL_INFO = 2565
STORE_SELL_GOODS_PREVIEW = 2567
STORE_GET_STORE_INFO = 2569
DUNGEON_GET_LEVEL_INFO = 1796
SUMMON_REQ_HOT_SUMMON_INFO = 3343

STATEFUL_PROTOCOLS = frozenset({
    ITEM_USE_ITEM,
    ITEM_GET_ITEMS,
    HERO_GET_HEROS,
    PLAYER_OPERATE_FORMATION,
    PLAYER_GET_FORMATIONS,
    MAIL_MAIL_HANDLE,
    MAIL_GET_MAILS,
    FRIEND_REQ_FRIENDS,
    FRIEND_REQ_RECOMMEND,
    TASK_SUBMIT_TASK_LIST,
    TASK_REQ_TASKS,
    TASK_SUBMIT_TASK,
    SIGN_REQ_SEVEN_CARNIVAL,
    STORE_BUY_GOODS,
    STORE_REFRESH_STORE,
    STORE_GET_COMMODITY_BUY_LOG,
    STORE_SELL_INFO,
    STORE_SELL_GOODS_PREVIEW,
    STORE_GET_STORE_INFO,
    DUNGEON_GET_LEVEL_INFO,
    SUMMON_REQ_HOT_SUMMON_INFO,
})


def inventory_records(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("items", {})
    if isinstance(raw, dict):
        return [deepcopy(v) for v in raw.values() if isinstance(v, dict)]
    if isinstance(raw, list):
        return [deepcopy(v) for v in raw if isinstance(v, dict)]
    return []


def equipment_records(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("equipments", [])
    return [deepcopy(v) for v in raw if isinstance(v, dict)] if isinstance(raw, list) else []


def hero_records(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("heroes", [])
    rows = [deepcopy(v) for v in raw if isinstance(v, dict)] if isinstance(raw, list) else []
    for hero in rows:
        # The save keeps progression (level/quality/advance); the stats those
        # imply are derived here so a level-up cannot leave them stale.
        hero["attr"] = battle_attributes(hero)
    return rows


def formation_records(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("formations", [])
    return [deepcopy(v) for v in raw if isinstance(v, dict)] if isinstance(raw, list) else []


def _level_info_rows(state: dict[str, Any]) -> list[dict[str, Any]]:
    """One levelInfo per stage the save knows about, newest state winning.

    `levelStates` is what the combat lifecycle actually maintains - fight
    counts and the star goals a clear ticked off - so it has to be the source
    here. Rebuilding the list from `passedLevels` alone reports every stage as
    a bare one-fight win, which is why cleared stages came back from a relog
    with their stars reset.
    """
    rows: dict[int, dict[str, Any]] = {}
    for raw_cid in state.get("passedLevels") or []:
        try:
            cid = int(raw_cid)
        except (TypeError, ValueError):
            continue
        if cid > 0:
            rows[cid] = {"cid": cid, "goals": [], "fightCount": 1, "win": True,
                         "buyCount": 0, "freeCount": 0}
    raw_states = state.get("levelStates")
    if isinstance(raw_states, dict):
        for key, row in raw_states.items():
            if not isinstance(row, dict):
                continue
            try:
                cid = int(row.get("cid", key))
            except (TypeError, ValueError):
                continue
            if cid <= 0:
                continue
            goals: list[int] = []
            for value in row.get("goals") or []:
                try:
                    goal = int(value)
                except (TypeError, ValueError):
                    continue
                if goal > 0 and goal not in goals:
                    goals.append(goal)
            rows[cid] = {
                "cid": cid,
                "goals": goals,
                "fightCount": max(0, int(row.get("fightCount", 0) or 0)),
                "win": bool(row.get("win", False)),
                "buyCount": max(0, int(row.get("buyCount", 0) or 0)),
                "freeCount": max(0, int(row.get("freeCount", 0) or 0)),
            }
    return [rows[cid] for cid in sorted(rows)]


def encode_dungeon_level_info(state: dict[str, Any]) -> bytes:
    records = bytearray()
    for row in _level_info_rows(state):
        info = enc_varint_field(1, row["cid"])
        if row["goals"]:
            packed = b"".join(uvarint(goal) for goal in row["goals"])
            info += enc_msg_field(2, packed)
        info += enc_varint_field(3, row["fightCount"])
        info += enc_bool_field(4, row["win"])
        info += enc_varint_field(5, row["buyCount"])
        info += enc_varint_field(6, row["freeCount"])
        records += enc_msg_field(1, info)
    if not records:
        return encode_dungeon_level_info({"passedLevels": [FIRST_PLOT_LEVEL]})
    # s2c 1796 field 1 is {false,{{true,{...}}}}: a plain submessage whose only
    # field is the repeated levelInfo list. Repeated elements are emitted as
    # one tag+len+body each at that field number, so `records` is already the
    # submessage body - wrapping it again puts a submessage where the decoder
    # expects levelInfo.cid and it bails with "not the same type at 1 v4".
    return enc_msg_field(1, bytes(records))


# SummonLoop loopType ids, per EC_SummonLoopType in the client.
SUMMON_LOOP_ROLE = 1
SUMMON_LOOP_EQUIPMENT = 2
HOT_SUMMON_WINDOW = 7 * 24 * 3600


def hot_summon_info(state: dict[str, Any]) -> dict[str, Any]:
    """s2c 3343, with loop orders that actually name a SummonLoop row.

    SummonDataMgr:getHotSummon does summonLoop_[loopType][loopId] and then
    ipairs()es the row's summonId with no nil guard, so the zero-filled default
    raises "attempt to index local 'loopCfg'" as soon as MainScene builds the
    summon panel. Take the lowest shipped loopId for each type instead; fall
    back to 1 (the first row of every shipped loopType) if the table cannot be
    read at all.
    """
    try:
        loops = game_static_config.config().summon_hot_loop_ids()
    except Exception:
        loops = {}
    end_time = int(state.get("hotSummonEndTime") or (time.time() + HOT_SUMMON_WINDOW))
    return {
        "heroHotSummonOrder": int(loops.get(SUMMON_LOOP_ROLE, 1)),
        "heroHotSummonTime": end_time,
        "equipHotSummonOrder": int(loops.get(SUMMON_LOOP_EQUIPMENT, 1)),
        "equipHotSummonTime": end_time,
        "hotHeroSummonScore": int(state.get("hotHeroSummonScore", 0) or 0),
        "hotEquipSummonScore": int(state.get("hotEquipSummonScore", 0) or 0),
    }


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


def _item_use(state: dict[str, Any], request: dict[str, Any]) -> tuple[list[dict[str, int]], bool]:
    requirements = request.get("items") or []
    if not isinstance(requirements, list) or not requirements:
        return [], False
    items = state.get("items", {})
    staged_rewards: list[dict[str, Any]] = []
    for req in requirements:
        if not isinstance(req, dict):
            return [], False
        item_id = str(req.get("itemId", "") or "")
        count = int(req.get("num", 0) or 0)
        row = items.get(item_id) if isinstance(items, dict) else None
        if not isinstance(row, dict) or count <= 0:
            return [], False
        configured = row.get("useRewards")
        if not isinstance(configured, list):
            return [], False
        staged_rewards.extend(normalize_rewards(configured, count))
    if not consume_items(state, requirements):
        return [], False
    rewards = grant_rewards(state, staged_rewards)
    return rewards, True


def _mail_by_id(state: dict[str, Any]) -> dict[str, dict[str, Any]]:
    rows = state.setdefault("mails", [])
    if not isinstance(rows, list):
        state["mails"] = rows = []
    return {str(row.get("id", "")): row for row in rows if isinstance(row, dict) and row.get("id") is not None}


def _mail_handle(state: dict[str, Any], request: dict[str, Any]) -> tuple[list[dict[str, int]], bool]:
    ids = [str(v) for v in request.get("ids", []) if str(v)]
    operation = int(request.get("type", 0) or 0)
    if not ids or operation not in (1, 2, 3):
        return [], False
    by_id = _mail_by_id(state)
    changed = False
    rewards: list[dict[str, Any]] = []
    if operation == 1:
        for mail_id in ids:
            mail = by_id.get(mail_id)
            if mail is not None and int(mail.get("status", 0) or 0) == 0:
                mail["status"] = 1
                changed = True
    elif operation == 2:
        for mail_id in ids:
            mail = by_id.get(mail_id)
            if mail is None or int(mail.get("status", 0) or 0) == 2:
                continue
            configured = mail.get("rewards") or []
            if isinstance(configured, list):
                rewards.extend(configured)
            mail["status"] = 2
            changed = True
        rewards = grant_rewards(state, rewards) if changed else []
    else:
        before = len(state["mails"])
        wanted = set(ids)
        state["mails"] = [
            row for row in state["mails"]
            if not (isinstance(row, dict) and str(row.get("id", "")) in wanted)
        ]
        changed = len(state["mails"]) != before
    return normalize_rewards(rewards), changed


def _find_task(state: dict[str, Any], raw_id: Any) -> dict[str, Any] | None:
    needle = str(raw_id)
    for task in state.setdefault("tasks", []):
        if not isinstance(task, dict):
            continue
        if str(task.get("id", "")) == needle or str(task.get("cid", "")) == needle:
            return task
    return None


def _claim_task(state: dict[str, Any], task: dict[str, Any] | None) -> tuple[dict[str, Any], bool]:
    if not isinstance(task, dict):
        return {"taskDbId": "", "taskCid": 0, "rewards": []}, False
    result = {
        "taskDbId": str(task.get("id", "") or ""),
        "taskCid": int(task.get("cid", 0) or 0),
        "rewards": [],
    }
    if int(task.get("status", 0) or 0) != 1:
        return result, False
    configured = task.get("rewards") or []
    result["rewards"] = grant_rewards(state, configured) if isinstance(configured, list) else []
    task["status"] = 2
    task["ct"] = int(task.get("ct", 0) or 0)
    return result, True


def _task_submit_one(state: dict[str, Any], request: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    return _claim_task(state, _find_task(state, request.get("taskCid", 0)))


def _task_submit_list(state: dict[str, Any], request: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    results: list[dict[str, Any]] = []
    all_rewards: list[dict[str, Any]] = []
    changed = False
    seen: set[str] = set()
    for raw_id in request.get("taskId", []) or []:
        key = str(raw_id)
        if key in seen:
            continue
        seen.add(key)
        result, claimed = _claim_task(state, _find_task(state, raw_id))
        if result["taskCid"]:
            results.append(result)
        if claimed:
            changed = True
            all_rewards.extend(result["rewards"])
    return {"result": results, "rewards": normalize_rewards(all_rewards)}, changed


def _stores(state: dict[str, Any]) -> list[dict[str, Any]]:
    """The shop the client sees: the shipped catalogue, save rows layered on.

    `StoreDataMgr` keeps no fallback of its own - `commodityMap_` is built from
    this reply and nothing else - so the catalogue has to come from the server
    even though every price in it is static data the client already ships.
    """
    rows = state.get("stores", [])
    overrides = [row for row in rows if isinstance(row, dict)] if isinstance(rows, list) else []
    try:
        catalogue = [deepcopy(store) for store in game_static_config.config().store_catalogue()]
    except game_static_config.StaticConfigUnavailable:
        return overrides
    by_id = {int(store.get("storeId", 0) or 0): store for store in catalogue}
    for override in overrides:
        store_id = int(override.get("storeId", 0) or 0)
        if store_id in by_id:
            by_id[store_id].update(override)
        else:
            by_id[store_id] = override
    return [by_id[key] for key in sorted(by_id)]


def _find_store(state: dict[str, Any], store_id: int) -> dict[str, Any] | None:
    for store in _stores(state):
        if int(store.get("storeId", 0) or 0) == int(store_id):
            return store
    return None


def _find_commodity(state: dict[str, Any], cid: int) -> tuple[dict[str, Any], dict[str, Any]] | None:
    for store in _stores(state):
        for commodity in store.get("commoditys", []) or []:
            if isinstance(commodity, dict) and int(commodity.get("id", 0) or 0) == int(cid):
                return store, commodity
    return None


def _purchase_record(state: dict[str, Any], cid: int) -> dict[str, Any]:
    purchases = state.setdefault("storePurchases", {})
    if not isinstance(purchases, dict):
        state["storePurchases"] = purchases = {}
    row = purchases.setdefault(str(int(cid)), {})
    if not isinstance(row, dict):
        purchases[str(int(cid))] = row = {}
    today = time.strftime("%Y-%m-%d", time.gmtime())
    if row.get("dayKey") != today:
        row["dayKey"] = today
        row["day"] = 0
    row.setdefault("total", 0)
    row.setdefault("cycle", 0)
    return row


def _remaining_for_commodity(state: dict[str, Any], commodity: dict[str, Any]) -> int | None:
    limit_type = int(commodity.get("limitType", 0) or 0)
    limit_val = max(0, int(commodity.get("limitVal", 0) or 0))
    if limit_type == 0 or limit_val <= 0:
        return None
    record = _purchase_record(state, int(commodity.get("id", 0) or 0))
    if limit_type == 1:
        used = int(record.get("cycle", 0) or 0)
    elif limit_type == 2:
        used = int(record.get("day", 0) or 0)
    else:
        used = int(record.get("total", 0) or 0)
    return max(0, limit_val - used)


def _buy_logs(state: dict[str, Any]) -> list[dict[str, int]]:
    out: list[dict[str, int]] = []
    for store in _stores(state):
        for commodity in store.get("commoditys", []) or []:
            if not isinstance(commodity, dict):
                continue
            cid = int(commodity.get("id", 0) or 0)
            if cid <= 0:
                continue
            record = _purchase_record(state, cid)
            limit_type = int(commodity.get("limitType", 0) or 0)
            now = int(record.get("day" if limit_type == 2 else "cycle", 0) or 0)
            if limit_type in (3, 5):
                now = int(record.get("total", 0) or 0)
            out.append({
                "type": 1,
                "cid": cid,
                "nowBuyCount": now,
                "totalBuyCount": int(record.get("total", 0) or 0),
                "storeState": 1,
            })
    return out


def _store_buy(state: dict[str, Any], request: dict[str, Any]) -> tuple[list[dict[str, int]], bool]:
    cid = int(request.get("cid", 0) or 0)
    count = int(request.get("num", 0) or 0)
    found = _find_commodity(state, cid)
    if found is None or count <= 0 or count > 200:
        return [], False
    _, commodity = found
    remaining = _remaining_for_commodity(state, commodity)
    if remaining is not None and count > remaining:
        return [], False
    price_ids = commodity.get("priceType", []) or []
    price_vals = commodity.get("priceVal", []) or []
    costs = [
        {"id": int(price_id), "num": int(price_num) * count}
        for price_id, price_num in zip(price_ids, price_vals)
        if int(price_id) > 0 and int(price_num) > 0
    ]
    goods = normalize_rewards(commodity.get("goodInfo", []) or [], count)
    if not goods or not consume_cids(state, costs):
        return [], False
    granted = grant_rewards(state, goods)
    record = _purchase_record(state, cid)
    record["day"] = int(record.get("day", 0) or 0) + count
    record["cycle"] = int(record.get("cycle", 0) or 0) + count
    record["total"] = int(record.get("total", 0) or 0) + count
    return granted, True


def _store_refresh(state: dict[str, Any], request: dict[str, Any]) -> bool:
    store = _find_store(state, int(request.get("cid", 0) or 0))
    if store is None:
        return False
    refresh = store.setdefault("storeRefresh", {})
    if not isinstance(refresh, dict):
        store["storeRefresh"] = refresh = {}
    free = max(0, int(refresh.get("freeNum", 0) or 0))
    if free > 0:
        refresh["freeNum"] = free - 1
    else:
        cfg = store.get("store") if isinstance(store.get("store"), dict) else {}
        cost_id = int(cfg.get("refreshCostId", 0) or 0)
        costs_by_count = cfg.get("refreshCostNum", []) or []
        index = int(refresh.get("todayRefreshCount", 0) or 0)
        if cost_id > 0 and costs_by_count:
            cost_num = int(costs_by_count[min(index, len(costs_by_count) - 1)] or 0)
            if cost_num > 0 and not consume_cids(state, [{"id": cost_id, "num": cost_num}]):
                return False
    refresh["todayRefreshCount"] = int(refresh.get("todayRefreshCount", 0) or 0) + 1
    refresh["totalRefreshCount"] = int(refresh.get("totalRefreshCount", 0) or 0) + 1
    refresh["nextRefreshTime"] = int(time.time())
    for commodity in store.get("commoditys", []) or []:
        if isinstance(commodity, dict) and int(commodity.get("limitType", 0) or 0) == 1:
            _purchase_record(state, int(commodity.get("id", 0) or 0))["cycle"] = 0
    return True


def _sale_rewards(state: dict[str, Any], goods: list[dict[str, Any]]) -> list[dict[str, int]] | None:
    items = state.get("items", {})
    if not isinstance(items, dict) or not goods:
        return None
    rewards: list[dict[str, Any]] = []
    for req in goods:
        if not isinstance(req, dict):
            return None
        item_id = str(req.get("id", "") or "")
        num = int(req.get("num", 0) or 0)
        row = items.get(item_id)
        configured = row.get("sellRewards") if isinstance(row, dict) else None
        if num <= 0 or not isinstance(configured, list):
            return None
        rewards.extend(normalize_rewards(configured, num))
    return normalize_rewards(rewards)


def _store_sell(state: dict[str, Any], request: dict[str, Any], commit: bool) -> tuple[list[dict[str, int]], bool]:
    goods = request.get("goods") or []
    rewards = _sale_rewards(state, goods)
    if rewards is None:
        return [], False
    if not commit:
        return rewards, False
    requirements = [{"itemId": row.get("id"), "num": row.get("num")} for row in goods if isinstance(row, dict)]
    if not consume_items(state, requirements):
        return [], False
    return grant_rewards(state, rewards), True


def _seven_carnival(state: dict[str, Any]) -> dict[str, Any]:
    row = state.get("sevenCarnival", {})
    if not isinstance(row, dict):
        row = {}
    return {
        "day": max(1, int(row.get("day", 1) or 1)),
        "storeList": row.get("storeList", []) if isinstance(row.get("storeList", []), list) else [],
        "state": int(row.get("state", 0) or 0),
    }


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto == ITEM_GET_ITEMS:
        return encode_response(proto, {
            "items": inventory_records(state),
            "equipments": equipment_records(state),
        }), False
    if proto == ITEM_USE_ITEM:
        rewards, changed = _item_use(state, decode_request(proto, body))
        return encode_response(proto, {"items": rewards}), changed
    if proto == HERO_GET_HEROS:
        return encode_response(proto, {"heros": hero_records(state)}), False
    if proto == PLAYER_GET_FORMATIONS:
        return encode_response(proto, {"formations": formation_records(state)}), False
    if proto == MAIL_GET_MAILS:
        return encode_response(proto, {"mails": state.get("mails", []) or []}), False
    if proto == MAIL_MAIL_HANDLE:
        rewards, changed = _mail_handle(state, decode_request(proto, body))
        return encode_response(proto, {"rewards": rewards}), changed
    if proto == TASK_REQ_TASKS:
        return encode_response(proto, {"taks": state.get("tasks", []) or []}), False
    if proto == TASK_SUBMIT_TASK:
        result, changed = _task_submit_one(state, decode_request(proto, body))
        return encode_response(proto, result), changed
    if proto == TASK_SUBMIT_TASK_LIST:
        result, changed = _task_submit_list(state, decode_request(proto, body))
        return encode_response(proto, result), changed
    if proto == FRIEND_REQ_FRIENDS:
        return encode_response(proto, {
            "friends": state.get("friends", []) or [],
            "receiveCount": int(state.get("friendReceiveCount", 0) or 0),
            "lastReceiveTime": int(state.get("friendLastReceiveTime", 0) or 0),
        }), False
    if proto == FRIEND_REQ_RECOMMEND:
        return encode_response(proto, {"friends": state.get("friendRecommendations", []) or []}), False
    if proto == SIGN_REQ_SEVEN_CARNIVAL:
        return encode_response(proto, _seven_carnival(state)), False
    if proto == STORE_GET_STORE_INFO:
        return encode_response(proto, {"stores": deepcopy(_stores(state))}), False
    if proto == STORE_GET_COMMODITY_BUY_LOG:
        return encode_response(proto, {"buyLogs": _buy_logs(state)}), False
    if proto == STORE_BUY_GOODS:
        goods, changed = _store_buy(state, decode_request(proto, body))
        return encode_response(proto, {"goods": goods}), changed
    if proto == STORE_REFRESH_STORE:
        changed = _store_refresh(state, decode_request(proto, body))
        return encode_response(proto, {"stores": deepcopy(_stores(state))}), changed
    if proto == STORE_SELL_GOODS_PREVIEW:
        rewards, _ = _store_sell(state, decode_request(proto, body), False)
        return encode_response(proto, {"rewards": rewards}), False
    if proto == STORE_SELL_INFO:
        rewards, changed = _store_sell(state, decode_request(proto, body), True)
        return encode_response(proto, {"success": changed, "rewards": rewards}), changed
    if proto == DUNGEON_GET_LEVEL_INFO:
        return encode_dungeon_level_info(state), False
    if proto == SUMMON_REQ_HOT_SUMMON_INFO:
        return encode_response(proto, hot_summon_info(state)), False
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
