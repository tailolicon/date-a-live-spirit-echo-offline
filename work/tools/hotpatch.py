#!/usr/bin/env python3
"""Push patched lua into the game's hot-update search path (no APK rebuild).

Android search order (TFFramework/ResPathConfig.lua) puts
  <writablePath>TFDebug/
in front of the APK assets, so a file dropped at
  /data/data/<pkg>/files/TFDebug/src/<rel>
overrides assets/src/<rel>.

Usage:
  python work/tools/hotpatch.py apply     # patch + push everything
  python work/tools/hotpatch.py revert    # remove our overrides
  python work/tools/hotpatch.py dump <assets/src/...lua>
"""
from __future__ import annotations

import os
import subprocess
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua_crypt import decrypt_bytes, encrypt_bytes  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
APK = os.path.join(REPO, "work", "apk", "com.datealive.action.rpg.apk")
DEVICE = os.environ.get("DAL_DEVICE", "127.0.0.1:16384")
PKG = "com.datealive.action.rpg"
# The engine builds its search path from two different roots (ResPathConfig.lua
# uses the sdcard "playmore" tree, AssetsMgr/TFPathConfig use getWritablePath).
# Which one wins per file is not worth chasing - write both, or a stale copy in
# the other tree silently keeps running.
REMOTES = [
    f"/storage/emulated/0/Android/data/{PKG}/files/playmore/{PKG}/TFDebug/src",
    f"/data/data/{PKG}/files/TFDebug/src",
]
REMOTE = REMOTES[0]
STAGE = os.path.join(REPO, "work", "hotpatch")
HOST_IP = os.environ.get("DAL_HOST_IP", "10.0.2.2")
HTTP_PORT = os.environ.get("DAL_HTTP_PORT", "18099")
BASE = f"http://{HOST_IP}:{HTTP_PORT}"


def adb(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(["adb", "-s", DEVICE, *args], capture_output=True, text=True)


def sh(cmd: str) -> str:
    r = adb("shell", "su -c '%s'" % cmd.replace("'", "'\''"))
    return (r.stdout or "") + (r.stderr or "")


def read_asset(rel: str) -> str:
    with zipfile.ZipFile(APK) as z:
        return decrypt_bytes(z.read("assets/src/" + rel)).decode("utf-8")


# ---------------------------------------------------------------- patches


def patch_utilhelper(src: str) -> str:
    """All account/notice endpoints -> local HTTP server (no TLS, no frida).

    Also re-enables lua print/dump: the release build stubs them out, which
    hides every net-layer diagnostic the game already emits.
    """
    import re
    src = src.replace("DEBUG_LOG = false", "DEBUG_LOG = true", 1)
    src = re.sub(r'"https?://[^"]*?/account/querydate"', f'"{BASE}/account/querydate"', src)
    src = re.sub(r'"https?://[^"]*?/globalNotice/get_global_notice"',
                 f'"{BASE}/globalNotice/get_global_notice"', src)
    src = re.sub(r'"https?://[^"]*?/account"', f'"{BASE}/account"', src)
    return src


MODE = os.environ.get("DAL_CIPHER_MODE", "zerokey")


def patch_commonmanager(src: str) -> str:
    """Neutralise the native packet cipher.

    Two strategies, selected by DAL_CIPHER_MODE:

    plainsend  setEncodeEnable(false). Confirmed to make the *outgoing*
               direction plaintext, but the client still refuses everything we
               send, so its receive path keeps decoding.
    zerokey    Leave the cipher engaged but hand it an all-zero key in both
               directions. If the keystream is derived from the key alone this
               turns both directions into identity; the client's own outgoing
               bytes tell us immediately whether it worked.
    """
    helper = '''
-- [DAL-OFFLINE] cipher-neutralising helper
local function __dal_plain(tag)
    local net = TFDirector:getNetWork()
    if not net then print("[DAL-OFFLINE] no net ("..tostring(tag)..")") return end
    local mode = "%MODE%"
    local ok1, ok2 = true, true
    if mode == "none" then
        -- leave the stock cipher completely alone
    elseif mode == "plainsend" then
        ok2 = pcall(function() net:SetUseDKeys(false) end)
        ok1 = pcall(function() net:setEncodeEnable(false) end)
    elseif mode == "zerokey2" then
        -- keys first, then kill the dynamic-key stream: SetEncodeKeys may well
        -- re-arm it, which would explain why the other order still encrypted.
        ok1 = pcall(function() net:SetEncodeKeys({0,0,0,0,0,0,0,0}) end)
        ok2 = pcall(function() net:SetUseDKeys(false) end)
    elseif mode == "dkeysoff" then
        ok2 = pcall(function() net:SetUseDKeys(false) end)
    else
        ok2 = pcall(function() net:SetUseDKeys(false) end)
        ok1 = pcall(function() net:SetEncodeKeys({0,0,0,0,0,0,0,0}) end)
    end
    print(string.format("[DAL-OFFLINE] cipher(%s/%s) ok=%s dkeys=%s",
        tostring(tag), mode, tostring(ok1), tostring(ok2)))
end

'''.replace("%MODE%", MODE)
    anchor = "--连接服务器\nfunction CommonManager:connectServer(requestLogin)"
    if anchor not in src:
        anchor = "function CommonManager:connectServer(requestLogin)"
    src = src.replace(anchor, helper + anchor, 1)

    probe = ""
    if os.environ.get("DAL_PROBE_LUA"):
        # Same idea, but with explicit payloads: a lua list of {protoId, args}
        # so we can watch how X moves with body content and length.
        probe = ("\n    for _, __e in ipairs(" + os.environ["DAL_PROBE_LUA"] + ") do\n"
                 "        pcall(function() TFDirector:getNetWork():Send(__e[1], __e[2]) end)\n"
                 "    end\n")
    elif os.environ.get("DAL_PROBE"):
        # Make the client emit one frame per proto id so the server log gives us
        # the header word X for each. X is constant per proto; this is how we
        # work out what it is derived from.
        ids = os.environ["DAL_PROBE"]
        probe = ("\n    for _, __pid in ipairs({" + ids + "}) do\n"
                 "        local __ok, __err = pcall(function()\n"
                 "            return TFDirector:getNetWork():Send(__pid, {})\n"
                 "        end)\n"
                 "        print(\"[DAL-PROBE] \"..tostring(__pid)..\" ok=\"..tostring(__ok)\n"
                 "              ..\" r=\"..tostring(__err))\n"
                 "    end\n")

    old = "    TFDirector:setEncodeKeys({0xac, 0x12, 0x19, 0xcd, 0x95, 0x34, 0xcb, 0xf1})"
    new = (old + "\n"
           "    __dal_plain(\"connect\")\n"
           # Native packet hex dumps are useful but drown logcat once frames
           # are 64KB, so keep them behind an env switch.
           + ("    pcall(function() TFDirector:SetNetLogEnable(true) end)\n"
              if os.environ.get("DAL_NETLOG") else "") +
           "    print(\"[DAL-OFFLINE] connectHandle nResult=\"..tostring(nResult))"
           + probe)
    assert old in src, "connectHandle key line missing"
    src = src.replace(old, new, 1)

    old2 = "    TFDirector:setEncodeKeys({1,2,3,4,5,6,7,8})"
    new2 = old2 + "\n    __dal_plain(\"afterlogin\")"
    assert old2 in src, "sendLogin key line missing"
    src = src.replace(old2, new2, 1)

    old3 = '        dump(loginMsg,"send login : ")'
    if old3 in src:
        src = src.replace(
            old3,
            old3 + '\n        print("[DAL-OFFLINE] sending LOGIN_ENTER_GAME token="..tostring(token))',
            1)
    return src


def patch_clientnet(src: str) -> str:
    """Trace the native -> lua receive path so we can see where packets die."""
    src = 'print("[DAL-OFFLINE] TFClientNet.lua override loaded")\n' + src
    hooks = [
        ("function TFClientNet:RecvCallback(nRet)",
         '\n\tprint("[DAL-OFFLINE] RecvCallback nRet="..tostring(nRet))'),
        ("\tnProtoType = self:UnpackType()",
         '\n\tprint("[DAL-OFFLINE] recv proto="..tostring(nProtoType))'),
        ("function TFClientNet:CloseCallback(nRet)",
         '\n\tprint("[DAL-OFFLINE] CloseCallback "..tostring(nRet))'),
        ("function TFClientNet:ConnectCallback(nRet)",
         '\n\tprint("[DAL-OFFLINE] ConnectCallback "..tostring(nRet))'),
    ]
    for anchor, inject in hooks:
        if anchor not in src:
            print("!! TFClientNet anchor missing:", anchor.strip())
            continue
        src = src.replace(anchor, anchor + inject, 1)
    return src


def patch_network(src: str) -> str:
    """Show which login messages are still outstanding.

    The scene only switches once every id registered by a DataMgr's onLogin has
    come back (NetWork:handleLoginMsg empties __waitLoginMsg). If one id never
    arrives the client sits on the login screen with no error at all, so print
    the pending set.
    """
    anchor = "function NetWork:checkLoginMsgOver()"
    if anchor not in src:
        print("!! NetWork anchor missing")
        return src
    return src.replace(
        anchor,
        anchor + '\n    print("[DAL-WAIT] pending: "..table.concat(__waitLoginMsg, ","))',
        1)


PATCHES = {
    "lua/UtilHelper.lua": patch_utilhelper,
    "lua/gamedata/CommonManager.lua": patch_commonmanager,
    "lua/net/NetWork.lua": patch_network,
    "TFFramework/net/TFClientNet.lua": patch_clientnet,
}


# ---------------------------------------------------------------- driver


def apply() -> int:
    os.makedirs(STAGE, exist_ok=True)
    for rel, fn in PATCHES.items():
        plain = read_asset(rel)
        patched = fn(plain)
        if patched == plain:
            print(f"!! {rel}: patch produced no change")
        local = os.path.join(STAGE, rel.replace("/", os.sep))
        os.makedirs(os.path.dirname(local), exist_ok=True)
        with open(local, "w", encoding="utf-8", newline="") as f:
            f.write(patched)
        blob = encrypt_bytes(patched.encode("utf-8"))
        enc = local + ".enc"
        with open(enc, "wb") as f:
            f.write(blob)

        base = os.path.basename(rel)
        tmp = f"/data/local/tmp/{base}.enc"
        adb("push", enc, tmp)
        for root in REMOTES:
            remote_dir = root + "/" + os.path.dirname(rel)
            sh(f"mkdir -p {remote_dir} && cp {tmp} {remote_dir}/{base} && "
               f"chmod -R 777 {root} && chmod 666 {remote_dir}/{base}")
        stamps = [sh(f"ls -la {r}/{rel}").strip().split()[-2:] for r in REMOTES]
        print(f"pushed {rel}: {stamps}")
    return 0


def revert() -> int:
    for rel in PATCHES:
        for root in REMOTES:
            sh(f"rm -f {root}/{rel}")
        print("removed", rel)
    return 0


def dump(name: str) -> int:
    with zipfile.ZipFile(APK) as z:
        sys.stdout.write(decrypt_bytes(z.read(name)).decode("utf-8"))
    return 0


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "apply"
    if cmd == "apply":
        sys.exit(apply())
    if cmd == "revert":
        sys.exit(revert())
    if cmd == "dump":
        sys.exit(dump(sys.argv[2]))
    print(__doc__)
    sys.exit(2)
