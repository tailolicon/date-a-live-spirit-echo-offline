#!/usr/bin/env python3
"""Encrypt/decrypt Date A Live: Spirit Echo lua assets (F8 8B 2D gzip wrapper)."""
from __future__ import annotations

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
    buf = buf[1:]
    if var_1 > 0:
        i = 2
        n = var_1 + 2
        out = bytearray(buf)
        out[i] = buf[i] ^ (var_1 & 0xFF)
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
    if data[2] == 0x2B:
        raise NotImplementedError("LZ4-wrapped asset")
    if data[2] in (0x2D, 0x3D):
        return decrypt_zip(data)
    return data


def encrypt_bytes(plain: bytes) -> bytes:
    comp = zlib.compressobj(9, zlib.DEFLATED, zlib.MAX_WBITS | 16)
    data = bytearray([0xF8]) + comp.compress(plain) + comp.flush()
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
    out = bytes(data)
    assert decrypt_bytes(out) == plain, "lua encrypt roundtrip failed"
    return out
