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
component="$package/.RetroRewindInstallActivity"
fixture_component="$package/.RetroRewindWorkerFixtureActivity"

if "$adb" devices | sed -n '2,$p' | grep -q '[[:space:]]device$'; then
  echo "ERROR: an Android device/emulator is already connected; preserve the one-emulator rule" >&2
  exit 1
fi

"$repo_root/scripts/build-android-fixture.sh"
"$repo_root/scripts/audit-android-package.sh"
emulator_log="$repo_root/.android-bootstrap/emulator-$avd-installer-ui.raw.log"
"$emulator" "@$avd" -no-window -no-audio -no-boot-anim -no-snapshot \
  -gpu auto -wipe-data >"$emulator_log" 2>&1 &
emulator_pid=$!
cleanup() {
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
  sleep 1
done
[[ "$booted" == 1 ]] || { echo "ERROR: emulator did not finish booting" >&2; exit 1; }

"$adb" shell input keyevent KEYCODE_WAKEUP >/dev/null
"$adb" shell wm dismiss-keyguard >/dev/null 2>&1 || true
"$adb" shell settings put system accelerometer_rotation 0
"$adb" shell settings put system user_rotation 1
"$adb" install -r "$repo_root/android/app/build/outputs/apk/debug/app-debug.apk" >/dev/null
"$adb" logcat -c

wait_for_marker() {
  local marker="$1"
  for _ in {1..40}; do
    if "$adb" logcat -d -v brief KartPadInstaller:I KartPadFixture:I AndroidRuntime:E '*:S' |
        grep -Fq "$marker"; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: installer UI marker was not observed: $marker" >&2
  "$adb" logcat -d -v brief KartPadInstaller:V KartPadFixture:V AndroidRuntime:E '*:S' >&2
  return 1
}

network_ready=0
for _ in {1..45}; do
  if "$adb" shell ping -c 1 -W 1 update.rwfc.net >/dev/null 2>&1; then
    network_ready=1
    break
  fi
  sleep 1
done
[[ "$network_ready" == 1 ]] || {
  echo "ERROR: emulator network/DNS did not become ready for the official version check" >&2
  exit 1
}

"$adb" shell am start -W -n "$fixture_component" \
  --ez dev.kartpad.android.TEST_RETRO_REWIND_VERSION_CHECK true >/dev/null
wait_for_marker "A3 Android official version check latest=6.12.5 update_required=false"
"$adb" shell am force-stop "$package"
"$adb" logcat -c

"$adb" shell am start -W -n "$component" >/dev/null
wait_for_marker "A3 installer UI state=not-installed"
if ! "$adb" shell dumpsys activity activities |
    grep -F "topResumedActivity=" | grep -Fq "$component"; then
  echo "ERROR: production installer UI is not the resumed activity" >&2
  exit 1
fi
"$adb" shell am force-stop "$package"
"$adb" shell pm grant "$package" android.permission.POST_NOTIFICATIONS
"$adb" logcat -c

"$adb" shell am start -W -n "$component" \
  --ez dev.kartpad.android.TEST_RETRO_REWIND_INSTALLER_UI true >/dev/null
wait_for_marker "A3 installer UI state=running-fixture"
if ! "$adb" shell dumpsys activity activities |
    grep -F "topResumedActivity=" | grep -Fq "$component"; then
  echo "ERROR: production installer UI is not the resumed activity" >&2
  exit 1
fi
notification_dump="$("$adb" shell dumpsys notification --noredact)"
if [[ "$notification_dump" != *"pkg=$package"* ||
      "$notification_dump" != *"contentIntent=PendingIntent"* ]]; then
  echo "ERROR: foreground progress notification is not visible and actionable" >&2
  exit 1
fi
if ! "$adb" shell dumpsys activity intents |
    grep -Fq "cmp=$package/.RetroRewindInstallActivity"; then
  echo "ERROR: installer notification does not return to the production UI" >&2
  exit 1
fi

# The bounded fixture exposes only one active control. Keyboard activation
# exercises the real production Cancel button without coordinate assumptions.
"$adb" shell input keyevent KEYCODE_TAB
"$adb" shell input keyevent KEYCODE_ENTER
wait_for_marker "A3 installer UI cancel requested"
wait_for_marker "A3 installer UI state=cancelled"

worker_id="$("$adb" logcat -d -v brief KartPadFixture:I '*:S' |
  sed -n 's/.*A3 durable worker fixture started id=\([^ ]*\).*/\1/p' | tail -1)"
[[ "$worker_id" =~ ^[0-9a-f-]{36}$ ]] || {
  echo "ERROR: could not parse installer UI worker id: $worker_id" >&2
  exit 1
}
if "$adb" logcat -d -v brief KartPadFixture:I '*:S' |
    grep -Fq "A3 durable worker fixture completed id=$worker_id"; then
  echo "ERROR: cancelled installer UI worker emitted a completion marker" >&2
  exit 1
fi

"$adb" shell am force-stop "$package"
"$adb" shell am start -W -n "$component" >/dev/null
wait_for_marker "A3 installer UI state=cancelled"
if "$adb" logcat -d -v brief KartPadInstaller:E KartPadFixture:E AndroidRuntime:E '*:S' |
    grep -q .; then
  echo "ERROR: installer UI fixture emitted an error" >&2
  "$adb" logcat -d -v brief KartPadInstaller:V KartPadFixture:V AndroidRuntime:E '*:S' >&2
  exit 1
fi

echo "Android A3 production installer UI passed: avd=$avd worker_id=$worker_id final_state=cancelled"
