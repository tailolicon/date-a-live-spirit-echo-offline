#!/usr/bin/env python3
"""Decrypt remaining protocol/login lua from the APK."""
from __future__ import annotations

import os
import zipfile

from dal_decrypt import decrypt_bytes

APK = r"work\apk\com.datealive.action.rpg.apk"
OUT = r"work\dump\decrypted"
NEED = (
    "proto",
    "Proto",
    "Logon",
    "login",
    "Login",
    "Net",
    "account",
    "Account",
    "Http",
    "http",
    "Socket",
    "s2c",
    "c2s",
    "MainPlayer",
)


def main() -> None:
    z = zipfile.ZipFile(APK)
    n = 0
    for i in z.infolist():
        name = i.filename
        if not name.endswith(".lua"):
            continue
        if "/uiconfig/" in name or "/ai/" in name:
            continue
        low = name.lower()
        if not any(k.lower() in low for k in NEED):
            continue
        dest = os.path.join(OUT, name.replace("/", os.sep))
        if os.path.exists(dest) and os.path.getsize(dest) > 0:
            continue
        try:
            pt = decrypt_bytes(z.read(name))
        except Exception as e:
            print("FAIL", name, e)
            continue
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        open(dest, "wb").write(pt)
        n += 1
        print(f"{len(pt):7d}  {name}")
    print("new files", n)


if __name__ == "__main__":
    main()
