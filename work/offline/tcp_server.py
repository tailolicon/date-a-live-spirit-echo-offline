#!/usr/bin/env python3
"""Local TCP game server for Date A Live: Spirit Echo."""
from __future__ import annotations

import os
import socket
import struct
import sys
import threading
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from player_info import encode_player_info
from player_save import load_save, save as persist
from proto_codec import enc_msg_field, enc_varint_field
import proto_gen
import angel_handlers
import city_dating_handlers
import combat_handlers
import dating_handlers
import dungeon_handlers
import formation_backup_handlers
import hero_progression_handlers
import player_handlers
import progression_handlers
import role_handlers
import sign_handlers
import stateful_handlers
import summon_handlers

try:
    from protocol_schema import proto_name
except Exception:
    proto_name = None

try:
    MINIMAL = proto_gen.build()
except Exception as exc:
    MINIMAL = {}
    print(f"proto_gen unavailable: {exc!r}", flush=True)

PORT = int(os.environ.get("DAL_GAME_PORT", "18100"))
OUT_XOR = bytes.fromhex(os.environ.get("DAL_OUT_XOR", ""))
TRY_MODES = [
    ("plain", "", 0, 0.0),
    ("xor-login", "0102030405060708", 0, 0.0),
    ("xor-connect", "ac1219cd9534cbf1", 0, 0.0),
    ("xor-login@6", "0102030405060708", 6, 0.0),
    ("xor-connect@6", "ac1219cd9534cbf1", 6, 0.0),
    ("xor-login@8", "0102030405060708", 8, 0.0),
]
TRY_ENABLED = bool(os.environ.get("DAL_TRY"))
_try_index = [0]
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs", "tcp.log")
HEAD_TOKEN = 0x712B
HDR = 8
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


def _name(proto: int, direction: str) -> str:
    if proto_name is None:
        return str(proto)
    try:
        return f"{proto}/{proto_name(proto, direction)}"
    except Exception:
        return str(proto)


def encode_enter_suc(state: dict) -> bytes:
    body = enc_varint_field(1, int(time.time()))
    body += enc_msg_field(2, encode_player_info(state))
    body += enc_varint_field(3, 0)
    body += enc_varint_field(4, 0)
    return body


def _xor_from(frame: bytes, key: bytes, start: int) -> bytes:
    if not key:
        return frame
    out = bytearray(frame)
    for i in range(start, len(out)):
        out[i] ^= key[(i - start) % len(key)]
    return bytes(out)


def checksum(payload: bytes) -> int:
    return (sum(payload) + 119) & 0xFF7F


PAD_UNIT = 0x10000


def pack(proto: int, body: bytes = b"", error: int = 0, key: bytes | None = None, start: int = 0) -> bytes:
    payload = struct.pack(">Hi", proto & 0xFFFF, error) + body
    total = -(-(8 + len(payload)) // PAD_UNIT) * PAD_UNIT
    payload += b"\x00" * (total - 8 - len(payload))
    frame = struct.pack(">HI", HEAD_TOKEN, total) + struct.pack(">H", checksum(payload)) + payload
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
        mode, keyhex, start, delay = self.mode
        if delay:
            time.sleep(delay)
        packet = pack(proto, body, error, bytes.fromhex(keyhex), start)
        log(f"-> {self.addr} [{mode}] proto={_name(proto, 's2c')} err={error} body={len(body)} raw={len(packet)} hex={packet[:16].hex()}")
        self.sock.sendall(packet)

    def handle(self, proto: int, body: bytes) -> None:
        log(f"<- {self.addr} proto={_name(proto, 'c2s')} x={self.x:#06x} body={body[:96].hex()}")
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
        try:
            if player_handlers.dispatch(self, proto, body):
                log(f"   player handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! player {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if role_handlers.dispatch(self, proto, body):
                log(f"   role handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! role {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if city_dating_handlers.dispatch(self, proto, body):
                log(f"   city-dating handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! city-dating {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if dating_handlers.dispatch(self, proto, body):
                log(f"   dating handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! dating {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if dungeon_handlers.dispatch(self, proto, body):
                log(f"   dungeon handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! dungeon {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if combat_handlers.dispatch(self, proto, body):
                log(f"   combat handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! combat {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if formation_backup_handlers.dispatch(self, proto, body):
                log(f"   formation-backup handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! formation-backup {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if hero_progression_handlers.dispatch(self, proto, body):
                log(f"   hero-progression handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! hero-progression {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if angel_handlers.dispatch(self, proto, body):
                log(f"   angel handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! angel {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if progression_handlers.dispatch(self, proto, body):
                log(f"   progression handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! progression {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if summon_handlers.dispatch(self, proto, body):
                log(f"   summon handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! summon {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if sign_handlers.dispatch(self, proto, body):
                log(f"   sign handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! sign {_name(proto, 'c2s')} failed: {exc!r}")
        try:
            if stateful_handlers.dispatch(self, proto, body):
                log(f"   stateful handled {_name(proto, 'c2s')}")
                return
        except Exception as exc:
            log(f"!! stateful {_name(proto, 'c2s')} failed: {exc!r}")
        if proto in MINIMAL:
            # No stateful owner: the client gets a descriptor-shaped body of
            # zeros. That is fine for live-service modules we do not model, and
            # it is exactly where a stuck feature will be - so mark it, and let
            # coverage_report.py list them from the trace.
            log(f"   generic {_name(proto, 'c2s')}")
            self.send_pkt(proto, MINIMAL[proto])
        else:
            log(f"   no s2c descriptor for {_name(proto, 'c2s')}; no reply")

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
                    try:
                        self.handle(proto, frame[10:])
                    except Exception as exc:
                        log(f"handle {_name(proto, 'c2s')} err {exc!r}")
        except Exception as exc:
            log(f"client {self.addr} err {exc!r}")
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
    handled = (
        len(stateful_handlers.STATEFUL_PROTOCOLS)
        + len(combat_handlers.COMBAT_PROTOCOLS)
        + len(dungeon_handlers.DUNGEON_PROTOCOLS)
        + len(dating_handlers.DATING_PROTOCOLS)
        + len(city_dating_handlers.CITY_DATING_PROTOCOLS)
        + len(role_handlers.ROLE_PROTOCOLS)
        + len(player_handlers.PLAYER_PROTOCOLS)
        + len(formation_backup_handlers.FORMATION_BACKUP_PROTOCOLS)
        + len(hero_progression_handlers.HERO_PROGRESSION_PROTOCOLS)
        + len(angel_handlers.ANGEL_PROTOCOLS)
        + len(progression_handlers.PROGRESSION_PROTOCOLS)
        + len(sign_handlers.SIGN_PROTOCOLS)
        + len(summon_handlers.SUMMON_PROTOCOLS)
    )
    log(f"game TCP :{PORT} (plain wire, head token {HEAD_TOKEN:#06x}, stateful={handled})")
    while True:
        sock, addr = srv.accept()
        Client(sock, addr).start()


if __name__ == "__main__":
    main()
