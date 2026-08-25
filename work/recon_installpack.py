#!/usr/bin/env python3
"""List InstallPack contents and hunt plaintext configs/hosts."""
from __future__ import annotations

import collections
import os
import re
import zipfile

APK = r"work\apk\InstallPack.apk"
URL = re.compile(rb"https?://[\x21-\x7e]{4,160}")
HOST = re.compile(rb"(?:[a-zA-Z0-9-]+\.)+(?:com|net|cn|org|io)(?:[:/][\x21-\x7e]{0,40})?")


def main() -> None:
    z = zipfile.ZipFile(APK)
    print("entries", len(z.infolist()))
    ext = collections.Counter()
    dirs = collections.Counter()
    for i in z.infolist():
        n = i.filename
        ext[os.path.splitext(n)[1].lower() or "(none)"] += 1
        dirs[n.split("/")[0]] += 1
    print("exts:")
    for k, v in ext.most_common(40):
        print(f"  {k:20s} {v:8d}")
    print("top dirs:")
    for k, v in dirs.most_common(20):
        print(f"  {k:20s} {v:8d}")
    print("\ninteresting names:")
    for i in z.infolist():
        n = i.filename.lower()
        if any(
            k in n
            for k in (
                ".lua",
                "config",
                "server",
                "host",
                "http",
                "json",
                "xml",
                "proto",
                "login",
                "net",
            )
        ) and i.file_size < 5_000_000:
            print(f"  {i.file_size:10d}  {i.filename}")

    print("\nURL scan (text-like, <2MB):")
    seen = set()
    nscan = 0
    for i in z.infolist():
        n = i.filename
        low = n.lower()
        if i.file_size > 2_000_000:
            continue
        if not any(low.endswith(e) for e in (".json", ".xml", ".txt", ".lua", ".cfg", ".ini", ".properties", ".js", ".html")):
            continue
        nscan += 1
        data = z.read(n)
        for m in list(URL.finditer(data)) + list(HOST.finditer(data)):
            s = m.group(0).decode("ascii", "replace")
            if s not in seen:
                seen.add(s)
                print(f"  {n}: {s}")
    print("scanned files", nscan, "unique hits", len(seen))


if __name__ == "__main__":
    main()
