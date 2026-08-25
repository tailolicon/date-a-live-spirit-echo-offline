#!/usr/bin/env python3
"""Local HTTP account/CDN stub for Date A Live: Spirit Echo.

Serves:
  GET /account/getServerInfo
  GET /account/login
  GET /account/querydate
  GET /globalNotice/get_global_notice
plus a catch-all 200 JSON so analytics/CDN probes don't stall.
"""
from __future__ import annotations

import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from player_save import load_save  # noqa: E402

PORT = int(os.environ.get("DAL_HTTP_PORT", "18099"))
GAME_PORT = int(os.environ.get("DAL_GAME_PORT", "18100"))
GAME_IP = os.environ.get("DAL_GAME_IP", "10.0.2.2")
LOG = os.path.join(os.path.dirname(os.path.abspath(__file__)), "logs", "http.log")


def log(msg: str) -> None:
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    line = f"{time.strftime('%H:%M:%S')} {msg}"
    print(line, flush=True)
    with open(LOG, "a", encoding="utf-8") as f:
        f.write(line + "\n")


def ok(data=None, msg: str = "SUCCESS") -> bytes:
    return json.dumps({"status": 0, "msg": msg, "data": data if data is not None else {}},
                      ensure_ascii=False).encode("utf-8")


def server_list(save: dict) -> dict:
    return {
        "serverInfos": [
            {
                "serverId": save["serverId"],
                "serverName": "Local Offline",
                "showServerName": "Local Offline",
                "areaId": 1,
                "showAreaId": 1,
                "state": 0,
                "show": 1,
                "lastLoginTime": int(time.time()),
                "notice": "",
            }
        ]
    }


def login_payload(save: dict) -> dict:
    return {
        "gameServerIp": GAME_IP,
        "gameServerPort": GAME_PORT,
        "groupName": save.get("groupName", "Local"),
        "group_id": save.get("group_id", 101),
        "hasRole": bool(save.get("hasRole", True)),
        "serverId": save.get("serverId", 101001),
        "tip": 0,
        "token": save.get("token", "offline_local_token"),
        "showServerName": "Local Offline",
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    timeout = 30

    def log_message(self, fmt: str, *args) -> None:
        log("%s - " % self.address_string() + (fmt % args))

    def _send(self, body: bytes, content_type: str = "application/json; charset=utf-8",
              status: int = 200) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "*")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.end_headers()

    def do_POST(self) -> None:
        self.do_GET()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)
        save = load_save()
        log(f"GET {self.path} host={self.headers.get('Host','')} qs={ {k: (v[0][:80] if v else '') for k, v in list(qs.items())[:12]} }")

        if path.endswith("/getServerInfo") or path.rstrip("/").endswith("/account"):
            self._send(ok(server_list(save)))
            return
        if path.endswith("/login"):
            self._send(ok(login_payload(save)))
            return
        if path.endswith("/querydate"):
            self._send(ok({"date": time.strftime("%Y-%m-%d"), "time": int(time.time())}))
            return
        if "get_global_notice" in path or "globalNotice" in path:
            self._send(ok({"notice": "", "list": []}))
            return
        if path.endswith("version.lua") or path.endswith("/version"):
            body = b'return "1.37"\n'
            self._send(body, "text/plain; charset=utf-8")
            return
        if "filelist" in path.lower():
            self._send(b"PK\x05\x06" + b"\x00" * 18, "application/zip")
            return
        if path.endswith(".json"):
            self._send(ok({"version": "1.37", "needUpdate": False}))
            return
        self._send(ok({}))

    def do_HEAD(self) -> None:
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()


def main() -> None:
    httpd = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    log(f"HTTP account server :{PORT}  game tcp -> {GAME_IP}:{GAME_PORT}")
    httpd.serve_forever()


if __name__ == "__main__":
    main()
