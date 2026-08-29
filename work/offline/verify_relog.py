#!/usr/bin/env python3
"""Log in twice and assert the tutorial does not come back.

The guide is the one piece of state whose bug only shows on the *second* login,
which makes it invisible to a single playthrough. This drives the real client
twice and reads what it did off the packet trace, so the answer does not depend
on watching the screen.

The tell is on the request side, which `tcp_server` logs in full:
`GuideDataMgr:onLogin` always sends one c2s 278 carrying `-1` ("where am I?"),
and then sends one more per guide step it *plays*. A finished guide means the
query and nothing else.

    python work/offline/verify_relog.py

Assumes PLAY.bat is already running - it needs the servers and the hot-patch.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)

DEVICE = os.environ.get("DAL_DEVICE", "127.0.0.1:16384")
PKG = "com.datealive.action.rpg"
ACTIVITY = f"{PKG}/org.cocos2dx.TerransForce.TerransForce"
TCP_LOG = os.path.join(ROOT, "logs", "tcp.log")
LUA_LOG = os.path.join(ROOT, "logs", "lua_errors.log")

# The logged peer is a Python tuple repr, so it has a space in it: match loosely.
GUIDE_REQUEST = re.compile(r"<- .*proto=278/\S+.*\bbody=([0-9a-f]*)")
# The client's `-1` sentinel, widened into an unsigned varint.
QUERY_FLOOR = 0x7FFFFFFF


def adb(*args: str, timeout: int = 30) -> str:
    try:
        done = subprocess.run(["adb", "-s", DEVICE, *args],
                              capture_output=True, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return ""
    return (done.stdout or "") + (done.stderr or "")


def device_ready() -> bool:
    subprocess.run(["adb", "connect", DEVICE], capture_output=True, text=True)
    return adb("shell", "getprop", "sys.boot_completed").strip() == "1"


def read_varint(body: bytes, index: int) -> tuple[int, int]:
    value = shift = 0
    while index < len(body):
        byte = body[index]
        index += 1
        value |= (byte & 0x7F) << shift
        shift += 7
        if not byte & 0x80:
            break
    return value, index


def guide_requests(trace: str) -> tuple[int, list[int]]:
    """(queries, steps reported) for the c2s 278 traffic in one login."""
    queries = 0
    steps: list[int] = []
    for line in trace.splitlines():
        match = GUIDE_REQUEST.search(line)
        if not match:
            continue
        body = bytes.fromhex(match.group(1))
        if not body or body[0] != 0x08:
            queries += 1
            continue
        value, _ = read_varint(body, 1)
        if value > QUERY_FLOOR:
            queries += 1
        else:
            steps.append(value)
    return queries, steps


def log_size() -> int:
    return os.path.getsize(TCP_LOG) if os.path.isfile(TCP_LOG) else 0


def log_since(offset: int) -> str:
    if not os.path.isfile(TCP_LOG):
        return ""
    with open(TCP_LOG, encoding="utf-8", errors="replace") as handle:
        handle.seek(offset)
        return handle.read()


def wait_for(offset: int, needle: str, seconds: int) -> bool:
    deadline = time.time() + seconds
    while time.time() < deadline:
        if needle in log_since(offset):
            return True
        time.sleep(2)
    return False


def login() -> str:
    """Force-restart the game, tap through to MainScene, return the new trace."""
    offset = log_size()
    adb("shell", "am", "force-stop", PKG)
    time.sleep(2)
    adb("shell", "am", "start", "-n", ACTIVITY)
    # The title needs two taps: one raises the server bar, one logs in.
    deadline = time.time() + 150
    while time.time() < deadline and "LOGIN_ENTER" not in log_since(offset):
        adb("shell", "input", "tap", "960", "540")
        time.sleep(6)
    wait_for(offset, "278/PLAYER_REQ_NEW_PLAYER_GUIDE", 90)
    # Let the guide, if it runs at all, report its first few steps.
    time.sleep(25)
    return log_since(offset)


def lua_errors_since(marker: int) -> list[str]:
    if not os.path.isfile(LUA_LOG):
        return []
    with open(LUA_LOG, encoding="utf-8", errors="replace") as handle:
        handle.seek(marker)
        return [line.strip() for line in handle if "LUA ERROR" in line]


def main() -> int:
    if not device_ready():
        print(f"! {DEVICE} is not reachable - start MuMu, then PLAY.bat")
        return 1
    if not os.path.isfile(TCP_LOG):
        print(f"! no {TCP_LOG} - is PLAY.bat running?")
        return 1

    lua_marker = os.path.getsize(LUA_LOG) if os.path.isfile(LUA_LOG) else 0
    failures: list[str] = []

    for label in ("first", "second"):
        print(f"[{label} login]")
        queries, steps = guide_requests(login())
        print(f"  c2s 278: {queries} query, {len(steps)} step report(s) {steps[:8]}")
        if queries == 0:
            failures.append(f"{label} login: the client never asked for its guide step")
        if label == "second" and steps:
            failures.append(
                f"second login: the client replayed {len(steps)} guide step(s) "
                f"{steps[:8]} - the tutorial is still coming back")

    from player_save import load_save
    step = load_save().get("newPlayerGuideStep")
    print(f"saved guide step: {step}")
    if not isinstance(step, int) or step <= 0:
        failures.append("the save did not record a guide step")

    errors = lua_errors_since(lua_marker)
    if errors:
        failures.append(f"{len(errors)} new Lua error(s); first: {errors[0][-120:]}")

    if failures:
        print("\nFAIL")
        for row in failures:
            print(f"  - {row}")
        return 1
    print("\nOK - no guide steps replayed on the second login, and no Lua errors")
    return 0


if __name__ == "__main__":
    sys.exit(main())
