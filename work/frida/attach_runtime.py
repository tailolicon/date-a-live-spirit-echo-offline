#!/usr/bin/env python3
"""Start the original-signed game, attach 32-bit Frida, patch login URLs on the heap."""
from __future__ import annotations

import os
import subprocess
import sys
import time

import frida

DEV = os.environ.get("DAL_DEVICE", "127.0.0.1:16384")
PKG = "com.datealive.action.rpg"
ACT = PKG + "/org.cocos2dx.TerransForce.SplashActivity"
PORT = os.environ.get("DAL_FRIDA_PORT", "27045")
SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "runtime.js")
FS = "/data/local/tmp/frida-server-dal32"


def adb(*a):
    return subprocess.run(["adb", "-s", DEV, *a], capture_output=True, text=True)


def main() -> int:
    adb("connect", DEV)
    adb("shell", "su", "-c", "echo 0 > /sys/fs/selinux/enforce")
    for p in (18099, 18100, 18082, 8082):
        adb("reverse", f"tcp:{p}", f"tcp:{p}" if p != 8082 else "tcp:18082")
    adb("forward", f"tcp:{PORT}", f"tcp:{PORT}")

    # 32-bit frida-server (game is app_process32 / houdini)
    subprocess.Popen(
        ["adb", "-s", DEV, "shell", f"su -c '{FS} -l 127.0.0.1:{PORT}'"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )
    time.sleep(2)

    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.4)
    adb("shell", "am", "start", "-n", ACT)

    pid = None
    for _ in range(40):
        time.sleep(0.4)
        toks = (adb("shell", "pidof", PKG).stdout or "").split()
        if toks:
            pid = int(toks[0])
            break
    if pid is None:
        print("no game pid", flush=True)
        return 1
    print("attach pid", pid, flush=True)

    d = frida.get_device_manager().add_remote_device("127.0.0.1:%s" % PORT)
    s = d.attach(pid)
    scr = s.create_script(open(SCRIPT, encoding="utf-8").read())
    scr.on("message", lambda m, _d: print("MSG", m, flush=True))
    scr.load()
    print("runtime.js loaded — keep this window open", flush=True)
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
