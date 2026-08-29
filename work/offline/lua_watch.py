#!/usr/bin/env python3
"""Surface the client's own Lua errors while it runs.

The game never shows a Lua error on screen. It hands the message and traceback
to Bugly (`Bugly:ReportLuaException`, and the crash handler's `recordException`
bridge call) and carries on, so a broken handler looks like a screen that
simply stops responding - which is why breakage here has had to be found by
playing to it and guessing.

Both paths reach logcat, so tailing it turns every one of those silent failures
into a named function and line number the moment it happens.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.abspath(__file__))
DEVICE = os.environ.get("DAL_DEVICE", "127.0.0.1:16384")
LOG = os.path.join(ROOT, "logs", "lua_errors.log")

# Bugly's own report call, the JNI bridge the crash reporter uses, and the
# handler-level complaints the game prints before bailing out of a response.
PATTERNS = (
    re.compile(r"LUA ERROR:"),
    re.compile(r"\[LUA-print\].*recv no \w+"),
    re.compile(r"can not found \w+"),
    re.compile(r"ReportLuaException"),
)
# A traceback follows the first line; keep printing until the frames run out.
TRACE = re.compile(r"^\s*(stack traceback:|\\9|\[string \")")
QUIET = re.compile(r"心跳|getFreeMem|CCLuaJavaBridge|JniHelper")


def interesting(line: str) -> bool:
    if QUIET.search(line):
        return False
    return any(pattern.search(line) for pattern in PATTERNS)


def main() -> int:
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    subprocess.run(["adb", "-s", DEVICE, "logcat", "-c"], capture_output=True)
    proc = subprocess.Popen(
        ["adb", "-s", DEVICE, "logcat", "-v", "time"],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, errors="replace", bufsize=1)
    print(f"lua watchdog on {DEVICE} -> {LOG}", flush=True)
    trailing = 0
    with open(LOG, "a", encoding="utf-8") as handle:
        handle.write(f"\n=== session {time.strftime('%Y-%m-%d %H:%M:%S')} ===\n")
        handle.flush()
        for line in proc.stdout or []:
            line = line.rstrip("\n")
            if interesting(line):
                trailing = 40
            elif trailing > 0 and TRACE.search(line):
                trailing -= 1
            else:
                trailing = max(0, trailing - 1) if trailing else 0
                continue
            print(f"[LUA] {line}", flush=True)
            handle.write(line + "\n")
            handle.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main())
