#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "usage: $0 [APK]" >&2
  exit 64
fi

repo_root="$(git rev-parse --show-toplevel)"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="${KARTPAD_ADB:-$sdk_root/platform-tools/adb}"
apk="${1:-$repo_root/android/app/build/outputs/apk/debug/app-debug.apk}"
package="dev.kartpad.android"
component="$package/.KartPadSaveStorageFixtureActivity"
expected_main_dol_sha256="80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"
marker="A6 save storage passed export=validated restore=staged active=replaced backup=preserved corrupt=rejected"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -x "$adb" ]] || fail "adb is unavailable at $adb"
[[ -f "$apk" ]] || fail "APK is unavailable at $apk"
devices="$($adb devices -l)"
ready_count="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
[[ "$ready_count" == 1 ]] || fail "expected exactly one ready Android target"
serial="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { print $1; exit }')"
adb_target=("$adb" -s "$serial")
[[ "$("${adb_target[@]}" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] ||
  fail "the connected target is not an Android emulator"

# shellcheck disable=SC2329 # Invoked by the EXIT trap.
restore_selector() {
  "${adb_target[@]}" shell am force-stop "$package" >/dev/null 2>&1 || true
  "${adb_target[@]}" shell am start -W \
    -n "$package/.KartPadLaunchActivity" >/dev/null 2>&1 || true
}
trap restore_selector EXIT

"${adb_target[@]}" install -r "$apk" >/dev/null
installed_main_dol_sha256="$("${adb_target[@]}" exec-out run-as "$package" \
  sha256sum files/KartPad/GameData/sys/main.dol | awk '{ print $1 }')"
[[ "$installed_main_dol_sha256" == "$expected_main_dol_sha256" ]] ||
  fail "app-private GameData changed or is not the approved fixture"

"${adb_target[@]}" logcat -c
"${adb_target[@]}" shell am force-stop "$package"
"${adb_target[@]}" shell am start -W -n "$component" >/dev/null
for _ in {1..30}; do
  output="$("${adb_target[@]}" logcat -d -v brief KartPadFixture:I AndroidRuntime:E '*:S')"
  if grep -Fq "$marker" <<<"$output"; then
    printf '%s\n' "$marker"
    exit 0
  fi
  if grep -Fq "A6 save storage failed" <<<"$output"; then
    printf '%s\n' "$output" >&2
    exit 1
  fi
  sleep 1
done

echo "ERROR: save storage fixture did not complete" >&2
printf '%s\n' "${output:-}" >&2
exit 1
