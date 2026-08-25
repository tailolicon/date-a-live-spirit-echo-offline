#!/usr/bin/env python3
"""Analyze encrypted lua header: CRC, XOR vs LuaJIT, AES block size."""
from __future__ import annotations

import binascii
import struct
import zipfile
import zlib

APK = r"work\apk\com.datealive.action.rpg.apk"
LJ = b"\x1bLJ"


def main() -> None:
    z = zipfile.ZipFile(APK)
    files = [
        "assets/src/LuaScript/TFPathConfig.lua",
        "assets/src/TFFramework/Main.lua",
        "assets/src/debugScript.lua",
        "assets/src/LuaScript/TFGameStartup.lua",
        "assets/src/TFFramework/HeitaoSdk/HeitaoSdk.lua",
        "assets/src/lua/uiconfig/secondary/uiconfig_zn/ui_prj.lua",
    ]
    blobs = []
    for n in files:
        try:
            blobs.append((n, z.read(n)))
        except KeyError:
            print("missing", n)
    for n, b in blobs:
        print(f"\n{n} len={len(b)} mod16={len(b)%16} mod4={len(b)%4}")
        print(" head", b[:24].hex())
        print(" tail", b[-16:].hex())
        body = b[11:]
        crc = zlib.crc32(body[4:]) & 0xFFFFFFFF
        hdr4 = struct.unpack_from("<I", body, 0)[0]
        print(f"  u32@11={hdr4:08x} crc32(body[4:])={crc:08x} match={hdr4==crc}")
        crc2 = zlib.crc32(b[15:]) & 0xFFFFFFFF
        print(f"  crc32(from15)={crc2:08x}")
        # xor with LJ
        xor = bytes(x ^ y for x, y in zip(b[:4], LJ + b"\x02"))
        print("  xor first4 vs 1bLJ02", xor.hex())

    # common prefix length across first 50 lua
    luas = [i.filename for i in z.infolist() if i.filename.endswith(".lua")][:80]
    data = [z.read(n) for n in luas]
    plen = 0
    while all(len(d) > plen and d[plen] == data[0][plen] for d in data):
        plen += 1
    print("\ncommon prefix of 80 lua files:", plen, "bytes", data[0][:plen].hex())

    # pairwise first-difference
    diffs = []
    for d in data:
        i = 0
        while i < min(len(d), len(data[0])) and d[i] == data[0][i]:
            i += 1
        diffs.append(i)
    print("min first-diff", min(diffs), "max", max(diffs))

    # try: remaining after 11-byte header, pad to 4
    b = blobs[0][1]
    for skip in range(0, 20):
        rest = b[skip:]
        pad = (4 - len(rest) % 4) % 4
        print(f"skip {skip:2d} rest {len(rest):4d} pad4={pad} pad16={(16-len(rest)%16)%16}")


if __name__ == "__main__":
    main()
