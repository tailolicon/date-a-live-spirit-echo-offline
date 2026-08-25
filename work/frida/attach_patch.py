#!/usr/bin/env python3
import os, subprocess, time, sys
import frida

DEV = os.environ.get("DAL_DEVICE", "127.0.0.1:16384")
PKG = "com.datealive.action.rpg"
PORT = os.environ.get("DAL_FRIDA_PORT", "27045")
SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "heap_patch.js")


def adb(*a):
    return subprocess.run(["adb", "-s", DEV, *a], capture_output=True, text=True)


def main():
    adb("reverse", "tcp:18099", "tcp:18099")
    adb("reverse", "tcp:18100", "tcp:18100")
    adb("forward", "tcp:"+PORT, "tcp:"+PORT)
    adb("shell", "am", "force-stop", PKG)
    time.sleep(0.5)
    adb("shell", "am", "start", "-n", PKG+"/org.cocos2dx.TerransForce.SplashActivity")
    pid = None
    for _ in range(40):
        time.sleep(0.5)
        r = adb("shell", "pidof", PKG)
        toks = (r.stdout or "").split()
        if toks:
            pid = int(toks[0]); break
    if not pid:
        print("no pid"); return 1
    print("pid", pid, flush=True)
    # 64-bit server
    proc = subprocess.Popen(
        ["adb", "-s", DEV, "shell",
         "su -c '/data/local/tmp/frida-server-dal -l 127.0.0.1:%s'" % PORT],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(2)
    d = frida.get_device_manager().add_remote_device("127.0.0.1:"+PORT)
    s = d.attach(pid)
    scr = s.create_script(open(SCRIPT, encoding="utf-8").read())
    scr.on("message", lambda m, _d: print("MSG", m, flush=True))
    scr.load()
    print("loaded, holding", flush=True)
    try:
        while True:
            time.sleep(2)
    except KeyboardInterrupt:
        pass
    return 0

if __name__ == "__main__":
    sys.exit(main())
