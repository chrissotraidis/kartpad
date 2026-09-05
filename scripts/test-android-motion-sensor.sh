#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="$sdk_root/platform-tools/adb"
lane="${1:-phone}"
case "$lane" in
  phone) user_rotation=1 ;;
  tablet) user_rotation=0 ;;
  *) echo "ERROR: lane must be phone or tablet" >&2; exit 64 ;;
esac

device_count="$("$adb" devices | sed -n '2,$p' | grep -c '[[:space:]]device$' || true)"
[[ "$device_count" == 1 ]] || {
  echo "ERROR: expected exactly one connected Android emulator/device" >&2
  exit 1
}

original_acceleration="$("$adb" emu sensor get acceleration |
  sed -n 's/^acceleration = //p')"
cleanup() {
  "$adb" emu sensor set acceleration "$original_acceleration" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"$repo_root/scripts/build-android-fixture.sh"
apk="$repo_root/android/app/build/outputs/apk/debug/app-debug.apk"
"$adb" install -r "$apk" >/dev/null
"$adb" shell pm clear dev.kartpad.android >/dev/null
"$adb" shell input keyevent KEYCODE_WAKEUP >/dev/null
"$adb" shell wm dismiss-keyguard >/dev/null 2>&1 || true
"$adb" shell settings put system accelerometer_rotation 0
"$adb" shell settings put system user_rotation "$user_rotation"

run_mode() {
  local mode="$1"
  local direction="$2"
  "$adb" emu sensor set acceleration 0:9.8:0.2 >/dev/null
  "$adb" logcat -c
  "$adb" shell am force-stop dev.kartpad.android
  "$adb" shell am start -W -n dev.kartpad.android/.KartPadActivity \
    --es dev.kartpad.android.TEST_MOTION_SENSOR "$mode" >/dev/null

  local registered=0
  for _ in {1..30}; do
    if "$adb" logcat -d -v brief KartPadMotion:I '*:S' |
        grep -Fq 'started registered=true'; then
      registered=1
      break
    fi
    sleep 1
  done
  [[ "$registered" == 1 ]] || {
    echo "ERROR: motion sensor did not register for $mode" >&2
    exit 1
  }

  sleep 1
  "$adb" emu sensor set acceleration -3.4:9.19:0.2 >/dev/null
  for _ in {1..40}; do
    samples="$("$adb" logcat -d -v brief KartPadFixture:I AndroidRuntime:E '*:S')"
    if grep -Fq 'A4 motion sensor' <<<"$samples" && \
        KARTPAD_MOTION_SAMPLES="$samples" python3 - "$mode" "$direction" <<'PY'
import os
import re
import sys

mode, direction = sys.argv[1:]
text = os.environ["KARTPAD_MOTION_SAMPLES"]
values = [
    float(value)
    for value in re.findall(
        rf"A4 motion sensor sample mode={mode} steering=(-?[0-9.eE+-]+)", text,
    )
]
if direction == "positive":
    raise SystemExit(0 if any(value > 0.30 for value in values) else 1)
raise SystemExit(0 if any(value < -0.30 for value in values) else 1)
PY
    then
      echo "A4 motion sensor mode=$mode direction=$direction passed"
      return 0
    fi
    sleep 1
  done
  echo "ERROR: motion sensor did not produce $direction steering for $mode" >&2
  "$adb" logcat -d -v brief KartPadFixture:I KartPadMotion:V AndroidRuntime:E '*:S' >&2
  exit 1
}

run_mode standard positive
run_mode inverted negative
echo "Android motion sensor flow passed: lane=$lane standard=positive inverted=negative"
