#!/usr/bin/env bash
set -euo pipefail

mkdir -p e2e work/offline/logs

adb root || true
adb wait-for-device
sleep 2

echo "ABI=$(adb shell getprop ro.product.cpu.abilist | tr -d '\r')" | tee e2e/device.txt
adb shell getprop ro.build.version.release | tr -d '\r' | sed 's/^/Android=/' | tee -a e2e/device.txt

SDK_ROOT="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
AAPT="$(find "$SDK_ROOT/build-tools" -type f -name aapt | sort -V | tail -1 || true)"
if [[ -n "$AAPT" ]]; then
  "$AAPT" dump badging work/apk/base-offline.apk > e2e/apk-badging.txt
else
  echo 'aapt not found; continuing without APK badging dump' > e2e/apk-badging.txt
fi

set +e
adb install -r work/apk/base-offline.apk 2>&1 | tee e2e/install.txt
INSTALL_RC=${PIPESTATUS[0]}
set -e
if [[ $INSTALL_RC -ne 0 ]]; then
  echo "base-offline.apk install failed (rc=$INSTALL_RC)" >&2
  exit "$INSTALL_RC"
fi
adb shell pm path com.datealive.action.rpg | tee e2e/package-paths.txt

DEVICE="$(adb devices | awk '$2=="device" && $1 ~ /^emulator-/ {print $1; exit}')"
test -n "$DEVICE"
DAL_DEVICE="$DEVICE" DAL_CIPHER_MODE=plainsend python work/tools/hotpatch_main_scene.py apply 2>&1 | tee e2e/hotpatch.txt

python -u work/offline/http_server.py > work/offline/logs/http.out 2>&1 &
HTTP_PID=$!
python -u work/offline/tcp_server_main_scene.py > work/offline/logs/tcp.out 2>&1 &
TCP_PID=$!
cleanup() {
  kill "$HTTP_PID" "$TCP_PID" 2>/dev/null || true
}
trap cleanup EXIT
sleep 2

adb logcat -c
adb shell am force-stop com.datealive.action.rpg || true
adb shell am start -n com.datealive.action.rpg/org.cocos2dx.TerransForce.TerransForce 2>&1 | tee e2e/am-start.txt

# The Cocos login UI exposes little useful accessibility metadata. Take a
# baseline screenshot, exercise the same tap-through flow used manually, then
# use a short touch-only monkey sequence to cover resolution/layout variance.
sleep 12
adb exec-out screencap -p > e2e/shot-00.png || true
for xy in '540 960' '960 540' '540 1450' '1450 540' '540 960' '960 540'; do
  adb shell input tap $xy || true
  sleep 3
done
adb shell monkey -p com.datealive.action.rpg --pct-touch 100 --throttle 700 -v 24 > e2e/monkey.txt 2>&1 || true
sleep 15

adb exec-out screencap -p > e2e/shot-final.png || true
adb logcat -d -v threadtime > e2e/logcat.txt
adb shell dumpsys activity activities > e2e/activity.txt || true
adb shell pidof com.datealive.action.rpg > e2e/pid.txt || true
cp work/offline/logs/tcp.out e2e/tcp.out || true
cp work/offline/logs/http.out e2e/http.out || true
cp work/offline/logs/tcp.log e2e/tcp.log || true

echo '=== TCP tail ==='
tail -80 e2e/tcp.out || true
echo '=== relevant logcat ==='
grep -E 'DAL-OFFLINE|DAL-WAIT|MainScene|MainLayer|DefaultMainLayer|levelCid|LUA ERROR|LUA-print' e2e/logcat.txt | tail -160 || true

# A connection and the stateful 1796 bootstrap must both have run.
grep -q 'proto=1796' e2e/tcp.out
grep -q 'bootstrap dungeon progress' e2e/tcp.out
# Regression signature from the captured black-screen run must be gone.
! grep -q 'recv no limitheroinfos: levelCid=0' e2e/logcat.txt
# MainLayer prints its selected uiconfig path during construction.
grep -q 'DefaultMainLayer' e2e/logcat.txt
