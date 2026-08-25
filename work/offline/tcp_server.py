#!/usr/bin/env python3
"""Local game TCP server for Date A Live: Spirit Echo (TerransForce TFClientSocket).

Wire format (confirmed on the wire once the packet cipher is disabled by the
CommonManager hot-patch):

    uint16 BE  head token   0x712B
    uint32 BE  total frame length (includes these 6 bytes)
    uint16 BE  X            (opaque header word, echoed back to the client)
    uint16 BE  proto id
    [server -> client only] int32 BE errorCode   (lua UnpackHeadInt)
    protobuf-wire body, fields in strict order (tag = field<<3 | wiretype)

The body encoding is plain protobuf wire format, but the lua reader
(NetOP:UnpackSingleVaule) is strictly ordered: a field whose tag does not match
the expected position is treated as NULL and is not consumed.
"""
from __future__ import annotations

import os
import socket
import struct
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from player_save import load_save, save as persist  # noqa: E402
from proto_codec import (  # noqa: E402
    enc_bool_field,
    enc_msg_field,
    enc_string_field,
    enc_varint_field,
)
import proto_gen  # noqa: E402

# Minimal well-formed body per s2c proto, generated from protos_s2c.lua.
try:
    MINIMAL = proto_gen.build()
except Exception as _e:  # keep the server usable even if the lua dump moved
    MINIMAL = {}
    print(f"proto_gen unavailable: {_e!r}", flush=True)

PORT = int(os.environ.get("DAL_GAME_PORT", "18100"))
# Experiment hook: XOR every outgoing frame with this repeating key (hex).
# Empty = plain wire (what the client speaks once the cipher is patched off).
OUT_XOR = bytes.fromhex(os.environ.get("DAL_OUT_XOR", ""))

# The client drops the socket ~20s after a reply it cannot read, then
# reconnects and replays LOGIN_ENTER_GAME. That gives a free search loop:
# try one candidate reply encoding per connection until lua reacts.
# name -> (key hex, offset the cipher starts at, extra delay before replying)
TRY_MODES = [
    ("plain",        "",                 0, 0.0),
    ("xor-login",    "0102030405060708", 0, 0.0),
    ("xor-connect",  "ac1219cd9534cbf1", 0, 0.0),
    ("xor-login@6",  "0102030405060708", 6, 0.0),
    ("xor-connect@6", "ac1219cd9534cbf1", 6, 0.0),
    ("xor-login@8",  "0102030405060708", 8, 0.0),
    ("xor-login+1s", "0102030405060708", 0, 1.5),
    ("xor-connect+1s", "ac1219cd9534cbf1", 0, 1.5),
]
TRY_ENABLED = bool(os.environ.get("DAL_TRY"))
_try_index = [0]
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs", "tcp.log")

HEAD_TOKEN = 0x712B
HDR = 8  # token(2) + len(4) + X(2)

LOGIN_ENTER = 257
LOGIN_LOGOUT = 258
LOGIN_RECONNECT = 261
LOGIN_PING = 262
LOGIN_NOTICE_LIST = 263
LOGIN_SERVER_TIME = 268
LOGIN_FUNC_SWITCH = 280


def log(msg: str) -> None:
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    line = f"{time.strftime('%H:%M:%S')} {msg}"
    print(line, flush=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


# ------------------------------------------------------------------ payloads


def encode_playerinfo(s: dict) -> bytes:
    """s2c 257 field 2, per protos_s2c.lua [257] playerinfo layout."""
    body = b""
    body += enc_varint_field(1, int(s["pid"]))                       # v4 pid
    body += enc_string_field(2, s.get("name", "Shido"))              # s  name
    body += enc_varint_field(3, int(s.get("lvl", 1)))                # v4 lvl
    body += enc_varint_field(4, int(s.get("exp", 0)))                # v8 exp
    body += enc_varint_field(5, int(s.get("vip_lvl", 0)))            # v4 vip_lvl
    body += enc_varint_field(6, int(s.get("vip_exp", 0)))            # v8 vip_exp
    body += enc_varint_field(7, int(s.get("language", 1)))           # v4 language
    body += enc_string_field(8, s.get("remark", ""))                 # s  remark
    body += enc_varint_field(9, int(s.get("helpFightHeroCid", 0)))   # v4
    # 10 attr: repeated submsg, omitted while empty
    body += enc_bool_field(11, bool(s.get("isFirstLogin", False)))   # b
    body += enc_string_field(12, s.get("clientDiscreteData", "{}"))  # s
    body += enc_string_field(13, s.get("settings", ""))              # s
    # 14 recoverTimeList: tv4 = repeated varint, one tag per element
    for v in s.get("recoverTimeList", []) or []:
        body += enc_varint_field(14, int(v))
    body += enc_varint_field(15, int(s.get("portraitCid", 0)))
    body += enc_varint_field(16, int(s.get("portraitFrameCid", 0)))
    # 17 element: nested submsg, omitted
    body += enc_varint_field(18, int(s.get("unionId", 0)))
    body += enc_string_field(19, s.get("unionName", ""))
    body += enc_varint_field(20, int(s.get("titleId", 0)))
    body += enc_varint_field(21, int(s.get("createTime", int(time.time()))))
    body += enc_varint_field(22, int(s.get("famousExp", 0)))
    return body


def encode_enter_suc(s: dict) -> bytes:
    body = enc_varint_field(1, int(time.time()))
    body += enc_msg_field(2, encode_playerinfo(s))
    body += enc_varint_field(3, 0)   # queue: must be 0 or the queue UI shows
    body += enc_varint_field(4, 0)   # queueTime
    return body


# ------------------------------------------------------------------ framing


def _xor_from(frame: bytes, key: bytes, start: int) -> bytes:
    if not key:
        return frame
    out = bytearray(frame)
    for i in range(start, len(out)):
        out[i] ^= key[(i - start) % len(key)]
    return bytes(out)


def checksum(payload: bytes) -> int:
    """The header word X.

    Derived by probing the client with ~70 crafted frames: it is the 16-bit sum
    of every payload byte (proto id onwards) plus 119, with bit 7 cleared - the
    native side stores the low 7 bits in the second byte and the rest in the
    first. A frame whose X does not match is dropped before it ever reaches
    lua, which is what kept every earlier reply invisible to the client.
    """
    return (sum(payload) + 119) & 0xFF7F


PAD_UNIT = 0x10000


def pack(proto: int, body: bytes = b"", error: int = 0,
         key: bytes | None = None, start: int = 0) -> bytes:
    """Build one s2c frame, padded so the client's plaintext path accepts it.

    TFClientSocket's receive loop has a bug in the branch it takes when the
    packet cipher is off (setEncodeEnable(false)): to decide whether a whole
    frame has arrived it reads the 32-bit length from offset 4 instead of
    offset 2 (0x59399a `ldr r0,[r0,#4]` vs the correct 0x5939ee
    `ldr.w r0,[r0,#2]`). Offset 4 straddles the low half of the length and the
    header word, so an ordinary 82-byte reply looks like a ~5.4MB one and the
    client waits for the rest forever - which is exactly why every earlier
    reply vanished without a trace.

    Padding the frame to a multiple of 65536 zeroes the two bytes the bogus
    read picks up, so it yields the (small) header word instead and the gate
    passes. The real parse at offset 2 then sees the true length, and the
    trailing zeros land past the last field the lua decoder looks for.
    """
    payload = struct.pack(">Hi", proto & 0xFFFF, error) + body
    total = -(-(8 + len(payload)) // PAD_UNIT) * PAD_UNIT
    payload += b"\x00" * (total - 8 - len(payload))
    frame = (struct.pack(">HI", HEAD_TOKEN, total)
             + struct.pack(">H", checksum(payload)) + payload)
    return _xor_from(frame, OUT_XOR if key is None else key, start)


class Client(threading.Thread):
    daemon = True

    def __init__(self, sock: socket.socket, addr) -> None:
        super().__init__(name=f"dal-{addr[1]}")
        self.sock = sock
        self.addr = addr
        self.buf = bytearray()
        self.save = load_save()
        self.x = 0
        self.entered = False
        if TRY_ENABLED:
            self.mode = TRY_MODES[_try_index[0] % len(TRY_MODES)]
            _try_index[0] += 1
        else:
            self.mode = ("plain", "", 0, 0.0)

    def send_pkt(self, proto: int, body: bytes = b"", error: int = 0) -> None:
        name, keyhex, start, delay = self.mode
        if delay:
            time.sleep(delay)
        pkt = pack(proto, body, error, bytes.fromhex(keyhex), start)
        log(f"-> {self.addr} [{name}] proto={proto} err={error} body={len(body)} "
            f"raw={len(pkt)} hex={pkt[:16].hex()}")
        self.sock.sendall(pkt)
        if os.environ.get("DAL_DRAINTEST") and proto == LOGIN_ENTER:
            # Does the client read at all? Push past both socket buffers and
            # see whether sendall blocks. If it returns fast, it is draining.
            t0 = time.time()
            try:
                self.sock.settimeout(8)
                self.sock.sendall(b"\x00" * (4 << 20))
                log(f"draintest: 4MB accepted in {time.time() - t0:.2f}s "
                    f"(client IS reading)")
            except Exception as e:
                log(f"draintest: blocked after {time.time() - t0:.2f}s {e!r} "
                    f"(client NOT reading)")
            finally:
                self.sock.settimeout(300)

    # -------------------------------------------------------------- handlers

    def handle(self, proto: int, body: bytes) -> None:
        log(f"<- {self.addr} proto={proto} x={self.x:#06x} body={body[:96].hex()}")
        if os.environ.get("DAL_SILENT"):
            return

        if proto in (LOGIN_ENTER, LOGIN_RECONNECT):
            self.entered = True
            self.save["isFirstLogin"] = False
            persist(self.save)
            self.send_pkt(proto, encode_enter_suc(self.save))
            return
        if proto == LOGIN_PING:
            self.send_pkt(LOGIN_PING)
            return
        if proto == LOGIN_SERVER_TIME:
            self.send_pkt(LOGIN_SERVER_TIME, enc_varint_field(1, int(time.time())))
            return
        # Everything else gets the generated minimal body for its proto. A
        # blanket *empty* body is not safe here: handlers that index their
        # fields take the client down with a SIGSEGV inside luajit.
        if proto in MINIMAL:
            self.send_pkt(proto, MINIMAL[proto])
        else:
            log(f"   (no s2c descriptor for proto {proto}, no reply)")

    # -------------------------------------------------------------- transport

    def run(self) -> None:
        log(f"client {self.addr} connected")
        self.sock.settimeout(300)
        try:
            while True:
                try:
                    chunk = self.sock.recv(65536)
                except socket.timeout:
                    continue
                if not chunk:
                    break
                if os.environ.get("DAL_ECHO"):
                    # Diagnostic: bounce the client's bytes straight back. With
                    # the stock cipher this tests whether the receive path is a
                    # symmetric stream starting from the same state as the send
                    # path - if it is, the client decodes its own frame.
                    log(f"echo {len(chunk)} {chunk[:32].hex()}")
                    self.sock.sendall(chunk)
                    continue
                if os.environ.get("DAL_RAW"):
                    log(f"raw {len(chunk)} {chunk.hex()}")
                self.buf.extend(chunk)
                while len(self.buf) >= HDR:
                    token, total = struct.unpack(">HI", bytes(self.buf[:6]))
                    if token != HEAD_TOKEN:
                        log(f"!! bad head token {token:#06x} hex={bytes(self.buf[:32]).hex()}")
                        self.buf.clear()
                        break
                    if total < HDR + 2 or total > 4_000_000:
                        log(f"!! bad length {total} hex={bytes(self.buf[:32]).hex()}")
                        self.buf.clear()
                        break
                    if len(self.buf) < total:
                        break
                    frame = bytes(self.buf[:total])
                    del self.buf[:total]
                    self.x, proto = struct.unpack(">HH", frame[6:10])
                    if os.environ.get("DAL_ECHO"):
                        # Diagnostic: bounce the client's own frame back verbatim.
                        # If lua reacts at all, the native reader accepts plain
                        # frames and only our payload shape is wrong.
                        log(f"echo {frame.hex()}")
                        self.sock.sendall(frame)
                        continue
                    try:
                        self.handle(proto, frame[10:])
                    except Exception as e:
                        log(f"handle {proto} err {e!r}")
        except Exception as e:
            log(f"client {self.addr} err {e!r}")
        finally:
            try:
                self.sock.close()
            except Exception:
                pass
            log(f"client {self.addr} closed")


def main() -> None:
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", PORT))
    srv.listen(8)
    log(f"game TCP :{PORT}  (plain wire, head token {HEAD_TOKEN:#06x})")
    while True:
        sock, addr = srv.accept()
        Client(sock, addr).start()


if __name__ == "__main__":
    main()
