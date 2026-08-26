#!/usr/bin/env python3
"""Hot-patch the offline client with MainScene zero-state guards.

The generic protobuf server deliberately omits empty repeated fields. This
client's custom Lua decoder leaves those fields as ``nil`` rather than ``{}``,
while several login handlers call pairs()/ipairs() unconditionally. The result
is a burst of Lua exceptions immediately before MainScene.

This wrapper keeps every existing patch from hotpatch.py and adds only the
small compatibility layer required by the zero-filled offline responses.
"""
from __future__ import annotations

import os
import sys

import hotpatch as base

DEFAULT_MAIN_UI = 100001  # Uichange.lua -> DefaultMainLayer
MARKER = "[DAL-OFFLINE] zero-state login normalization"


def patch_network(src: str) -> str:
    """Apply the normal NetWork tracing patch plus zero-state normalization."""
    if MARKER in src:
        return src
    src = base.patch_network(src)

    anchor = "    TFDirector:dispatchProtocolWith(nType, tTemp)"
    assert src.count(anchor) == 1, "NetWork dispatch anchor missing/ambiguous"

    # File-local so the descriptor table is required and unpacked once, not
    # once per received packet (the login fan-out alone is ~110 of them).
    head = "local NetHelper = require(\"TFFramework.net.NetHelper\")"
    assert src.count(head) == 1, "NetHelper require anchor missing/ambiguous"
    src = src.replace(
        head, head + "\nlocal __dalProtoDesc, __dalDescCache = nil, nil", 1)

    block = f'''    -- {MARKER}
    -- An empty repeated field is simply absent on the wire, and the client's
    -- reader turns "absent" into NULL, which PackStruct maps to nil (not {{}}).
    -- Plenty of handlers then call ipairs() on it unconditionally. Rather than
    -- chase one crash at a time, read the message's own descriptor and hand
    -- back an empty table for any repeated field that came back nil.
    --
    -- Crucially this is done *lazily*, through __index, instead of writing the
    -- keys in. Several handlers gate on the response being empty at all -
    -- MainLayer:onRecyclingItems does `if next(data)` - and materialising the
    -- fields eagerly makes an all-empty response look populated, which pops an
    -- empty dialog on every login. next()/pairs()/# ignore metatables, so the
    -- gate still sees {{}} while ipairs(data.field) gets its table.
    --
    -- protos_s2c entries are {{callback, types, names}}; types[i] and
    -- names[i] line up, except inside a nested spec where names[1] is the
    -- struct's own name and the fields start at 2 - hence the offset.
    local __dalRepeatScalar = {{
        pv4 = true, pv8 = true, tv4 = true, tv8 = true,
        ts = true, av4 = true, av8 = true, an1 = true,
    }}

    local function __dalDefer(node, key)
        local mt = getmetatable(node)
        if mt == nil then
            mt = {{__dalKeys = {{}}}}
            mt.__index = function(t, k)
                if mt.__dalKeys[k] then
                    local fresh = {{}}
                    rawset(t, k, fresh)   -- read once, then it is a real field
                    return fresh
                end
                return nil
            end
            setmetatable(node, mt)
        elseif mt.__dalKeys == nil then
            node[key] = {{}}              -- someone else owns this metatable
            return
        end
        mt.__dalKeys[key] = true
    end

    local function __dalFillFields(types, names, offset, node)
        if type(types) ~= "table" or type(names) ~= "table"
           or type(node) ~= "table" then
            return
        end
        for i = 1, #types do
            local tspec = types[i]
            local nspec = names[i + offset]
            if type(tspec) == "table" then
                local key = nil
                if type(nspec) == "table" and type(nspec[2]) == "table" then
                    key = nspec[2][1]
                end
                if type(key) == "string" then
                    local child = rawget(node, key)
                    if tspec[1] then
                        if child == nil then
                            __dalDefer(node, key)
                        elseif type(child) == "table" then
                            for _, item in ipairs(child) do
                                __dalFillFields(tspec[2], nspec[2], 1, item)
                            end
                        end
                    elseif type(child) == "table" then
                        __dalFillFields(tspec[2], nspec[2], 1, child)
                    end
                end
            elseif type(nspec) == "string" and __dalRepeatScalar[tspec]
                   and rawget(node, nspec) == nil then
                __dalDefer(node, nspec)
            end
        end
    end

    if __dalProtoDesc == nil then
        local __dalOk, __dalMod = pcall(require, "lua.net.protos_s2c")
        __dalProtoDesc = (__dalOk and type(__dalMod) == "table") and __dalMod or false
        __dalDescCache = {{}}
    end
    if __dalProtoDesc and type(tTemp) == "table" then
        local __dalDesc = __dalDescCache[nType]
        if __dalDesc == nil then
            __dalDesc = false
            local __dalMake = __dalProtoDesc[nType]
            if __dalMake then
                local __dalOk, __dalOut = pcall(__dalMake)
                if __dalOk and type(__dalOut) == "table" then
                    __dalDesc = __dalOut
                end
            end
            __dalDescCache[nType] = __dalDesc
        end
        if __dalDesc then
            __dalFillFields(__dalDesc[2], __dalDesc[3], 0, tTemp)
        end
    end

    -- Proto 3010 is otherwise generated with wearId=0, which is not a row in
    -- Uichange.lua. 100001 is the permanent bundled DefaultMainLayer.
    if nType == 3010 and (tTemp.wearId == nil or tTemp.wearId == 0) then
        tTemp.wearId = {DEFAULT_MAIN_UI}
    end

    -- Proto 6824 with roomType=0 asks for a controller that does not exist.
    -- nil intentionally takes WorldRoomDataMgr's no-room branch.
    if nType == 6824 and tTemp.roomType == 0 then
        tTemp.roomType = nil
    end

    -- Proto 8501's generated curDungeon=0 has no HuntingLevel row, and
    -- LeagueDataMgr indexes it immediately. Function 98 (guild hunting) opens
    -- at level 4; the starter offline player is level 1, so do not dispatch an
    -- impossible hunting state. The response was already collected for login
    -- accounting before this point in NetHelper.receive().
    if nType == 8501 and tTemp.curBoss and
       (tTemp.curBoss.curDungeon == nil or tTemp.curBoss.curDungeon == 0) then
        print("[DAL-OFFLINE] skip invalid HuntingDungeonInfo curDungeon=0")
        return
    end

    TFDirector:dispatchProtocolWith(nType, tTemp)'''
    return src.replace(anchor, block, 1)


# Replace only the NetWork transform. All URL/cipher/native tracing patches are
# inherited unchanged from hotpatch.py.
base.PATCHES["lua/net/NetWork.lua"] = patch_network

# ARTIFACTS.md keeps base-offline.apk on Drive. The original extracted base APK
# remains preferred, but the signed offline build contains the same Lua asset
# and is a useful fallback for a freshly-restored workspace.
if not os.path.isfile(base.APK):
    fallback = os.path.join(base.REPO, "work", "apk", "base-offline.apk")
    if os.path.isfile(fallback):
        base.APK = fallback


# MuMu normally exposes root through `su`, while debug Android Emulator system
# images can expose an already-root adb shell with no `su` binary. Keep the
# original path for MuMu but run commands directly when adbd itself is root.
_base_sh = base.sh


def _portable_device_sh(cmd: str) -> str:
    uid = base.adb("shell", "id", "-u")
    if uid.returncode == 0 and (uid.stdout or "").strip() == "0":
        r = base.adb("shell", cmd)
        return (r.stdout or "") + (r.stderr or "")
    return _base_sh(cmd)


base.sh = _portable_device_sh


def main() -> int:
    cmd = sys.argv[1] if len(sys.argv) > 1 else "apply"
    if cmd == "apply":
        return base.apply()
    if cmd == "revert":
        return base.revert()
    if cmd == "dump" and len(sys.argv) > 2:
        return base.dump(sys.argv[2])
    print(__doc__)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
