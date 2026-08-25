#!/usr/bin/env python3
"""Decrypt Date A Live Spirit Pledge/Echo text assets (lua/json).

Algorithm from n0k0m3/DALSP-Assets-Decryption-tool (dalsp_decrypt.decryptZIP).
Personal research use only.
"""
from __future__ import annotations

import os
import zipfile
import zlib

SIGN2 = bytes([0xF8, 0x8B])


def decrypt_zip(data: bytes) -> bytes:
    if len(data) < 5 or data[:2] != SIGN2 or data[2] not in (0x2D, 0x3D):
        return data
    buf = bytearray(data)
    buf[1] = 0x1F
    buf[2] = 0x8B
    data_size = len(buf)
    var_1 = 0x14 if (data_size - 3) >= 0x15 else (data_size - 3)
    buf = buf[1:]  # gzip magic now at 0
    if var_1 > 0:
        i = 2
        n = var_1 + 2
        acc = var_1
        out = bytearray(buf)
        out[i] = buf[i] ^ (acc & 0xFF)
        running = 0
        for idx in range(i, n - 1):
            running = (running + buf[idx]) & 0xFFFFFFFF
            key = (running + 0x14) % 0x2D
            out[idx + 1] = buf[idx + 1] ^ (key & 0xFF)
        buf = out
    return zlib.decompress(bytes(buf), zlib.MAX_WBITS | 32)


def decrypt_bytes(data: bytes) -> bytes:
    if data[:2] != SIGN2:
        return data
    # 0x2b = LZ4 wrapper; Spirit Echo lua/json we have seen is 0x2d (zip only)
    if data[2] == 0x2B:
        raise NotImplementedError("LZ4-wrapped asset; install lz4 if needed")
    if data[2] in (0x2D, 0x3D):
        return decrypt_zip(data)
    return data


PRIORITY = [
    "assets/src/LuaScript/TFPathConfig.lua",
    "assets/src/TFFramework/Main.lua",
    "assets/src/TFFramework/net/TFClientNet.lua",
    "assets/src/TFFramework/net/TFClientNetOp.lua",
    "assets/src/TFFramework/net/TFClientNetVar.lua",
    "assets/src/TFFramework/net/TFClientNetVarOp.lua",
    "assets/src/TFFramework/net/NetHelper.lua",
    "assets/src/TFFramework/client/director/TFDirector_Net.lua",
    "assets/src/TFFramework/client/manager/TFProtocolManager.lua",
    "assets/src/lua/dataMgr/ServerDataMgr.lua",
    "assets/src/lua/logic/login/LoginLayer.lua",
    "assets/src/lua/logic/login/LoginScene.lua",
    "assets/src/lua/logic/login/ServerChoose.lua",
    "assets/src/lua/logic/login/CheckServerLayer.lua",
    "assets/src/lua/manager/SdkManager.lua",
    "assets/src/lua/public/GlobalVarConfig.lua",
    "assets/src/lua/logic/common/GameConfig.lua",
    "assets/src/lua/table/secondary/DlsServerData.lua",
]


def main() -> None:
    out_root = r"work\dump\decrypted"
    os.makedirs(out_root, exist_ok=True)
    z = zipfile.ZipFile(r"work\apk\com.datealive.action.rpg.apk")
    # test pathconfig
    raw = z.read("assets/src/LuaScript/TFPathConfig.lua")
    pt = decrypt_bytes(raw)
    print("TFPathConfig decrypted", len(pt), pt[:80])
    dest = os.path.join(out_root, "assets", "src", "LuaScript", "TFPathConfig.lua")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    open(dest, "wb").write(pt)

    ok = 0
    fail = 0
    for name in PRIORITY:
        try:
            data = z.read(name)
        except KeyError:
            print("MISSING", name)
            fail += 1
            continue
        try:
            pt = decrypt_bytes(data)
        except Exception as e:
            print("FAIL", name, e)
            fail += 1
            continue
        rel = name.replace("/", os.sep)
        dest = os.path.join(out_root, rel)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        open(dest, "wb").write(pt)
        head = pt[:60].replace(b"\n", b" ")
        print(f"OK {len(pt):7d}  {name}  {head!r}")
        ok += 1
    print(f"done ok={ok} fail={fail}")


if __name__ == "__main__":
    main()
