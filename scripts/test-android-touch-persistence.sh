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
"$adb" shell pm clear dev.kartpad.android >/dev/null
"$adb" logcat -c

"$adb" shell am start -W -n dev.kartpad.android/.KartPadActivity \
  --es dev.kartpad.android.TEST_TOUCH_PERSISTENCE seed >/dev/null
seeded="A4 touch persistence fixture seeded a=0.55,0.55 size=1.25 b=hidden"
for _ in {1..30}; do
  output="$("$adb" logcat -d -v brief KartPadFixture:I AndroidRuntime:E '*:S')"
  grep -Fq "$seeded" <<<"$output" && break
  sleep 1
done
grep -Fq "$seeded" <<<"${output:-}" || {
  echo "ERROR: touch-persistence fixture did not seed state" >&2
  exit 1
}

# Allow SharedPreferences.apply() to finish, then require a new process to read
# and render the saved values.
sleep 1
"$adb" shell am force-stop dev.kartpad.android
"$adb" shell am start -W -n dev.kartpad.android/.KartPadActivity \
  --es dev.kartpad.android.TEST_TOUCH_PERSISTENCE verify >/dev/null

for _ in {1..30}; do
  output="$("$adb" logcat -d -v brief KartPadFixture:I AndroidRuntime:E '*:S')"
  if grep -Fq "A4 touch persistence fixture passed" <<<"$output"; then
    printf '%s\n' "$seeded"
    grep -F "A4 touch persistence fixture passed" <<<"$output" | tail -1
    exit 0
  fi
  if grep -Fq "A4 touch persistence fixture failed" <<<"$output"; then
    printf '%s\n' "$output" >&2
    exit 1
  fi
  sleep 1
done

echo "ERROR: touch-persistence fixture did not emit its pass marker" >&2
"$adb" logcat -d -v brief KartPadFixture:V AndroidRuntime:E '*:S' >&2
exit 1
