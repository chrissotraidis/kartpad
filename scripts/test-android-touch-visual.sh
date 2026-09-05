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

"$repo_root/scripts/build-android-fixture.sh"
apk="$repo_root/android/app/build/outputs/apk/debug/app-debug.apk"
"$adb" install -r "$apk" >/dev/null
"$adb" shell input keyevent KEYCODE_WAKEUP >/dev/null
"$adb" shell wm dismiss-keyguard >/dev/null 2>&1 || true
"$adb" shell settings put system accelerometer_rotation 0
"$adb" shell settings put system user_rotation "$user_rotation"
"$adb" logcat -c
"$adb" shell am force-stop dev.kartpad.android
"$adb" shell am start -W -n dev.kartpad.android/.KartPadActivity \
  --ez dev.kartpad.android.TEST_TOUCH_OVERLAY true >/dev/null

artifact_root="$repo_root/.android-bootstrap/touch-visual-$lane"
mkdir -p "$artifact_root"
tree="$artifact_root/hierarchy.xml"
frame="$artifact_root/frame.raw"
ready=0
for _ in {1..20}; do
  if "$adb" shell uiautomator dump /sdcard/kartpad-touch-visual.xml >/dev/null \
      2>&1 &&
      "$adb" exec-out cat /sdcard/kartpad-touch-visual.xml >"$tree" &&
      grep -Fq 'content-desc="Move stick"' "$tree" &&
      grep -Fq 'content-desc="Z button"' "$tree" &&
      "$adb" logcat -d -v brief KartPadFixture:I '*:S' |
        grep -Fq 'A1 Vulkan present passed'; then
    ready=1
    break
  fi
  sleep 1
done
[[ "$ready" == 1 ]] || {
  echo "ERROR: touch overlay did not expose its stable accessibility tree" >&2
  exit 1
}

"$adb" exec-out screencap >"$frame"
"$repo_root/scripts/check-android-touch-visual.py" \
  --tree "$tree" --frame "$frame" --lane "$lane"
