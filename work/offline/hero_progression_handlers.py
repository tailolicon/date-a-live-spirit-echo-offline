#!/usr/bin/env python3
"""Stateful hero level/advance/quality/skin transactions.

All costs are read from the exact 1.37 static tables through game_static_config.
Invalid, unavailable, or unaffordable operations are acknowledged without
mutating the save rather than granting free progression.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from game_static_config import GameStaticConfig, StaticConfigUnavailable, config as static_config
from hero_stats import battle_attributes
from player_save import save as persist
from protocol_schema import decode_request, encode_response
from state_transactions import consume_cids

HERO_HERO_UPGRADE = 1027
HERO_HERO_ADVANCE = 1028
HERO_HERO_EXP_INFO = 1029  # server push used together with 1027
HERO_HERO_INFO = 1026      # server push consumed by GoodsDataMgr
HERO_REQ_UP_QUALITY = 1035
HERO_REQ_CHANGE_HERO_SKIN = 1036

HERO_PROGRESSION_PROTOCOLS = frozenset({
    HERO_HERO_UPGRADE,
    HERO_HERO_ADVANCE,
    HERO_REQ_UP_QUALITY,
    HERO_REQ_CHANGE_HERO_SKIN,
})


@dataclass
class HandlerResult:
    body: bytes
    mutated: bool = False
    extra_packets: tuple[tuple[int, bytes], ...] = ()


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _hero_rows(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("heroes", [])
    return [row for row in raw if isinstance(row, dict)] if isinstance(raw, list) else []


def _find_hero(state: dict[str, Any], sid: Any) -> dict[str, Any] | None:
    wanted = str(sid or "")
    if not wanted:
        return None
    for row in _hero_rows(state):
        if str(row.get("id", "")) == wanted:
            return row
    return None


def _wire_hero(hero: dict[str, Any], cfg: GameStaticConfig) -> dict[str, Any]:
    cid = _as_int(hero.get("cid"))
    static = cfg.hero(cid) or {}
    strategy = hero.get("skillStrategyInfo")
    if not isinstance(strategy, list) or not strategy:
        strategy = [{
            "id": 1,
            "name": "Default",
            "alreadyUseSkillPiont": 0,
            "angeSkillInfos": [],
            "passiveSkillInfo": [],
        }]
    use_strategy = max(1, _as_int(hero.get("useSkillStrategy"), 1))
    if not any(_as_int(row.get("id")) == use_strategy for row in strategy if isinstance(row, dict)):
        use_strategy = _as_int(strategy[0].get("id"), 1)
    skin_cid = _as_int(hero.get("skinCid"), _as_int(static.get("defaultSkin")))
    return {
        "ct": _as_int(hero.get("ct")),
        "id": str(hero.get("id", "")),
        "cid": cid,
        "lvl": max(1, _as_int(hero.get("lvl"), 1)),
        "exp": max(0, _as_int(hero.get("exp"))),
        "attr": battle_attributes(hero, cfg),
        "advancedLvl": max(0, _as_int(hero.get("advancedLvl"))),
        "equipments": hero.get("equipments", []) if isinstance(hero.get("equipments", []), list) else [],
        "helpFight": bool(hero.get("helpFight", False)),
        "angelLvl": max(0, _as_int(hero.get("angelLvl"))),
        "angeSkillInfos": hero.get("angeSkillInfos", []) if isinstance(hero.get("angeSkillInfos", []), list) else [],
        "useSkillPiont": max(0, _as_int(hero.get("useSkillPiont"))),
        "quality": max(1, _as_int(hero.get("quality"), _as_int(static.get("baseQuality"), 1))),
        "provide": _as_int(hero.get("provide")),
        "fightPower": max(0, _as_int(hero.get("fightPower"))),
        "skinCid": skin_cid,
        "skillStrategyInfo": strategy,
        "useSkillStrategy": use_strategy,
        "crystalInfo": hero.get("crystalInfo", []) if isinstance(hero.get("crystalInfo", []), list) else [],
        "equipSkillIds": hero.get("equipSkillIds", []) if isinstance(hero.get("equipSkillIds", []), list) else [],
        "euqipFetterInfo": hero.get("euqipFetterInfo", []) if isinstance(hero.get("euqipFetterInfo", []), list) else [],
        "heroStatus": _as_int(hero.get("heroStatus"), 1),
        "deadLine": max(0, _as_int(hero.get("deadLine"))),
        "gemInfos": hero.get("gemInfos", []) if isinstance(hero.get("gemInfos", []), list) else [],
        "skinCidTemp": max(0, _as_int(hero.get("skinCidTemp"))),
        "exploreTreasureSkill": hero.get("exploreTreasureSkill", []) if isinstance(hero.get("exploreTreasureSkill", []), list) else [],
        "breakLv": max(0, _as_int(hero.get("breakLv"))),
        "angelStrengthen": hero.get("angelStrengthen", []) if isinstance(hero.get("angelStrengthen", []), list) else [],
    }


def _hero_push(hero: dict[str, Any], cfg: GameStaticConfig) -> tuple[int, bytes]:
    return HERO_HERO_INFO, encode_response(HERO_HERO_INFO, _wire_hero(hero, cfg))


def _level_up(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    hero = _find_hero(state, request.get("heroId"))
    result_body = encode_response(HERO_HERO_UPGRADE, {"rewards": []})
    if hero is None:
        return HandlerResult(result_body)
    cid = _as_int(hero.get("cid"))
    hero_cfg = cfg.hero(cid)
    if not hero_cfg:
        return HandlerResult(result_body)
    current_level = max(1, _as_int(hero.get("lvl"), 1))
    current_exp = max(0, _as_int(hero.get("exp")))
    level_cap = min(max(1, _as_int(state.get("lvl"), 1)), cfg.max_level())
    if current_level >= level_cap:
        return HandlerResult(result_body)

    allowed = {int(value) for value in hero_cfg.get("expItems", [])}
    costs: list[dict[str, int]] = []
    gained = 0
    for row in request.get("items", []) or []:
        if not isinstance(row, dict):
            return HandlerResult(result_body)
        item_cid = _as_int(row.get("itemId"))
        count = _as_int(row.get("num"))
        value = cfg.exp_item_value(item_cid) if item_cid in allowed else None
        if item_cid <= 0 or count <= 0 or value is None or value <= 0:
            return HandlerResult(result_body)
        costs.append({"id": item_cid, "num": count})
        gained += value * count
    if not costs or gained <= 0:
        return HandlerResult(result_body)
    if not consume_cids(state, costs):
        return HandlerResult(result_body)

    level = current_level
    exp = current_exp + gained
    while level < level_cap:
        threshold = cfg.level_exp(level)
        if threshold is None or threshold <= 0 or exp < threshold:
            break
        exp -= threshold
        level += 1
    hero["lvl"] = level
    hero["exp"] = exp
    wire = _wire_hero(hero, cfg)
    extra = (
        (HERO_HERO_INFO, encode_response(HERO_HERO_INFO, wire)),
        (HERO_HERO_EXP_INFO, encode_response(HERO_HERO_EXP_INFO, {
            "id": str(hero.get("id", "")), "exp": exp, "cid": cid,
        })),
    )
    return HandlerResult(result_body, True, extra)


def _advance(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    hero = _find_hero(state, request.get("heroId"))
    empty = encode_response(HERO_HERO_ADVANCE, {"hero": {}})
    if hero is None:
        return HandlerResult(empty)
    current = max(0, _as_int(hero.get("advancedLvl")))
    if current >= 10:
        return HandlerResult(encode_response(HERO_HERO_ADVANCE, {"hero": _wire_hero(hero, cfg)}))
    costs = cfg.advance_cost(_as_int(hero.get("cid")), current)
    if costs is None or not consume_cids(state, costs):
        return HandlerResult(encode_response(HERO_HERO_ADVANCE, {"hero": _wire_hero(hero, cfg)}))
    hero["advancedLvl"] = current + 1
    wire = _wire_hero(hero, cfg)
    return HandlerResult(
        encode_response(HERO_HERO_ADVANCE, {"hero": wire}), True, (_hero_push(hero, cfg),)
    )


def _quality(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    hero = _find_hero(state, request.get("heroId"))
    empty = encode_response(HERO_REQ_UP_QUALITY, {"hero": {}})
    if hero is None:
        return HandlerResult(empty)
    static = cfg.hero(_as_int(hero.get("cid"))) or {}
    current = max(1, _as_int(hero.get("quality"), _as_int(static.get("baseQuality"), 1)))
    if current >= 5:
        return HandlerResult(encode_response(HERO_REQ_UP_QUALITY, {"hero": _wire_hero(hero, cfg)}))
    next_quality = current + 1
    costs = cfg.quality_cost(_as_int(hero.get("cid")), next_quality)
    if costs is None or not consume_cids(state, costs):
        return HandlerResult(encode_response(HERO_REQ_UP_QUALITY, {"hero": _wire_hero(hero, cfg)}))
    hero["quality"] = next_quality
    wire = _wire_hero(hero, cfg)
    return HandlerResult(
        encode_response(HERO_REQ_UP_QUALITY, {"hero": wire}), True, (_hero_push(hero, cfg),)
    )


def _item_rows(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("items", {})
    if isinstance(raw, dict):
        return [row for row in raw.values() if isinstance(row, dict)]
    if isinstance(raw, list):
        return [row for row in raw if isinstance(row, dict)]
    return []


def _resolve_skin(state: dict[str, Any], hero: dict[str, Any], skin_id: str, is_switch: bool,
                  cfg: GameStaticConfig) -> int | None:
    cid = _as_int(hero.get("cid"))
    hero_cfg = cfg.hero(cid) or {}
    allowed = cfg.allowed_skins(cid)
    if not allowed:
        return None
    requested = _as_int(skin_id)
    if is_switch:
        condition = _as_int(hero_cfg.get("conditionHeroQuality"))
        paint = _as_int(hero_cfg.get("paint"))
        quality = max(1, _as_int(hero.get("quality"), _as_int(hero_cfg.get("baseQuality"), 1)))
        if requested == paint and paint > 0 and condition > 0 and quality >= condition and cfg.skin_exists(paint):
            return paint
        return None
    default_skin = _as_int(hero_cfg.get("defaultSkin"))
    if requested == default_skin and requested in allowed and cfg.skin_exists(requested):
        return requested
    for row in _item_rows(state):
        if str(row.get("id", "")) != str(skin_id):
            continue
        skin_cid = _as_int(row.get("cid"))
        if skin_cid in allowed and cfg.skin_exists(skin_cid) and _as_int(row.get("num"), 1) > 0:
            return skin_cid
    return None


def _change_skin(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    hero = _find_hero(state, request.get("heroId"))
    if hero is None:
        return HandlerResult(encode_response(HERO_REQ_CHANGE_HERO_SKIN, {"hero": {}, "beforeSkinId": ""}))
    before = str(hero.get("skinCid", "") or "")
    target = _resolve_skin(state, hero, str(request.get("skinId", "")), bool(request.get("isSwitch", False)), cfg)
    if target is None or target == _as_int(hero.get("skinCid")):
        return HandlerResult(encode_response(HERO_REQ_CHANGE_HERO_SKIN, {
            "hero": _wire_hero(hero, cfg), "beforeSkinId": before,
        }))
    hero["skinCid"] = target
    wire = _wire_hero(hero, cfg)
    return HandlerResult(
        encode_response(HERO_REQ_CHANGE_HERO_SKIN, {"hero": wire, "beforeSkinId": before}),
        True,
        (_hero_push(hero, cfg),),
    )


def response_for(proto: int, state: dict[str, Any], body: bytes = b"",
                 cfg: GameStaticConfig | None = None) -> HandlerResult | None:
    if proto not in HERO_PROGRESSION_PROTOCOLS:
        return None
    provider = cfg or static_config()
    try:
        request = decode_request(proto, body)
        if proto == HERO_HERO_UPGRADE:
            return _level_up(state, request, provider)
        if proto == HERO_HERO_ADVANCE:
            return _advance(state, request, provider)
        if proto == HERO_REQ_UP_QUALITY:
            return _quality(state, request, provider)
        if proto == HERO_REQ_CHANGE_HERO_SKIN:
            return _change_skin(state, request, provider)
    except StaticConfigUnavailable:
        # Local server can still boot without the external APK artifact.  Costed
        # progression stays non-mutating until the exact 1.37 config is present.
        return HandlerResult(encode_response(proto, {}))
    return None


def dispatch(client: Any, proto: int, body: bytes) -> bool:
    result = response_for(proto, client.save, body)
    if result is None:
        return False
    if result.mutated:
        persist(client.save)
    for extra_proto, extra_body in result.extra_packets:
        client.send_pkt(extra_proto, extra_body)
    client.send_pkt(proto, result.body)
    return True
