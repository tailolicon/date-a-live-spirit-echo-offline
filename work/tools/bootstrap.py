#!/usr/bin/env python3
"""Regenerate the decrypted lua reference tree from the game APK.

The APK and the full decrypted dump are far too large for git (the APK is
~180MB, the complete lua tree is ~2GB, most of it `lua/table` and
`lua/uiconfig` data blobs). What the tooling and any future work actually need
is a curated slice: the protocol descriptors, the DataMgrs, the login/UI logic
and the TFFramework net layer. That slice is ~22MB and lives in `reference/lua`,
which *is* committed.

Run this after dropping the APK at work/apk/com.datealive.action.rpg.apk to
rebuild `reference/lua` from scratch, or with --full to also produce the
complete dump under work/dump/all_lua (git-ignored).

    python work/tools/bootstrap.py
    python work/tools/bootstrap.py --full
"""
from __future__ import annotations

import os
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua_crypt import decrypt_bytes  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
APK = os.environ.get("DAL_APK", os.path.join(REPO, "work", "apk",
                                             "com.datealive.action.rpg.apk"))
REFERENCE = os.path.join(REPO, "reference", "lua")
FULL_DUMP = os.path.join(REPO, "work", "dump", "all_lua")

# Everything a reader needs to follow the protocol and the login flow.
# Deliberately excludes lua/table, lua/uiconfig and lua/ai: pure data, ~2GB.
KEEP_PREFIXES = (
    "assets/src/lua/net/",
    "assets/src/lua/dataMgr/",
    "assets/src/lua/gamedata/",
    "assets/src/lua/manager/",
    "assets/src/lua/public/",
    "assets/src/lua/logic/",
    "assets/src/TFFramework/",
    "assets/src/LuaScript/",
)
KEEP_FILES = (
    "assets/src/lua/UtilHelper.lua",
)
PREFIX = "assets/src/"


def wanted(name: str) -> bool:
    if not name.endswith(".lua"):
        return False
    return name in KEEP_FILES or name.startswith(KEEP_PREFIXES)


def extract(dest_root: str, keep_all: bool) -> tuple[int, int]:
    if not os.path.isfile(APK):
        raise SystemExit(
            f"APK not found at {APK}\n"
            "Put com.datealive.action.rpg.apk there (or set DAL_APK) and rerun.")
    ok = fail = 0
    with zipfile.ZipFile(APK) as z:
        for info in z.infolist():
            name = info.filename
            if not name.endswith(".lua"):
                continue
            if not keep_all and not wanted(name):
                continue
            rel = name[len(PREFIX):] if name.startswith(PREFIX) else name
            dest = os.path.join(dest_root, rel.replace("/", os.sep))
            try:
                plain = decrypt_bytes(z.read(name))
            except Exception as e:
                print(f"FAIL {name}: {e!r}")
                fail += 1
                continue
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "wb") as f:
                f.write(plain)
            ok += 1
    return ok, fail


def main() -> int:
    full = "--full" in sys.argv[1:]
    ok, fail = extract(REFERENCE, keep_all=False)
    print(f"reference/lua: {ok} files decrypted, {fail} failed")
    if full:
        ok, fail = extract(FULL_DUMP, keep_all=True)
        print(f"work/dump/all_lua: {ok} files decrypted, {fail} failed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
