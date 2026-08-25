#!/usr/bin/env python3
import subprocess, time, frida, sys

DEV = "127.0.0.1:16384"
PORT = "27045"
cmd = ["adb", "-s", DEV, "shell",
       "su -c '/data/local/tmp/frida-server-dal -l 127.0.0.1:%s'" % PORT]
print("cmd", cmd, flush=True)
p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
time.sleep(3)
print("poll", p.poll(), flush=True)
if p.poll() is not None:
    print("out", p.stdout.read()[:2000], flush=True)
    sys.exit(1)
d = frida.get_device_manager().add_remote_device("127.0.0.1:%s" % PORT)
print("nprocs", len(d.enumerate_processes()), flush=True)
pid = d.spawn(["com.datealive.action.rpg"])
print("spawned", pid, flush=True)
d.kill(pid)
print("ok", flush=True)
