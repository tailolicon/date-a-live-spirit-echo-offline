#!/usr/bin/env python3
"""Phase 0 recon: inspect APKs for networking, engine, hosts, anti-tamper."""
from __future__ import annotations

import collections
import os
import zipfile

BASE = r"work\apk\com.datealive.action.rpg.apk"
CFG = r"work\apk\config.armeabi_v7a.apk"


def list_apk(path: str) -> None:
    z = zipfile.ZipFile(path)
    print(f"\n===== {path} =====")
    print(f"entries: {len(z.infolist())}")
    ext = collections.Counter()
    dirs = collections.Counter()
    for i in z.infolist():
        n = i.filename
        ext[os.path.splitext(n)[1].lower() or "(none)"] += 1
        dirs[n.split("/")[0]] += 1
    print("exts:")
    for k, v in ext.most_common(40):
        print(f"  {k:20s} {v}")
    print("top dirs:")
    for k, v in dirs.most_common():
        print(f"  {k:20s} {v}")
    print("libs / interesting:")
    keys = (
        "pairip",
        "okhttp",
        "unity",
        "il2cpp",
        "firebase",
        "protobuf",
        "grpc",
        "websocket",
        "socket",
        "crash",
        "sentry",
        "bugly",
        " cocos",
        "libcocos",
        "libunity",
        "libgame",
        "libmain",
        "libmono",
        "libil2cpp",
        "global-metadata",
        "libUE4",
        "libunreal",
        "libgodot",
        "libxlua",
        "lua",
        "libfmod",
        "libTerrans",
        "signing",
        "integrity",
        "play-services",
        "gms",
    )
    for i in z.infolist():
        n = i.filename
        low = n.lower()
        if n.startswith("lib/") or any(k.lower() in low for k in keys):
            print(f"  {n:90s} {i.file_size:12d}")
    print("assets top (depth<=2):")
    for i in z.infolist():
        n = i.filename
        if n.startswith("assets/") and n.count("/") <= 2 and i.file_size:
            print(f"  {n:90s} {i.file_size:12d}")


def main() -> None:
    list_apk(BASE)
    list_apk(CFG)


if __name__ == "__main__":
    main()
