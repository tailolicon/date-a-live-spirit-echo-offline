#!/usr/bin/env python3
"""Ship the binaries that cannot live in git to Google Drive, via rclone.

Most of what git excludes is *derived*, so uploading all 3.8GB would be waste:

  work/apk/com.datealive.action.rpg.apk    inside the XAPK
  work/apk/InstallPack.apk                 inside the XAPK
  work/apk/config.armeabi_v7a.apk          inside the XAPK
  work/apk/*.offline.apk                   unsigned intermediate of base-offline.apk
  work/apk/*.idsig                         produced by signing
  work/dump/                               bootstrap.py --full
  work/frida/frida-server*                 frida's own GitHub releases

What genuinely cannot be reproduced is the original XAPK, the signed offline
build that is actually installed, and the keystore that signed it.

    python work/tools/upload_artifacts.py --manifest
    python work/tools/upload_artifacts.py --remote gdrive:dal-offline
    python work/tools/upload_artifacts.py --remote gdrive:dal-offline --all

rclone needs a Google Drive remote first (one-time, interactive):
    rclone config
"""
from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import subprocess
import sys
import zipfile

REPO = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
LOGS = os.path.join(REPO, "work", "offline", "logs")
LOGS_ZIP = os.path.join(REPO, "work", "offline", "logs-bundle.zip")

# (path relative to repo root, why it is here)
CORE = [
    ("Date+A+Live_+Spirit+Echo_1.37_APKPure.xapk",
     "Original store package: base APK + armeabi_v7a split + InstallPack + manifest. "
     "Everything else is derived from this."),
    ("work/apk/base-offline.apk",
     "Signed repacked offline build - this is what is installed on the emulator."),
    ("work/apk/debug.keystore",
     "Throwaway keystore that signed base-offline.apk (store/key pass: android). "
     "Needed to re-sign an updated build so it installs over the existing one."),
    ("work/extract/lib/libTerransForce.so",
     "ARM32 engine binary. Every address in docs/PROTOCOL.md refers to this file."),
]

EXTRA = [
    ("work/dump/all_lua", "Full decrypted lua tree (~2GB). Regenerate instead: bootstrap.py --full"),
    ("work/frida/frida-server-17.2.17-android-x86", "frida-server, also on frida's releases page"),
    ("work/frida/frida-server-17.2.17-android-x86_64", "frida-server, also on frida's releases page"),
]


def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def human(n: int) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024.0
    return str(n)


def bundle_logs() -> str | None:
    """Zip the session logs and packet traces; skip the screenshots."""
    if not os.path.isdir(LOGS):
        return None
    names = [n for n in sorted(os.listdir(LOGS))
             if os.path.splitext(n)[1].lower() in (".log", ".out", ".txt", ".hex")]
    if not names:
        return None
    with zipfile.ZipFile(LOGS_ZIP, "w", zipfile.ZIP_DEFLATED) as z:
        for n in names:
            z.write(os.path.join(LOGS, n), n)
    return LOGS_ZIP


def collect(include_extra: bool) -> list[tuple[str, str]]:
    items = list(CORE)
    logs = bundle_logs()
    if logs:
        items.append((os.path.relpath(logs, REPO).replace(os.sep, "/"),
                      "Session logs: packet trace (tcp.out), account API (http.out), logcat."))
    if include_extra:
        items += EXTRA
    return [(p, why) for p, why in items if os.path.exists(os.path.join(REPO, p))]


def write_manifest(items: list[tuple[str, str]], remote: str | None) -> str:
    lines = [
        "# Artifacts kept outside git",
        "",
        "Binaries too large or not redistributable for the repo. Rebuild the",
        "derived ones locally rather than fetching them:",
        "",
        "| Derived file | How to get it back |",
        "|---|---|",
        "| `work/apk/com.datealive.action.rpg.apk` | inside the XAPK |",
        "| `work/apk/InstallPack.apk` | inside the XAPK |",
        "| `work/apk/config.armeabi_v7a.apk` | inside the XAPK |",
        "| `work/apk/*.offline.apk` | `python work/patch_offline_lua.py` |",
        "| `work/apk/*.idsig` | produced by signing |",
        "| `work/dump/all_lua` | `python work/tools/bootstrap.py --full` |",
        "| `work/extract/` | unzip the base APK |",
        "| `work/frida/frida-server*` | frida GitHub releases |",
        "",
    ]
    if remote:
        lines += [f"Uploaded to `{remote}`.", ""]
    lines += ["## Contents", ""]
    for path, why in items:
        full = os.path.join(REPO, path)
        if os.path.isdir(full):
            size = sum(os.path.getsize(os.path.join(r, f))
                       for r, _, fs in os.walk(full) for f in fs)
            digest = "(directory)"
        else:
            size = os.path.getsize(full)
            print(f"  hashing {path} ({human(size)})", flush=True)
            digest = sha256(full)
        lines += [f"### `{path}`", "", why, "",
                  f"- size: {human(size)}", f"- sha256: `{digest}`", ""]
    text = "\n".join(lines)
    dest = os.path.join(REPO, "docs", "ARTIFACTS.md")
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    return dest


def upload(items: list[tuple[str, str]], remote: str) -> int:
    if not shutil.which("rclone"):
        print("rclone not on PATH", file=sys.stderr)
        return 1
    remotes = subprocess.run(["rclone", "listremotes"], capture_output=True, text=True).stdout
    name = remote.split(":")[0] + ":"
    if name not in remotes:
        print(f"rclone has no remote named {name}\n"
              f"configured: {remotes.strip() or '(none)'}\n"
              f"run `rclone config` once to add a Google Drive remote.", file=sys.stderr)
        return 1
    for path, _ in items:
        src = os.path.join(REPO, path)
        dest = f"{remote}/{os.path.dirname(path)}".rstrip("/")
        print(f"--> {path}", flush=True)
        r = subprocess.run(["rclone", "copy", src, dest, "--progress",
                            "--drive-chunk-size", "128M"])
        if r.returncode != 0:
            print(f"failed on {path}", file=sys.stderr)
            return r.returncode
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--remote", help="rclone destination, e.g. gdrive:dal-offline")
    ap.add_argument("--all", action="store_true",
                    help="also send the regenerable dump and frida-server binaries")
    ap.add_argument("--manifest", action="store_true", help="write docs/ARTIFACTS.md only")
    args = ap.parse_args()

    items = collect(args.all)
    print(f"{len(items)} artifacts")
    dest = write_manifest(items, args.remote)
    print("wrote", os.path.relpath(dest, REPO))
    if args.manifest or not args.remote:
        return 0
    return upload(items, args.remote)


if __name__ == "__main__":
    sys.exit(main())
