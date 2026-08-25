#!/usr/bin/env python3
"""Stateful Angel skill-tree, awakening, breakthrough and strengthen handlers.

The client remains the authority for presentation, while every cost/unlock rule
here is sourced from the exact 1.37 Lua tables. Invalid or unaffordable writes
are acknowledged without mutating persistent state.
"""
from __future__ import annotations

from dataclasses import dataclass
from copy import deepcopy
from typing import Any

from game_static_config import GameStaticConfig, StaticConfigUnavailable, config as static_config
from hero_progression_handlers import HERO_HERO_INFO, _wire_hero
from player_save import save as persist
from protocol_schema import decode_request, encode_response
from state_transactions import consume_cids

HERO_RESP_ANGEL_ADD_BIT = 1033
HERO_REQ_AWAKE_ANGEL = 1037
HERO_REQ_UPGRADE_SKILL = 1038
HERO_REQ_MODIFY_STRATEGY_NAME = 1039
HERO_REQ_EQUIP_PASSIVE_SKILL = 1041
HERO_RES_PROPERTY_CHANGE = 1043
HERO_REQ_RESET_SKILL = 1044
HERO_REQ_ANGEL_STRENGTHEN = 1051
HERO_SPIRIT_RSP_SPIRIT_REFRESH = 8405
HERO_SPIRIT_REQ_UPGRADE_ANGLE_SPIRIT = 8409
SKILL_POINT_ATTR = 13
PASSIVE_SKILL_TYPE = 10
MAX_STRATEGY_NAME = 32

ANGEL_PROTOCOLS = frozenset({
    HERO_RESP_ANGEL_ADD_BIT,
    HERO_REQ_AWAKE_ANGEL,
    HERO_REQ_UPGRADE_SKILL,
    HERO_REQ_MODIFY_STRATEGY_NAME,
    HERO_REQ_EQUIP_PASSIVE_SKILL,
    HERO_REQ_RESET_SKILL,
    HERO_REQ_ANGEL_STRENGTHEN,
    HERO_SPIRIT_REQ_UPGRADE_ANGLE_SPIRIT,
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


def _find_hero_by_sid(state: dict[str, Any], sid: Any) -> dict[str, Any] | None:
    wanted = str(sid or "")
    for hero in _hero_rows(state):
        if str(hero.get("id", "")) == wanted:
            return hero
    return None


def _find_hero_by_cid(state: dict[str, Any], cid: Any) -> dict[str, Any] | None:
    wanted = _as_int(cid)
    for hero in _hero_rows(state):
        if _as_int(hero.get("cid")) == wanted:
            return hero
    return None


def _strategy_rows(hero: dict[str, Any]) -> list[dict[str, Any]]:
    raw = hero.get("skillStrategyInfo")
    if not isinstance(raw, list):
        hero["skillStrategyInfo"] = raw = []
    return [row for row in raw if isinstance(row, dict)]


def _strategy(hero: dict[str, Any], strategy_id: int, *, create: bool = False,
              cfg: GameStaticConfig | None = None) -> dict[str, Any] | None:
    if strategy_id <= 0:
        return None
    rows = _strategy_rows(hero)
    for row in rows:
        if _as_int(row.get("id")) == strategy_id:
            row.setdefault("name", "Default" if strategy_id == 1 else f"Strategy {strategy_id}")
            row.setdefault("alreadyUseSkillPiont", 0)
            row.setdefault("angeSkillInfos", [])
            row.setdefault("passiveSkillInfo", [])
            return row
    if not create or cfg is None or cfg.block("AngelSkillPage", strategy_id) is None:
        return None
    row = {
        "id": strategy_id,
        "name": "Default" if strategy_id == 1 else f"Strategy {strategy_id}",
        "alreadyUseSkillPiont": 0,
        "angeSkillInfos": [],
        "passiveSkillInfo": [],
    }
    hero.setdefault("skillStrategyInfo", []).append(row)
    hero["skillStrategyInfo"].sort(key=lambda value: _as_int(value.get("id")))
    return row


def _active_strategy(hero: dict[str, Any], cfg: GameStaticConfig) -> dict[str, Any]:
    strategy_id = max(1, _as_int(hero.get("useSkillStrategy"), 1))
    row = _strategy(hero, strategy_id, create=True, cfg=cfg)
    if row is None:
        row = _strategy(hero, 1, create=True, cfg=cfg)
        hero["useSkillStrategy"] = 1
    assert row is not None
    return row


def _skill_level(page: dict[str, Any], skill_type: int, pos: int) -> int:
    for row in page.get("angeSkillInfos", []) or []:
        if isinstance(row, dict) and _as_int(row.get("type")) == skill_type and _as_int(row.get("pos")) == pos:
            return max(0, _as_int(row.get("lvl")))
    return 0


def _set_skill_level(page: dict[str, Any], skill_type: int, pos: int, level: int) -> None:
    rows = page.setdefault("angeSkillInfos", [])
    target = None
    for row in rows:
        if isinstance(row, dict) and _as_int(row.get("type")) == skill_type and _as_int(row.get("pos")) == pos:
            target = row
            break
    if level <= 0:
        page["angeSkillInfos"] = [
            row for row in rows
            if not (isinstance(row, dict) and _as_int(row.get("type")) == skill_type and _as_int(row.get("pos")) == pos)
        ]
        return
    if target is None:
        rows.append({"type": skill_type, "pos": pos, "lvl": level})
    else:
        target["lvl"] = level


def _node_unlocked(hero: dict[str, Any], page: dict[str, Any], node: dict[str, Any], cfg: GameStaticConfig) -> bool:
    if max(1, _as_int(hero.get("lvl"), 1)) < _as_int(node.get("needHeroLvl")):
        return False
    if max(1, _as_int(hero.get("angelLvl"), 1)) < _as_int(node.get("needAngelLvl")):
        return False
    for node_id in node.get("frontCondition", []) or []:
        required = cfg.angel_skill_by_id(_as_int(node_id))
        if required is None:
            return False
        if _skill_level(page, _as_int(required["skillType"]), _as_int(required["pos"])) < _as_int(required["lvl"]):
            return False
    return True


def _attr_value(hero: dict[str, Any], attr_type: int) -> int:
    for row in hero.get("attr", []) or []:
        if isinstance(row, dict) and _as_int(row.get("type")) == attr_type:
            return max(0, _as_int(row.get("val")))
    return 0


def _set_attr(hero: dict[str, Any], attr_type: int, value: int) -> None:
    rows = hero.get("attr")
    if not isinstance(rows, list):
        hero["attr"] = rows = []
    for row in rows:
        if isinstance(row, dict) and _as_int(row.get("type")) == attr_type:
            row["val"] = max(0, int(value))
            return
    rows.append({"type": int(attr_type), "val": max(0, int(value))})


def _skill_point_total(hero: dict[str, Any]) -> int:
    return _attr_value(hero, SKILL_POINT_ATTR) // 100


def _spirit_info(state: dict[str, Any]) -> dict[str, Any]:
    raw = state.get("spiritInfo")
    source = raw if isinstance(raw, dict) else {}
    specialism = [deepcopy(row) for row in source.get("specialism", []) or [] if isinstance(row, dict)]
    angle_spirits = [deepcopy(row) for row in source.get("angleSpirits", []) or [] if isinstance(row, dict)]
    value = {
        "spiritPoints": max(0, _as_int(source.get("spiritPoints"))),
        "grade": max(0, _as_int(source.get("grade"))),
        "level": max(1, _as_int(source.get("level"), 1)),
        "exp": max(0, _as_int(source.get("exp"))),
        "specialism": specialism,
        "firstShow": bool(source.get("firstShow", False)),
        "feedback": bool(source.get("feedback", False)),
        "angleSpirits": angle_spirits,
        "maxLv": max(1, _as_int(source.get("maxLv"), max(1, _as_int(source.get("level"), 1)))),
    }
    state["spiritInfo"] = value
    return value


def _angle_break_level(spirit: dict[str, Any], hero_cid: int) -> int:
    for row in spirit.get("angleSpirits", []) or []:
        if isinstance(row, dict) and _as_int(row.get("heroCid")) == hero_cid:
            return max(0, _as_int(row.get("lv")))
    return 0


def _set_angle_break_level(spirit: dict[str, Any], hero_cid: int, level: int) -> None:
    rows = spirit.setdefault("angleSpirits", [])
    for row in rows:
        if isinstance(row, dict) and _as_int(row.get("heroCid")) == hero_cid:
            row["lv"] = max(0, int(level))
            return
    rows.append({"heroCid": int(hero_cid), "lv": max(0, int(level))})


def _property_push(hero: dict[str, Any]) -> tuple[int, bytes]:
    return HERO_RES_PROPERTY_CHANGE, encode_response(HERO_RES_PROPERTY_CHANGE, {
        "heroId": str(hero.get("id", "")),
        "attr": [{"type": SKILL_POINT_ATTR, "val": _attr_value(hero, SKILL_POINT_ATTR)}],
        "fightPower": max(0, _as_int(hero.get("fightPower"))),
    })


def _hero_push(hero: dict[str, Any], cfg: GameStaticConfig) -> tuple[int, bytes]:
    return HERO_HERO_INFO, encode_response(HERO_HERO_INFO, _wire_hero(hero, cfg))


def _awake(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    sid = str(request.get("heroId", ""))
    hero = _find_hero_by_sid(state, sid)
    current = max(1, _as_int((hero or {}).get("angelLvl"), 1))
    body = encode_response(HERO_REQ_AWAKE_ANGEL, {"heroId": sid, "angelLvl": current})
    if hero is None:
        return HandlerResult(body)
    costs = cfg.angel_awake_cost(_as_int(hero.get("cid")), current)
    if costs is None or not costs or not consume_cids(state, costs):
        return HandlerResult(body)
    hero["angelLvl"] = current + 1
    return HandlerResult(
        encode_response(HERO_REQ_AWAKE_ANGEL, {"heroId": sid, "angelLvl": current + 1}),
        True,
        (_hero_push(hero, cfg),),
    )


def _upgrade_skill(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    sid = str(request.get("heroId", ""))
    hero = _find_hero_by_sid(state, sid)
    skill_type = _as_int(request.get("type"))
    pos = _as_int(request.get("pos"))
    operation = _as_int(request.get("operation"), 1)
    if hero is None or skill_type <= 0 or skill_type == PASSIVE_SKILL_TYPE or pos <= 0:
        return HandlerResult(encode_response(HERO_REQ_UPGRADE_SKILL, {
            "heroId": sid, "angeSkillInfo": {"type": skill_type, "pos": pos, "lvl": 0}, "useSkillPiont": 0,
        }))
    page = _active_strategy(hero, cfg)
    current = _skill_level(page, skill_type, pos)
    used = max(0, _as_int(page.get("alreadyUseSkillPiont")))
    new_level = current
    new_used = used
    if operation == 1:
        node = cfg.angel_skill(_as_int(hero.get("cid")), skill_type, pos, current + 1)
        if node is not None and _node_unlocked(hero, page, node, cfg):
            cost = max(0, _as_int(node.get("needSkillPoint")))
            if cost <= max(0, _skill_point_total(hero) - used):
                new_level = current + 1
                new_used = used + cost
    elif operation == 2 and current > 0:
        node = cfg.angel_skill(_as_int(hero.get("cid")), skill_type, pos, current)
        if node is not None:
            new_level = current - 1
            new_used = max(0, used - max(0, _as_int(node.get("needSkillPoint"))))
    if new_level != current:
        _set_skill_level(page, skill_type, pos, new_level)
        page["alreadyUseSkillPiont"] = new_used
    return HandlerResult(encode_response(HERO_REQ_UPGRADE_SKILL, {
        "heroId": sid,
        "angeSkillInfo": {"type": skill_type, "pos": pos, "lvl": new_level},
        "useSkillPiont": new_used,
    }), new_level != current)


def _rename_strategy(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    sid = str(request.get("heroId", ""))
    strategy_id = _as_int(request.get("skillStrategyId"))
    raw_name = str(request.get("name", "") or "").strip()
    hero = _find_hero_by_sid(state, sid)
    if hero is None:
        return HandlerResult(encode_response(HERO_REQ_MODIFY_STRATEGY_NAME, {
            "heroId": sid, "skillStrategyId": strategy_id, "name": "",
        }))
    page = _strategy(hero, strategy_id, create=True, cfg=cfg)
    if page is None:
        return HandlerResult(encode_response(HERO_REQ_MODIFY_STRATEGY_NAME, {
            "heroId": sid, "skillStrategyId": strategy_id, "name": "",
        }))
    if not raw_name or len(raw_name) > MAX_STRATEGY_NAME:
        return HandlerResult(encode_response(HERO_REQ_MODIFY_STRATEGY_NAME, {
            "heroId": sid, "skillStrategyId": strategy_id, "name": str(page.get("name", "")),
        }))
    changed = str(page.get("name", "")) != raw_name
    if changed:
        page["name"] = raw_name
    return HandlerResult(encode_response(HERO_REQ_MODIFY_STRATEGY_NAME, {
        "heroId": sid, "skillStrategyId": strategy_id, "name": str(page.get("name", "")),
    }), changed)


def _equip_passive(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    sid = str(request.get("heroId", ""))
    skill_id = _as_int(request.get("skillId"))
    requested_pos = _as_int(request.get("pos"))
    hero = _find_hero_by_sid(state, sid)
    if hero is None:
        return HandlerResult(encode_response(HERO_REQ_EQUIP_PASSIVE_SKILL, {
            "heroId": sid, "passiveSkillInfo": {"pos": requested_pos, "skillId": 0},
        }))
    page = _active_strategy(hero, cfg)
    rows = page.setdefault("passiveSkillInfo", [])
    existing = next((row for row in rows if isinstance(row, dict) and _as_int(row.get("skillId")) == skill_id), None)
    if requested_pos <= 0:
        if existing is None:
            return HandlerResult(encode_response(HERO_REQ_EQUIP_PASSIVE_SKILL, {
                "heroId": sid, "passiveSkillInfo": {"pos": 0, "skillId": 0},
            }))
        old_pos = _as_int(existing.get("pos"))
        existing["skillId"] = 0
        return HandlerResult(encode_response(HERO_REQ_EQUIP_PASSIVE_SKILL, {
            "heroId": sid, "passiveSkillInfo": {"pos": old_pos, "skillId": 0},
        }), True)

    node = cfg.angel_skill_by_id(skill_id)
    slot = cfg.passive_slot(requested_pos)
    valid = (
        node is not None
        and _as_int(node.get("heroId")) == _as_int(hero.get("cid"))
        and _as_int(node.get("skillType")) == PASSIVE_SKILL_TYPE
        and slot is not None
        and max(1, _as_int(hero.get("lvl"), 1)) >= _as_int(slot.get("needHeroLvl"))
        and max(1, _as_int(hero.get("angelLvl"), 1)) >= _as_int(slot.get("needAngelLvl"))
        and _node_unlocked(hero, page, node, cfg)
    )
    if not valid:
        current = next((row for row in rows if isinstance(row, dict) and _as_int(row.get("pos")) == requested_pos), None)
        return HandlerResult(encode_response(HERO_REQ_EQUIP_PASSIVE_SKILL, {
            "heroId": sid,
            "passiveSkillInfo": {"pos": requested_pos, "skillId": _as_int((current or {}).get("skillId"))},
        }))
    changed = False
    for row in rows:
        if isinstance(row, dict) and _as_int(row.get("skillId")) == skill_id and _as_int(row.get("pos")) != requested_pos:
            row["skillId"] = 0
            changed = True
    target = next((row for row in rows if isinstance(row, dict) and _as_int(row.get("pos")) == requested_pos), None)
    if target is None:
        rows.append({"pos": requested_pos, "skillId": skill_id})
        changed = True
    elif _as_int(target.get("skillId")) != skill_id:
        target["skillId"] = skill_id
        changed = True
    return HandlerResult(encode_response(HERO_REQ_EQUIP_PASSIVE_SKILL, {
        "heroId": sid, "passiveSkillInfo": {"pos": requested_pos, "skillId": skill_id},
    }), changed)


def _reset_skill(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    sid = str(request.get("heroId", ""))
    strategy_id = _as_int(request.get("skillStrategyId"))
    hero = _find_hero_by_sid(state, sid)
    page = _strategy(hero, strategy_id, create=False, cfg=cfg) if hero is not None else None
    if page is None:
        empty = {"id": strategy_id, "name": "", "alreadyUseSkillPiont": 0, "angeSkillInfos": [], "passiveSkillInfo": []}
        return HandlerResult(encode_response(HERO_REQ_RESET_SKILL, {"heroId": sid, "skillStrategy": empty}))
    changed = bool(page.get("angeSkillInfos")) or bool(page.get("passiveSkillInfo")) or _as_int(page.get("alreadyUseSkillPiont")) != 0
    if changed:
        page["alreadyUseSkillPiont"] = 0
        page["angeSkillInfos"] = []
        page["passiveSkillInfo"] = []
    return HandlerResult(encode_response(HERO_REQ_RESET_SKILL, {
        "heroId": sid, "skillStrategy": deepcopy(page),
    }), changed)


def _strengthen(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    sid = str(request.get("heroId", ""))
    skill_type = _as_int(request.get("skillType"))
    cost_type = 2 if _as_int(request.get("costType")) == 2 else 1
    hero = _find_hero_by_sid(state, sid)
    current = 0
    if hero is not None:
        for row in hero.get("angelStrengthen", []) or []:
            if isinstance(row, dict) and _as_int(row.get("skillType")) == skill_type:
                current = max(0, _as_int(row.get("lv")))
                break
    body = encode_response(HERO_REQ_ANGEL_STRENGTHEN, {"heroId": sid, "skillType": skill_type, "lv": current})
    if hero is None or skill_type <= 0:
        return HandlerResult(body)
    static = cfg.hero(_as_int(hero.get("cid"))) or {}
    if _as_int(static.get("openAngelStrengthen")) <= 0:
        return HandlerResult(body)
    costs = cfg.angel_strengthen_cost(_as_int(hero.get("cid")), skill_type, current + 1, cost_type)
    if costs is None or not costs or not consume_cids(state, costs):
        return HandlerResult(body)
    rows = hero.setdefault("angelStrengthen", [])
    target = next((row for row in rows if isinstance(row, dict) and _as_int(row.get("skillType")) == skill_type), None)
    if target is None:
        rows.append({"skillType": skill_type, "lv": current + 1})
    else:
        target["lv"] = current + 1
    return HandlerResult(encode_response(HERO_REQ_ANGEL_STRENGTHEN, {
        "heroId": sid, "skillType": skill_type, "lv": current + 1,
    }), True, (_hero_push(hero, cfg),))


def _breakthrough(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    hero_cid = _as_int(request.get("hero"))
    cost_id = _as_int(request.get("costId"))
    hero = _find_hero_by_cid(state, hero_cid)
    empty = encode_response(HERO_SPIRIT_REQ_UPGRADE_ANGLE_SPIRIT, {})
    if hero is None or cost_id <= 0:
        return HandlerResult(empty)
    raw_spirit = state.get("spiritInfo")
    current = _angle_break_level(raw_spirit if isinstance(raw_spirit, dict) else {}, hero_cid)
    next_stage = cfg.angel_break_stage(hero_cid, current + 1)
    if next_stage is None:
        return HandlerResult(empty)
    options = next_stage.get("costOptions", []) or []
    if cost_id > len(options):
        return HandlerResult(empty)
    costs = options[cost_id - 1]
    if not costs or not consume_cids(state, costs):
        return HandlerResult(empty)
    spirit = _spirit_info(state)
    new_level = current + 1
    _set_angle_break_level(spirit, hero_cid, new_level)
    hero["breakLv"] = new_level
    reward_by_attr = {int(row["id"]): int(row["num"]) for row in next_stage.get("reward", []) or []}
    if SKILL_POINT_ATTR in reward_by_attr:
        _set_attr(hero, SKILL_POINT_ATTR, reward_by_attr[SKILL_POINT_ATTR])
    extras = [
        (HERO_SPIRIT_RSP_SPIRIT_REFRESH, encode_response(HERO_SPIRIT_RSP_SPIRIT_REFRESH, {"spirits": spirit})),
        _property_push(hero),
        _hero_push(hero, cfg),
    ]
    return HandlerResult(empty, True, tuple(extras))


def _add_bit(state: dict[str, Any], request: dict[str, Any], cfg: GameStaticConfig) -> HandlerResult:
    hero = _find_hero_by_sid(state, request.get("heroId"))
    node = cfg.angel_skill_by_id(_as_int(request.get("cid")))
    valid = hero is not None and node is not None and _as_int(node.get("heroId")) == _as_int(hero.get("cid"))
    return HandlerResult(encode_response(HERO_RESP_ANGEL_ADD_BIT, {} if valid else {}))


def response_for(proto: int, state: dict[str, Any], body: bytes = b"",
                 cfg: GameStaticConfig | None = None) -> HandlerResult | None:
    if proto not in ANGEL_PROTOCOLS:
        return None
    provider = cfg or static_config()
    try:
        request = decode_request(proto, body)
        if proto == HERO_RESP_ANGEL_ADD_BIT:
            return _add_bit(state, request, provider)
        if proto == HERO_REQ_AWAKE_ANGEL:
            return _awake(state, request, provider)
        if proto == HERO_REQ_UPGRADE_SKILL:
            return _upgrade_skill(state, request, provider)
        if proto == HERO_REQ_MODIFY_STRATEGY_NAME:
            return _rename_strategy(state, request, provider)
        if proto == HERO_REQ_EQUIP_PASSIVE_SKILL:
            return _equip_passive(state, request, provider)
        if proto == HERO_REQ_RESET_SKILL:
            return _reset_skill(state, request, provider)
        if proto == HERO_REQ_ANGEL_STRENGTHEN:
            return _strengthen(state, request, provider)
        if proto == HERO_SPIRIT_REQ_UPGRADE_ANGLE_SPIRIT:
            return _breakthrough(state, request, provider)
    except StaticConfigUnavailable:
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
