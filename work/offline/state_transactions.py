#!/usr/bin/env python3
"""Atomic inventory/reward operations for the offline preservation server."""
from __future__ import annotations

from copy import deepcopy
from typing import Any, Iterable

from player_save import DIAMOND_CID, GOLD_CID, resource_item

RESOURCE_MIRRORS = {GOLD_CID: "gold", DIAMOND_CID: "diamonds"}


def _items(state: dict[str, Any]) -> dict[str, dict[str, Any]]:
    raw = state.setdefault("items", {})
    if not isinstance(raw, dict):
        converted: dict[str, dict[str, Any]] = {}
        if isinstance(raw, list):
            for row in raw:
                if isinstance(row, dict) and row.get("id") is not None:
                    converted[str(row["id"])] = row
        state["items"] = converted
        return converted
    return raw


def sync_resource_mirrors(state: dict[str, Any]) -> None:
    totals = {cid: 0 for cid in RESOURCE_MIRRORS}
    for row in _items(state).values():
        if not isinstance(row, dict):
            continue
        cid = int(row.get("cid", 0) or 0)
        if cid in totals:
            totals[cid] += max(0, int(row.get("num", 0) or 0))
    for cid, key in RESOURCE_MIRRORS.items():
        state[key] = totals[cid]


def find_item(state: dict[str, Any], item_id: str) -> dict[str, Any] | None:
    return _items(state).get(str(item_id))


def find_item_by_cid(state: dict[str, Any], cid: int) -> dict[str, Any] | None:
    target = int(cid)
    for row in _items(state).values():
        if isinstance(row, dict) and int(row.get("cid", 0) or 0) == target:
            return row
    return None


def item_count(state: dict[str, Any], *, item_id: str | None = None, cid: int | None = None) -> int:
    if item_id is not None:
        row = find_item(state, item_id)
        return max(0, int(row.get("num", 0) or 0)) if row else 0
    if cid is None:
        return 0
    return sum(
        max(0, int(row.get("num", 0) or 0))
        for row in _items(state).values()
        if isinstance(row, dict) and int(row.get("cid", 0) or 0) == int(cid)
    )


def add_item(state: dict[str, Any], cid: int, num: int, *, item_id: str | None = None) -> dict[str, Any]:
    cid = int(cid)
    num = int(num)
    if cid <= 0 or num <= 0:
        raise ValueError("reward id and quantity must be positive")
    items = _items(state)
    row = items.get(str(item_id)) if item_id is not None else find_item_by_cid(state, cid)
    if row is None:
        key = str(item_id) if item_id is not None else str(cid)
        if key in items:
            suffix = 2
            base = key
            while f"{base}:{suffix}" in items:
                suffix += 1
            key = f"{base}:{suffix}"
        row = resource_item(cid, 0)
        row["id"] = key
        items[key] = row
    row["num"] = max(0, int(row.get("num", 0) or 0)) + num
    row["cid"] = cid
    row.setdefault("ct", 0)
    row.setdefault("outTime", 0)
    sync_resource_mirrors(state)
    return row


def _normalize_requirements(requirements: Iterable[dict[str, Any]]) -> list[tuple[str, int]]:
    merged: dict[str, int] = {}
    for req in requirements:
        if not isinstance(req, dict):
            continue
        item_id = str(req.get("itemId", req.get("id", "")) or "")
        num = int(req.get("num", 0) or 0)
        if item_id and num > 0:
            merged[item_id] = merged.get(item_id, 0) + num
    return list(merged.items())


def consume_items(state: dict[str, Any], requirements: Iterable[dict[str, Any]]) -> bool:
    """Consume instance IDs atomically. Invalid/insufficient requests do nothing."""
    reqs = _normalize_requirements(requirements)
    if not reqs:
        return False
    items = _items(state)
    for item_id, num in reqs:
        row = items.get(item_id)
        if not isinstance(row, dict) or int(row.get("num", 0) or 0) < num:
            return False
    for item_id, num in reqs:
        row = items[item_id]
        row["num"] = int(row.get("num", 0) or 0) - num
    sync_resource_mirrors(state)
    return True


def consume_cids(state: dict[str, Any], costs: Iterable[dict[str, Any]]) -> bool:
    """Consume fungible item CIDs atomically, spanning stacks if necessary."""
    merged: dict[int, int] = {}
    for cost in costs:
        if not isinstance(cost, dict):
            continue
        cid = int(cost.get("id", cost.get("cid", 0)) or 0)
        num = int(cost.get("num", 0) or 0)
        if cid > 0 and num > 0:
            merged[cid] = merged.get(cid, 0) + num
    if not merged:
        return True
    for cid, num in merged.items():
        if item_count(state, cid=cid) < num:
            return False
    items = _items(state)
    for cid, remaining in merged.items():
        for row in items.values():
            if remaining <= 0:
                break
            if not isinstance(row, dict) or int(row.get("cid", 0) or 0) != cid:
                continue
            have = max(0, int(row.get("num", 0) or 0))
            take = min(have, remaining)
            row["num"] = have - take
            remaining -= take
    sync_resource_mirrors(state)
    return True


def normalize_rewards(rewards: Iterable[dict[str, Any]], multiplier: int = 1) -> list[dict[str, int]]:
    multiplier = max(1, int(multiplier))
    merged: dict[int, int] = {}
    for reward in rewards or []:
        if not isinstance(reward, dict):
            continue
        cid = int(reward.get("id", reward.get("cid", 0)) or 0)
        num = int(reward.get("num", 0) or 0) * multiplier
        if cid > 0 and num > 0:
            merged[cid] = merged.get(cid, 0) + num
    return [{"id": cid, "num": num} for cid, num in sorted(merged.items())]


def grant_rewards(state: dict[str, Any], rewards: Iterable[dict[str, Any]], multiplier: int = 1) -> list[dict[str, int]]:
    normalized = normalize_rewards(rewards, multiplier)
    for reward in normalized:
        add_item(state, reward["id"], reward["num"])
    return deepcopy(normalized)
