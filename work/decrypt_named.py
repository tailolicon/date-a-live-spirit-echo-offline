#!/usr/bin/env python3
import os
import zipfile
from dal_decrypt import decrypt_bytes

APK = r"work\apk\com.datealive.action.rpg.apk"
OUT = r"work\dump\decrypted"
NAMES = [
    "assets/src/lua/manager/CommonManager.lua",
    "assets/src/lua/public/TFGlobalUtils.lua",
    "assets/src/lua/utils/Utils.lua",
    "assets/src/lua/utils/HttpHelper.lua",
    "assets/src/LuaScript/TFGameStartup.lua",
    "assets/src/lua/gamedata/CommonManager.lua",
    "assets/src/lua/manager/FileCheckMgr.lua",
]


def main():
    z = zipfile.ZipFile(APK)
    names = [i.filename for i in z.infolist() if i.filename.endswith(".lua")]
    hits = [n for n in names if any(k in n.lower() for k in (
        "commonmanager", "tfglobal", "httphelper", "urlconfig", "gameconfig",
        "requireglobal", "channel", "configurl", "debug"
    ))]
    for n in sorted(set(NAMES + hits)):
        if "/uiconfig/" in n:
            continue
        try:
            data = z.read(n)
        except KeyError:
            print("MISS", n)
            continue
        dest = os.path.join(OUT, n.replace("/", os.sep))
        if os.path.exists(dest):
            print("have", n)
            continue
        pt = decrypt_bytes(data)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        open(dest, "wb").write(pt)
        print(len(pt), n)


if __name__ == "__main__":
    main()
