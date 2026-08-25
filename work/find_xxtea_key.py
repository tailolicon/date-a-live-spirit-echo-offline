#!/usr/bin/env python3
"""Try candidate 16-byte keys from libTerransForce.so against an encrypted lua file."""
from __future__ import annotations

import struct
import zipfile

SO = r"work\extract\lib\libTerransForce.so"
APK = r"work\apk\com.datealive.action.rpg.apk"
SIGN = bytes.fromhex("f88b2d1c03060c18030409")
DELTA = 0x9E3779B9
LUA_MAGICS = (b"\x1bLJ", b"\x1bLua", b"--", b"local", b"return", b"function")


def mx(z: int, y: int, sum_: int, k: list[int], p: int, e: int) -> int:
    return (((z >> 5) ^ (y << 2)) + ((y >> 3) ^ (z << 4))) ^ (
        (sum_ ^ y) + (k[(p & 3) ^ e] ^ z)
    ) & 0xFFFFFFFF


def xxtea_decrypt(data: bytes, key: bytes) -> bytes | None:
    if len(data) < 8 or len(data) % 4:
        return None
    k = list(struct.unpack("<4I", (key + b"\x00" * 16)[:16]))
    v = list(struct.unpack("<%dI" % (len(data) // 4), data))
    n = len(v) - 1
    y = v[0]
    q = 6 + 52 // (n + 1)
    sum_ = (q * DELTA) & 0xFFFFFFFF
    while sum_:
        e = (sum_ >> 2) & 3
        for p in range(n, 0, -1):
            z = v[p - 1]
            y = v[p] = (v[p] - mx(z, y, sum_, k, p, e)) & 0xFFFFFFFF
        z = v[n]
        y = v[0] = (v[0] - mx(z, y, sum_, k, 0, e)) & 0xFFFFFFFF
        sum_ = (sum_ - DELTA) & 0xFFFFFFFF
    # last uint32 is original length (xxtea-c convention)
    out = b"".join(struct.pack("<I", x) for x in v)
    orig_len = v[-1]
    if 0 < orig_len <= len(out) - 4:
        return out[:orig_len]
    return out


def looks_lua(b: bytes) -> bool:
    if not b:
        return False
    return any(b.startswith(m) or b[1:].startswith(m) for m in LUA_MAGICS) or b[:3] == b"\x1bLJ"


def candidates(so: bytes) -> list[bytes]:
    out: list[bytes] = []
    seen: set[bytes] = set()

    def add(k: bytes) -> None:
        if k and k not in seen and len(k) >= 6:
            seen.add(k)
            out.append(k)

    buf = bytearray()
    for b in so:
        if 32 <= b < 127:
            buf.append(b)
        else:
            if 6 <= len(buf) <= 32:
                add(bytes(buf))
                add(bytes(buf)[:16])
            buf.clear()
    # well-known defaults
    for k in (
        b"2dxLua",
        b"XXTEA",
        b"phanta",
        b"Phanta",
        b"TerransForce",
        b"datealive",
        b"DateALive",
        b"heitao",
        b"Heitao2015",
        b"yizhan2018",
        b"yzjlzl",
        b"dal2018",
        b"echo2025",
        b"spirit echo",
        b"1234567890abcdef",
    ):
        add(k)
    return out


def main() -> None:
    z = zipfile.ZipFile(APK)
    blob = z.read("assets/src/LuaScript/TFPathConfig.lua")
    assert blob.startswith(SIGN), blob[:16].hex()
    ct = blob[len(SIGN) :]
    print("ciphertext", len(ct), "mod4", len(ct) % 4)
    so = open(SO, "rb").read()
    cands = candidates(so)
    print("candidates", len(cands))
    hits = 0
    for k in cands:
        try:
            pt = xxtea_decrypt(ct, k)
        except Exception:
            continue
        if pt and looks_lua(pt):
            print("HIT key=", k, "pt[:32]=", pt[:32])
            hits += 1
        elif pt and pt[:4] == b"\x1bLJ":
            print("HIT LJ key=", k)
            hits += 1
    print("hits", hits)
    # also try: skip 4 extra header bytes (maybe crc)
    for skip in (0, 4, 8, 15, 16):
        c2 = blob[len(SIGN) + skip :]
        if len(c2) % 4:
            c2 = c2[: len(c2) - (len(c2) % 4)]
        if len(c2) < 8:
            continue
        for k in (b"2dxLua", b"phanta", b"PhantaSDK", b"TerransForce"):
            pt = xxtea_decrypt(c2, k)
            if pt:
                print(f"skip={skip} key={k!r} pt[:16]={pt[:16]!r}")


if __name__ == "__main__":
    main()
