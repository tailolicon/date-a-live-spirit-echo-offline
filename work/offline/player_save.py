#!/usr/bin/env python3
"""Local persistent player state for the offline preservation server."""
from __future__ import annotations

import json
import os
import time
from copy import deepcopy
from typing import Any

ROOT = os.path.dirname(os.path.abspath(__file__))
SAVE_PATH = os.path.join(ROOT, "saves", "player.json")
SCHEMA_VERSION = 3
FIRST_PLOT_LEVEL = 101101
GOLD_CID = 500001
DIAMOND_CID = 500002
FRIENDSHIP_CID = 500003
POWER_CID = 500004
STARTER_HERO_CID = 110101
STARTER_HERO_SID = "local-110101-1"
STARTER_HERO_SKIN = 1101011
STARTER_HERO_QUALITY = 4
STARTER_RESOURCES = {GOLD_CID: 1_000_000, DIAMOND_CID: 10_000, FRIENDSHIP_CID: 10_000, POWER_CID: 999}


def resource_item(cid: int, num: int, ct: int = 0) -> dict[str, Any]:
    cid = int(cid)
    return {"ct": int(ct), "id": str(cid), "cid": cid, "num": max(0, int(num)), "outTime": 0}


def default_resource_items() -> dict[str, dict[str, Any]]:
    return {str(cid): resource_item(cid, num) for cid, num in STARTER_RESOURCES.items()}


def starter_hero() -> dict[str, Any]:
    """Minimal complete HeroInfo for the bundled Tohka starter (cid 110101)."""
    return {
        "ct": 0,
        "id": STARTER_HERO_SID,
        "cid": STARTER_HERO_CID,
        "lvl": 1,
        "exp": 0,
        "attr": [],
        "advancedLvl": 0,
        "equipments": [],
        "helpFight": False,
        "angelLvl": 0,
        "angeSkillInfos": [],
        "useSkillPiont": 0,
        "quality": STARTER_HERO_QUALITY,
        "provide": 0,
        "fightPower": 0,
        "skinCid": STARTER_HERO_SKIN,
        "skillStrategyInfo": [{
            "id": 1,
            "name": "Default",
            "alreadyUseSkillPiont": 0,
            "angeSkillInfos": [],
            "passiveSkillInfo": [],
        }],
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


def default_formations(starter_sid: str = STARTER_HERO_SID) -> list[dict[str, Any]]:
    return [
        {"ct": 0, "type": 1, "status": 1, "stance": [starter_sid] if starter_sid else []},
        {"ct": 0, "type": 2, "status": 1, "stance": []},
        {"ct": 0, "type": 3, "status": 1, "stance": []},
    ]


def default_save() -> dict[str, Any]:
    now = int(time.time())
    return {
        "schemaVersion": SCHEMA_VERSION,
        "pid": 10001,
        "name": "Shido",
        "lvl": 1,
        "exp": 0,
        "vip_lvl": 0,
        "vip_exp": 0,
        "language": 1,
        "remark": "",
        "helpFightHeroCid": STARTER_HERO_CID,
        "attr": [],
        "isFirstLogin": True,
        "clientDiscreteData": "{}",
        "settings": "",
        "recoverTimeList": [],
        "portraitCid": 0,
        "portraitFrameCid": 0,
        "unionId": 0,
        "unionName": "",
        "titleId": 0,
        "createTime": now,
        "famousExp": 0,
        "serverId": 101001,
        "group_id": 101,
        "groupName": "Local",
        "token": "offline_local_token",
        "hasRole": True,
        "account": "offline",
        "password": "",
        "items": default_resource_items(),
        "heroes": [starter_hero()],
        "formations": default_formations(),
        "passedLevels": [FIRST_PLOT_LEVEL],
        "mails": [],
        "tasks": [],
        "friends": [],
        "storePurchases": {},
        "gold": STARTER_RESOURCES[GOLD_CID],
        "diamonds": STARTER_RESOURCES[DIAMOND_CID],
        "updated": now,
    }


def _normalize_items(data: dict[str, Any], base_items: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
    raw = data.get("items")
    result: dict[str, dict[str, Any]] = {}
    if isinstance(raw, dict):
        for raw_id, value in raw.items():
            if isinstance(value, dict):
                item = deepcopy(value)
                cid = int(item.get("cid", raw_id))
                item.setdefault("ct", 0)
                item.setdefault("id", str(raw_id))
                item["cid"] = cid
                item["num"] = max(0, int(item.get("num", item.get("count", 0))))
                item.setdefault("outTime", 0)
                result[str(item["id"])] = item
            elif isinstance(value, (int, float)):
                cid = int(raw_id)
                result[str(cid)] = resource_item(cid, int(value))
    elif isinstance(raw, list):
        for value in raw:
            if not isinstance(value, dict) or "cid" not in value:
                continue
            item = deepcopy(value)
            cid = int(item["cid"])
            item.setdefault("ct", 0)
            item.setdefault("id", str(cid))
            item["num"] = max(0, int(item.get("num", item.get("count", 0))))
            item.setdefault("outTime", 0)
            result[str(item["id"])] = item
    legacy = {GOLD_CID: data.get("gold"), DIAMOND_CID: data.get("diamonds")}
    for cid, default_item in base_items.items():
        if cid in result:
            continue
        numeric_cid = int(cid)
        legacy_value = legacy.get(numeric_cid)
        item = deepcopy(default_item)
        if isinstance(legacy_value, (int, float)) and int(legacy_value) > 0:
            item["num"] = int(legacy_value)
        result[cid] = item
    return result


def _normalize_heroes(value: Any, *, migrate_empty: bool) -> list[dict[str, Any]]:
    result = [deepcopy(v) for v in value if isinstance(v, dict)] if isinstance(value, list) else []
    seen: set[str] = set()
    clean: list[dict[str, Any]] = []
    for hero in result:
        sid = str(hero.get("id", hero.get("sid", "")) or "")
        try:
            cid = int(hero.get("cid", 0) or 0)
        except (TypeError, ValueError):
            cid = 0
        if not sid or cid <= 0 or sid in seen:
            continue
        hero["id"] = sid
        hero["cid"] = cid
        hero.setdefault("ct", 0)
        hero["lvl"] = max(1, int(hero.get("lvl", hero.get("level", 1)) or 1))
        hero["exp"] = max(0, int(hero.get("exp", 0) or 0))
        hero["advancedLvl"] = max(0, int(hero.get("advancedLvl", 0) or 0))
        hero["quality"] = max(1, int(hero.get("quality", 1) or 1))
        hero.setdefault("skinCid", 0)
        hero.setdefault("skillStrategyInfo", [])
        hero.setdefault("useSkillStrategy", 1)
        seen.add(sid)
        clean.append(hero)
    if not clean and migrate_empty:
        clean.append(starter_hero())
    return clean


def _normalize_formations(value: Any, *, starter_sid: str = "", migrate_empty: bool = False) -> list[dict[str, Any]]:
    by_type: dict[int, dict[str, Any]] = {}
    if isinstance(value, list):
        for formation in value:
            if not isinstance(formation, dict):
                continue
            ftype = int(formation.get("type", 0))
            if ftype not in (1, 2, 3):
                continue
            clean = deepcopy(formation)
            clean["ct"] = int(clean.get("ct", 0))
            clean["status"] = int(clean.get("status", 1))
            clean["stance"] = [str(v) for v in clean.get("stance", []) if str(v)]
            by_type[ftype] = clean
    defaults = default_formations(starter_sid if migrate_empty else "")
    for default in defaults:
        by_type.setdefault(default["type"], deepcopy(default))
    if migrate_empty and starter_sid:
        main = by_type[1]
        if not main.get("stance"):
            main["stance"] = [starter_sid]
    return [by_type[k] for k in (1, 2, 3)]


def normalize_save(data: dict[str, Any] | None) -> dict[str, Any]:
    incoming = deepcopy(data) if isinstance(data, dict) else {}
    try:
        previous_schema = int(incoming.get("schemaVersion", 0) or 0)
    except (TypeError, ValueError):
        previous_schema = 0
    migrating_v3 = previous_schema < 3

    base = default_save()
    base.update(incoming)
    base["schemaVersion"] = SCHEMA_VERSION
    base["items"] = _normalize_items(incoming, default_resource_items())

    raw_heroes = incoming.get("heroes", base.get("heroes", []))
    base["heroes"] = _normalize_heroes(raw_heroes, migrate_empty=migrating_v3)
    starter_sid = str(base["heroes"][0].get("id", "")) if base["heroes"] else ""
    base["formations"] = _normalize_formations(
        incoming.get("formations"), starter_sid=starter_sid, migrate_empty=migrating_v3
    )
    if migrating_v3 and base["heroes"] and not int(base.get("helpFightHeroCid", 0) or 0):
        base["helpFightHeroCid"] = int(base["heroes"][0].get("cid", 0) or 0)

    passed = incoming.get("passedLevels")
    clean_passed: list[int] = []
    if isinstance(passed, list):
        for value in passed:
            try:
                cid = int(value)
            except (TypeError, ValueError):
                continue
            if cid > 0 and cid not in clean_passed:
                clean_passed.append(cid)
    if FIRST_PLOT_LEVEL not in clean_passed:
        clean_passed.insert(0, FIRST_PLOT_LEVEL)
    base["passedLevels"] = clean_passed
    for key in ("mails", "tasks", "friends"):
        value = incoming.get(key, base.get(key, []))
        base[key] = [deepcopy(v) for v in value if isinstance(v, dict)] if isinstance(value, list) else []
    by_cid = {int(v.get("cid", 0)): v for v in base["items"].values()}
    base["gold"] = int(by_cid.get(GOLD_CID, {}).get("num", 0))
    base["diamonds"] = int(by_cid.get(DIAMOND_CID, {}).get("num", 0))
    return base


def load_save() -> dict[str, Any]:
    if not os.path.isfile(SAVE_PATH):
        state = default_save()
        save(state)
        return state
    with open(SAVE_PATH, encoding="utf-8") as f:
        data = json.load(f)
    state = normalize_save(data)
    if state != data:
        save(state)
    return state


def save(data: dict[str, Any]) -> None:
    os.makedirs(os.path.dirname(SAVE_PATH), exist_ok=True)
    state = normalize_save(data)
    state["updated"] = int(time.time())
    tmp = SAVE_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, ensure_ascii=False, indent=2)
    os.replace(tmp, SAVE_PATH)


def backup() -> str:
    src = load_save()
    stamp = time.strftime("%Y%m%d-%H%M%S")
    path = os.path.join(ROOT, "saves", f"player-{stamp}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(src, f, ensure_ascii=False, indent=2)
    return path
