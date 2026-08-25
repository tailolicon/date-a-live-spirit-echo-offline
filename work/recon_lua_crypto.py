#!/usr/bin/env python3
"""Hunt lua decrypt / xxtea / loadbuffer in native lib + bytecode samples."""
from __future__ import annotations

import os
import re
import struct
import zipfile

SO = r"work\extract\lib\libTerransForce.so"
APK = r"work\apk\com.datealive.action.rpg.apk"
OUT = r"work\extract\lua_crypto_strings.txt"

NEEDLES = [
    "xxtea",
    "XXTEA",
    "luaL_load",
    "lua_load",
    "loadbuffer",
    "LoadBuffer",
    "decrypt",
    "Decrypt",
    "uncompress",
    "inflate",
    "luajit",
    "LuaJIT",
    "\x1bLJ",
    "TFLua",
    "luaopen",
    "chunk",
    "bytecode",
    "xxtea_decrypt",
    "AES",
    "TEA",
    "encode",
    "decodeLua",
    "decode_lua",
    "LuaLoader",
    "tf_decrypt",
    "xor",
    "crypt",
    "Heitao",
    "phanta",
    "HttpClient",
    "serverUrl",
    "SERVER",
    "api.",
    ".com",
]


def strings_from(data: bytes, minlen: int = 4) -> list[str]:
    out: list[str] = []
    buf = bytearray()
    for b in data:
        if 32 <= b < 127:
            buf.append(b)
        else:
            if len(buf) >= minlen:
                out.append(buf.decode("ascii"))
            buf.clear()
    if len(buf) >= minlen:
        out.append(buf.decode("ascii"))
    return out


def main() -> None:
    so = open(SO, "rb").read()
    ss = strings_from(so, 4)
    hits = []
    for s in ss:
        low = s.lower()
        if any(n.lower() in low for n in NEEDLES) or "lua" in low:
            hits.append(s)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(hits))
    print(f"so lua/crypto strings: {len(hits)}")
    for s in hits[:250]:
        print(s)
    if len(hits) > 250:
        print(f"... +{len(hits)-250}")

    # entropy of lua header vs rest
    z = zipfile.ZipFile(APK)
    sample = z.read("assets/src/LuaScript/TFPathConfig.lua")
    print("\nTFPathConfig full hex:")
    print(sample.hex())
    print("bytes", list(sample[:32]))

    sample2 = z.read("assets/src/TFFramework/Main.lua")
    print("\nMain.lua first 64 hex:")
    print(sample2[:64].hex())

    # compare headers of several files
    names = [i.filename for i in z.infolist() if i.filename.endswith(".lua")][:20]
    print("\nfirst 16 bytes of 20 lua files:")
    for n in names:
        b = z.read(n)[:16]
        print(b.hex(), n.split("/")[-1], "sz", z.getinfo(n).file_size)

    # check if remaining looks like luajit after skipping header
    for skip in range(0, 24):
        chunk = sample[skip:skip+4]
        if chunk == b"\x1bLJ\x01" or chunk == b"\x1bLJ\x02" or chunk.startswith(b"\x1bLJ"):
            print("LJ magic at", skip)
        if chunk == b"\x1bLua":
            print("Lua magic at", skip)

    # zlib/gzip try
    import zlib
    for skip in range(0, 32):
        for wbits in (15, -15, 31, 47):
            try:
                d = zlib.decompress(sample[skip:], wbits)
                print(f"zlib ok skip={skip} wbits={wbits} -> {d[:20]!r} len={len(d)}")
            except Exception:
                pass


if __name__ == "__main__":
    main()
