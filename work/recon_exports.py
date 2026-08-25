#!/usr/bin/env python3
import struct

so = open(r"work\extract\lib\libTerransForce.so", "rb").read()
# ELF64 dynstr/dynsym scan via simple strings of exported-looking
# just print curl/http/CheckUpdate nearby strings
idx = so.find(b"CheckUpdate")
print("CheckUpdate context", so[idx-80:idx+80])
idx = so.find(b"startDownloadZip")
print("startDownloadZip context", so[idx-40:idx+80])

# JNI
for s in [b"httpRequest", b"TFClientNetHttp", b"nativeOnResponse", b"curl_easy_setopt"]:
    print(s, so.find(s))
