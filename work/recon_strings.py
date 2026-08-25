#!/usr/bin/env python3
"""Pull URL/host/crypto strings from libTerransForce.so and dex."""
from __future__ import annotations

import os
import re
import zipfile

SO = r"work\extract\lib\libTerransForce.so"
APK = r"work\apk\com.datealive.action.rpg.apk"
OUT = r"work\extract\strings.txt"

PAT = re.compile(
    rb"(https?://[\x21-\x7e]{4,180}|wss?://[\x21-\x7e]{4,180}|"
    rb"(?:[a-zA-Z0-9-]+\.)+(?:com|net|org|cn|io|gg|me)[\x21-\x7e]{0,80})",
)
CRYPTO = re.compile(
    rb"(HMAC|SHA256|MD5|AES|RSA|sign|Sign|token|Token|openssl|curl_|CURLOPT|"
    rb"pairip|frida|xposed|magisk|root|emulator|OkHttp|WebSocket|protobuf|"
    rb"socket\.io|WAMP|Heitao|heitao|TFHttp|HttpClient)",
    re.I,
)


def strings_from(data: bytes, minlen: int = 6) -> list[str]:
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
    with open(SO, "rb") as f:
        so = f.read()
    so_s = strings_from(so)
    print(f"so strings: {len(so_s)}")

    hits = []
    for s in so_s:
        b = s.encode()
        if PAT.search(b) or CRYPTO.search(b):
            hits.append("SO  " + s)
    print(f"so hits: {len(hits)}")

    z = zipfile.ZipFile(APK)
    for dex in ("classes.dex", "classes2.dex", "classes3.dex"):
        data = z.read(dex)
        print(f"{dex} {len(data)}")
        for m in PAT.finditer(data):
            hits.append(f"DEX {dex} {m.group(0).decode('ascii','replace')}")
        for m in CRYPTO.finditer(data):
            # too noisy; skip generic
            pass

    # unique urls from dex via looser extract
    url_re = re.compile(rb"https?://[\x21-\x7e]{4,180}")
    ws_re = re.compile(rb"wss?://[\x21-\x7e]{4,180}")
    for dex in ("classes.dex", "classes2.dex", "classes3.dex"):
        data = z.read(dex)
        for m in list(url_re.finditer(data)) + list(ws_re.finditer(data)):
            hits.append(f"DEXURL {dex} {m.group(0).decode('ascii','replace')}")

    uniq = []
    seen = set()
    for h in hits:
        if h not in seen:
            seen.add(h)
            uniq.append(h)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\n".join(uniq))
    print(f"wrote {len(uniq)} lines to {OUT}")
    for h in uniq[:200]:
        print(h)
    if len(uniq) > 200:
        print(f"... +{len(uniq)-200}")


if __name__ == "__main__":
    main()
