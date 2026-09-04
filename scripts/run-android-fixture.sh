#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="$sdk_root/platform-tools/adb"
emulator="$sdk_root/emulator/emulator"
avd="${1:-$KARTPAD_ANDROID_PHONE_AVD}"
case "$avd" in
  "$KARTPAD_ANDROID_PHONE_AVD") expected_page_size=4096 ;;
  "$KARTPAD_ANDROID_PS16K_AVD") expected_page_size=16384 ;;
  *) echo "ERROR: unsupported AVD: $avd" >&2; exit 1 ;;
esac

if "$adb" devices | sed -n '2,$p' | grep -q '[[:space:]]device$'; then
  echo "ERROR: an Android device/emulator is already connected; preserve the one-emulator rule" >&2
  exit 1
fi

"$repo_root/scripts/build-android-fixture.sh"
"$repo_root/scripts/audit-android-package.sh"
emulator_log="$repo_root/.android-bootstrap/emulator-$avd.raw.log"
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

# A freshly wiped phone image initially reports portrait even though KartPad is
# landscape-only. Settle the disposable AVD before launching SDL so Android
# does not destroy the first activity while its native thread is starting.
"$adb" shell input keyevent KEYCODE_WAKEUP >/dev/null
"$adb" shell wm dismiss-keyguard >/dev/null 2>&1 || true
"$adb" shell settings put system accelerometer_rotation 0
"$adb" shell settings put system user_rotation 1
"$adb" shell am start -W -a android.intent.action.MAIN \
  -c android.intent.category.HOME >/dev/null
sleep 2

abi="$("$adb" shell getprop ro.product.cpu.abi | tr -d '\r')"
page_size="$("$adb" shell getconf PAGE_SIZE | tr -d '\r')"
[[ "$abi" == "arm64-v8a" ]] || { echo "ERROR: unexpected device ABI: $abi" >&2; exit 1; }
[[ "$page_size" == "$expected_page_size" ]] || {
  echo "ERROR: $avd page size $page_size != $expected_page_size" >&2
  exit 1
}

apk="$repo_root/android/app/build/outputs/apk/debug/app-debug.apk"
"$adb" install -r "$apk" >/dev/null
"$adb" logcat -c
"$adb" shell am force-stop dev.kartpad.android
"$adb" shell am start -W -n dev.kartpad.android/.KartPadActivity \
  --ez dev.kartpad.android.TEST_RETRO_REWIND_EXTRACTION true \
  --ez dev.kartpad.android.TEST_RETRO_REWIND_WORKER true >/dev/null
wait_for_marker() {
  local marker="$1"
  for _ in {1..60}; do
    if "$adb" logcat -d -v brief KartPadFixture:I AndroidRuntime:E '*:S' |
        grep -Fq "$marker"; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: fixture marker was not observed: $marker" >&2
  "$adb" logcat -d -v brief KartPadFixture:V SDL:V AndroidRuntime:E libc:F '*:S' >&2
  return 1
}

wait_for_marker \
  "A1 guest memory passed reserve_bytes=4294967296"
wait_for_marker \
  "A1 ELF scheduler passed operations=2000000 hash=0x7287563387fb1677 fiber_switches=1000000"
wait_for_marker "A2 SDL gamepad contract passed"
wait_for_marker "A3 JNI archive extraction passed entries=2 bytes=7"
wait_for_marker "A3 durable worker fixture enqueued twice with KEEP"
wait_for_marker "A3 durable worker fixture started id="
worker_id="$("$adb" logcat -d -v brief KartPadFixture:I '*:S' |
  sed -n 's/.*A3 durable worker fixture started id=\([^ ]*\).*/\1/p' |
  tail -1)"
[[ "$worker_id" =~ ^[0-9a-f-]{36}$ ]] || {
  echo "ERROR: could not parse unique worker id: $worker_id" >&2
  exit 1
}
wait_for_marker "A3 durable worker fixture completed id=$worker_id attempt=0"
worker_starts="$("$adb" logcat -d -v brief KartPadFixture:I '*:S' |
  grep -Fc "A3 durable worker fixture started id=$worker_id")"
[[ "$worker_starts" == 1 ]] || {
  echo "ERROR: unique worker fixture started $worker_starts times" >&2
  exit 1
}
wait_for_marker \
  "A1 Vulkan present passed abi=arm64-v8a page_size=$expected_page_size"

# Exercise the other allowed landscape orientation and require SDL to observe
# it before accepting a newly created Dawn surface presentation.
"$adb" shell settings put system accelerometer_rotation 1
"$adb" emu sensor set acceleration -9.81:0:0 >/dev/null
wait_for_marker "A1 orientation observed orientation=2 previous=1"
wait_for_marker \
  "A1 Vulkan recreate passed generation=2 reason=orientation orientation=2 page_size=$expected_page_size"

for cycle in 1 2 3; do
  generation=$((cycle + 2))
  "$adb" shell input keyevent KEYCODE_HOME
  wait_for_marker "A1 lifecycle background observed cycle=$cycle"
  # Let Android complete onStop/surface teardown before requesting foreground.
  sleep 3
  "$adb" shell am start -W -n dev.kartpad.android/.KartPadActivity >/dev/null
  wait_for_marker \
    "A1 Vulkan recreate passed generation=$generation reason=foreground orientation=2 page_size=$expected_page_size"
done

if "$adb" logcat -d -v brief KartPadFixture:E '*:S' | grep -q .; then
  echo "ERROR: fixture emitted an error despite reaching all pass markers" >&2
  "$adb" logcat -d -v brief KartPadFixture:V '*:S' >&2
  exit 1
fi

echo "Android A1/A2 fixture passed: avd=$avd api=$("$adb" shell getprop ro.build.version.sdk | tr -d '\r') abi=$abi page_size=$page_size guest_memory=4GiB-aliased-protected scheduler=2M-operations fiber=1M-register-checked-switches gamepad_contract=passed backend=Vulkan readback_rgba=20-80-e0-ff surface=presented lifecycle=orientation-plus-3-background-foreground-recreations"
