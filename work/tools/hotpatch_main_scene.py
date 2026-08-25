#!/usr/bin/env python3
"""Hot-patch the offline client with MainScene zero-state guards.

The generic protobuf server deliberately omits empty repeated fields.  This
client's custom Lua decoder leaves those fields as ``nil`` rather than ``{}``,
while several login handlers call pairs()/ipairs() unconditionally.  The
result is a burst of Lua exceptions immediately before MainScene.

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

    block = f'''    -- {MARKER}
    -- Empty repeated protobuf fields are absent on the wire. This client then
    -- decodes them as nil, but these login handlers require Lua tables.
    local __dalEmptyLists = {{
        [280]  = {{"switchs"}},
        [5663] = {{"favorList"}},
        [4869] = {{"eTypes"}},
        [5145] = {{"configList"}},
        [5120] = {{"mainAdBoardInfo"}},
        [3010] = {{"uiChange"}},
    }}
    local __dalFields = __dalEmptyLists[nType]
    if __dalFields then
        for _, __dalKey in ipairs(__dalFields) do
            if tTemp[__dalKey] == nil then
                tTemp[__dalKey] = {{}}
            end
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
