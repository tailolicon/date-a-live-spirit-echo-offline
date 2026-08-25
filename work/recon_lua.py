#!/usr/bin/env python3
"""Extract config + network-related Lua from the base APK."""
from __future__ import annotations

import os
import re
import zipfile

APK = r"work\apk\com.datealive.action.rpg.apk"
OUT = r"work\extract"

URL_RE = re.compile(
    rb"(https?://[^\s\"'<>\\]{4,200}|wss?://[^\s\"'<>\\]{4,200})",
    re.I,
)
HOSTISH = re.compile(
    rb"(?:api|login|server|host|url|endpoint|gate|socket|ws)[^\n]{0,80}",
    re.I,
)
NET_NAME = re.compile(
    r"(http|https|socket|websocket|wss|login|session|proto|net|server|host|url|gate|sdk|heitao|auth|token|sign|hmac|encrypt)",
    re.I,
)

os.makedirs(OUT, exist_ok=True)


def main() -> None:
    z = zipfile.ZipFile(APK)
    urls: dict[str, list[str]] = {}
    net_files: list[tuple[str, int]] = []

    # dump small top-level assets
    for name in (
        "assets/config.json",
        "assets/obb_config.json",
        "assets/packageList.xml",
        "assets/filedownloader.properties",
        "assets/src/packageList.xml",
        "assets/src/debugScript.lua",
        "assets/src/LuaScript/TFGameStartup.lua",
        "assets/src/LuaScript/TFPathConfig.lua",
        "assets/src/LuaScript/TFAssetsManager.lua",
        "assets/src/LuaScript/AssetsMgr.lua",
        "assets/src/TFFramework/HeitaoSdk/HeitaoSdk.lua",
        "assets/src/TFFramework/HeitaoSdk/android/HeitaoSdkAndroid.lua",
        "assets/src/TFFramework/Main.lua",
    ):
        try:
            data = z.read(name)
        except KeyError:
            print("MISSING", name)
            continue
        dest = os.path.join(OUT, name.replace("/", os.sep))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(data)
        print(f"dumped {name} ({len(data)} bytes)")

    print("\n===== scanning lua/json/xml/properties for URLs =====")
    for info in z.infolist():
        n = info.filename
        low = n.lower()
        if not n.startswith("assets/"):
            continue
        if not any(low.endswith(ext) for ext in (".lua", ".json", ".xml", ".txt", ".properties", ".proto")):
            continue
        if info.file_size > 2_000_000:
            continue
        data = z.read(n)
        found = [m.group(0).decode("utf-8", "replace") for m in URL_RE.finditer(data)]
        if found:
            urls[n] = found
        if NET_NAME.search(n) or (low.endswith(".lua") and HOSTISH.search(data)):
            net_files.append((n, info.file_size))

    print("\n----- URLs -----")
    for n, us in sorted(urls.items()):
        uniq = sorted(set(us))
        print(f"\n{n}")
        for u in uniq[:30]:
            print(f"  {u}")
        if len(uniq) > 30:
            print(f"  ... +{len(uniq)-30} more")

    print("\n----- net-named files -----")
    for n, s in sorted(net_files):
        print(f"  {s:8d}  {n}")

    # dump net-named lua (cap)
    dumped = 0
    for n, s in sorted(net_files):
        if not n.endswith(".lua"):
            continue
        if s > 500_000:
            continue
        dest = os.path.join(OUT, n.replace("/", os.sep))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(z.read(n))
        dumped += 1
    print(f"\ndumped {dumped} net lua files to {OUT}")


if __name__ == "__main__":
    main()
