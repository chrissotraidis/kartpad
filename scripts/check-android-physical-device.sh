#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="${KARTPAD_ADB:-$sdk_root/platform-tools/adb}"
minimum_free_kib="${KARTPAD_ANDROID_A2_MIN_FREE_KIB:-4194304}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -x "$adb" ]] || fail "adb is unavailable at the configured path"
[[ "$minimum_free_kib" =~ ^[0-9]+$ ]] || \
  fail "KARTPAD_ANDROID_A2_MIN_FREE_KIB must be an integer"

set +e
devices="$("$adb" devices -l 2>&1)"
devices_status=$?
set -e
(( devices_status == 0 )) || fail "unable to enumerate ADB targets; no device serial was printed"
ready_count="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
unavailable_count="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 != "device" && NF >= 2 { count++ } END { print count + 0 }')"

if [[ "$ready_count" != 1 ]]; then
  fail "expected exactly one ready ADB target (ready=$ready_count unavailable=$unavailable_count); no device serial was printed"
fi

# Keep the ADB serial private. It is used only to disambiguate shell commands and
# is deliberately never included in output suitable for an evidence record.
serial="$(printf '%s\n' "$devices" | awk 'NR > 1 && $2 == "device" { print $1; exit }')"
adb_shell() {
  local output
  local command_status
  set +e
  output="$("$adb" -s "$serial" shell "$@" 2>&1)"
  command_status=$?
  set -e
  if (( command_status != 0 )); then
    output="${output//$serial/<redacted>}"
    echo "ERROR: adb shell command failed ($*): $output" >&2
    return "$command_status"
  fi
  printf '%s\n' "$output" | tr -d '\r'
}

qemu="$(adb_shell getprop ro.kernel.qemu)"
[[ "$qemu" != 1 ]] || fail "the sole ready ADB target is an emulator, not physical hardware"

api="$(adb_shell getprop ro.build.version.sdk)"
abi="$(adb_shell getprop ro.product.cpu.abi)"
page_size="$(adb_shell getconf PAGE_SIZE)"
manufacturer="$(adb_shell getprop ro.product.manufacturer |
  tr '[:space:]' '_' | tr -cd '[:alnum:]_.-')"
model="$(adb_shell getprop ro.product.model |
  tr '[:space:]' '_' | tr -cd '[:alnum:]_.-')"

[[ "$api" =~ ^[0-9]+$ ]] || fail "device returned an invalid API level"
(( api >= KARTPAD_ANDROID_MIN_SDK )) || \
  fail "device API $api is below KartPad's minimum API $KARTPAD_ANDROID_MIN_SDK"
[[ "$abi" == arm64-v8a ]] || fail "device primary ABI is $abi, expected arm64-v8a"
case "$page_size" in
  4096|16384) ;;
  *) fail "device page size is $page_size, expected 4096 or 16384" ;;
esac

free_kib="$(adb_shell df -k /data | awk 'NR > 1 { print $4; exit }')"
[[ "$free_kib" =~ ^[0-9]+$ ]] || fail "could not determine free space on /data"
(( free_kib >= minimum_free_kib )) || \
  fail "device has $free_kib KiB free on /data; A2 preflight requires $minimum_free_kib KiB"

input_dump="$(adb_shell dumpsys input 2>/dev/null || true)"
controller_count=0
while IFS= read -r source_hex; do
  [[ "$source_hex" =~ ^0[xX][0-9a-fA-F]+$ ]] || continue
  source_value=$((source_hex))
  # These are AINPUT_SOURCE_GAMEPAD and AINPUT_SOURCE_JOYSTICK from the
  # pinned NDK's android/input.h. A device may advertise both in one mask.
  if (( (source_value & 0x401) == 0x401 ||
        (source_value & 0x01000010) == 0x01000010 )); then
    controller_count=$((controller_count + 1))
  fi
done < <(printf '%s\n' "$input_dump" |
  sed -nE 's/^[[:space:]]*Sources:[[:space:]]*(0[xX][0-9a-fA-F]+).*$/\1/p')

if adb_shell pm path dev.kartpad.android 2>/dev/null | grep -Fq 'package:'; then
  package_state=installed
else
  package_state=not-installed
fi

if adb_shell cmd gpu vkjson 2>/dev/null | grep -Eq 'deviceName|apiVersion|driverVersion'; then
  vulkan_inventory=available
else
  vulkan_inventory=unavailable
fi

echo "Android A2 physical-device preflight passed: device=${manufacturer:-unknown}_${model:-unknown} api=$api abi=$abi page_size=$page_size free_kib=$free_kib package=$package_state input_controller_candidates=$controller_count vulkan_inventory=$vulkan_inventory adb_serial=redacted"
if (( controller_count == 0 )); then
  echo "NOTICE: no gamepad/joystick source is visible in dumpsys input; connect the intended controller before the hands-on A2 run" >&2
fi
echo "MANUAL: verify SDL controller connection, complete race/results/save/relaunch, pause/resume, surface recreation, audible audio, tactile rumble, and acceptable physical-device performance"
