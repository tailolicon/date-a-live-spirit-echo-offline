# Date A Live: Spirit Echo — offline private server

Personal research/preservation project: run the (online-only) mobile game
**Date A Live: Spirit Echo 1.37** single-player against a local server, on an
x86 MuMu emulator.

**Current state: playable.** The client clears server select, logs into the
local game server, completes the ~110-message login fan-out, renders MainScene,
runs the opening tutorial, and opens the Volume 1 instance map with stage 1‑1
already cleared from the save. Heartbeats hold, and a full login produces no Lua
errors. What is thin is *content*: most modules still answer with zeros, so
progression beyond the starter state is not persisted yet.

Read `docs/PROTOCOL.md` first. It has the wire format, the findings that
unblocked this, and the exact addresses in the binary.

---

## Prerequisites (not in the repo)

| What | Where it goes | Why it is not committed |
|---|---|---|
| `com.datealive.action.rpg.apk` (~180MB) | `work/apk/` | Not redistributable, too large |
| MuMu emulator, rooted, adb reachable | default `127.0.0.1:16384` | — |
| Python 3.11+ | on PATH | — |

`docs/ARTIFACTS.md` lists the binaries that live outside git — the original
XAPK, the signed offline build, the keystore, `libTerransForce.so` and the
session logs — with sizes and SHA-256, plus how to regenerate everything else
locally instead of downloading it. `work/tools/upload_artifacts.py` pushes that
set to Drive via rclone.

The APK must be the **repacked offline build** — the stock APK points at the
live login server. `work/patch_offline_lua.py` produces it from the stock APK
(patches the login URL and skips hot-update, then re-signs). Once installed,
everything else is done by hot-patching lua at runtime; the APK is not rebuilt
again.

After dropping the APK in place:

```bash
python work/tools/bootstrap.py     # rebuild reference/lua from the APK
```

`reference/lua` is already committed, so this is only needed if you want to
refresh it or produce the full dump (`--full`).

## Running

```bat
PLAY.bat
```

which is `work/offline/play_offline.py`:

1. hot-patches lua onto the device (`work/tools/hotpatch.py apply`),
2. starts `http_server.py` on **:18099** (account API) and `tcp_server.py` on
   **:18100** (game server),
3. force-stops and relaunches the game.

Then in the game: tap through → server bar appears → tap again → it logs in.

No Frida, no adb reverse, no TLS. The device reaches the host at `10.0.2.2`
(MuMu is `10.0.2.15/24`) and the patched URLs point straight there.

Logs land in `work/offline/logs/` (git-ignored): `tcp.out` is the packet trace,
`http.out` the account API, and the game's own lua logging shows up in
`adb logcat` under `[Phanta] [LUA-print]`.

---

## Layout

```
docs/PROTOCOL.md            wire format, the client-side length bug, cipher notes
reference/lua/              curated decrypted game lua (protocol + logic, ~22MB)

work/tools/
  hotpatch.py               decrypt -> patch -> re-encrypt -> push lua to device
  lua_crypt.py              the APK's F8 8B 2D gzip asset wrapper
  bootstrap.py              rebuild reference/lua (and the full dump) from the APK

work/offline/
  play_offline.py           launcher (PLAY.bat)
  http_server.py            /account/getServerInfo, /login, /querydate, notices
  tcp_server.py             the game server: framing, checksum, padding, handlers
  proto_gen.py              minimal s2c bodies generated from protos_s2c.lua
  proto_codec.py            protobuf-wire helpers
  player_save.py            work/offline/saves/player.json
  edit_state.py             save editor

work/                       APK recon + decryption scripts from the first pass
work/frida/                 superseded injection approach, kept for reference
```

## How the hot-patch works

Android search paths (`TFFramework/ResPathConfig.lua`) put the writable trees
in front of the APK assets, so an encrypted lua dropped at `TFDebug/src/<path>`
overrides `assets/src/<path>`. Two roots are in play and which one wins per
file is not worth chasing, so `hotpatch.py` writes **both**:

```
/storage/emulated/0/Android/data/<pkg>/files/playmore/<pkg>/TFDebug/src
/data/data/<pkg>/files/TFDebug/src
```

A stale copy in the other tree will silently keep running. If a patch seems to
have no effect, that is the first thing to check.

Current patches:

| File | What it does |
|---|---|
| `lua/UtilHelper.lua` | account URLs → `10.0.2.2:18099`; `DEBUG_LOG = true` (release builds stub out `print`/`dump`) |
| `lua/gamedata/CommonManager.lua` | `setEncodeEnable(false)` to drop the packet cipher; connect tracing |
| `lua/net/NetWork.lua` | prints the outstanding login-message set; defers `{}` for empty repeated fields (see below) |
| `TFFramework/net/TFClientNet.lua` | receive-path tracing |

`hotpatch.py revert` removes them.

### Empty repeated fields

An empty repeated field is simply absent on the wire, and the client's reader
turns "absent" into NULL, which `PackStruct` maps to **nil**, not `{}`. Handlers
that `ipairs()` such a field unconditionally then crash — `RechargeDataMgr` did,
which took MainLayer's red-dot check down with it.

`hotpatch_main_scene.py` reads the message's own descriptor from
`protos_s2c.lua` and hands back an empty table for any repeated field that came
back nil. It does this **lazily, through `__index`**, because several handlers
gate on the response being empty at all — `MainLayer:onRecyclingItems` does
`if next(data)`. Writing the keys in eagerly made every login pop an empty
"Recycle Item" dialog that re-requested itself on Confirm. `next`, `pairs` and
`#` ignore metatables, so the gate still sees `{}` while
`ipairs(data.field)` gets its table.

## The two things that mattered

1. **Header checksum.** `X = (0x77 + sum(payload_bytes)) & 0x7F7F`, verified
   against the routine at `0x594C18` in `libTerransForce.so`. Only the send
   path calls it, so the client never validates it — but it still has to be
   small, because of:

2. **A bug in the client.** With the cipher off, the receive loop reads the
   frame length from offset 4 instead of offset 2 (`0x59399A ldr r0,[r0,#4]`
   vs the correct `0x5939EE ldr.w r0,[r0,#2]`). An 82-byte reply therefore
   looks like a ~5.4MB one and the client waits for the rest forever, with no
   error. Padding every reply to a multiple of 65536 zeroes the two bytes that
   bogus read picks up and the gate passes.

Both are covered in detail in `docs/PROTOCOL.md`.

## Validating a reply before you ship it

The client's decoder never rejects a bad body. It walks the descriptor in
order, and any field whose tag does not match the expected position is silently
set to NULL — every field after it is lost too. The failure then surfaces
somewhere else entirely, minutes later, as a nil index inside a DataMgr.

That is exactly how MainScene came to be black: the s2c 1796 body wrapped the
repeated `levelInfos` list in one submessage too many, so `FubenDataMgr`
received nothing and MainScene never finished loading.

`work/offline/proto_validate.py` mirrors that decoder. Run it directly to check
every generated body, or let the tests do it:

```bash
python work/offline/proto_validate.py     # all 947 generated s2c bodies
python -m pytest work/offline work/tools  # + every stateful handler response
```

**Any new handler body should go through `proto_validate.validate()`** — the
test in `test_proto_validate.py` already sweeps every `response_for()`, so a new
protocol added to a `*_PROTOCOLS` set is covered automatically.

`pip install lupa` additionally enables the tests that run the generated Lua
hot-patch in a real Lua VM; they skip cleanly without it.

## Where to pick up

- **Progression is not persisted** past what `player_save.py` models. Modules
  outside the `*_handlers.py` set still answer with generated zeros, so their
  state resets on every login.
- **Empty repeated fields are handled generically now.** The NetWork hot-patch
  reads each message's own descriptor and defers an empty table for any
  repeated field that came back nil (see below), so that class of crash should
  not need per-proto patching any more.
- **Zero-valued config ids are not.** A scalar id of 0 that has to name a real
  row in a static table is still handled case by case — `hot_summon_info()` in
  `stateful_handlers.py` shows the preferred shape: read the real id out of the
  shipped table via `game_static_config.py` rather than inventing one.

## Scope

Single-player research and preservation on a game whose service the owner
controls. Not for use against live servers, and the game's own code under
`reference/lua` is not mine to redistribute — keep this repo private.
