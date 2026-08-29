#!/usr/bin/env python3
"""The fixed-spirit roster a story stage lends the player (s2c 1808).

Every Volume 1 stage is `heroLimitType = LIMIT_NJ`, so the team is not the
player's own formation: it is whatever `DungeonLevel.heroLimitID` names in
`HeroLimitforDungeon`, handed out by the server.  `FubenSquadView` opens with
an empty `formationData_` and waits for this reply; `FubenDataMgr:onRecvLimitHeros`
drops a response whose `heros` list is empty on the floor, which leaves the
squad screen with no team at all and makes the Fight button a no-op
(`Utils:showTips(2100116)` - "no spirit in the lineup").

`BattleDataMgr:heroData` then resolves each battle slot through
`FubenDataMgr:getLimitHero(limitCid)`, so this reply is also what the fight
itself runs on: its attributes are the ones the spirit fights with.
"""
from __future__ import annotations

from typing import Any

from game_static_config import GameStaticConfig, config as static_config
from protocol_schema import decode_request, encode_response

DUNGEON_LIMIT_HERO_DUNGEON = 1808

DUNGEON_PROTOCOLS = frozenset({DUNGEON_LIMIT_HERO_DUNGEON})

# EC_LimitHeroType: only these two lend server-owned spirits.
LIMIT_HERO_TYPES = frozenset({1, 2})

# The formation `type` the client stores story-stage line-ups under.
MAIN_FORMATION_TYPE = 1


def _as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _default_strategy(angel_skills: list[dict[str, int]]) -> dict[str, Any]:
    return {
        "id": 1,
        "name": "Default",
        "alreadyUseSkillPiont": 0,
        # HeroDataMgr:setHeroAngelInfo reads the *strategy's* skill list, not
        # the hero's, so the unlocked nodes have to be mirrored here too.
        "angeSkillInfos": [dict(row) for row in angel_skills],
        "passiveSkillInfo": [],
    }


def _angel_skills(cfg: GameStaticConfig, hero_cid: int, node_ids: list[int]) -> list[dict[str, int]]:
    """Turn HeroLimitforDungeon.angelUp node ids into wire angeSkillInfos rows."""
    rows: list[dict[str, int]] = []
    seen: set[tuple[int, int]] = set()
    for node_id in node_ids:
        node = cfg.angel_skill_by_id(_as_int(node_id))
        if node is None or _as_int(node.get("heroId")) != int(hero_cid):
            continue
        key = (_as_int(node.get("skillType")), _as_int(node.get("pos")))
        if key in seen:
            continue
        seen.add(key)
        rows.append({"type": key[0], "pos": key[1], "lvl": _as_int(node.get("lvl"), 1)})
    return rows


def limit_hero_info(cfg: GameStaticConfig, limit_id: int) -> dict[str, Any] | None:
    """A complete HeroInfo for one HeroLimitforDungeon row."""
    row = cfg.limit_hero(limit_id)
    if row is None:
        return None
    hero_cid = _as_int(row.get("heroCid"))
    if hero_cid <= 0:
        return None
    static = cfg.hero(hero_cid) or {}
    level = max(1, _as_int(row.get("level"), 1))
    quality = _as_int(static.get("baseQuality"), 1)
    skin_cid = _as_int(row.get("skinCid")) or _as_int(static.get("defaultSkin"))
    angel_skills = _angel_skills(cfg, hero_cid, row.get("angelUp") or [])
    return {
        "ct": 0,
        # `changesid` rewrites id->sid and cid->id, so this only ever surfaces
        # as the hero's string handle; keying it by limitId keeps the roster
        # unique when one stage lends the same spirit twice.
        "id": str(limit_id),
        "cid": hero_cid,
        "lvl": level,
        "exp": 0,
        "attr": cfg.hero_attributes(hero_cid, level, quality=quality),
        "advancedLvl": 0,
        "equipments": [],
        "helpFight": False,
        # HeroDataMgr:getAngelLevel() does `angelLvl or 1`; 0 is truthy in Lua
        # and locks every node that needs the Lv.1 baseline.
        "angelLvl": 1,
        "angeSkillInfos": [dict(skill) for skill in angel_skills],
        "useSkillPiont": 0,
        "quality": quality,
        "provide": 0,
        "fightPower": _as_int(row.get("powerValue")),
        "skinCid": skin_cid,
        "skillStrategyInfo": [_default_strategy(angel_skills)],
        "useSkillStrategy": 1,
        "crystalInfo": [],
        "equipSkillIds": [],
        "euqipFetterInfo": [],
        "heroStatus": 1,
        "deadLine": 0,
        "gemInfos": [],
        "skinCidTemp": 0,
        "exploreTreasureSkill": [],
        "breakLv": max(0, _as_int(row.get("breakthrough"))),
        "angelStrengthen": [],
    }


def limit_hero_roster(level_cid: int, cfg: GameStaticConfig | None = None) -> dict[str, Any]:
    """s2c 1808 for one stage: its lent spirits plus the line-up they fill."""
    cfg = cfg or static_config()
    empty = {"heros": [], "leveId": max(0, int(level_cid)), "limitFormation": {
        "ct": 0, "type": MAIN_FORMATION_TYPE, "status": 1, "stance": []}}
    if level_cid <= 0:
        return empty
    limits = cfg.dungeon_hero_limit(level_cid)
    if limits is None or _as_int(limits.get("heroLimitType")) not in LIMIT_HERO_TYPES:
        return empty

    heros: list[dict[str, Any]] = []
    stance: list[str] = []
    for limit_id in limits.get("heroLimitIds") or []:
        limit_id = _as_int(limit_id)
        if limit_id <= 0:
            continue
        info = limit_hero_info(cfg, limit_id)
        if info is None:
            continue
        heros.append({"limitId": limit_id, "heros": info})
        stance.append(str(limit_id))

    return {
        "heros": heros,
        "leveId": int(level_cid),
        "limitFormation": {
            "ct": 0,
            "type": MAIN_FORMATION_TYPE,
            "status": 1,
            "stance": stance,
        },
    }


def response_for(proto: int, state: dict[str, Any], body: bytes = b"") -> tuple[bytes, bool] | None:
    if proto != DUNGEON_LIMIT_HERO_DUNGEON:
        return None
    request = decode_request(proto, body)
    level_cid = _as_int(request.get("levelId"))
    values = limit_hero_roster(level_cid)
    return encode_response(proto, values), False


def dispatch(client: Any, proto: int, body: bytes) -> bool:
    result = response_for(proto, client.save, body)
    if result is None:
        return False
    payload, _ = result
    client.send_pkt(proto, payload)
    return True
