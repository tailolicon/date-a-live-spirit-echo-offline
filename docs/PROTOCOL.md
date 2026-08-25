# Date A Live: Spirit Echo — offline server notes

State as of 2026-08-25. The client now clears server select, logs into the
local game server, completes the whole login fan-out and switches to MainScene.

## What was actually broken

The server picker was never the problem. Picking "Local Offline" runs
`LogonHelper:authorize()` → `GET /account/login` → `CommonManager:connectServer()`
→ TCP to the game server, and the `LOGIN_ENTER_GAME` handshake never got a
reply the client could read. `CommonManager:reConnectServer` retried 3× and
dropped back to the login screen, which *looks* like "stuck on server select".

Two independent walls sat behind that:

1. the game TCP protocol was not implemented, and
2. once it was, the client still discarded every reply — because of a bug in
   the client itself (see "The length bug" below).

## Login / account HTTP

Plain HTTP, no TLS and no Frida. `lua/UtilHelper.lua` is hot-patched so
`URL_LOGIN`, `URL_LOGIN_QUERYDATE` and `URL_ANNOUNCEMENT` point at
`http://10.0.2.2:18099/...`. `10.0.2.2` is this machine as seen from MuMu (the
device is 10.0.2.15/24). The old HTTPS front on :18082 and the `runtime.js`
URL/`connect()` rewriting are gone.

## Hot-patching lua without rebuilding the APK

Android search paths (`TFFramework/ResPathConfig.lua`) put the writable trees
in front of the APK assets, so an encrypted lua dropped at `TFDebug/src/<path>`
overrides `assets/src/<path>`. Two roots are in play and which one wins per
file is not worth chasing, so `work/tools/hotpatch.py` writes **both**:

```
/storage/emulated/0/Android/data/<pkg>/files/playmore/<pkg>/TFDebug/src
/data/data/<pkg>/files/TFDebug/src
```

A stale copy in the other tree will silently keep running — that cost an hour
of debugging blind. Encryption is the APK's own `F8 8B 2D` gzip wrapper
(`work/tools/lua_crypt.py`).

Release builds stub out `print`/`dump` (`DEBUG_LOG = false` in
`lua/UtilHelper.lua`); the patch flips it to `true`, which is what makes the
game's own net diagnostics visible under `[Phanta] [LUA-print]`.

## Game TCP wire format

```
uint16 BE  head token = 0x712B      (constructor default, TFClientSocket+0x1910A)
uint32 BE  total frame length, header included
uint16 BE  X = checksum, see below
uint16 BE  proto id
[s2c only] int32 BE errorCode       (lua NetOP:UnpackHeadInt)
protobuf-wire body
```

Bodies are ordinary protobuf wire format — `NetOP:TypeCount(i, type)` is
`field << 3 | wiretype` — but `NetOP:UnpackSingleVaule` reads fields strictly in
order: a tag that does not match the expected position yields NULL and is not
consumed. Layouts live in `lua/net/protos_c2s.lua` / `protos_s2c.lua`
(`codes_*.lua` carry the human-readable comments).

`setUseShortPackLen(true)` switches the length to `uint16` and the header to 6
bytes; the default is the long form above.

### The header checksum X

```python
X = (0x77 + sum(payload_bytes)) & 0x7F7F     # payload = proto id onwards
```

Recovered by probing the client with ~70 crafted frames, then confirmed in the
binary at `0x594C18`:

```
movs r0, #0x77 ; acc = 119
loop: ldrb r4, [r1, r3] ; add r0, r4
movw r1, #0x7f7f ; ands r0, r1
```

It has exactly one caller — the send path — so **the receive side never
verifies it**. It still has to be small, for the reason below.

## The length bug (why replies were invisible)

`setEncodeEnable(false)` turns the packet cipher off in *both* directions: all
four cipher entry points test the flag at `TFClientSocket+0x9A` and skip when
it is clear. But the receive loop's plaintext branch reads the 32-bit frame
length from the **wrong offset**:

```
0x59399a   ldr   r0, [r0, #4]      <- plaintext branch  (wrong)
0x5939ee   ldr.w r0, [r0, #2]      <- the real parse    (right)
```

Offset 4 straddles the low half of the length and the header word, so an
82-byte reply looks like a ~5.4 MB one: the client waits for the rest forever,
never errors, and eventually drops the socket on the heartbeat timeout.

Workaround: pad every s2c frame to a multiple of 65536. That zeroes the two
bytes the bogus read picks up, so it yields the (small) checksum instead and
the "have we got the whole frame" gate passes. The real parse at offset 2 then
sees the true length, and the trailing zeros land past the last field the lua
decoder looks for. Costs 64 KB per message on loopback — irrelevant here.

## The packet cipher (not needed, but characterised)

`CommonManager:connectHandle` sets `{0xac,0x12,0x19,0xcd,0x95,0x34,0xcb,0xf1}`
and `sendLogin` switches to `{1,2,3,4,5,6,7,8}` straight after sending
`LOGIN_ENTER_GAME`; `SetEncodeKeys(keys, bEncode)` with `bEncode == nil` sets
encode *and* decode.

It is not a repeating XOR of the key bytes, and it is not a pure keystream
either: keying it with all zeros still produces ciphertext, and the stream
depends on the plaintext (two frames sharing their first four bytes but
differing at byte 5 diverge from byte 5 on). Key arrays live at +0x80/+0x88
(encode) and +0x90 (decode), `SetUseDKeys` toggles +0x98, `setEncodeEnable`
toggles +0x9A. Since disabling it works, it was never reversed further.

## Answering the login fan-out

`MainPlayer:onLogin` walks every DataMgr, each firing its own request and
registering the reply id in `NetWork:waitLoginS2CMsg`. The scene only switches
once `__waitLoginMsg` is empty — about 104 messages. `proto_gen.py` generates a
minimal body per proto straight from `protos_s2c.lua`:

- scalars → zero / empty string,
- repeated fields → absent (the reader yields an empty table),
- non-repeated submessages → **filled in recursively**.

That last point matters: an empty submessage leaves every field nil and
handlers that compare them raise (`LeagueDataMgr:checkSelfInUnion`). Replying
with a blanket empty body is worse still — it takes the client down with a
SIGSEGV inside luajit.

## Running it

`PLAY.bat` → `work/offline/play_offline.py`: hot-patch, start
`http_server.py` (:18099) and `tcp_server.py` (:18100), launch the game. No
Frida, no adb reverse, no APK rebuild.

## Known remaining issues

- MainScene renders black and the process has exited on one of two runs after
  reaching it. The login pipeline itself is stable (heartbeats held for minutes
  on the good run), so this is about the *content* of the generated replies and
  the main-scene assets, not the protocol.
- Two non-fatal handler errors from zero-valued config ids:
  `LeagueDataMgr.lua:926` (`bossCfg` nil) and `WorldRoomDataMgr.lua:447`
  (`controler` nil).
- Nothing is persisted yet beyond `work/offline/saves/player.json`; every
  module answers with zeros on each login.
