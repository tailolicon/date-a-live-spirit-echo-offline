#!/usr/bin/env python3
"""Dump proto files + search DEX for game hosts / HttpClient / Heitao."""
from __future__ import annotations

import os
import re
import zipfile

APK = r"work\apk\com.datealive.action.rpg.apk"
OUT = r"work\extract"

HOST_RE = re.compile(
    rb"[\x20-\x7e]{0,20}(?:datealive|heitao|phanta|yoka|thunder|leiting|dal[-.]|"
    rb"spirit.?echo|yuenzhan|yzjl|api[-.]|game[-.]server|login[-.]|"
    rb"gateway|socket)[\x20-\x7e]{0,80}",
    re.I,
)
URL_RE = re.compile(rb"[a-zA-Z0-9._-]{3,40}\.(?:com|net|cn|org|io)(?:/[\x21-\x7e]{0,60})?")


def main() -> None:
    z = zipfile.ZipFile(APK)
    print("===== proto / textproto =====")
    for i in z.infolist():
        n = i.filename
        if n.endswith(".proto") or n.endswith(".textproto") or n.endswith(".binarypb"):
            dest = os.path.join(OUT, n.replace("/", os.sep))
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            data = z.read(n)
            with open(dest, "wb") as f:
                f.write(data)
            print(f"  {n} {len(data)}")

    print("\n===== DEX host-ish =====")
    seen = set()
    for dex in ("classes.dex", "classes2.dex", "classes3.dex"):
        data = z.read(dex)
        for m in HOST_RE.finditer(data):
            s = m.group(0).decode("ascii", "replace")
            if s not in seen:
                seen.add(s)
                print(f"{dex}: {s}")
        print(f"--- urls in {dex} ---")
        urls = set()
        for m in URL_RE.finditer(data):
            s = m.group(0).decode("ascii", "replace")
            if any(k in s.lower() for k in ("date", "heitao", "phanta", "yoka", "dal", "leiting", "thunder", "yzjl", "echo", "rpg", "game")):
                urls.add(s)
        for u in sorted(urls):
            print(" ", u)

    # Java class names
    print("\n===== class names of interest =====")
    cls_re = re.compile(rb"L([a-zA-Z0-9_$/]+);")
    interesting = []
    for dex in ("classes.dex", "classes2.dex", "classes3.dex"):
        data = z.read(dex)
        for m in cls_re.finditer(data):
            c = m.group(1).decode("ascii")
            low = c.lower()
            if any(k in low for k in ("phanta", "heitao", "datealive", "terrans", "httpclient", "socket", "websocket", "protobuf", "xxtea", "encrypt")):
                interesting.append(c)
    for c in sorted(set(interesting)):
        print(" ", c)


if __name__ == "__main__":
    main()
