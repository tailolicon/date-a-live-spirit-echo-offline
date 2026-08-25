#!/usr/bin/env python3
import os
import shutil
import subprocess
import zipfile

APKS = [
    r"work\apk\base-offline.apk",
    r"work\apk\config.armeabi_v7a.apk",
    r"work\apk\InstallPack.apk",
]
KS = r"work\apk\debug.keystore"
APKSIGNER = r"E:\Android\Sdk\build-tools\36.0.0\apksigner.bat"
SKIP = (".SF", ".RSA", ".DSA", ".EC")


def strip(path: str) -> None:
    tmp = path + ".nosig"
    print("strip", path)
    with zipfile.ZipFile(path, "r") as zin, zipfile.ZipFile(tmp, "w") as zout:
        for item in zin.infolist():
            name = item.filename
            upper = name.upper()
            if upper.startswith("META-INF/") and (
                upper.endswith(SKIP) or "BNDLTOOL" in upper or "MANIFEST.MF" == os.path.basename(upper)
            ):
                continue
            zout.writestr(item, zin.read(item.filename))
    os.replace(tmp, path)
    print(" stripped", os.path.getsize(path))


def sign(path: str) -> None:
    print("sign", path)
    subprocess.check_call([
        APKSIGNER, "sign",
        "--ks", KS,
        "--ks-key-alias", "androiddebugkey",
        "--ks-pass", "pass:android",
        "--key-pass", "pass:android",
        "--v1-signing-enabled", "true",
        "--v2-signing-enabled", "true",
        path,
    ])


def main() -> None:
    for p in APKS:
        strip(p)
        sign(p)
    print("done")


if __name__ == "__main__":
    main()
