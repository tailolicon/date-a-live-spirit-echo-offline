# Artifacts kept outside git

Binaries too large or not redistributable for the repo. Rebuild the
derived ones locally rather than fetching them:

| Derived file | How to get it back |
|---|---|
| `work/apk/com.datealive.action.rpg.apk` | inside the XAPK |
| `work/apk/InstallPack.apk` | inside the XAPK |
| `work/apk/config.armeabi_v7a.apk` | inside the XAPK |
| `work/apk/*.offline.apk` | `python work/patch_offline_lua.py` |
| `work/apk/*.idsig` | produced by signing |
| `work/dump/all_lua` | `python work/tools/bootstrap.py --full` |
| `work/extract/` | unzip the base APK |
| `work/frida/frida-server*` | frida GitHub releases |

## Contents

### `Date+A+Live_+Spirit+Echo_1.37_APKPure.xapk`

Original store package: base APK + armeabi_v7a split + InstallPack + manifest. Everything else is derived from this.

- size: 1.2 GB
- sha256: `123b01823d22afb95e85a6440ea6d2ba95b250cda64c4cc35e4538c183f88c67`

### `work/apk/base-offline.apk`

Signed repacked offline build - this is what is installed on the emulator.

- size: 173.2 MB
- sha256: `03a0693a4878ecdcf09dd89638813f7fd0540de196bd7c5f4c2b6befd39d40ac`

### `work/apk/debug.keystore`

Throwaway keystore that signed base-offline.apk (store/key pass: android). Needed to re-sign an updated build so it installs over the existing one.

- size: 2.6 KB
- sha256: `d8857dabe25b1dfe6cd2e0c854b29eee6f8c9f5b23277b3465550ade32c09f30`

### `work/extract/lib/libTerransForce.so`

ARM32 engine binary. Every address in docs/PROTOCOL.md refers to this file.

- size: 9.9 MB
- sha256: `f0ab620552b397df6441069b2ac077e936e2daec3facaf15cac58bdbbe4ba920`

### `work/offline/logs-bundle.zip`

Session logs: packet trace (tcp.out), account API (http.out), logcat.

- size: 13.8 MB
- sha256: `ee73f543655b4344dc8bea2b8a292634e536a936bb40ed3d1506c223a08a2266`
