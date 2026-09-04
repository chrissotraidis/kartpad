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
component="$package/.KartPadActivity"

if "$adb" devices | sed -n '2,$p' | grep -q '[[:space:]]device$'; then
  echo "ERROR: an Android device/emulator is already connected; preserve the one-emulator rule" >&2
  exit 1
fi

"$repo_root/scripts/build-android-fixture.sh"
"$repo_root/scripts/audit-android-package.sh"
emulator_log="$repo_root/.android-bootstrap/emulator-$avd-worker-restart.raw.log"
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
  sleep 2
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
  for _ in {1..60}; do
    if "$adb" logcat -d -v brief KartPadFixture:I AndroidRuntime:E '*:S' |
        grep -Fq "$marker"; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: worker restart marker was not observed: $marker" >&2
  "$adb" logcat -d -v brief KartPadFixture:V WM-WorkerWrapper:V AndroidRuntime:E '*:S' >&2
  return 1
}

"$adb" shell am start -W -n "$component" \
  --ez dev.kartpad.android.TEST_RETRO_REWIND_WORKER_RESTART true >/dev/null
wait_for_marker "A3 durable worker restart fixture enqueued id="
worker_id="$("$adb" logcat -d -v brief KartPadFixture:I '*:S' |
  sed -n 's/.*A3 durable worker restart fixture enqueued id=\([^ ]*\).*/\1/p' |
  tail -1)"
[[ "$worker_id" =~ ^[0-9a-f-]{36}$ ]] || {
  echo "ERROR: could not parse durable worker id: $worker_id" >&2
  exit 1
}
wait_for_marker "A3 durable resume fixture started id=$worker_id attempt=0 prefix=0"
wait_for_marker "A3 durable resume fixture checkpoint id=$worker_id bytes="

"$adb" shell am force-stop "$package"
if "$adb" shell pidof "$package" | grep -q '[0-9]'; then
  echo "ERROR: KartPad process survived force-stop" >&2
  exit 1
fi
"$adb" shell am start -W -n "$component" >/dev/null
wait_for_marker "A3 durable resume fixture started id=$worker_id attempt=1 prefix="
resumed_from="$("$adb" logcat -d -v brief KartPadFixture:I '*:S' |
  sed -n "s/.*A3 durable resume fixture started id=$worker_id attempt=1 prefix=\([0-9][0-9]*\).*/\1/p" |
  tail -1)"
if ! [[ "$resumed_from" =~ ^[0-9]+$ ]] ||
    ! (( resumed_from > 0 && resumed_from < 92 )); then
  echo "ERROR: persisted worker resumed from invalid offset: $resumed_from" >&2
  exit 1
fi
wait_for_marker "A3 durable resume fixture completed id=$worker_id attempt=1"

worker_starts="$("$adb" logcat -d -v brief KartPadFixture:I '*:S' |
  grep -Fc "A3 durable resume fixture started id=$worker_id")"
[[ "$worker_starts" == 2 ]] || {
  echo "ERROR: persisted worker $worker_id started $worker_starts times; expected exactly 2" >&2
  exit 1
}
if "$adb" logcat -d -v brief KartPadFixture:E AndroidRuntime:E '*:S' | grep -q .; then
  echo "ERROR: worker restart fixture emitted an error" >&2
  "$adb" logcat -d -v brief KartPadFixture:V AndroidRuntime:E '*:S' >&2
  exit 1
fi

echo "Android A3 durable worker resume passed: avd=$avd worker_id=$worker_id process_starts=$worker_starts resumed_from=$resumed_from final_state=completed"
