#!/usr/bin/env python3
"""Run the client's own FubenDataMgr against the bytes this server sends.

This is the original bug - "can't get into a stage" - checked against the code
that actually decided it, rather than against a reading of that code.

Two decisions made a stage unenterable, and neither raised anything:

* `onRecvLimitHeros` drops a reply whose `heros` list is empty and returns. The
  squad screen is then left with no team, and its Fight button only ever shows
  "no spirit in the lineup".
* `checkPlotLevelEnabled` gates on `MainPlayer:getPlayerLv() >= levelCfg.playerLv`,
  and `FubenLevelView` makes a locked node untouchable. A settlement that never
  paid player EXP left the map dead-ended one stage in.

The Lua here is the shipped `FubenDataMgr.lua` on the shipped `BaseDataMgr`
and `class.lua`; the tables are the complete ones out of the APK; the replies
are the real bodies `dungeon_handlers`, `combat_handlers` and
`stateful_handlers` put on the wire. Breaking either fix makes this fail - that
is checked by hand with a mutation, not assumed.
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

import combat_handlers as combat  # noqa: E402
import dungeon_handlers as dungeon  # noqa: E402
import game_static_config  # noqa: E402
import proto_validate  # noqa: E402
from game_static_config import StaticConfigUnavailable, config as static_config  # noqa: E402
from player_save import default_save  # noqa: E402
from protocol_schema import decode_fields, encode_fields, registry  # noqa: E402

REFERENCE = os.path.abspath(os.path.join(HERE, "..", "..", "reference", "lua"))
CLASS_LUA = os.path.join(REFERENCE, "TFFramework", "base", "class.lua")
BASE_LUA = os.path.join(REFERENCE, "lua", "dataMgr", "BaseDataMgr.lua")
FUBEN_LUA = os.path.join(REFERENCE, "lua", "dataMgr", "FubenDataMgr.lua")

STAGE_1_1, STAGE_1_2 = 101101, 101102
TOHKA = 110101

PRELUDE = """
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

function table.merge(target, source)
    for key, value in pairs(source or {}) do target[key] = value end
    return target
end
function table.indexOf(list, wanted)
    for index, value in ipairs(list or {}) do
        if value == wanted then return index end
    end
    return -1
end
function table.insertTo(target, source)
    for _, value in ipairs(source or {}) do table.insert(target, value) end
end
function tobool(value) return value ~= nil and value ~= false and value ~= 0 end
function math.mod(a, b) return a % b end

local counter = 0
function getObjectCount() counter = counter + 1 return counter end
function print(...) end
function dump(...) end
function Box(...) end
function import(_) return _G.BASE_DATA_MGR end
function handler(obj, method) return function(...) return method(obj, ...) end end
function requireNew(_) return {new = function() return {} end} end
function require(_) return {} end

CCUserDefault = {sharedUserDefault = function() return {
    getIntegerForKey = function() return 0 end,
    setIntegerForKey = function() end,
    getBoolForKey = function() return false end,
    setBoolForKey = function() end,
    flush = function() end,
} end}
TFDirector = {addProto = function() end, send = function() end}
EventMgr = {addEventListener = function() end, dispatchEvent = function() end}
Bugly = {ReportLuaException = function(_, message) _G.LAST_BUGLY = message end}
ServerDataMgr = {getServerTime = function() return 1787000000 end}
-- The one knob the level gate turns on.
MainPlayer = {
    level = 1,
    getPlayerLv = function(self) return self.level end,
    getPlayerExp = function() return 0 end,
    getExpProgress = function() return 0 end,
    getPlayerId = function() return 10001 end,
}
HeroDataMgr = {
    getHero = function() return nil end,
    changeDataByFuben = function() end,
    heroOnBattle = function() end,
    getIsFormationOn = function() return false end,
    getHeroIdByFormationPos = function() return nil end,
}
Utils = {showTips = function() end, getKVP = function() return {} end,
         openView = function() end, sendHttpLog = function() end}
TextDataMgr = {getText = function(_, id) return tostring(id) end}
FunctionDataMgr = {updateOpenFuncList = function() end}
CommonManager = {setStarEvaluateFlage = function() end}
AlertManager = {closeLayerByName = function() end}
TFAssetsManager = {checkChapterComplete = function() return true end}
c2s = setmetatable({}, {__index = function() return 0 end})
s2c = setmetatable({}, {__index = function() return 0 end})
EC_LimitHeroType = {NONE = 0, LIMIT_NJ = 1, LIMIT_J = 2, DISABLE = 3,
                    SIMULATION_TRIAL_LOCK = 4, SIMULATION_TRIAL = 5}
EC_BattleHeroType = {OWN = 1, LIMIT = 2, SIMULATION = 3}
EC_FBType = {PLOT = 1}
EC_FBDiff = {SIMPLE = 1}
EV_FUBEN_UPDATE_LIMITHERO = "EV_FUBEN_UPDATE_LIMITHERO"
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
        static_config().table("DungeonLevel")
    except StaticConfigUnavailable:
        return False
    return True


@unittest.skipIf(lupa is None, "needs lupa for a real Lua VM")
@unittest.skipUnless(os.path.isfile(FUBEN_LUA), "needs reference/lua")
@unittest.skipUnless(tables_available(), "needs work/apk/base-offline.apk")
class FubenDataMgrAgainstRealRepliesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        # Whole tables, straight out of the APK - the biggest is 14MB of Lua
        # and still loads in a fraction of a second.
        cls.tables = {}
        for name in ("DungeonLevel", "DungeonLevelGroup", "DungeonChapter", "Hero"):
            cls.tables[name] = static_config().table(name)

    def build(self, state: dict | None = None):
        """A fresh FubenDataMgr, loaded from the client's own source."""
        state = default_save() if state is None else state
        lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        lua.execute(PRELUDE)
        with open(CLASS_LUA, encoding="utf-8", errors="replace") as handle:
            lua.execute(handle.read())
        with open(BASE_LUA, encoding="utf-8", errors="replace") as handle:
            lua.globals().BASE_DATA_MGR = lua.execute(handle.read())
        pools = lua.table()
        for name, source in self.tables.items():
            pools[name] = lua.execute("return (function() " + source + " end)()")
        lua.globals().POOLS = pools
        # Tables outside that set are not consulted by the decisions under test;
        # an empty one keeps the manager's set-up loops harmless.
        lua.execute("""
            TabDataMgr = {getData = function(_, name, key)
                local pool = _G.POOLS[name] or {}
                if key ~= nil then return pool[key] end
                return pool
            end}
        """)
        with open(FUBEN_LUA, encoding="utf-8", errors="replace") as handle:
            manager = lua.execute(handle.read())
        # What the client does on login: clear the per-session tables, then take
        # the cleared-stage list from the server. `isPassPlotLevel` reads it.
        manager.reset(manager)
        manager.onRecvLevelInfo(manager, to_lua(lua, {"data": self.level_info(state)}))
        return lua, manager

    def level_info(self, state: dict) -> dict:
        """The real s2c 1796 body, decoded the way the client reads it."""
        import stateful_handlers

        body = stateful_handlers.encode_dungeon_level_info(state)
        assert proto_validate.validate(1796, body).ok
        return decode_fields(registry().s2c[1796], body)

    # -- the squad screen's team -------------------------------------------

    def limit_reply(self, level_cid: int) -> dict:
        body, _ = dungeon.response_for(
            dungeon.DUNGEON_LIMIT_HERO_DUNGEON, {},
            encode_fields(registry().c2s[dungeon.DUNGEON_LIMIT_HERO_DUNGEON],
                          {"levelId": level_cid}))
        self.assertTrue(proto_validate.validate(1808, body).ok)
        return decode_fields(registry().s2c[1808], body)

    def test_the_lent_team_is_accepted_and_kept(self) -> None:
        """The bug: an empty `heros` list is dropped and the squad stays empty."""
        lua, manager = self.build()
        manager.onRecvLimitHeros(manager, to_lua(lua, {"data": self.limit_reply(STAGE_1_1)}))
        self.assertIsNone(lua.globals().LAST_BUGLY,
                          "onRecvLimitHeros reported the reply as unusable")
        lent = manager.getLimitHero(manager, 1000)
        self.assertIsNotNone(lent, "stage 1-1 lends limit hero 1000")
        self.assertEqual(int(lent.cid), TOHKA)
        # `changesid` rewrites id -> sid and cid -> id.
        self.assertEqual(int(lent.id), TOHKA)
        self.assertIsNotNone(manager.getLevelFormation(manager, STAGE_1_1),
                             "FubenSquadView blocks the Fight button on this")

    def test_an_empty_reply_is_what_emptied_the_squad(self) -> None:
        """Pin the regression, through the same real code."""
        lua, manager = self.build()
        manager.onRecvLimitHeros(
            manager, to_lua(lua, {"data": {"heros": [], "leveId": STAGE_1_1}}))
        self.assertIsNotNone(lua.globals().LAST_BUGLY,
                             "the old reply should be reported as unusable")
        self.assertIsNone(manager.getLimitHero(manager, 1000))

    def test_the_lent_spirit_can_survive_a_frame(self) -> None:
        """Property:init reads `attr` verbatim; without it max HP is 0."""
        lua, manager = self.build()
        manager.onRecvLimitHeros(manager, to_lua(lua, {"data": self.limit_reply(STAGE_1_1)}))
        lent = manager.getLimitHero(manager, 1000)
        # onRecvLimitHeros rewrites attr into a {type = value} map.
        self.assertGreater(int(lent.attr[1]), 0, "attr[1] is max HP")

    # -- the level gate ------------------------------------------------------

    def test_the_next_stage_is_locked_until_the_player_levels(self) -> None:
        """`Button_level:setTouchEnabled(enabled)` - a locked node is inert."""
        lua, manager = self.build()
        needed = (static_config().dungeon_definition(STAGE_1_2) or {})["playerLvl"]
        self.assertGreater(needed, 1)

        lua.globals().MainPlayer.level = 1
        enabled, _pre, level_open, _time = manager.checkPlotLevelEnabled(manager, STAGE_1_2)
        self.assertFalse(enabled, "at Lv.1 the node must be locked")
        self.assertFalse(level_open)

        lua.globals().MainPlayer.level = needed
        enabled, _pre, level_open, _time = manager.checkPlotLevelEnabled(manager, STAGE_1_2)
        self.assertTrue(level_open, f"at Lv.{needed} the level gate must open")

    def test_clearing_the_first_stage_pays_enough_to_open_the_second(self) -> None:
        """Settlement has to move the player's level, or the map dead-ends."""
        state = default_save()
        start = encode_fields(registry().c2s[1793], {"levelCid": STAGE_1_1})
        combat.response_for(1793, state, start)
        finish = encode_fields(registry().c2s[1794],
                               {"levelCid": STAGE_1_1, "isWin": True, "goals": [1, 2, 3]})
        payload, changed = combat.response_for(1794, state, finish)
        self.assertTrue(changed)
        self.assertTrue(proto_validate.validate(1794, payload).ok)

        lua, manager = self.build(state)
        lua.globals().MainPlayer.level = int(state["lvl"])
        enabled, _pre, level_open, _time = manager.checkPlotLevelEnabled(manager, STAGE_1_2)
        self.assertTrue(level_open,
                        f"after clearing 1-1 the player is Lv.{state['lvl']}, "
                        "which must open 1-2")


if __name__ == "__main__":
    unittest.main()
