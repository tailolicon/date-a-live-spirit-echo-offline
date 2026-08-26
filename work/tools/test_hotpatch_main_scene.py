#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(TOOLS, "..", ".."))
sys.path.insert(0, TOOLS)

import hotpatch_main_scene as target  # noqa: E402

PROTOS_S2C = os.path.join(REPO, "reference", "lua", "lua", "net", "protos_s2c.lua")

try:
    import lupa
except ImportError:  # optional: the shape tests below still run without it
    lupa = None


class MainSceneHotpatchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        path = os.path.join(REPO, "reference", "lua", "lua", "net", "NetWork.lua")
        with open(path, encoding="utf-8") as f:
            cls.source = f.read()
        cls.patched = target.patch_network(cls.source)

    def test_empty_lists_are_normalized_from_the_descriptor(self) -> None:
        self.assertIn("__dalFillFields", self.patched)
        self.assertIn('pcall(require, "lua.net.protos_s2c")', self.patched)

    def test_descriptor_table_is_loaded_once(self) -> None:
        self.assertEqual(
            self.patched.count("local __dalProtoDesc, __dalDescCache = nil, nil"), 1)
        self.assertIn("__dalDescCache[nType]", self.patched)

    def test_invalid_zero_ids_are_neutralized(self) -> None:
        self.assertIn("tTemp.wearId = 100001", self.patched)
        self.assertIn("nType == 6824 and tTemp.roomType == 0", self.patched)
        self.assertIn("nType == 8501 and tTemp.curBoss", self.patched)
        self.assertIn("skip invalid HuntingDungeonInfo curDungeon=0", self.patched)

    def test_existing_network_tracing_is_preserved(self) -> None:
        self.assertIn("[DAL-WAIT] pending:", self.patched)

    def test_patch_is_idempotent(self) -> None:
        self.assertEqual(target.patch_network(self.patched), self.patched)
        self.assertEqual(self.patched.count(target.MARKER), 1)

    def test_dispatch_survives_for_normal_messages(self) -> None:
        self.assertEqual(
            self.patched.count("TFDirector:dispatchProtocolWith(nType, tTemp)"), 1)


@unittest.skipIf(lupa is None, "lupa not installed; skipping Lua execution tests")
class WalkerBehaviourTests(unittest.TestCase):
    """Run the generated Lua for real - a patch that parses can still be wrong."""

    @classmethod
    def setUpClass(cls) -> None:
        path = os.path.join(REPO, "reference", "lua", "lua", "net", "NetWork.lua")
        with open(path, encoding="utf-8") as f:
            patched = target.patch_network(f.read())
        body = patched[patched.index("    local __dalRepeatScalar"):
                       patched.index("    if __dalProtoDesc == nil then")]
        cls.lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        cls.fill = cls.lua.eval('function(s) return load(s, "walker")() end')(
            "return function() " + body + " return __dalFillFields end")()
        cls.protos = cls.lua.execute(
            'local f, err = loadfile(%r)\n'
            'if not f then error(err) end\n'
            'return f()' % PROTOS_S2C.replace("\\", "/"))

    def walk(self, proto: int, node_src: str):
        desc = self.protos[proto]()
        node = self.lua.eval(node_src)
        self.fill(desc[2], desc[3], 0, node)
        return node

    def test_whole_patched_file_compiles(self) -> None:
        path = os.path.join(REPO, "reference", "lua", "lua", "net", "NetWork.lua")
        with open(path, encoding="utf-8") as f:
            patched = target.patch_network(f.read())
        compiled = self.lua.eval('function(s) return load(s, "NetWork.lua") end')(patched)
        self.assertIsNotNone(compiled, "patched NetWork.lua does not parse")

    def test_absent_repeated_field_reads_as_a_table(self) -> None:
        # s2c 4362 rewardCfgs: RechargeDataMgr:getCanRewardList ipairs()es it
        # straight off the response, which crashed MainLayer:checkNewRecharge.
        node = self.walk(4362, "{}")
        self.assertEqual(lupa.lua_type(node["rewardCfgs"]), "table")

    def test_an_all_empty_response_still_looks_empty(self) -> None:
        """MainLayer:onRecyclingItems opens its dialog on `if next(data)`.

        Writing the keys in eagerly made every login pop an empty Recycle Item
        dialog that re-requested itself on Confirm. The fill is lazy so the
        emptiness gate keeps working.
        """
        for proto in (519, 4362):
            node = self.walk(proto, "{}")
            self.assertTrue(
                self.lua.eval("function(t) return next(t) == nil end")(node),
                f"proto {proto} response should still read as empty")

    def test_reading_a_deferred_field_materializes_it_for_writes(self) -> None:
        node = self.walk(4362, "{}")
        self.lua.eval("function(t) table.insert(t.rewardCfgs, {id = 1}) end")(node)
        size, first = self.lua.eval(
            "function(t) return #t.rewardCfgs, t.rewardCfgs[1].id end")(node)
        self.assertEqual((size, first), (1, 1))

    def test_unknown_keys_are_still_nil(self) -> None:
        node = self.walk(4362, "{}")
        self.assertIsNone(node["totallyMadeUp"])

    def test_nested_and_sibling_fields_are_handled(self) -> None:
        node = self.walk(6676, "{open=true}")
        self.assertEqual(lupa.lua_type(node["playerReCallRank"]), "table")
        self.assertEqual(lupa.lua_type(node["awardInfo"]), "table")
        self.assertTrue(node["open"], "scalar fields must be left alone")

    def test_present_rows_are_recursed_into_not_replaced(self) -> None:
        node = self.walk(4362, "{rewardCfgs={ {id=7, canReward=true, amount=100} }}")
        self.assertEqual(node["rewardCfgs"][1]["id"], 7)
        self.assertEqual(lupa.lua_type(node["rewardCfgs"][1]["items"]), "table")

    def test_packed_repeated_scalars_are_covered(self) -> None:
        # levelInfo.goals is pv4: repeated, but written as a plain type string.
        node = self.walk(1796, "{levelInfos={levelInfos={{cid=101101}}}}")
        row = node["levelInfos"]["levelInfos"][1]
        self.assertEqual(row["cid"], 101101)
        self.assertEqual(lupa.lua_type(row["goals"]), "table")

    def test_every_shipped_descriptor_walks_without_error(self) -> None:
        keys = self.lua.eval(
            "function(t) local k = {} for i in pairs(t) do k[#k+1] = i end return k end"
        )(self.protos)
        failures = []
        for proto in keys.values():
            try:
                desc = self.protos[proto]()
                self.fill(desc[2], desc[3], 0, self.lua.eval("{}"))
            except Exception as exc:  # noqa: BLE001 - report, do not mask
                failures.append((proto, repr(exc)))
        self.assertEqual(failures, [])


if __name__ == "__main__":
    unittest.main()
