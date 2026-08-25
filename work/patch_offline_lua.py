#!/usr/bin/env python3
"""Patch login URLs + skip hot-update, re-encrypt, rebuild+sign base APK."""
from __future__ import annotations

import os
import shutil
import subprocess
import zipfile
import zlib

from dal_decrypt import decrypt_bytes

APK_IN = r"work\apk\com.datealive.action.rpg.apk"
APK_OUT = r"work\apk\com.datealive.action.rpg.offline.apk"
UTIL = "assets/src/lua/UtilHelper.lua"
UPDATE = "assets/src/lua/logic/login/UpdateLayer_new.lua"
SERVER = "assets/src/lua/dataMgr/ServerDataMgr.lua"


def encrypt_zip(plain: bytes) -> bytes:
    gzip_compress = zlib.compressobj(9, zlib.DEFLATED, zlib.MAX_WBITS | 16)
    data = gzip_compress.compress(plain) + gzip_compress.flush()
    data = bytearray([0xF8]) + data
    data[10] = 0x03
    data_size = len(data)
    var_1 = 0x14 if (data_size - 3) >= 0x15 else (data_size - 3)
    if var_1 > 0:
        i = 2
        n = var_1 + 2
        while i < n:
            var_2 = var_1 % 0x2D
            data[i + 1] = var_2 ^ data[i + 1]
            var_1 = data[i + 1] + var_2
            i += 1
    data[1] = 0x8B
    data[2] = 0x2D
    return bytes(data)


def patch_util(src: str) -> str:
    src = src.replace("VERSION_DEBUG = false", "VERSION_DEBUG = true", 1)
    src = src.replace(
        "https://dal-login-us.heitaoglobal.com:8082/account",
        "http://127.0.0.1:18099/account",
    )
    src = src.replace(
        "https://dal-login-us.heitaoglobal.com:8082/globalNotice/get_global_notice",
        "http://127.0.0.1:18099/globalNotice/get_global_notice",
    )
    return src


def patch_update(src: str) -> str:
    needle = "function UpdateLayer_new:updateVision()"
    inject = (
        "function UpdateLayer_new:updateVision()\n"
        "    restartLuaEngine(\"CompleteUpdate\")\n"
        "    do return end\n"
        "local function __dal_orig_updateVision()"
    )
    if needle not in src:
        raise SystemExit("updateVision not found")
    return src.replace(needle, inject, 1)


def main() -> None:
    z = zipfile.ZipFile(APK_IN)
    util = decrypt_bytes(z.read(UTIL)).decode("utf-8")
    upd = decrypt_bytes(z.read(UPDATE)).decode("utf-8")
    srv = decrypt_bytes(z.read(SERVER)).decode("utf-8")
    util_p = patch_util(util)
    upd_p = patch_update(upd)
    srv_p = srv.replace("http://192.168.38.150:8081/account", "http://127.0.0.1:18099/account")
    srv_p = srv_p.replace("https://dal-login-us.heitaoglobal.com:8082/account", "http://127.0.0.1:18099/account")
    srv_p = srv_p.replace("http://43.130.144.246:7070/account", "http://127.0.0.1:18099/account")
    # roundtrip check
    rt = decrypt_bytes(encrypt_zip(util_p.encode("utf-8"))).decode("utf-8")
    assert "127.0.0.1:18099" in rt, "encrypt roundtrip failed"
    print("roundtrip ok, patched util", len(util_p), "update", len(upd_p))

    shutil.copyfile(APK_IN, APK_OUT)
    # zipfile can't replace in-place cleanly on all pythons; rebuild
    tmp = APK_OUT + ".tmp"
    with zipfile.ZipFile(APK_IN, "r") as zin, zipfile.ZipFile(tmp, "w") as zout:
        for item in zin.infolist():
            data = zin.read(item.filename)
            if item.filename == UTIL:
                data = encrypt_zip(util_p.encode("utf-8"))
            elif item.filename == UPDATE:
                data = encrypt_zip(upd_p.encode("utf-8"))
            elif item.filename == SERVER:
                data = encrypt_zip(srv_p.encode("utf-8"))
            # keep stored for already-compressed entries
            zout.writestr(item, data)
    os.replace(tmp, APK_OUT)
    print("wrote", APK_OUT, os.path.getsize(APK_OUT))

    keystore = os.path.join("work", "apk", "debug.keystore")
    keytool = r"C:\Program Files\Java\jdk-21.0.11\bin\keytool.exe"
    jarsigner = r"C:\Program Files\Java\jdk-21.0.11\bin\jarsigner.exe"
    if not os.path.isfile(keystore):
        subprocess.check_call([
            keytool, "-genkeypair", "-v", "-keystore", keystore,
            "-alias", "androiddebugkey", "-keyalg", "RSA", "-keysize", "2048",
            "-validity", "10000",
            "-storepass", "android", "-keypass", "android",
            "-dname", "CN=Android Debug,O=Android,C=US",
        ])
    signed = APK_OUT.replace(".apk", "-signed.apk")
    # try apksigner then jarsigner
    apksigner = shutil.which("apksigner")
    if apksigner:
        subprocess.check_call([
            apksigner, "sign", "--ks", keystore, "--ks-key-alias", "androiddebugkey",
            "--ks-pass", "pass:android", "--key-pass", "pass:android",
            "--out", signed, APK_OUT,
        ])
    else:
        subprocess.check_call([
            jarsigner, "-sigalg", "SHA256withRSA", "-digestalg", "SHA-256",
            "-keystore", keystore, "-storepass", "android", "-keypass", "android",
            APK_OUT, "androiddebugkey",
        ])
        signed = APK_OUT
    print("signed", signed)
    dest = r"work\apk\base-offline.apk"
    shutil.copyfile(signed, dest)
    print("final", dest)


if __name__ == "__main__":
    main()
