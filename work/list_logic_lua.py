#!/usr/bin/env python3
import zipfile

z = zipfile.ZipFile(r"work\apk\com.datealive.action.rpg.apk")
for i in z.infolist():
    n = i.filename
    if n.startswith("assets/src/lua/") and n.endswith(".lua") and "/uiconfig/" not in n:
        print(f"{i.file_size:7d}  {n[len('assets/src/lua/'):]}")
    if n.startswith("assets/src/TFFramework/") and n.endswith(".lua") and (
        "Net" in n or "Http" in n or "Socket" in n or "Protocol" in n or "TFClient" in n
    ):
        print(f"{i.file_size:7d}  {n}")
