#!/usr/bin/env python3
"""Read the small slice of 1.37 static data needed by the offline server.

The original game keeps its Lua tables in the APK behind the same F8/8B/2D
wrapper used by the hotpatch tooling.  Keeping progression rules sourced from
those tables prevents the local server from inventing EXP/cost values.
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
    match = re.search(rf"(?m)^\s*\[{int(key)}\]\s*=\s*\{{", src)
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


_CONFIG: GameStaticConfig | None = None


def config() -> GameStaticConfig:
    global _CONFIG
    if _CONFIG is None:
        _CONFIG = GameStaticConfig()
    return _CONFIG
