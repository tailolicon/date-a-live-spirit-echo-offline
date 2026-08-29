#!/usr/bin/env python3
"""Run the client's own GuideDataMgr against the bytes this server sends.

The tutorial bug only shows on the *second* login, so a single playthrough
cannot see it and neither can reading the code. This closes most of that gap
without a device: the real `lua/dataMgr/GuideDataMgr.lua`, the real
`TFFramework/base/class.lua`, and the real `Guide` table out of the APK, driven
with the actual s2c 278 body `player_handlers` produces.

What it does not cover is rendering and input - a device still owns that. What
it does cover is the decision: given this reply, does the client set out to
replay the new-player guide?
"""
from __future__ import annotations

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

try:
    import lupa
except ImportError:  # pragma: no cover - optional dependency
    lupa = None

import player_handlers as player  # noqa: E402
import proto_validate  # noqa: E402
from game_static_config import StaticConfigUnavailable, config as static_config  # noqa: E402
from protocol_schema import decode_fields, encode_fields, registry  # noqa: E402

REFERENCE = os.path.abspath(os.path.join(HERE, "..", "..", "reference", "lua"))
CLASS_LUA = os.path.join(REFERENCE, "TFFramework", "base", "class.lua")
BASE_LUA = os.path.join(REFERENCE, "lua", "dataMgr", "BaseDataMgr.lua")
GUIDE_LUA = os.path.join(REFERENCE, "lua", "dataMgr", "GuideDataMgr.lua")
QUERY = 0xFFFFFFFF

# Enough of the game's globals for GuideDataMgr to load and answer. Anything it
# only calls for side effects is a no-op; nothing here fakes a decision.
PRELUDE = """
local recorded = {}
_G.recorded = recorded

function clone(object)
    local lookup = {}
    local function copy(item)
        if type(item) ~= "table" then return item end
        if lookup[item] then return lookup[item] end
        local out = {}
        lookup[item] = out
        for key, value in pairs(item) do out[copy(key)] = copy(value) end
        return setmetatable(out, getmetatable(item))
    end
    return copy(object)
end

local counter = 0
function getObjectCount() counter = counter + 1 return counter end
function print(...) end
function dump(...) end
function import(_) return _G.BASE_DATA_MGR end
function handler(obj, method) return function(...) return method(obj, ...) end end

CCUserDefault = {sharedUserDefault = function() return {
    getIntegerForKey = function() return 0 end,
    setIntegerForKey = function() end,
    getBoolForKey = function() return false end,
    setBoolForKey = function() end,
    flush = function() end,
} end}

TFDirector = {
    addProto = function() end,
    send = function(_, code, msg) recorded[#recorded + 1] = {code = code, msg = msg} end,
}
EventMgr = {addEventListener = function() end, dispatchEvent = function() end}
CommonManager = {
    firstLoginIn = nil,
    setFirstLoginIn = function(self, value) self.firstLoginIn = value end,
    getFirstLoginIn = function(self) return self.firstLoginIn end,
}
c2s = setmetatable({}, {__index = function() return 0 end})
s2c = setmetatable({}, {__index = function() return 0 end})
"""


def to_lua(lua, value):
    """Rebuild a decoded body as real Lua tables.

    Handing lupa a Python list leaves it 0-indexed, so the client's `ipairs`
    walks off the end. The client is given Lua tables on a device; give it Lua
    tables here, or the harness tests lupa's bridging instead of the game.
    """
    if isinstance(value, dict):
        table = lua.table()
        for key, item in value.items():
            table[key] = to_lua(lua, item)
        return table
    if isinstance(value, (list, tuple)):
        table = lua.table()
        for index, item in enumerate(value, start=1):
            table[index] = to_lua(lua, item)
        return table
    return value


def tables_available() -> bool:
    try:
        static_config().table("Guide")
    except StaticConfigUnavailable:
        return False
    return True


def server_reply(state: dict, guide_id: int) -> dict:
    """The decoded body `player_handlers` actually puts on the wire."""
    body, _ = player.response_for(
        player.PLAYER_REQ_NEW_PLAYER_GUIDE, state,
        encode_fields(registry().c2s[player.PLAYER_REQ_NEW_PLAYER_GUIDE],
                      {"guideId": guide_id}))
    assert proto_validate.validate(player.PLAYER_REQ_NEW_PLAYER_GUIDE, body).ok
    return decode_fields(registry().s2c[player.PLAYER_REQ_NEW_PLAYER_GUIDE], body)


@unittest.skipIf(lupa is None, "needs lupa for a real Lua VM")
@unittest.skipUnless(os.path.isfile(GUIDE_LUA), "needs reference/lua")
@unittest.skipUnless(tables_available(), "needs work/apk/base-offline.apk")
class GuideDataMgrAgainstRealRepliesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.guide_table = static_config().table("Guide")

    def build(self):
        """A fresh GuideDataMgr, loaded from the client's own source."""
        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        lua.execute(PRELUDE)
        with open(CLASS_LUA, encoding="utf-8", errors="replace") as handle:
            lua.execute(handle.read())
        with open(BASE_LUA, encoding="utf-8", errors="replace") as handle:
            lua.globals().BASE_DATA_MGR = lua.execute(handle.read())
        guide = lua.execute("return (function() " + self.guide_table + " end)()")
        # Not `__guide`: Python name-mangles a `__name` attribute written inside
        # a class body, so the stub would read a global nobody ever set.
        lua.globals().GUIDE_TABLE = guide
        lua.globals().TabDataMgr = lua.eval(
            "{getData = function(_, name) if name == 'Guide' then return _G.GUIDE_TABLE end end}")
        with open(GUIDE_LUA, encoding="utf-8", errors="replace") as handle:
            manager = lua.execute(handle.read())
        return lua, manager

    def send(self, lua, manager, reply: dict) -> None:
        """Hand the decoded body to the real proto handler, as a Lua table."""
        manager.recvSaveStep(manager, to_lua(lua, {"data": reply}))

    def test_the_manager_agrees_on_how_many_steps_there_are(self) -> None:
        """If the counts disagree, `finish` means different things on each side."""
        lua, manager = self.build()
        self.assertEqual(int(manager.maxNewStep),
                         static_config().new_guide_step_count())

    def test_a_fresh_save_starts_the_tutorial(self) -> None:
        """The control: the guide must still run for a brand-new player."""
        lua, manager = self.build()
        self.send(lua, manager, server_reply({}, QUERY))
        self.assertTrue(manager.newGuiding, "a new player should get the tutorial")
        manager.resetNewGuideStep(manager)
        self.assertTrue(manager.newGuiding)

    def test_a_finished_save_does_not_replay_the_tutorial(self) -> None:
        """The bug, as the client sees it."""
        lua, manager = self.build()
        finished = {"newPlayerGuideStep": 9999}
        self.send(lua, manager, server_reply(finished, QUERY))
        self.assertFalse(manager.newGuiding, "the guide must be off after a relog")
        manager.resetNewGuideStep(manager)
        self.assertFalse(manager.newGuiding)

    def test_a_zero_filled_reply_is_what_replayed_it(self) -> None:
        """Pin the regression: the old answer, through the same real code."""
        lua, manager = self.build()
        self.send(lua, manager, {"guideId": 0, "finish": False})
        self.assertTrue(manager.newGuiding,
                        "a zero-filled 278 is exactly what restarted the tutorial")

    def test_skipping_sticks_across_the_relog(self) -> None:
        """Skip reports the last step; the next login must come back finished."""
        state: dict = {}
        last = static_config().new_guide_step_count()
        server_reply(state, last)          # the Skip button's report
        lua, manager = self.build()
        self.send(lua, manager, server_reply(state, QUERY))
        self.assertFalse(manager.newGuiding)
        manager.resetNewGuideStep(manager)
        self.assertFalse(manager.newGuiding)

    def test_a_mid_tutorial_relog_resumes_instead_of_restarting(self) -> None:
        state: dict = {}
        for step in (1, 2, 3):
            server_reply(state, step)
        lua, manager = self.build()
        self.send(lua, manager, server_reply(state, QUERY))
        self.assertTrue(manager.newGuiding, "the tutorial is not over yet")
        # Subscript, not attribute: `manager.__step` would mangle here too.
        self.assertEqual(int(manager["__step"]), 4,
                         "it must resume at step 4, not restart at 1")


if __name__ == "__main__":
    unittest.main()
