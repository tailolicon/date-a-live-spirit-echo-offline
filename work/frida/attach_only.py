#!/usr/bin/env python3
"""Attach 32-bit Frida to the already-running game. Does not restart it."""
from __future__ import annotations

import os, subprocess, sys, time
import frida

DEV = os.environ.get("DAL_DEVICE", "127.0.0.1:16384")
PKG = "com.datealive.action.rpg"
PORT = os.environ.get("DAL_FRIDA_PORT", "27045")
SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "runtime.js")
FS = "/data/local/tmp/frida-server-dal32"


def adb(*a):
    return subprocess.run(["adb", "-s", DEV, *a], capture_output=True, text=True)


def main() -> int:
    adb("reverse", "tcp:18099", "tcp:18099")
    adb("reverse", "tcp:18100", "tcp:18100")
    adb("reverse", "tcp:8082", "tcp:18082")
    adb("forward", f"tcp:{PORT}", f"tcp:{PORT}")
    adb("shell", "su", "-c", "echo 0 > /sys/fs/selinux/enforce")
    subprocess.Popen(
        ["adb", "-s", DEV, "shell", f"su -c '{FS} -l 127.0.0.1:{PORT}'"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    time.sleep(2)
    toks = (adb("shell", "pidof", PKG).stdout or "").split()
    if not toks:
        print("game not running", flush=True)
        return 1
    pid = int(toks[0])
    print("attach pid", pid, flush=True)
    d = frida.get_device_manager().add_remote_device("127.0.0.1:%s" % PORT)
    s = d.attach(pid)
    scr = s.create_script(open(SCRIPT, encoding="utf-8").read())
    scr.on("message", lambda m, _d: print("MSG", m, flush=True))
    scr.load()
    print("loaded — keep open", flush=True)
    try:
        while True:
            time.sleep(2)
            if not (adb("shell", "pidof", PKG).stdout or "").strip():
                print("game died", flush=True)
                return 0
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    sys.exit(main())
