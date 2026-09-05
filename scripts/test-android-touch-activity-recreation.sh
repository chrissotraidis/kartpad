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
  --ez dev.kartpad.android.TEST_TOUCH_ACTIVITY_RECREATE true >/dev/null

armed="A4 activity recreation fixture armed held=0x10 owners=1"
outgoing="A4 activity recreation fixture outgoing old=neutral"
passed="A4 activity recreation fixture passed new=neutral"
for _ in {1..45}; do
  output="$("$adb" logcat -d -v brief KartPadFixture:I AndroidRuntime:E '*:S')"
  if grep -Fq "$armed" <<<"$output" &&
      grep -Fq "$outgoing" <<<"$output" &&
      grep -Fq "$passed" <<<"$output" &&
      grep -Fq "a_size=1.25 b=hidden" <<<"$output"; then
    grep -F "$armed" <<<"$output" | tail -1
    grep -F "$outgoing" <<<"$output" | tail -1
    grep -F "$passed" <<<"$output" | tail -1
    exit 0
  fi
  if grep -Fq "A4 activity recreation fixture failed" <<<"$output"; then
    printf '%s\n' "$output" >&2
    exit 1
  fi
  sleep 1
done

echo "ERROR: activity recreation fixture did not emit every pass marker" >&2
"$adb" logcat -d -v brief KartPadFixture:V AndroidRuntime:E '*:S' >&2
exit 1
