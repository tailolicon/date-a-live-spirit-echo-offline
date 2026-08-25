#!/usr/bin/env python3
"""Edit the local player save. Usage:
  python work/offline/edit_state.py --name Shido --lvl 10 --gold 999999 --diamonds 9999
"""
from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from player_save import backup, load_save, save  # noqa: E402


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--name")
    p.add_argument("--lvl", type=int)
    p.add_argument("--exp", type=int)
    p.add_argument("--vip", type=int)
    p.add_argument("--gold", type=int)
    p.add_argument("--diamonds", type=int)
    p.add_argument("--pid", type=int)
    args = p.parse_args()
    b = backup()
    print("backup", b)
    s = load_save()
    if args.name is not None:
        s["name"] = args.name
    if args.lvl is not None:
        s["lvl"] = args.lvl
    if args.exp is not None:
        s["exp"] = args.exp
    if args.vip is not None:
        s["vip_lvl"] = args.vip
    if args.gold is not None:
        s["gold"] = args.gold
    if args.diamonds is not None:
        s["diamonds"] = args.diamonds
    if args.pid is not None:
        s["pid"] = args.pid
    save(s)
    print("saved", {k: s[k] for k in ("pid", "name", "lvl", "exp", "vip_lvl", "gold", "diamonds")})
    return 0


if __name__ == "__main__":
    sys.exit(main())
