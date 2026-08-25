#!/usr/bin/env python3
"""Build minimal, well-formed s2c bodies straight from protos_s2c.lua.

The login handshake fans out into ~100 module requests, and the client will sit
on the loading spinner until every one of them is answered. Hand-writing that
many bodies is pointless: the lua side already carries a machine-readable type
descriptor for every message, so generate from it.

Each entry in protos_s2c.lua looks like

    [257] = function()
        return {
            {"net.NetHelper", "receive"},
            {'v4', {false,{'v4','s',...}}, 'v4', 'v4', },
            {'serverTime', {false,{'playerinfo',...}}, 'queue', 'queueTime', }
        }
    end,

The middle list is the wire layout. NetOP:UnpackSingleVaule walks it in order
and treats a tag that does not match the expected position as NULL, so a
minimal body only has to supply the scalars; repeated fields can be left out
entirely and a non-repeated submessage can be sent zero-length.

Replying with a *completely* empty body is not safe - several handlers index
the fields they expect and take the client down with a SIGSEGV inside luajit.
"""
from __future__ import annotations

import os
import re
import struct

from proto_codec import enc_string_field, enc_varint_field, tag, uvarint

_REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                     "..", ".."))
_CANDIDATES = (
    os.path.join(_REPO, "reference", "lua", "lua", "net", "protos_s2c.lua"),
    os.path.join(_REPO, "work", "dump", "all_lua", "assets", "src", "lua", "net",
                 "protos_s2c.lua"),
)


def _find_protos() -> str:
    env = os.environ.get("DAL_PROTOS_S2C")
    if env:
        return env
    for path in _CANDIDATES:
        if os.path.isfile(path):
            return path
    return _CANDIDATES[0]


PROTOS_S2C = _find_protos()

# NetOP tblTypeNum: wire type per lua type tag.
VARINT_TYPES = {"n1", "n2", "n4", "v4", "v8", "sv4", "b"}
STRING_TYPES = {"s", "a", "srsa"}
FIXED32_TYPES = {"f4"}
# Repeated / packed / array forms: an empty message is a valid "none".
REPEATED_TYPES = {"av4", "av8", "an1", "ts", "tv4", "tv8", "pv4", "pv8"}


def _split_top(s: str) -> list[str]:
    """Split a lua list body on commas that are not inside braces or quotes."""
    out, depth, cur, quote = [], 0, [], None
    for ch in s:
        if quote:
            cur.append(ch)
            if ch == quote:
                quote = None
            continue
        if ch in "'\"":
            quote = ch
            cur.append(ch)
        elif ch == "{":
            depth += 1
            cur.append(ch)
        elif ch == "}":
            depth -= 1
            cur.append(ch)
        elif ch == "," and depth == 0:
            out.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        out.append("".join(cur).strip())
    return out


def _match_brace(s: str, start: int) -> int:
    """Index just past the '}' matching the '{' at `start`."""
    depth, i, quote = 0, start, None
    while i < len(s):
        ch = s[i]
        if quote:
            if ch == quote:
                quote = None
        elif ch in "'\"":
            quote = ch
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    raise ValueError("unbalanced braces")


def encode_minimal(types: list[str]) -> bytes:
    """One zero/empty value per scalar field, in wire order."""
    out = b""
    for idx, t in enumerate(types, start=1):
        t = t.strip().rstrip(",").strip()
        if not t:
            continue
        if t.startswith("{"):
            # Repeated ({true,...}) may be absent - the reader yields an empty
            # table. A non-repeated one must be filled in recursively: sending
            # it zero-length leaves every field nil, and handlers that compare
            # them raise ("attempt to compare number with nil" in
            # LeagueDataMgr:checkSelfInUnion, for one).
            if re.match(r"\{\s*false\b", t):
                inner = _split_top(t[1:-1])
                sub = b""
                if len(inner) > 1 and inner[1].strip().startswith("{"):
                    sub = encode_minimal(_split_top(inner[1].strip()[1:-1]))
                out += tag(idx, 2) + uvarint(len(sub)) + sub
            continue
        t = t.strip("'\"")
        if t in VARINT_TYPES:
            out += enc_varint_field(idx, 0)
        elif t in STRING_TYPES:
            out += enc_string_field(idx, "")
        elif t in FIXED32_TYPES:
            out += tag(idx, 5) + struct.pack("<f", 0.0)
        elif t in REPEATED_TYPES:
            pass  # empty repeated field: simply absent
    return out


def load_types(path: str = PROTOS_S2C) -> dict[int, list[str]]:
    src = open(path, encoding="utf-8", errors="replace").read()
    out: dict[int, list[str]] = {}
    for m in re.finditer(r"\[(\d+)\]\s*=\s*function\(\)\s*return\s*\{", src):
        pid = int(m.group(1))
        end = _match_brace(src, m.end() - 1)
        parts = _split_top(src[m.end():end - 1])
        if len(parts) < 2:
            continue
        types = parts[1].strip()
        if not types.startswith("{"):
            continue
        out[pid] = _split_top(types[1:-1])
    return out


def build(path: str = PROTOS_S2C) -> dict[int, bytes]:
    return {pid: encode_minimal(t) for pid, t in load_types(path).items()}


if __name__ == "__main__":
    bodies = build()
    print("protos:", len(bodies))
    for pid in (257, 295, 5200, 304):
        if pid in bodies:
            print(pid, bodies[pid].hex())
