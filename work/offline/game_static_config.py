#!/usr/bin/env python3
"""Read the 1.37 static data used by the offline server.

The original game keeps its Lua tables in the APK behind the same F8/8B/2D
wrapper used by the hotpatch tooling. Keeping economy/progression rules sourced
from those tables prevents the local server from inventing costs or rewards.
"""
from __future__ import annotations

from functools import lru_cache
import os
import re
import zipfile
import zlib
from typing import Any

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SIGN2 = bytes([0xF8, 0x8B])


class StaticConfigUnavailable(RuntimeError):
    pass


def decrypt_bytes(data: bytes) -> bytes:
    if len(data) < 3 or data[:2] != SIGN2:
        return data
    if data[2] not in (0x2D, 0x3D):
        raise StaticConfigUnavailable(f"unsupported Lua wrapper {data[:3].hex()}")
    buf = bytearray(data)
    buf[1] = 0x1F
    buf[2] = 0x8B
    span = 0x14 if len(buf) - 3 >= 0x15 else len(buf) - 3
    buf = buf[1:]
    if span > 0:
        out = bytearray(buf)
        out[2] = buf[2] ^ (span & 0xFF)
        running = 0
        for index in range(2, span + 1):
            running = (running + buf[index]) & 0xFFFFFFFF
            key = (running + 0x14) % 0x2D
            out[index + 1] = buf[index + 1] ^ (key & 0xFF)
        buf = out
    return zlib.decompress(bytes(buf), zlib.MAX_WBITS | 32)


def _match_brace(src: str, start: int) -> int:
    depth = 0
    quote: str | None = None
    escaped = False
    for index in range(start, len(src)):
        char = src[index]
        if quote is not None:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == quote:
                quote = None
            continue
        if char in ("'", '"'):
            quote = char
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index + 1
    raise ValueError("unbalanced Lua table")


def _indexed_block(src: str, key: int) -> str | None:
    match = re.search(rf"\[{int(key)}\]\s*=\s*\{{", src)
    if match is None:
        return None
    start = src.find("{", match.start())
    return src[match.start():_match_brace(src, start)]


def _named_block(src: str, name: str) -> str | None:
    match = re.search(rf"\b{re.escape(name)}\s*=\s*\{{", src)
    if match is None:
        return None
    start = src.find("{", match.start())
    return src[match.start():_match_brace(src, start)]


def _string_field(src: str, name: str, default: str = "") -> str:
    match = re.search(rf"\b{re.escape(name)}\s*=\s*\"([^\"]*)\"", src)
    return match.group(1) if match else default


def _text_id(src: str, name: str) -> int:
    """A numeric field the tables sometimes quote (`name = "302001"`)."""
    value = _int_field(src, name, -1)
    if value >= 0:
        return value
    quoted = _string_field(src, name)
    try:
        return max(0, int(quoted))
    except (TypeError, ValueError):
        return 0


def _time_of_day(value: str) -> int:
    """`"08:40:00"` -> seconds since midnight; the wire field is an int."""
    parts = value.split(":") if value else []
    if len(parts) != 3:
        return 0
    try:
        hours, minutes, seconds = (int(part) for part in parts)
    except ValueError:
        return 0
    return max(0, hours * 3600 + minutes * 60 + seconds)


def _int_field(src: str, name: str, default: int = 0) -> int:
    match = re.search(rf"\b{re.escape(name)}\s*=\s*(-?\d+)", src)
    return int(match.group(1)) if match else default


def _bool_field(src: str, name: str, default: bool = False) -> bool:
    match = re.search(rf"\b{re.escape(name)}\s*=\s*(true|false)", src)
    return (match.group(1) == "true") if match else default


def _array_ints(src: str | None) -> list[int]:
    if not src:
        return []
    return [int(value) for _, value in re.findall(r"\[(\d+)\]\s*=\s*(-?\d+)\s*,?", src)]


def _array_pairs(src: str | None) -> list[dict[str, int]]:
    if not src:
        return []
    result: list[dict[str, int]] = []
    for match in re.finditer(r"\[(\d+)\]\s*=\s*\{", src):
        start = src.find("{", match.start())
        child = src[start:_match_brace(src, start)]
        cid_match = re.search(r"\[1\]\s*=\s*(\d+)", child)
        num_match = re.search(r"\[2\]\s*=\s*(\d+)", child)
        if cid_match and num_match:
            cid, num = int(cid_match.group(1)), int(num_match.group(1))
            if cid > 0 and num > 0:
                result.append({"id": cid, "num": num})
    return result


def _map_costs(src: str | None) -> list[dict[str, int]]:
    if not src:
        return []
    result: list[dict[str, int]] = []
    for cid, num in re.findall(r"\[(\d+)\]\s*=\s*(\d+)\s*,?", src):
        cid_i, num_i = int(cid), int(num)
        if cid_i > 0 and num_i > 0:
            result.append({"id": cid_i, "num": num_i})
    return result


def _int_map(src: str | None) -> dict[int, int]:
    """Parse a flat Lua `{ [key] = value }` table, zero values included."""
    if not src:
        return {}
    result: dict[int, int] = {}
    root_start = src.find("{")
    if root_start < 0:
        return {}
    root_end = _match_brace(src, root_start)
    for key, value in re.findall(r"\[(\d+)\]\s*=\s*(-?\d+)\s*,?", src[root_start:root_end]):
        result[int(key)] = int(value)
    return result


def _map_options(src: str | None) -> list[list[dict[str, int]]]:
    """Parse lists like BreakCost where every row is an alternative item map."""
    if not src:
        return []
    result: list[list[dict[str, int]]] = []
    # Only inspect immediate children: nested map keys are item CIDs, not option indexes.
    root_start = src.find("{")
    root_end = _match_brace(src, root_start) if root_start >= 0 else len(src)
    cursor = root_start + 1
    while cursor < root_end:
        match = re.search(r"\[(\d+)\]\s*=\s*\{", src[cursor:root_end])
        if match is None:
            break
        absolute = cursor + match.start()
        brace = src.find("{", absolute)
        end = _match_brace(src, brace)
        option = _map_costs(src[brace:end])
        if option:
            result.append(option)
        cursor = end
    return result


def _reward_rows(src: str | None) -> list[dict[str, int]]:
    if not src:
        return []
    result: list[dict[str, int]] = []
    for match in re.finditer(r"\[(\d+)\]\s*=\s*\{", src):
        start = src.find("{", match.start())
        child = src[start:_match_brace(src, start)]
        cid = _int_field(child, "id")
        minimum = _int_field(child, "min", _int_field(child, "num"))
        maximum = _int_field(child, "max", minimum)
        weight = _int_field(child, "weight", 10000)
        if cid > 0 and maximum > 0:
            result.append({
                "id": cid,
                "min": max(0, minimum),
                "max": max(maximum, minimum),
                "weight": max(0, min(10000, weight)),
            })
    return result


def _top_level_block(src: str, key: int) -> str | None:
    """Like `_indexed_block`, but anchored to a *top level* row.

    The generated tables indent top-level keys with exactly four spaces. Big
    tables (DatingRule is 2.5MB) routinely carry the same `[id] = {` inside a
    nested list, and an unanchored search happily returns that instead.
    """
    match = re.search(rf"(?m)^    \[{int(key)}\]\s*=\s*\{{", src)
    if match is None:
        return None
    start = src.find("{", match.start())
    return src[match.start():_match_brace(src, start)]


def _top_level_blocks(src: str):
    # Generated secondary tables use exactly four spaces for top-level keys.
    for match in re.finditer(r"(?m)^    \[(\d+)\]\s*=\s*\{", src):
        start = src.find("{", match.start())
        yield int(match.group(1)), src[match.start():_match_brace(src, start)]


class GameStaticConfig:
    TABLE_PATH = "assets/src/lua/table/secondary/{name}.lua"
    # The build the offline stack runs is the English one.
    LANGUAGE = "en"

    def __init__(self, apk_path: str | None = None, tables: dict[str, str] | None = None) -> None:
        self.tables = dict(tables or {})
        env_path = os.environ.get("DAL_BASE_APK")
        candidates = [
            apk_path,
            env_path,
            os.path.join(ROOT, "work", "apk", "base-offline.apk"),
            os.path.join(ROOT, "work", "apk", "com.datealive.action.rpg.apk"),
        ]
        self.apk_path = next((p for p in candidates if p and os.path.isfile(p)), None)

    @lru_cache(maxsize=None)
    def table(self, name: str) -> str:
        if name in self.tables:
            return self.tables[name]
        if not self.apk_path:
            raise StaticConfigUnavailable(
                "base-offline.apk is required for static progression data; set DAL_BASE_APK"
            )
        # Tables that carry display text ship one copy per language instead of
        # a shared one, so a name that is missing at the top level is not a
        # missing table - it is a localised one.
        candidates = [self.TABLE_PATH.format(name=name),
                      self.TABLE_PATH.format(name=f"{self.LANGUAGE}/{name}")]
        last: Exception | None = None
        for asset in candidates:
            try:
                with zipfile.ZipFile(self.apk_path) as archive:
                    blob = archive.read(asset)
            except (OSError, KeyError, zipfile.BadZipFile) as exc:
                last = exc
                continue
            return decrypt_bytes(blob).decode("utf-8")
        raise StaticConfigUnavailable(f"cannot read table {name}: {last}") from last

    def block(self, table: str, key: int) -> str | None:
        return _indexed_block(self.table(table), key)

    def max_level(self) -> int:
        keys = [int(value) for value in re.findall(r"(?m)^\s*\[(\d+)\]\s*=\s*\{", self.table("LevelUp"))]
        return max(keys, default=1)

    def level_exp(self, level: int) -> int | None:
        block = self.block("LevelUp", level)
        if not block:
            return None
        value = _int_field(block, "heroExp", -1)
        return value if value >= 0 else None

    def player_level_exp(self, level: int) -> int | None:
        """Player EXP needed to leave `level`, per MainPlayer:getExpProgress."""
        block = self.block("LevelUp", level)
        if not block:
            return None
        value = _int_field(block, "playerExp", -1)
        return value if value > 0 else None

    def exp_item_value(self, cid: int) -> int | None:
        block = self.block("Item", cid)
        use_profit = _named_block(block or "", "useProfit")
        fixed = _named_block(use_profit or "", "fix")
        items = _named_block(fixed or "", "items")
        first = _indexed_block(items or "", 1)
        if not first or _int_field(first, "id") != 500006:
            return None
        value = _int_field(first, "num")
        return value if value > 0 else None

    def hero(self, cid: int) -> dict[str, Any] | None:
        block = self.block("Hero", cid)
        if not block:
            return None
        condition = _named_block(block, "condition")
        return {
            "attribute": _int_field(block, "attribute"),
            "baseQuality": _int_field(block, "quality", _int_field(block, "rarity", 1)),
            "rarity": _int_field(block, "rarity", 1),
            "heroLimitType": _int_field(block, "heroLimitType"),
            "expItems": _array_ints(_named_block(block, "expitem")),
            "defaultSkin": _int_field(block, "defaultSkin"),
            "optionalSkins": _array_ints(_named_block(block, "optionalSkin")),
            "paint": _int_field(block, "paint"),
            "changeType": _bool_field(block, "changeType"),
            "conditionHeroQuality": _int_field(condition or "", "heroQuality"),
            "angelLevelId": _int_field(block, "AngelLevelId"),
            "openAngelStrengthen": _int_field(block, "openAngelStrengthen"),
        }

    def progress_cost(self, progress_id: int) -> list[dict[str, int]] | None:
        block = self.block("HeroProgress", progress_id)
        if block is None:
            return None
        return _array_pairs(_named_block(block, "consume"))

    def advance_cost(self, hero_cid: int, advanced_level: int) -> list[dict[str, int]] | None:
        hero = self.hero(hero_cid)
        if not hero or hero["attribute"] <= 0:
            return None
        return self.progress_cost(int(hero["attribute"]) * 100 + int(advanced_level) + 1)

    def quality_cost(self, hero_cid: int, next_quality: int) -> list[dict[str, int]] | None:
        hero = self.hero(hero_cid)
        if not hero or hero["attribute"] <= 0:
            return None
        return self.progress_cost(int(hero["attribute"]) * 100 + int(next_quality))

    def allowed_skins(self, hero_cid: int) -> set[int]:
        hero = self.hero(hero_cid)
        if not hero:
            return set()
        result = {int(hero["defaultSkin"])} if int(hero["defaultSkin"]) > 0 else set()
        result.update(int(value) for value in hero["optionalSkins"] if int(value) > 0)
        if int(hero["paint"]) > 0:
            result.add(int(hero["paint"]))
        return result

    def skin_exists(self, skin_cid: int) -> bool:
        return self.block("HeroSkin", skin_cid) is not None

    def angel_awake_cost(self, hero_cid: int, angel_level: int) -> list[dict[str, int]] | None:
        hero_block = self.block("Hero", hero_cid)
        wake = _named_block(hero_block or "", "angelWakeCons")
        row = _indexed_block(wake or "", angel_level)
        return _map_costs(row) if row is not None else None

    @lru_cache(maxsize=1)
    def _angel_skill_index(self) -> dict[tuple[int, int, int, int], dict[str, Any]]:
        result: dict[tuple[int, int, int, int], dict[str, Any]] = {}
        for node_id, block in _top_level_blocks(self.table("AngelSkillTree")):
            hero_id = _int_field(block, "heroId")
            skill_type = _int_field(block, "skillType")
            pos = _int_field(block, "pos")
            lvl = _int_field(block, "lvl")
            if hero_id <= 0 or skill_type <= 0 or pos <= 0 or lvl <= 0:
                continue
            result[(hero_id, skill_type, pos, lvl)] = {
                "id": node_id,
                "heroId": hero_id,
                "skillType": skill_type,
                "pos": pos,
                "lvl": lvl,
                "skillIds": _array_ints(_named_block(block, "skillId")),
                "needSkillPoint": max(0, _int_field(block, "needSkillPiont")),
                "needHeroLvl": max(0, _int_field(block, "needHeroLvl")),
                "needAngelLvl": max(0, _int_field(block, "needAngelLvl")),
                "frontCondition": _array_ints(_named_block(block, "frontCondition")),
            }
        return result

    def angel_skill(self, hero_cid: int, skill_type: int, pos: int, lvl: int) -> dict[str, Any] | None:
        return self._angel_skill_index().get((int(hero_cid), int(skill_type), int(pos), int(lvl)))

    def angel_skill_by_id(self, node_id: int) -> dict[str, Any] | None:
        for node in self._angel_skill_index().values():
            if int(node["id"]) == int(node_id):
                return node
        return None

    def angel_skill_for_passive(self, hero_cid: int, skill_id: int) -> dict[str, Any] | None:
        for node in self._angel_skill_index().values():
            if int(node["heroId"]) == int(hero_cid) and int(node["skillType"]) == 10 and int(skill_id) in node["skillIds"]:
                return node
        return None

    def passive_slot(self, pos: int) -> dict[str, int] | None:
        block = self.block("AngelPassiveSkillGrooves", pos)
        if not block:
            return None
        return {
            "pos": int(pos),
            "needAngelLvl": max(0, _int_field(block, "AngelLvl")),
            "needHeroLvl": max(0, _int_field(block, "needHeroLvl")),
        }

    @lru_cache(maxsize=1)
    def _angel_strengthen_index(self) -> dict[tuple[int, int, int], dict[str, Any]]:
        result: dict[tuple[int, int, int], dict[str, Any]] = {}
        for row_id, block in _top_level_blocks(self.table("AngelStrengthen")):
            hero_id = _int_field(block, "heroId")
            skill_type = _int_field(block, "skillType")
            lvl = _int_field(block, "lvl")
            if hero_id <= 0 or skill_type <= 0 or lvl <= 0:
                continue
            result[(hero_id, skill_type, lvl)] = {
                "id": row_id,
                "cost1": _array_pairs(_named_block(block, "needCost")),
                "cost2": _array_pairs(_named_block(block, "needCost2")),
                "frontCondition": _array_ints(_named_block(block, "frontCondition")),
            }
        return result

    def angel_strengthen_cost(self, hero_cid: int, skill_type: int, lvl: int, cost_type: int) -> list[dict[str, int]] | None:
        row = self._angel_strengthen_index().get((int(hero_cid), int(skill_type), int(lvl)))
        if row is None:
            return None
        return list(row["cost2" if int(cost_type) == 2 else "cost1"])

    def angel_break_stage(self, hero_cid: int, break_level: int) -> dict[str, Any] | None:
        hero = self.hero(hero_cid)
        level_id = int((hero or {}).get("angelLevelId", 0))
        if level_id <= 0:
            return None
        block = self.block("AngelBreakthrough", level_id * 1000 + int(break_level))
        if not block:
            return None
        reward = _named_block(block, "BreakReward")
        return {
            "level": max(0, _int_field(block, "AngelLevel")),
            "costOptions": _map_options(_named_block(block, "BreakCost")),
            "reward": _map_costs(reward),
        }

    # HeroProgress is indexed twice over the same row space: the client reads
    # baseAttr at `attribute * 100 + advancedLvl` (strengthen) and upAttr at
    # `attribute * 100 + quality` (evolution) - see StrengthenResult.lua, which
    # renders `basic + growth * lv`. Rows run 1..#EC_HeroQuality (8), so an
    # unstrengthened hero (advancedLvl 0) falls back to the first row.
    MIN_PROGRESS_STAGE = 1
    MAX_PROGRESS_STAGE = 8

    def hero_progress(self, progress_id: int) -> dict[str, dict[int, int]] | None:
        block = self.block("HeroProgress", progress_id)
        if block is None:
            return None
        return {
            "baseAttr": _int_map(_named_block(block, "baseAttr")),
            "upAttr": _int_map(_named_block(block, "upAttr")),
        }

    def _progress_stage(self, stage: int) -> int:
        return max(self.MIN_PROGRESS_STAGE, min(self.MAX_PROGRESS_STAGE, int(stage)))

    def hero_attributes(self, hero_cid: int, level: int, *, quality: int = 0,
                        advanced_level: int = 0) -> list[dict[str, int]]:
        """The attr list a HeroInfo carries on the wire, in {type, val} rows."""
        hero = self.hero(hero_cid)
        attribute = int((hero or {}).get("attribute", 0))
        if attribute <= 0:
            return []
        if quality <= 0:
            quality = int((hero or {}).get("baseQuality", 1) or 1)
        base_row = self.hero_progress(attribute * 100 + self._progress_stage(advanced_level))
        growth_row = self.hero_progress(attribute * 100 + self._progress_stage(quality))
        if base_row is None:
            return []
        growth = growth_row["upAttr"] if growth_row else {}
        level = max(1, int(level))
        merged: dict[int, int] = dict(base_row["baseAttr"])
        for attr_type, step in growth.items():
            merged[attr_type] = merged.get(attr_type, 0) + step * level
        return [{"type": attr_type, "val": value} for attr_type, value in sorted(merged.items())]

    def dungeon_dating_ids(self, level_cid: int) -> list[int]:
        """DungeonLevel.datingID - the script a `dungeonType = DATING` stage plays."""
        block = self.block("DungeonLevel", level_cid)
        if not block:
            return []
        return _array_ints(_named_block(block, "datingID"))

    # EC_NewCityType -> the table trio a city-dating line is configured in.
    CITY_TABLES = {
        1: ("Outside", "OutsideStep", "OutsideScript"),
        2: ("Favor", "FavorStep", "FavorScript"),
        3: ("Novel", "NovelStep", "NovelScript"),
    }

    def city_tables(self, dating_type: int) -> tuple[str, str, str] | None:
        return self.CITY_TABLES.get(int(dating_type))

    @lru_cache(maxsize=None)
    def city_steps(self, dating_type: int, dating_value: int) -> tuple[dict[str, Any], ...]:
        """Every step of one city-dating line, in ascending step order."""
        tables = self.city_tables(dating_type)
        if tables is None:
            return ()
        _, step_table, _ = tables
        rows: list[dict[str, Any]] = []
        for step_id, block in _top_level_blocks(self.table(step_table)):
            if _int_field(block, "mainId") != int(dating_value):
                continue
            rows.append({
                "stepId": step_id,
                "basicCity": _int_field(block, "basicCity"),
                "events": _array_ints(_named_block(block, "event")),
                "stepTime": _time_of_day(_string_field(block, "stepTime")),
                "day": _int_field(block, "day"),
            })
        return tuple(sorted(rows, key=lambda row: row["stepId"]))

    def city_step(self, dating_type: int, dating_value: int, step_id: int) -> dict[str, Any] | None:
        for row in self.city_steps(dating_type, dating_value):
            if row["stepId"] == int(step_id):
                return row
        return None

    def city_event(self, dating_type: int, event_id: int) -> dict[str, Any] | None:
        tables = self.city_tables(dating_type)
        if tables is None:
            return None
        block = _top_level_block(self.table(tables[2]), event_id)
        if block is None:
            return None
        return {
            "id": int(event_id),
            "stepId": _int_field(block, "stepId"),
            "stepJump": _int_field(block, "stepJump"),
            "startId": _int_field(block, "startId"),
            "bindBuild": _int_field(block, "bindBuild"),
            "bindRole": _int_field(block, "bindRole"),
            "eventType": _int_field(block, "eventType"),
            "use": _bool_field(block, "use", True),
        }

    def dating_rule(self, rule_cid: int) -> dict[str, Any] | None:
        block = _top_level_block(self.table("DatingRule"), rule_cid)
        if block is None:
            return None
        return {
            "cid": int(rule_cid),
            "startNodeId": _int_field(block, "start_node_id"),
            "type": _int_field(block, "type"),
            "roleId": _int_field(block, "roleId"),
        }

    def dungeon_hero_limit(self, level_cid: int) -> dict[str, Any] | None:
        """The heroLimit* half of a DungeonLevel row (drives s2c 1808)."""
        block = self.block("DungeonLevel", level_cid)
        if not block:
            return None
        return {
            "cid": int(level_cid),
            "heroLimitType": _int_field(block, "heroLimitType"),
            "heroLimitIds": _array_ints(_named_block(block, "heroLimitID")),
            "heroForbiddenIds": _array_ints(_named_block(block, "heroForbiddenID")),
            "limitDungeon": _int_field(block, "limitDungeon"),
            "isDuelMod": _bool_field(block, "isDuelMod"),
        }

    def limit_hero(self, limit_id: int) -> dict[str, Any] | None:
        """One HeroLimitforDungeon row: the fixed spirit a story stage lends."""
        block = self.block("HeroLimitforDungeon", limit_id)
        if not block:
            return None
        return {
            "limitId": int(limit_id),
            "heroCid": _int_field(block, "heroID"),
            "level": max(1, _int_field(block, "level", 1)),
            "skinCid": _int_field(block, "skinID"),
            "rarity": _int_field(block, "rarity", 1),
            "breakthrough": max(0, _int_field(block, "breakthrough")),
            "powerValue": max(0, _int_field(block, "powerValue")),
            "angelUp": _array_ints(_named_block(block, "angelUp")),
            "sephiroth": _array_pairs(_named_block(block, "sephiroth")),
        }

    def dungeon_definition(self, level_cid: int) -> dict[str, Any] | None:
        block = self.block("DungeonLevel", level_cid)
        if not block:
            return None
        next_level = int(level_cid) + 1
        next_block = self.block("DungeonLevel", next_level)
        if next_block is None or int(level_cid) not in _array_ints(_named_block(next_block, "preLevelId")):
            next_level = 0
        return {
            "cid": int(level_cid),
            "dungeonType": _int_field(block, "dungeonType"),
            "datingIds": _array_ints(_named_block(block, "datingID")),
            "playerLvl": max(0, _int_field(block, "playerLv")),
            "fightCount": max(0, _int_field(block, "fightCount")),
            "isFree": _bool_field(block, "isFree"),
            "cost": _array_pairs(_named_block(block, "cost")),
            "rewardDrop": max(0, _int_field(block, "reward")),
            "firstRewardDrop": max(0, _int_field(block, "firstReward")),
            "rewardMultipleDrop": max(0, _int_field(block, "rewardMultiple")),
            "preLevels": _array_ints(_named_block(block, "preLevelId")),
            "nextLevelCid": next_level,
        }

    def dungeon_drop(self, drop_id: int) -> dict[str, list[dict[str, int]]] | None:
        if int(drop_id) <= 0:
            return {"fixed": [], "basic": []}
        block = self.block("Drop", drop_id)
        if block is None:
            return None
        use_profit = _named_block(block, "useProfit")
        fixed = _named_block(use_profit or "", "fix")
        basic = _named_block(use_profit or "", "basic")
        return {
            "fixed": _reward_rows(_named_block(fixed or "", "items")),
            "basic": _reward_rows(_named_block(basic or "", "items")),
        }

    @lru_cache(maxsize=1)
    def store_catalogue(self) -> tuple[dict[str, Any], ...]:
        """Every open store with its commodities, in s2c 2569 wire shape.

        `StoreDataMgr` builds `commodityMap_` only from this reply - nothing in
        the client falls back to the shipped Commodity table. So an empty store
        list is not just an empty shop: any screen that prices something by
        commodity id gets nil, and `SummonBuyResourceView:initData` indexes it
        without a guard the moment the summon panel's "+" button is tapped.
        """
        by_store: dict[int, list[dict[str, Any]]] = {}
        for row_id, block in _top_level_blocks(self.table("Commodity")):
            store_id = _int_field(block, "storeId")
            if store_id <= 0:
                continue
            by_store.setdefault(store_id, []).append({
                "id": row_id,
                "grid": _int_field(block, "grid"),
                "order": _int_field(block, "order"),
                "openContType": _int_field(block, "openContType"),
                "openContVal": _int_field(block, "openContVal"),
                "buyBeginTime": 0,
                "buyEndTime": 0,
                "sellTimeType": _int_field(block, "sellTimeType"),
                "limitType": _int_field(block, "limitType"),
                "batchBuy": _bool_field(block, "batchBuy"),
                "serLimit": _int_field(block, "serLimit"),
                "sellDescribtion": _text_id(block, "sellDescribtion"),
                "goodInfo": _map_costs(_named_block(block, "goods")),
                "priceType": _array_ints(_named_block(block, "priceType")),
                "priceVal": _array_ints(_named_block(block, "priceVal")),
                "des": _text_id(block, "des"),
                "title": _text_id(block, "title"),
                "tag": _text_id(block, "tag"),
                "autoRefreshCorn": bool(_string_field(block, "autoRefreshCorn")),
                "showBeginTime": 0,
                "showEndTime": 0,
                "limitVal": _int_field(block, "limitVal"),
                # `extra` is JSON the client feeds straight to json.decode
                # behind a bare `if commodityCfg.extra then`. An empty string is
                # truthy in Lua, so "" decodes to nil and the next index throws;
                # the field has to be absent, not blank.
                "extra": None,
            })

        stores: list[dict[str, Any]] = []
        for store_id, block in _top_level_blocks(self.table("Store")):
            if not _bool_field(block, "isOpen", True):
                continue
            commodities = sorted(by_store.get(store_id, []), key=lambda row: (row["order"], row["id"]))
            if not commodities:
                continue
            stores.append({
                "storeId": store_id,
                # `__handleStoreInfo` seeds `storeInfo_[storeCid]` from
                # `storeRefresh` and then writes `.pic` / `.groupRefreshTime`
                # onto it unguarded, so the refresh block has to be present or
                # the very next line indexes nil. `pic` stays absent for the
                # opposite reason: "" is truthy in Lua, so an empty one is a
                # write, not a skip.
                "storeRefresh": {
                    "todayRefreshCount": 0,
                    "totalRefreshCount": 0,
                    "nextRefreshTime": 0,
                    "freeNum": 0,
                },
                "pic": None,
                "groupRefreshTime": 0,
                "store": {
                    "icon": _string_field(block, "icon"),
                    "name": _text_id(block, "name"),
                    "roleSet": _int_field(block, "roleSet"),
                    "showCurrency": _array_ints(_named_block(block, "showCurrency")),
                    "autoRefreshCorn": bool(_string_field(block, "autoRefreshCorn")),
                    "manualRefresh": _bool_field(block, "manualRefresh"),
                    "refreshCostId": _int_field(block, "refreshCostId"),
                    "refreshCostNum": _array_ints(_named_block(block, "refreshCostNum")),
                    "openContVal": _int_field(block, "openContVal"),
                    "openContType": _int_field(block, "openContType"),
                    "commoditySupplyType": _int_field(block, "commoditySupplyType"),
                    "showBeginTime": 0,
                    "buyBeginTime": 0,
                    "buyEndTime": 0,
                    "showEndTime": 0,
                    "rank": _int_field(block, "rank"),
                    "storeType": _int_field(block, "storeType"),
                    "openTimeType": _int_field(block, "openTimeType"),
                    # Same trap as the commodity `extra` above:
                    # StoreDataMgr:sortWithCommodity json.decodes it unguarded.
                    "extra": None,
                },
                "commoditys": commodities,
            })
        return tuple(sorted(stores, key=lambda row: row["storeId"]))

    def equipment(self, cid: int) -> dict[str, Any] | None:
        """One Equipment row - enough to mint a wire-valid owned instance."""
        block = self.block("Equipment", cid)
        if block is None:
            return None
        return {
            "cid": int(cid),
            "star": max(0, _int_field(block, "star")),
            "maxLevel": max(1, _int_field(block, "maxLevel", 1)),
            "maxAdvanced": max(0, _int_field(block, "maxAdvanced")),
            "pileUp": _bool_field(block, "pileUp"),
            "gridMax": max(1, _int_field(block, "gridMax", 1)),
            "superType": _int_field(block, "superType"),
        }

    # GuideType.new_guide in GuideDataMgr.
    NEW_GUIDE_TYPE = 1

    @lru_cache(maxsize=1)
    def _new_guide_jumps(self) -> dict[int, int]:
        """`Guide[step].stepId` where it skips ahead of `step + 1`.

        `GuideDataMgr:saveStep` advances its own cursor to `cfg.stepId` when
        that row names one, so a server that only ever adds one falls behind at
        those rows and sends the player back through a step the guide meant to
        skip.
        """
        jumps: dict[int, int] = {}
        for step, block in _top_level_blocks(self.table("Guide")):
            if _int_field(block, "guideType") != self.NEW_GUIDE_TYPE:
                continue
            target = _int_field(block, "stepId")
            if target > step:
                jumps[step] = target
        return jumps

    def new_guide_next_step(self, step: int) -> int:
        """Where the client's cursor lands after finishing `step`."""
        step = int(step)
        return self._new_guide_jumps().get(step, step + 1)

    @lru_cache(maxsize=1)
    def new_guide_step_count(self) -> int:
        """`maxNewStep`: how many steps the new-player guide has.

        `GuideDataMgr` counts the `guideType = new_guide` rows itself and calls
        the guide over once its step passes that count, so the server has to
        agree on the number to know when to stop replaying it.
        """
        total = 0
        for _, block in _top_level_blocks(self.table("Guide")):
            if _int_field(block, "guideType") == self.NEW_GUIDE_TYPE:
                total += 1
        return total

    def summon(self, summon_cid: int) -> dict[str, Any] | None:
        """One Summon row: which pool it draws from and what a pull costs."""
        block = _top_level_block(self.table("Summon"), summon_cid)
        if block is None:
            return None
        costs = _map_options(_named_block(block, "cost"))
        first_costs = _map_options(_named_block(block, "firstCost"))
        return {
            "cid": int(summon_cid),
            "poolType": _int_field(block, "poolType"),
            "summonType": _int_field(block, "summonType"),
            "cardCount": max(1, _int_field(block, "cardCount", 1)),
            "costs": costs,
            "firstCosts": first_costs,
            "costCommodity": _int_field(block, "costCommodity"),
            "rareGetTimes": max(0, _int_field(block, "rareGetTimes")),
            "minQuality": _array_ints(_named_block(block, "minQuality")),
            "maxQuality": _array_ints(_named_block(block, "maxQuality")),
        }

    @lru_cache(maxsize=None)
    def summon_pool(self, pool_type: int) -> tuple[dict[str, Any], ...]:
        """Every SummonPool row a pool draws from, with its weights and payout."""
        rows: list[dict[str, Any]] = []
        for row_id, block in _top_level_blocks(self.table("SummonPool")):
            if _int_field(block, "poolType") != int(pool_type):
                continue
            items = _map_costs(_named_block(block, "itemMap"))
            if not items:
                continue
            rows.append({
                "id": row_id,
                "type": _int_field(block, "type"),
                "quality": _int_field(block, "quality"),
                "weights": _array_ints(_named_block(block, "weight")),
                "items": items,
            })
        return tuple(rows)

    def summon_hot_loop_ids(self) -> dict[int, int]:
        """Lowest valid loopId per loopType in SummonLoop.

        SummonDataMgr:getHotSummon indexes summonLoop_[loopType][loopId] and
        then walks the row's summonId list with no nil guard, so an order of 0 -
        which is what a zero-filled s2c 3343 carries - takes MainScene's summon
        panel down. Loop ids are 1-based in every shipped row; read them rather
        than assume it.
        """
        loops: dict[int, int] = {}
        for _, block in _top_level_blocks(self.table("SummonLoop")):
            loop_type = _int_field(block, "loopType", -1)
            loop_id = _int_field(block, "loopId", -1)
            if loop_type < 0 or loop_id <= 0:
                continue
            current = loops.get(loop_type)
            if current is None or loop_id < current:
                loops[loop_type] = loop_id
        return loops


_CONFIG: GameStaticConfig | None = None


def config() -> GameStaticConfig:
    global _CONFIG
    if _CONFIG is None:
        _CONFIG = GameStaticConfig()
    return _CONFIG
