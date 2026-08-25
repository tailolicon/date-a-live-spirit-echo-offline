#!/usr/bin/env python3
"""Launch Date A Live: Spirit Echo against the local private server.

The stack is now just three pieces - no Frida, no TLS front, no APK rebuild:

  1. work/tools/hotpatch_main_scene.py drops the existing offline lua patches
     plus zero-state MainScene guards into the game's TFDebug search path.
  2. http_server.py :18099   account/getServerInfo, /login, /querydate, notices.
  3. tcp_server_main_scene.py :18100 wraps the game server with the minimum
     persistent dungeon state needed to enter the normal MainLayer.

The device reaches this machine at 10.0.2.2 (MuMu is 10.0.2.15/24), so the
patched URLs point straight there and no adb reverse or connect() hook is
needed. Keep this window open; Ctrl+C stops the servers and the game.
"""
from __future__ import annotations

import os
import socket
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
DEVICE = os.environ.get("DAL_DEVICE", "127.0.0.1:16384")
PKG = "com.datealive.action.rpg"
ACTIVITY = f"{PKG}/org.cocos2dx.TerransForce.TerransForce"
HTTP_PORT = int(os.environ.get("DAL_HTTP_PORT", "18099"))
GAME_PORT = int(os.environ.get("DAL_GAME_PORT", "18100"))
DIAG = os.path.join(ROOT, "logs")


def adb(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["adb", "-s", DEVICE, *args], capture_output=True, text=True)


def adb_any(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["adb", *args], capture_output=True, text=True)


def device_online() -> bool:
    out = adb_any("devices").stdout or ""
    return any(line.startswith(DEVICE) and "\tdevice" in line for line in out.splitlines())


def ensure_device() -> bool:
    if device_online():
        return True
    adb_any("connect", DEVICE)
    time.sleep(1)
    if not device_online():
        adb_any("start-server")
        adb_any("connect", DEVICE)
        time.sleep(1)
    return device_online()


def port_free(port: int) -> None:
    """Drop whatever still holds the port from an earlier run."""
    try:
        out = subprocess.run(["netstat", "-ano"], capture_output=True, text=True).stdout
        pids = {line.split()[-1] for line in out.splitlines()
                if f":{port} " in line and "LISTENING" in line.upper()}
        for pid in pids:
            subprocess.run(["taskkill", "/PID", pid, "/F"], capture_output=True)
        if pids:
            time.sleep(1)
    except Exception:
        pass


def port_alive(port: int) -> bool:
    s = socket.socket()
    s.settimeout(1)
    try:
        s.connect(("127.0.0.1", port))
        return True
    except Exception:
        return False
    finally:
        s.close()


def spawn(script: str, logname: str) -> subprocess.Popen:
    return subprocess.Popen(
        [sys.executable, "-u", os.path.join(ROOT, script)],
        cwd=REPO, env=dict(os.environ),
        stdout=open(os.path.join(DIAG, logname), "w", encoding="utf-8"),
        stderr=subprocess.STDOUT)


def game_running() -> bool:
    return bool((adb("shell", "pidof", PKG).stdout or "").strip())


def main() -> int:
    os.makedirs(DIAG, exist_ok=True)
    print("[1/4] device")
    if not ensure_device():
        print(f"  ! cannot reach {DEVICE} - is MuMu running?")
        return 1

    print("[2/4] hot-patching lua")
    r = subprocess.run([sys.executable, os.path.join(REPO, "work", "tools", "hotpatch_main_scene.py"),
                        "apply"], cwd=REPO, capture_output=True, text=True,
                       env=dict(os.environ, DAL_CIPHER_MODE=os.environ.get(
                           "DAL_CIPHER_MODE", "plainsend")))
    if r.returncode != 0:
        print("  ! hotpatch failed:\n" + (r.stderr or r.stdout))
        return 1
    print("      " + "\n      ".join(
        line.split(":")[0] for line in (r.stdout or "").splitlines() if line.startswith("pushed")))

    print("[3/4] local servers")
    port_free(HTTP_PORT)
    port_free(GAME_PORT)
    procs = [spawn("http_server.py", "http.out"),
             spawn("tcp_server_main_scene.py", "tcp.out")]
    time.sleep(1.5)
    for name, port in (("HTTP", HTTP_PORT), ("game TCP", GAME_PORT)):
        if not port_alive(port):
            print(f"  ! {name} server did not come up on :{port}")

    print("[4/4] launching game")
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1)
    adb("shell", "am", "start", "-n", ACTIVITY)

    print(f"READY - keep this window open. Logs: work/offline/logs/")
    print(f"        HTTP :{HTTP_PORT}   GAME-TCP :{GAME_PORT}")
    print(f"        save: work/offline/saves/player.json")
    try:
        while True:
            time.sleep(5)
            if not ensure_device():
                print("  device dropped, reconnecting", flush=True)
    except KeyboardInterrupt:
        print("stopping")
        for p in procs:
            try:
                p.terminate()
            except Exception:
                pass
        adb("shell", "am", "force-stop", PKG)
    return 0


if __name__ == "__main__":
    sys.exit(main())
