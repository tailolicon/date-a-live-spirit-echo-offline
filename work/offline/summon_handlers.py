#!/usr/bin/env python3
"""Summoning (s2c 3329), rolled off the shipped SummonPool tables.

`SummonDataMgr:onRecvSummon` guards on `data.item` and then does

    local summonType = self:getSummonCfg(data.id).summonType

for `preciousCount`, `sixGuaranteesCount` and `wishId`. Those are plain scalars,
so a zero-filled reply carries `0` for each - and `0` is truthy in Lua. The
guard passes, `getSummonCfg(0)` is nil, and the panel throws on every pull
(`SummonDataMgr.lua:1024`). `data.id` has to name a real Summon row, which
means actually resolving the pull rather than answering with a shaped blank.

What a pool pays out is a mix: most rows hand over items, but `type = 1` rows
hand over a *hero cid*, and a hero the player does not own yet has to be created
in the save - the client only ever learns its roster from the server.
"""
from __future__ import annotations

import random
import time
from typing import Any

from game_static_config import GameStaticConfig, StaticConfigUnavailable, config as static_config
from hero_stats import battle_attributes
from player_save import default_skill_strategy, save as persist
from protocol_schema import decode_request, encode_response
from state_transactions import add_equipment, consume_cids, grant_rewards, normalize_rewards

SUMMON_SUMMON = 3329
HERO_HERO_INFO_LIST = 1025
ITEM_ITEM_LIST = 515

SUMMON_PROTOCOLS = frozenset({SUMMON_SUMMON})

# SummonPool.type: a row that hands over a spirit rather than an item.
POOL_TYPE_HERO = 1
DEFAULT_WEIGHT = 10000


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _band(values: list[int], index: int, default: int) -> int:
    if not values:
        return default
    return _as_int(values[min(max(index, 0), len(values) - 1)], default)


def _row_weight(row: dict[str, Any], cost_index: int) -> int:
    """SummonPool.weight is a list; the shipped rows carry one entry per band.

    Which band a pull uses is the server's own business in the original and is
    not recoverable from the client, so the cost option indexes it and the
    first entry stands in when there are fewer bands than cost options. Every
    weight is still a real shipped number - none of this invents rates.
    """
    weights = row.get("weights") or []
    weight = _band(weights, cost_index, DEFAULT_WEIGHT)
    return max(0, weight)


def _pick(rows: list[dict[str, Any]], cost_index: int,
          rng: random.Random) -> dict[str, Any] | None:
    weighted = [(row, _row_weight(row, cost_index)) for row in rows]
    total = sum(weight for _, weight in weighted)
    if total <= 0:
        return rng.choice(rows) if rows else None
    roll = rng.randrange(total)
    for row, weight in weighted:
        roll -= weight
        if roll < 0:
            return row
    return weighted[-1][0]


def _hero_sid(state: dict[str, Any], hero_cid: int) -> str:
    existing = {str(row.get("id", "")) for row in state.get("heroes", []) or []
                if isinstance(row, dict)}
    index = 1
    while f"local-{hero_cid}-{index}" in existing:
        index += 1
    return f"local-{hero_cid}-{index}"


def _grant_hero(state: dict[str, Any], hero_cid: int,
                cfg: GameStaticConfig) -> dict[str, Any] | None:
    """Add a summoned spirit to the roster, or convert a duplicate.

    The original turns a spirit the player already owns into its shards; there
    is no shard mapping we can read back for every hero, so a duplicate is
    simply not granted twice and the caller reports the pull unchanged.
    """
    static = cfg.hero(hero_cid)
    if static is None:
        return None
    heroes = state.setdefault("heroes", [])
    if not isinstance(heroes, list):
        state["heroes"] = heroes = []
    if any(_as_int(row.get("cid")) == hero_cid for row in heroes if isinstance(row, dict)):
        return None
    hero = {
        "ct": 0,
        "id": _hero_sid(state, hero_cid),
        "cid": hero_cid,
        "lvl": 1,
        "exp": 0,
        "attr": [],
        "advancedLvl": 0,
        "equipments": [],
        "helpFight": False,
        "angelLvl": 1,
        "angeSkillInfos": [],
        "useSkillPiont": 0,
        "quality": max(1, _as_int(static.get("baseQuality"), 1)),
        "provide": 0,
        "fightPower": 0,
        "skinCid": _as_int(static.get("defaultSkin")),
        "skillStrategyInfo": [default_skill_strategy()],
        "useSkillStrategy": 1,
        "crystalInfo": [],
        "equipSkillIds": [],
        "euqipFetterInfo": [],
        "heroStatus": 1,
        "deadLine": 0,
        "gemInfos": [],
        "skinCidTemp": 0,
        "exploreTreasureSkill": [],
        "breakLv": 0,
        "angelStrengthen": [],
    }
    heroes.append(hero)
    return hero


def _counters(state: dict[str, Any], summon_cid: int) -> dict[str, Any]:
    raw = state.setdefault("summonCounters", {})
    if not isinstance(raw, dict):
        state["summonCounters"] = raw = {}
    row = raw.get(str(summon_cid))
    if not isinstance(row, dict):
        row = {"pulls": 0, "sinceRare": 0}
        raw[str(summon_cid)] = row
    row.setdefault("pulls", 0)
    row.setdefault("sinceRare", 0)
    return row


def summon(state: dict[str, Any], request: dict[str, Any],
           cfg: GameStaticConfig | None = None,
           rng: random.Random | None = None) -> dict[str, Any] | None:
    """Resolve one pull. Returns the s2c 3329 values, or None to stay silent."""
    summon_cid = _as_int(request.get("cid"))
    if summon_cid <= 0:
        return None
    try:
        cfg = cfg or static_config()
        config_row = cfg.summon(summon_cid)
        pool = list(cfg.summon_pool(_as_int((config_row or {}).get("poolType")))) if config_row else []
    except StaticConfigUnavailable:
        return None
    if config_row is None or not pool:
        return None

    counters = _counters(state, summon_cid)
    cost_index = max(0, _as_int(request.get("cost")) - 1)
    # `firstCost` is a discount priced in a *different* item (a starter ticket).
    # It is an alternative, not a toll: charging it unconditionally on the first
    # pull shuts the banner for anyone who does not hold that item, and shuts it
    # permanently, because the pull never happens to advance the count past 0.
    options: list[list[dict[str, int]]] = []
    if counters["pulls"] == 0 and config_row["firstCosts"]:
        first = config_row["firstCosts"]
        options.append(first[min(cost_index, len(first) - 1)])
    if config_row["costs"]:
        normal = config_row["costs"]
        options.append(normal[min(cost_index, len(normal) - 1)])
    payable = [price for price in options if price]
    if payable and not any(consume_cids(state, price) for price in payable):
        # Cannot pay: acknowledge nothing rather than handing out a free pull.
        return None

    rng = rng or random.Random()
    rare_every = _as_int(config_row.get("rareGetTimes"))
    low = _band(config_row.get("minQuality") or [], cost_index, 0)
    high = _band(config_row.get("maxQuality") or [], cost_index, 0)
    rare_rows = [row for row in pool if low <= _as_int(row.get("quality")) <= high] if high else []

    drawn: list[dict[str, int]] = []
    for _ in range(max(1, _as_int(config_row.get("cardCount"), 1))):
        counters["pulls"] += 1
        counters["sinceRare"] += 1
        candidates = pool
        if rare_every and rare_rows and counters["sinceRare"] >= rare_every:
            candidates = rare_rows
        row = _pick(candidates, cost_index, rng)
        if row is None:
            continue
        if rare_rows and row in rare_rows:
            counters["sinceRare"] = 0
        drawn.extend(row["items"])

    # A pool row's payout can be a spirit, a piece of equipment or a plain
    # item, and the client stores all three in different places. Routing every
    # id into the bag would show phantom items and leave the roster and the
    # equipment screen empty, so each one goes where its table says it lives.
    items: list[dict[str, int]] = []
    bag: list[dict[str, int]] = []
    for entry in drawn:
        cid = _as_int(entry.get("id"))
        num = max(1, _as_int(entry.get("num"), 1))
        if cfg.hero(cid) is not None:
            if _grant_hero(state, cid, cfg) is not None:
                items.append({"id": cid, "num": num})
            continue
        equipment = cfg.equipment(cid)
        if equipment is not None:
            add_equipment(state, cid, num, equipment)
            items.append({"id": cid, "num": num})
            continue
        bag.append({"id": cid, "num": num})
        items.append({"id": cid, "num": num})

    if bag:
        grant_rewards(state, bag)

    return {
        "item": normalize_rewards(items),
        "activeId": [],
        "hotHeroSummonScore": 0,
        "hotEquipSummonScore": 0,
        "fixItem": [],
        # The whole point: getSummonCfg(id) has to resolve.
        "id": summon_cid,
        "preciousCount": 0,
        "sixGuaranteesCount": max(0, _as_int(counters.get("sinceRare"))),
        "wishId": 0,
        "noobInfo": None,
        "freeInfo": None,
        "freeTime": None,
    }


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto != SUMMON_SUMMON:
        return None
    values = summon(state, decode_request(proto, body))
    if values is None:
        return None
    return encode_response(proto, values), True


def dispatch(client: Any, proto: int, body: bytes) -> bool:
    result = response_for(proto, client.save, body)
    if result is None:
        return False
    payload, mutated = result
    if mutated:
        persist(client.save)
    client.send_pkt(proto, payload)
    # The roster and the bag both moved; GoodsDataMgr and HeroDataMgr only
    # learn either from a push.
    import stateful_handlers
    client.send_pkt(HERO_HERO_INFO_LIST, encode_response(
        HERO_HERO_INFO_LIST, {"heros": stateful_handlers.hero_records(client.save)}))
    client.send_pkt(ITEM_ITEM_LIST, encode_response(ITEM_ITEM_LIST, {
        "items": stateful_handlers.inventory_records(client.save),
        "equipments": stateful_handlers.equipment_records(client.save),
    }))
    return True
