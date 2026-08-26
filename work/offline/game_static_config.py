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


def _top_level_blocks(src: str):
    # Generated secondary tables use exactly four spaces for top-level keys.
    for match in re.finditer(r"(?m)^    \[(\d+)\]\s*=\s*\{", src):
        start = src.find("{", match.start())
        yield int(match.group(1)), src[match.start():_match_brace(src, start)]


class GameStaticConfig:
    TABLE_PATH = "assets/src/lua/table/secondary/{name}.lua"

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
        asset = self.TABLE_PATH.format(name=name)
        try:
            with zipfile.ZipFile(self.apk_path) as archive:
                blob = archive.read(asset)
        except (OSError, KeyError, zipfile.BadZipFile) as exc:
            raise StaticConfigUnavailable(f"cannot read {asset}: {exc}") from exc
        return decrypt_bytes(blob).decode("utf-8")

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
