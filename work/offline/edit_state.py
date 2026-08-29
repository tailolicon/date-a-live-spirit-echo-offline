#!/usr/bin/env python3
"""Edit the local player save. Usage:
  python work/offline/edit_state.py --name Shido --lvl 10 --gold 999999 --diamonds 9999
  python work/offline/edit_state.py --item 570033=1000 --item 500006=500000
  python work/offline/edit_state.py --list-currencies

`--item` takes any item CID, so it reaches the currencies with no flag of their
own - summon tickets, spirit EXP, event coins. The game only ever shows a
balance the server pushed, so restart PLAY.bat (or relog) after editing.
"""
from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from player_save import STARTER_RESOURCES, TEST_CURRENCIES, backup, load_save, resource_item, save  # noqa: E402

# Names for the ids worth editing by hand, so --list-currencies is readable.
CURRENCY_NAMES = {
    500001: "gold", 500002: "diamond", 500003: "friendship", 500004: "stamina",
    500005: "player exp", 500006: "spirit exp", 500014: "activity",
    500016: "favor", 500017: "arcade coin", 500018: "tiangong coin",
    500024: "energy", 500025: "airship fuel", 500030: "theater tries",
    500096: "token money", 570101: "life essence",
    566058: "summon ticket (first-pull)", 570033: "summon ticket (banner 1)",
    570035: "summon ticket (banner 2)", 570150: "summon ticket (limited)",
}


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--name")
    p.add_argument("--lvl", type=int)
    p.add_argument("--exp", type=int)
    p.add_argument("--vip", type=int)
    p.add_argument("--gold", type=int)
    p.add_argument("--diamonds", type=int)
    p.add_argument("--pid", type=int)
    p.add_argument("--item", action="append", metavar="CID=NUM",
                   help="set an item/currency balance; repeatable")
    p.add_argument("--list-currencies", action="store_true",
                   help="print the ids --item accepts, with current balances")
    args = p.parse_args()

    if args.list_currencies:
        state = load_save()
        held = {int(row.get("cid", 0) or 0): int(row.get("num", 0) or 0)
                for row in state.get("items", {}).values() if isinstance(row, dict)}
        for cid in sorted({*CURRENCY_NAMES, *STARTER_RESOURCES, *TEST_CURRENCIES, *held}):
            print(f"  {cid:<8} {held.get(cid, 0):>10}  {CURRENCY_NAMES.get(cid, '')}")
        return 0
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
    for pair in args.item or []:
        cid_text, _, num_text = pair.partition("=")
        try:
            cid, num = int(cid_text), int(num_text)
        except ValueError:
            print(f"  ! skipping {pair!r}: expected CID=NUM")
            continue
        if cid <= 0 or num < 0:
            print(f"  ! skipping {pair!r}: cid must be positive and num non-negative")
            continue
        items = s.setdefault("items", {})
        existing = next((row for row in items.values()
                         if isinstance(row, dict) and int(row.get("cid", 0) or 0) == cid), None)
        if existing is None:
            items[str(cid)] = resource_item(cid, num)
        else:
            existing["num"] = num
        print(f"  set {cid} = {num}  {CURRENCY_NAMES.get(cid, '')}")
    save(s)
    print("saved", {k: s[k] for k in ("pid", "name", "lvl", "exp", "vip_lvl", "gold", "diamonds")})
    return 0


if __name__ == "__main__":
    sys.exit(main())
