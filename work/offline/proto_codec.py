#!/usr/bin/env python3
"""Minimal protobuf-style codec matching TerransForce lua TypeCount tags."""
from __future__ import annotations


def uvarint(n: int) -> bytes:
    n = int(n) & ((1 << 64) - 1)
    out = bytearray()
    while n > 0x7F:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    out.append(n)
    return bytes(out)


def svarint(n: int) -> bytes:
    return uvarint((int(n) << 1) ^ (int(n) >> 63))


def tag(field: int, wire: int) -> bytes:
    return uvarint((field << 3) | wire)


def enc_varint_field(field: int, value: int) -> bytes:
    return tag(field, 0) + uvarint(value)


def enc_bool_field(field: int, value: bool) -> bytes:
    return enc_varint_field(field, 1 if value else 0)


def enc_string_field(field: int, value: str) -> bytes:
    b = (value or "").encode("utf-8")
    return tag(field, 2) + uvarint(len(b)) + b


def enc_msg_field(field: int, body: bytes) -> bytes:
    if not body:
        return b""
    return tag(field, 2) + uvarint(len(body)) + body


def enc_packed_varint_field(field: int, values: list[int]) -> bytes:
    if not values:
        return b""
    inner = b"".join(uvarint(v) for v in values)
    return tag(field, 2) + uvarint(len(inner)) + inner


def read_uvarint(buf: bytes, i: int) -> tuple[int, int]:
    n = 0
    shift = 0
    while True:
        if i >= len(buf):
            raise ValueError("truncated varint")
        b = buf[i]
        i += 1
        n |= (b & 0x7F) << shift
        if not (b & 0x80):
            return n, i
        shift += 7
        if shift > 63:
            raise ValueError("varint too long")


def xor_bytes(data: bytes, key: bytes) -> bytes:
    if not key:
        return data
    out = bytearray(len(data))
    klen = len(key)
    for i, b in enumerate(data):
        out[i] = b ^ key[i % klen]
    return bytes(out)
