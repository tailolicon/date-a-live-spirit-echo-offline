#!/usr/bin/env python3
"""Runtime schema registry for the TerransForce Lua protobuf descriptors.

The client ships its protocol IDL as Lua tables. This module parses those
tables so offline handlers can work with dictionaries rather than hand-built
protobuf bytes.
"""
from __future__ import annotations

from dataclasses import dataclass
import os
import re
import struct
import time
from typing import Any

import proto_gen
from proto_codec import read_uvarint, svarint, tag, uvarint

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
NET_ROOT = os.path.join(ROOT, "reference", "lua", "lua", "net")
PROTOS_S2C = os.path.join(NET_ROOT, "protos_s2c.lua")
PROTOS_C2S = os.path.join(NET_ROOT, "protos_c2s.lua")
CODES_S2C = os.path.join(NET_ROOT, "codes_s2c.lua")
CODES_C2S = os.path.join(NET_ROOT, "codes_c2s.lua")

VARINT_TYPES = set(proto_gen.VARINT_TYPES)
STRING_TYPES = set(proto_gen.STRING_TYPES)
FIXED32_TYPES = set(proto_gen.FIXED32_TYPES)
REPEATED_TYPES = set(proto_gen.REPEATED_TYPES)
PACKED_VARINT_TYPES = {"pv4", "pv8"}
REPEATED_STRING_TYPES = {"ts"}
REPEATED_VARINT_TYPES = REPEATED_TYPES - PACKED_VARINT_TYPES - REPEATED_STRING_TYPES


@dataclass(frozen=True)
class FieldSpec:
    name: str
    kind: str
    repeated: bool = False
    children: tuple["FieldSpec", ...] = ()


def _atom(expr: str) -> str:
    return expr.strip().rstrip(",").strip().strip("'\"")


def _list(expr: str) -> list[str]:
    expr = expr.strip().rstrip(",").strip()
    if not (expr.startswith("{") and expr.endswith("}")):
        return []
    return proto_gen._split_top(expr[1:-1])


def _parse_fields(type_exprs: list[str], name_exprs: list[str]) -> tuple[FieldSpec, ...]:
    fields: list[FieldSpec] = []
    for index, texpr in enumerate(type_exprs):
        nexpr = name_exprs[index] if index < len(name_exprs) else f"'field{index + 1}'"
        texpr = texpr.strip()
        if texpr.startswith("{"):
            tparts = _list(texpr)
            nparts = _list(nexpr)
            repeated = bool(tparts) and _atom(tparts[0]).lower() == "true"
            tchildren = _list(tparts[1]) if len(tparts) > 1 else []
            nchildren = _list(nparts[1]) if len(nparts) > 1 else []
            name = _atom(nchildren[0]) if nchildren else f"field{index + 1}"
            child_names = nchildren[1:] if len(nchildren) > 1 else []
            fields.append(FieldSpec(name, "message", repeated, _parse_fields(tchildren, child_names)))
            continue
        kind = _atom(texpr)
        fields.append(FieldSpec(_atom(nexpr) or f"field{index + 1}", kind, kind in REPEATED_TYPES))
    return tuple(fields)


def load_schemas(path: str) -> dict[int, tuple[FieldSpec, ...]]:
    with open(path, encoding="utf-8", errors="replace") as handle:
        src = handle.read()
    out: dict[int, tuple[FieldSpec, ...]] = {}
    for m in re.finditer(r"\[(\d+)\]\s*=\s*function\(\)\s*return\s*\{", src):
        proto = int(m.group(1))
        end = proto_gen._match_brace(src, m.end() - 1)
        parts = proto_gen._split_top(src[m.end():end - 1])
        if len(parts) < 3:
            continue
        out[proto] = _parse_fields(_list(parts[1]), _list(parts[2]))
    return out


def load_codes(path: str, table_name: str) -> tuple[dict[str, int], dict[int, str]]:
    with open(path, encoding="utf-8", errors="replace") as handle:
        src = handle.read()
    by_name: dict[str, int] = {}
    by_id: dict[int, str] = {}
    pattern = rf"\b{re.escape(table_name)}\.([A-Z0-9_]+)\s*=\s*(\d+)"
    for name, raw_id in re.findall(pattern, src):
        proto = int(raw_id)
        by_name[name] = proto
        by_id.setdefault(proto, name)
    return by_name, by_id


def _default_value(field: FieldSpec) -> Any:
    if field.repeated:
        return []
    name = field.name.lower()
    if field.kind in STRING_TYPES:
        return ""
    if field.kind in FIXED32_TYPES:
        return 0.0
    if field.kind == "b":
        return False
    if field.kind in VARINT_TYPES:
        if "time" in name and not name.startswith(("fight", "queue", "cost")):
            return int(time.time())
        return 0
    return 0


def _message_field(field_no: int, body: bytes) -> bytes:
    return tag(field_no, 2) + uvarint(len(body)) + body


def _encode_primitive(field_no: int, spec: FieldSpec, value: Any) -> bytes:
    kind = spec.kind
    if kind in STRING_TYPES:
        raw = str(value or "").encode("utf-8")
        return tag(field_no, 2) + uvarint(len(raw)) + raw
    if kind in FIXED32_TYPES:
        return tag(field_no, 5) + struct.pack("<f", float(value or 0.0))
    if kind == "sv4":
        return tag(field_no, 0) + svarint(int(value or 0))
    if kind in VARINT_TYPES:
        return tag(field_no, 0) + uvarint(1 if kind == "b" and bool(value) else int(value or 0))
    return b""


def encode_fields(fields: tuple[FieldSpec, ...], values: dict[str, Any] | None = None) -> bytes:
    values = values or {}
    out = bytearray()
    for field_no, spec in enumerate(fields, start=1):
        value = values.get(spec.name, _default_value(spec))
        if spec.kind == "message":
            if spec.repeated:
                for entry in value or []:
                    if isinstance(entry, dict):
                        out += _message_field(field_no, encode_fields(spec.children, entry))
            else:
                entry = value if isinstance(value, dict) else {}
                out += _message_field(field_no, encode_fields(spec.children, entry))
            continue
        if spec.repeated:
            seq = value if isinstance(value, (list, tuple)) else []
            if spec.kind in PACKED_VARINT_TYPES:
                inner = b"".join(uvarint(int(v)) for v in seq)
                if inner:
                    out += _message_field(field_no, inner)
            elif spec.kind in REPEATED_STRING_TYPES:
                for v in seq:
                    raw = str(v).encode("utf-8")
                    out += tag(field_no, 2) + uvarint(len(raw)) + raw
            else:
                base = FieldSpec(spec.name, "v8" if "8" in spec.kind else "v4")
                for v in seq:
                    out += _encode_primitive(field_no, base, v)
            continue
        out += _encode_primitive(field_no, spec, value)
    return bytes(out)


def _read_wire_fields(buf: bytes) -> dict[int, list[tuple[int, Any]]]:
    out: dict[int, list[tuple[int, Any]]] = {}
    i = 0
    while i < len(buf):
        key, i = read_uvarint(buf, i)
        field_no, wire = key >> 3, key & 7
        if field_no <= 0:
            break
        if wire == 0:
            value, i = read_uvarint(buf, i)
        elif wire == 1:
            if i + 8 > len(buf):
                raise ValueError("truncated fixed64")
            value = buf[i:i + 8]
            i += 8
        elif wire == 2:
            size, i = read_uvarint(buf, i)
            if i + size > len(buf):
                raise ValueError("truncated bytes")
            value = buf[i:i + size]
            i += size
        elif wire == 5:
            if i + 4 > len(buf):
                raise ValueError("truncated fixed32")
            value = buf[i:i + 4]
            i += 4
        else:
            raise ValueError(f"unsupported wire type {wire}")
        out.setdefault(field_no, []).append((wire, value))
    return out


def _zigzag_decode(value: int) -> int:
    return (value >> 1) ^ -(value & 1)


def decode_fields(fields: tuple[FieldSpec, ...], body: bytes) -> dict[str, Any]:
    raw = _read_wire_fields(body)
    out: dict[str, Any] = {}
    for field_no, spec in enumerate(fields, start=1):
        entries = raw.get(field_no, [])
        if not entries:
            continue
        if spec.kind == "message":
            decoded = [decode_fields(spec.children, bytes(v)) for wire, v in entries if wire == 2]
            if spec.repeated:
                out[spec.name] = decoded
            elif decoded:
                out[spec.name] = decoded[-1]
            continue
        if spec.kind in PACKED_VARINT_TYPES:
            vals: list[int] = []
            for wire, v in entries:
                if wire == 0:
                    vals.append(int(v))
                elif wire == 2:
                    j = 0
                    raw_bytes = bytes(v)
                    while j < len(raw_bytes):
                        n, j = read_uvarint(raw_bytes, j)
                        vals.append(n)
            out[spec.name] = vals
            continue
        if spec.kind in REPEATED_STRING_TYPES:
            out[spec.name] = [bytes(v).decode("utf-8", "replace") for wire, v in entries if wire == 2]
            continue
        if spec.kind in REPEATED_VARINT_TYPES:
            out[spec.name] = [int(v) for wire, v in entries if wire == 0]
            continue
        wire, value = entries[-1]
        if spec.kind in STRING_TYPES and wire == 2:
            out[spec.name] = bytes(value).decode("utf-8", "replace")
        elif spec.kind in FIXED32_TYPES and wire == 5:
            out[spec.name] = struct.unpack("<f", bytes(value))[0]
        elif spec.kind == "b" and wire == 0:
            out[spec.name] = bool(value)
        elif spec.kind == "sv4" and wire == 0:
            out[spec.name] = _zigzag_decode(int(value))
        elif spec.kind in VARINT_TYPES and wire == 0:
            out[spec.name] = int(value)
    return out


class ProtocolRegistry:
    def __init__(self, protos_s2c: str = PROTOS_S2C, protos_c2s: str = PROTOS_C2S,
                 codes_s2c: str = CODES_S2C, codes_c2s: str = CODES_C2S) -> None:
        self.s2c = load_schemas(protos_s2c)
        self.c2s = load_schemas(protos_c2s)
        self.s2c_by_name, self.s2c_names = load_codes(codes_s2c, "s2c")
        self.c2s_by_name, self.c2s_names = load_codes(codes_c2s, "c2s")

    def encode_response(self, proto: int, values: dict[str, Any] | None = None) -> bytes:
        return encode_fields(self.s2c[proto], values)

    def decode_request(self, proto: int, body: bytes) -> dict[str, Any]:
        fields = self.c2s.get(proto)
        return decode_fields(fields, body) if fields is not None else {}

    def name(self, proto: int, direction: str = "c2s") -> str:
        names = self.c2s_names if direction == "c2s" else self.s2c_names
        return names.get(proto, f"PROTO_{proto}")


_REGISTRY: ProtocolRegistry | None = None


def registry() -> ProtocolRegistry:
    global _REGISTRY
    if _REGISTRY is None:
        _REGISTRY = ProtocolRegistry()
    return _REGISTRY


def encode_response(proto: int, values: dict[str, Any] | None = None) -> bytes:
    return registry().encode_response(proto, values)


def decode_request(proto: int, body: bytes) -> dict[str, Any]:
    return registry().decode_request(proto, body)


def proto_name(proto: int, direction: str = "c2s") -> str:
    return registry().name(proto, direction)
