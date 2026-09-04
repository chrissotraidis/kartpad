#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="$sdk_root/platform-tools/adb"
emulator="$sdk_root/emulator/emulator"
avd="$KARTPAD_ANDROID_PHONE_AVD"
package="dev.kartpad.android"
filler="/data/local/tmp/kartpad-low-space.fill"

if "$adb" devices | sed -n '2,$p' | grep -q '[[:space:]]device$'; then
  echo "ERROR: an Android device/emulator is already connected; preserve the one-emulator rule" >&2
  exit 1
fi

"$repo_root/scripts/build-android-fixture.sh"
"$repo_root/scripts/audit-android-package.sh"
emulator_log="$repo_root/.android-bootstrap/emulator-$avd-low-space.raw.log"
"$emulator" "@$avd" -no-window -no-audio -no-boot-anim -no-snapshot \
  -gpu auto -wipe-data >"$emulator_log" 2>&1 &
emulator_pid=$!
cleanup() {
  "$adb" shell rm -f "$filler" >/dev/null 2>&1 || true
  "$adb" emu kill >/dev/null 2>&1 || true
  wait "$emulator_pid" 2>/dev/null || true
}
trap cleanup EXIT

"$adb" wait-for-device
booted=0
for _ in {1..60}; do
  if [[ "$("$adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
    booted=1
    break
  fi
  sleep 2
done
[[ "$booted" == 1 ]] || { echo "ERROR: emulator did not finish booting" >&2; exit 1; }

abi="$("$adb" shell getprop ro.product.cpu.abi | tr -d '\r')"
page_size="$("$adb" shell getconf PAGE_SIZE | tr -d '\r')"
[[ "$abi" == "arm64-v8a" ]] || { echo "ERROR: unexpected device ABI: $abi" >&2; exit 1; }
[[ "$page_size" == "4096" ]] || { echo "ERROR: unexpected page size: $page_size" >&2; exit 1; }

apk="$repo_root/android/app/build/outputs/apk/debug/app-debug.apk"
"$adb" install -r "$apk" >/dev/null

required_bytes="$(python3 - "$repo_root/builder/profiles/mkwii-rmcp01-rev0.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    retro = json.load(stream)["retroRewind"]
print(retro["archive"]["bytes"] + retro["archive"]["maximumExpandedBytes"] + 256 * 1024 * 1024)
PY
)"
available_kib="$("$adb" shell df -k /data | awk 'NR == 2 {print $4}' | tr -d '\r')"
[[ "$available_kib" =~ ^[0-9]+$ ]] || {
  echo "ERROR: could not read disposable AVD free space" >&2
  exit 1
}
available_bytes=$((available_kib * 1024))
target_bytes=$((required_bytes - 128 * 1024 * 1024))
fill_bytes=$((available_bytes - target_bytes))
if (( fill_bytes <= 0 )); then
  echo "ERROR: wiped AVD is already below the controlled low-space target" >&2
  exit 1
fi
maximum_fill_bytes=$((2 * 1024 * 1024 * 1024))
if (( fill_bytes > maximum_fill_bytes )); then
  echo "ERROR: controlled filler would exceed the 2 GiB safety cap" >&2
  exit 1
fi
host_available_kib="$(df -Pk "$repo_root" | awk 'NR == 2 {print $4}')"
host_reserve_bytes=$((8 * 1024 * 1024 * 1024))
if (( host_available_kib * 1024 < fill_bytes + host_reserve_bytes )); then
  echo "ERROR: host lacks the required 8 GiB reserve for the disposable filler" >&2
  exit 1
fi

fill_mib=$(((fill_bytes + 1024 * 1024 - 1) / (1024 * 1024)))
"$adb" shell dd if=/dev/zero of="$filler" bs=1048576 count="$fill_mib" \
  >/dev/null 2>&1

"$adb" logcat -c
"$adb" shell am start -W \
  -n "$package/.RetroRewindWorkerFixtureActivity" \
  --ez dev.kartpad.android.TEST_RETRO_REWIND_SPACE_PROBE true >/dev/null

marker=""
for _ in {1..30}; do
  marker="$("$adb" logcat -d -v raw KartPadFixture:I AndroidRuntime:E '*:S' |
    grep -F 'A3 Android space probe error=' | tail -1 || true)"
  [[ -n "$marker" ]] && break
  sleep 1
done
[[ "$marker" == *"error=INSUFFICIENT_SHARED_STORE"* ]] || {
  echo "ERROR: production space probe did not reject the controlled low-space store" >&2
  printf '%s\n' "$marker" >&2
  exit 1
}

reported_required="$(printf '%s\n' "$marker" |
  sed -n 's/.*required_files=\([0-9][0-9]*\).*/\1/p')"
reported_available="$(printf '%s\n' "$marker" |
  sed -n 's/.*available_files=\([0-9][0-9]*\).*/\1/p')"
[[ "$reported_required" == "$required_bytes" ]] || {
  echo "ERROR: Android requirement $reported_required != profile requirement $required_bytes" >&2
  exit 1
}
if [[ ! "$reported_available" =~ ^[0-9]+$ ]] ||
    (( reported_available >= reported_required )); then
  echo "ERROR: Android low-space result did not report a real deficit" >&2
  exit 1
fi

if "$adb" shell run-as "$package" ls cache 2>/dev/null |
    grep -Eq 'RetroRewind.*\.(zip|part)$'; then
  echo "ERROR: low-space probe unexpectedly left archive acquisition state" >&2
  exit 1
fi

echo "Android Retro Rewind low-space preflight passed: avd=$avd api=36 abi=$abi page_size=$page_size required=$reported_required available=$reported_available filler_mib=$fill_mib archive_bytes=0"
