#!/usr/bin/env python3
"""Spawn Date A Live: Spirit Echo suspended, inject Frida, resume."""
from __future__ import annotations

import os
import subprocess
import sys
import time

import frida

PKG = "com.datealive.action.rpg"
DEV = os.environ.get("DAL_DEVICE", "127.0.0.1:16384")
FRIDA_PORT = os.environ.get("DAL_FRIDA_PORT", "27045")
SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "offline.js")
HOLD = int(sys.argv[1]) if len(sys.argv) > 1 else 36000


def adb(*a):
    return subprocess.run(["adb", "-s", DEV, *a], capture_output=True, text=True)


def get_device():
    return frida.get_device_manager().add_remote_device("127.0.0.1:%s" % FRIDA_PORT)


def main() -> int:
    adb("shell", "am", "force-stop", PKG)
    adb("reverse", "tcp:18099", "tcp:18099")
    adb("reverse", "tcp:18100", "tcp:18100")
    time.sleep(0.8)
    dev = get_device()
    pid = None
    spawned = False
    for attempt in range(3):
        try:
            pid = dev.spawn([PKG])
            spawned = True
            break
        except Exception as e:
            print("spawn retry", attempt, e, flush=True)
            time.sleep(1.0)
    if pid is None:
        print("spawn failed; am start + attach", flush=True)
        adb("shell", "am", "force-stop", PKG)
        adb("shell", "am", "start", "-n",
            PKG + "/org.cocos2dx.TerransForce.SplashActivity")
        for _ in range(25):
            time.sleep(0.4)
            r = adb("shell", "pidof", PKG)
            toks = (r.stdout or "").split()
            if toks:
                pid = int(toks[0])
                break
        if pid is None:
            print("no pid after am start", flush=True)
            return 1
        print("attach pid=%s" % pid, flush=True)
        sess = dev.attach(pid)
    else:
        print("spawned pid=%s" % pid, flush=True)
        sess = dev.attach(pid)
    scr = sess.create_script(open(SCRIPT, encoding="utf-8").read())

    def on_msg(m, _d):
        print("MSG", m, flush=True)

    scr.on("message", on_msg)
    scr.load()
    if spawned:
        print("script loaded; resuming", flush=True)
        dev.resume(pid)
    else:
        print("script loaded (attached)", flush=True)
    t0 = time.time()
    while time.time() - t0 < HOLD:
        time.sleep(1)
        try:
            if not any(p.pid == pid for p in dev.enumerate_processes()):
                print("game process gone", flush=True)
                return 0
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
