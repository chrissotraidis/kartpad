#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="$sdk_root/platform-tools/adb"
lane="${1:-phone}"
case "$lane" in
  phone) expected_width=2400; expected_height=1080; user_rotation=1 ;;
  tablet) expected_width=2560; expected_height=1600; user_rotation=0 ;;
  *) echo "ERROR: lane must be phone or tablet" >&2; exit 64 ;;
esac

device_count="$("$adb" devices | sed -n '2,$p' | grep -c '[[:space:]]device$' || true)"
[[ "$device_count" == 1 ]] || {
  echo "ERROR: expected exactly one connected Android emulator/device" >&2
  exit 1
}

"$repo_root/scripts/build-android-fixture.sh"
apk="$repo_root/android/app/build/outputs/apk/debug/app-debug.apk"
"$adb" install -r "$apk" >/dev/null
"$adb" shell input keyevent KEYCODE_WAKEUP >/dev/null
"$adb" shell wm dismiss-keyguard >/dev/null 2>&1 || true
"$adb" shell settings put system accelerometer_rotation 0
"$adb" shell settings put system user_rotation "$user_rotation"
"$adb" shell am force-stop dev.kartpad.android
"$adb" shell am start -W -n dev.kartpad.android/.KartPadLaunchActivity \
  --ez dev.kartpad.android.TEST_MODE_CHOOSER_GAME_DATA_VALID true >/dev/null

artifact_root="$repo_root/.android-bootstrap/selector-visual-$lane"
mkdir -p "$artifact_root"
tree="$artifact_root/hierarchy.xml"
frame="$artifact_root/frame.raw"
ready=0
for _ in {1..20}; do
  if "$adb" shell uiautomator dump /sdcard/kartpad-selector-visual.xml >/dev/null \
      2>&1 &&
      "$adb" exec-out cat /sdcard/kartpad-selector-visual.xml >"$tree" &&
      grep -Fq 'content-desc="Mario Kart Wii' "$tree" &&
      grep -Fq 'content-desc="Retro Rewind&#10;Download 6.12.5' "$tree"; then
    ready=1
    break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || {
  echo "ERROR: selector did not reach its stable source-fixture state" >&2
  exit 1
}

"$adb" exec-out screencap >"$frame"
"$repo_root/scripts/check-android-selector-visual.py" \
  --tree "$tree" \
  --frame "$frame" \
  --width "$expected_width" \
  --height "$expected_height"
