#!/usr/bin/env python3
"""Which protocols a session actually exercised, and who answered them.

`tcp_server` tags every reply with the module that produced it, or `generic`
when nothing owned the protocol and the client got a descriptor-shaped body of
zeros. Zeros are correct for the live-service modules this server does not
model, and they are also exactly what a stuck feature looks like from the
outside, so the generic list is the standing to-do list: run the game, reach
the thing that does not work, and read off the candidates instead of guessing.

    python work/offline/coverage_report.py [logs/tcp.log]
"""
from __future__ import annotations

import collections
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
DEFAULT_LOG = os.path.join(ROOT, "logs", "tcp.log")

REQUEST = re.compile(r"<- \([^)]*\) proto=(\d+)/(\S+)")
HANDLED = re.compile(r"^\d\d:\d\d:\d\d\s+(\S+) handled (\d+)/(\S+)")
GENERIC = re.compile(r"^\d\d:\d\d:\d\d\s+generic (\d+)/(\S+)")
FAILED = re.compile(r"^\d\d:\d\d:\d\d\s+!! (\S+) (\d+)/(\S+) failed: (.*)")
NO_REPLY = re.compile(r"no s2c descriptor for (\d+)/(\S+)")

# Heartbeat and login plumbing are answered inline by the server loop.
INLINE = {257, 258, 261, 262, 268}


def main(path: str) -> int:
    if not os.path.isfile(path):
        print(f"no trace at {path}; run PLAY.bat first")
        return 1
    seen: collections.Counter[tuple[int, str]] = collections.Counter()
    owner: dict[int, str] = {}
    generic: dict[int, str] = {}
    silent: dict[int, str] = {}
    failures: list[str] = []

    with open(path, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            match = REQUEST.search(line)
            if match:
                seen[(int(match.group(1)), match.group(2))] += 1
                continue
            match = HANDLED.search(line)
            if match:
                owner[int(match.group(2))] = match.group(1)
                continue
            match = GENERIC.search(line)
            if match:
                generic[int(match.group(1))] = match.group(2)
                continue
            match = NO_REPLY.search(line)
            if match:
                silent[int(match.group(1))] = match.group(2)
                continue
            match = FAILED.search(line)
            if match:
                failures.append(f"{match.group(2)}/{match.group(3)} in {match.group(1)}: {match.group(4)}")

    total = sum(seen.values())
    protocols = {proto for proto, _ in seen}
    handled = protocols & set(owner)
    inline = protocols & INLINE
    print(f"{path}: {total} requests over {len(protocols)} protocols\n")
    print(f"  stateful   {len(handled):>4}")
    print(f"  inline     {len(inline):>4}   (login/heartbeat)")
    print(f"  generic    {len(generic):>4}   zero-filled from the descriptor")
    print(f"  unanswered {len(silent):>4}")

    if failures:
        print("\nhandler failures (these are bugs):")
        for row in sorted(set(failures)):
            print(f"  {row}")

    if silent:
        print("\nno reply at all (client may be waiting forever):")
        for proto in sorted(silent):
            print(f"  {proto}/{silent[proto]}  x{seen[(proto, silent[proto])]}")

    if generic:
        print("\ngeneric zero-filled replies, most-asked first:")
        counts = {proto: seen[(proto, name)] for proto, name in generic.items()}
        for proto in sorted(generic, key=lambda p: -counts.get(p, 0)):
            print(f"  {proto}/{generic[proto]}  x{counts.get(proto, 0)}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else DEFAULT_LOG))
