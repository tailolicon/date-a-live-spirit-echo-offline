#!/usr/bin/env python3
"""Local persistent player save for Date A Live: Spirit Echo (research)."""
from __future__ import annotations

import json
import os
import time
from copy import deepcopy

ROOT = os.path.dirname(os.path.abspath(__file__))
SAVE_PATH = os.path.join(ROOT, "saves", "player.json")


def default_save() -> dict:
    now = int(time.time())
    return {
        "pid": 10001,
        "name": "Shido",
        "lvl": 1,
        "exp": 0,
        "vip_lvl": 0,
        "vip_exp": 0,
        "language": 1,
        "remark": "",
        "helpFightHeroCid": 0,
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
        "items": {},
        "heroes": [],
        "gold": 0,
        "diamonds": 0,
        "updated": now,
    }


def load_save() -> dict:
    if not os.path.isfile(SAVE_PATH):
        s = default_save()
        save(s)
        return s
    with open(SAVE_PATH, encoding="utf-8") as f:
        data = json.load(f)
    base = default_save()
    base.update(data)
    return base


def save(data: dict) -> None:
    os.makedirs(os.path.dirname(SAVE_PATH), exist_ok=True)
    data = deepcopy(data)
    data["updated"] = int(time.time())
    tmp = SAVE_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, SAVE_PATH)


def backup() -> str:
    src = load_save()
    stamp = time.strftime("%Y%m%d-%H%M%S")
    path = os.path.join(ROOT, "saves", f"player-{stamp}.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(src, f, ensure_ascii=False, indent=2)
    return path
