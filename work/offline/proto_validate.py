#!/usr/bin/env python3
"""Decode an s2c body exactly the way the client does, and report what breaks.

The client's reader (TFFramework/net/TFClientNetOp.lua) is not a protobuf
parser. It walks the descriptor from protos_s2c.lua in order and, at each
position, peeks the next tag and compares it against `TypeCount(i, type)` =
`i * 8 + wiretype`. Three things follow, and all three bite:

  * A tag that does not match is *not an error* - the field is set to NULL and
    nothing is consumed. So a body with a wrong field simply loses every field
    from that point on, silently, and the failure surfaces much later as a nil
    index deep inside a DataMgr.
  * When the field number matches but the wire type does not, the client prints
    "[error]not the same type at ..." and then still NULLs the field. That
    print is the only direct signal, and only if DEBUG_LOG is on.
  * Nesting is positional too: `{false,{...}}` is one submessage, `{true,{...}}`
    is a repeated one emitted as tag+len+body per element at the same field
    number. Wrapping a repeated list in an extra submessage - the easy mistake -
    puts a submessage where the first scalar belongs and trips case two.

So mirror the reader here and let the tests assert that a body survives it,
rather than discovering it as a black screen on the device.
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from typing import Any

import proto_gen

# Wire type per lua type tag - NetOP's tblTypeNum.
TYPE_NUM = {
    "n1": 0, "n2": 0, "n4": 0,
    "s": 2, "a": 2, "srsa": 2,
    "v4": 0, "v8": 0,
    "av4": 2, "av8": 2, "an1": 2,
    "t": 2, "ts": 2,
    "tv4": 0, "tv8": 0,
    "pv4": 2, "pv8": 2,
    "f4": 5, "b": 0, "sv4": 0,
}


class Truncated(Exception):
    """Ran off the end of the body - the client would read into the padding."""


@dataclass
class Report:
    proto: int
    consumed: int = 0
    total: int = 0
    mismatches: list[str] = field(default_factory=list)
    absent: list[str] = field(default_factory=list)
    truncated: str | None = None

    @property
    def ok(self) -> bool:
        """No wire-type clash and nothing left unread.

        A missing field is legitimate - that is how an empty repeated field is
        expressed - so `absent` is reported but does not fail.
        """
        return not self.mismatches and self.truncated is None and self.consumed == self.total

    def __str__(self) -> str:
        bits = [f"proto {self.proto}: {self.consumed}/{self.total} bytes"]
        if self.truncated:
            bits.append(f"TRUNCATED {self.truncated}")
        for m in self.mismatches:
            bits.append(f"MISMATCH {m}")
        if self.consumed != self.total and not self.truncated:
            bits.append(f"{self.total - self.consumed} trailing bytes unread")
        return "; ".join(bits)


class Reader:
    def __init__(self, buf: bytes) -> None:
        self.buf = buf
        self.i = 0

    # GetReadPacketSize() is bytes *remaining*: the lua uses differences of it
    # to measure how much a nested read consumed.
    def remaining(self) -> int:
        return len(self.buf) - self.i

    def peek_tag(self) -> int | None:
        """PreUnpackWiretype: the next varint, without consuming it."""
        save = self.i
        try:
            return self.varint()
        except Truncated:
            return None
        finally:
            self.i = save

    def varint(self) -> int:
        out, shift = 0, 0
        while True:
            if self.i >= len(self.buf):
                raise Truncated("varint")
            b = self.buf[self.i]
            self.i += 1
            out |= (b & 0x7F) << shift
            if not b & 0x80:
                return out
            shift += 7
            if shift > 63:
                raise Truncated("varint too long")

    def take(self, n: int) -> bytes:
        if n < 0 or self.i + n > len(self.buf):
            raise Truncated(f"{n} bytes")
        out = self.buf[self.i:self.i + n]
        self.i += n
        return out


def type_count(index: int, spec: Any) -> int:
    wire = TYPE_NUM["t"] if isinstance(spec, list) else TYPE_NUM.get(spec, 2)
    return index * 8 + wire


def _clean(spec: str) -> str:
    return spec.strip().rstrip(",").strip().strip("'\"")


def parse_spec(raw: str) -> Any:
    """Turn one descriptor entry into either a type string or [repeated, [...]]."""
    raw = raw.strip().rstrip(",").strip()
    if not raw.startswith("{"):
        return _clean(raw)
    parts = proto_gen._split_top(raw[1:-1])
    repeated = parts[0].strip() == "true"
    inner_raw = parts[1].strip() if len(parts) > 1 else "{}"
    inner = proto_gen._split_top(inner_raw[1:-1]) if inner_raw.startswith("{") else []
    return [repeated, [parse_spec(p) for p in inner if p.strip()]]


class Validator:
    def __init__(self, proto: int) -> None:
        self.report = Report(proto)

    def scalar(self, r: Reader, kind: str, index: int) -> None:
        """Consume one value, tag already handled by the caller per the lua."""
        if kind in ("s", "a", "srsa"):
            r.take(r.varint())
        elif kind in ("pv4", "pv8"):
            # UnpackRepeatIntPacked: length, then varints filling it.
            n = r.varint()
            end = r.remaining() - n
            while r.remaining() > end:
                r.varint()
        elif kind in ("tv4", "tv8", "ts"):
            # UnpackRepeatInt: keeps eating while the tag repeats. Note the
            # caller did NOT consume the tag for these.
            sub = kind[1:]
            want = index * 8 + TYPE_NUM[sub]
            while r.peek_tag() == want:
                r.varint()
                if sub == "s":
                    r.take(r.varint())
                else:
                    r.varint()
        elif kind in ("av4", "av8", "an1"):
            for _ in range(r.varint()):
                r.varint()
        elif kind == "f4":
            r.take(4)
        elif kind in ("n1", "n2", "n4", "v4", "v8", "b", "sv4"):
            r.varint()
        else:
            raise Truncated(f"unknown type {kind!r}")

    def table(self, r: Reader, spec: list, tag_type: int, limit: int | None,
              path: str) -> None:
        """UnpackTable: repeated (or single) submessage at one field number."""
        repeated, fields = spec
        start = r.remaining()
        while r.peek_tag() == tag_type:
            r.varint()               # tag
            n = r.varint()           # element length
            left = n
            for idx, sub in enumerate(fields, start=1):
                before = r.remaining()
                if left == 0:
                    break
                self.value(r, fields, idx, left, f"{path}[{idx}]")
                left -= before - r.remaining()
            if not repeated:
                break
            if limit is not None and start - r.remaining() == limit:
                break

    def value(self, r: Reader, specs: list, index: int, limit: int | None,
              path: str) -> None:
        """UnpackSingleVaule."""
        spec = specs[index - 1]
        tag = r.peek_tag()
        want = type_count(index, spec)
        if tag != want:
            if tag is not None and tag // 8 == want // 8:
                self.report.mismatches.append(
                    f"{path}: field {index} expects wire {want % 8} "
                    f"({spec if isinstance(spec, str) else 'submessage'}), "
                    f"got wire {tag % 8}")
            else:
                self.report.absent.append(f"{path}: field {index}")
            return
        if isinstance(spec, list):
            self.table(r, spec, tag, limit, path)
            return
        if not spec.startswith("t"):
            r.varint()               # consume the tag
        self.scalar(r, spec, index)


def validate(proto: int, body: bytes, types: list[str] | None = None) -> Report:
    """Walk `body` the way the client would and report what it would lose."""
    if types is None:
        types = load_types().get(proto)
        if types is None:
            raise KeyError(f"no s2c descriptor for proto {proto}")
    specs = [parse_spec(t) for t in types if t.strip()]
    v = Validator(proto)
    r = Reader(body)
    v.report.total = len(body)
    try:
        for idx in range(1, len(specs) + 1):
            v.value(r, specs, idx, None, f"{proto}")
    except Truncated as exc:
        v.report.truncated = str(exc)
    v.report.consumed = r.i
    return v.report


_TYPES: dict[int, list[str]] | None = None


def load_types() -> dict[int, list[str]]:
    global _TYPES
    if _TYPES is None:
        _TYPES = proto_gen.load_types()
    return _TYPES


if __name__ == "__main__":
    import sys

    bad = []
    for pid, body in sorted(proto_gen.build().items()):
        rep = validate(pid, body)
        if not rep.ok:
            bad.append(rep)
    print(f"{len(bad)} generated bodies do not round-trip")
    for rep in bad[:40]:
        print(" ", rep)
    sys.exit(1 if bad else 0)
