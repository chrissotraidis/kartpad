#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 BEFORE_APK AFTER_APK" >&2
  exit 64
fi

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="${KARTPAD_ADB:-$sdk_root/platform-tools/adb}"
aapt2="${KARTPAD_AAPT2:-$sdk_root/build-tools/36.0.0/aapt2}"
before_apk="$1"
after_apk="$2"
package="dev.kartpad.android"
expected_main_dol_sha256="80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -x "$adb" ]] || fail "adb is unavailable at $adb"
[[ -x "$aapt2" ]] || fail "aapt2 is unavailable at $aapt2"
[[ -f "$before_apk" ]] || fail "before APK is unavailable at $before_apk"
[[ -f "$after_apk" ]] || fail "after APK is unavailable at $after_apk"

devices="$($adb devices -l)"
ready_count="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
[[ "$ready_count" == 1 ]] || fail "expected exactly one ready Android target"
serial="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { print $1; exit }')"
adb_target=("$adb" -s "$serial")
[[ "$("${adb_target[@]}" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] ||
  fail "the connected target is not an Android emulator"

restore_selector() {
  "${adb_target[@]}" shell am force-stop "$package" >/dev/null 2>&1 || true
  "${adb_target[@]}" shell am start -W \
    -n "$package/.KartPadLaunchActivity" >/dev/null 2>&1 || true
}
trap restore_selector EXIT

remote_exists() {
  "${adb_target[@]}" shell run-as "$package" test -e "$1"
}

file_digest() {
  local remote_file="$1"
  if remote_exists "$remote_file"; then
    "${adb_target[@]}" exec-out run-as "$package" sha256sum "$remote_file" |
      awk '{ print $1 }'
  else
    printf 'absent\n'
  fi
}

tree_digest() {
  local remote_root="$1"
  if remote_exists "$remote_root"; then
    "${adb_target[@]}" exec-out run-as "$package" tar -cf - "$remote_root" |
      shasum -a 256 | awk '{ print $1 }'
  else
    printf 'absent\n'
  fi
}

state_digest() {
  {
    printf 'config=%s\n' "$(file_digest files/KartPad/Config.toml)"
    printf 'main_dol=%s\n' "$(file_digest files/KartPad/GameData/sys/main.dol)"
    printf 'nand=%s\n' "$(tree_digest files/KartPad/NAND)"
    printf 'saves=%s\n' "$(tree_digest files/KartPad/Saves)"
    printf 'preferences=%s\n' "$(tree_digest shared_prefs)"
    printf 'retro_version=%s\n' \
      "$(file_digest files/KartPad/RetroRewind/RetroRewind6/version.txt)"
  } | shasum -a 256 | awk '{ print $1 }'
}

apk_version_code() {
  "$aapt2" dump badging "$1" |
    sed -n "s/^package: .*versionCode='\([0-9][0-9]*\)'.*/\1/p"
}

apk_package_name() {
  "$aapt2" dump badging "$1" |
    sed -n "s/^package: name='\([^']*\)'.*/\1/p"
}

installed_version_code() {
  "${adb_target[@]}" shell dumpsys package "$package" |
    sed -n 's/^[[:space:]]*versionCode=\([0-9][0-9]*\).*/\1/p' |
    head -1 | tr -d '\r'
}

install_and_validate_game_data() {
  local apk="$1"
  local expected_version_code="$2"
  "${adb_target[@]}" install -r "$apk" >/dev/null
  [[ "$(installed_version_code)" == "$expected_version_code" ]] ||
    fail "installed package version does not match the requested APK"
  local installed_main_dol_sha256
  installed_main_dol_sha256="$(file_digest files/KartPad/GameData/sys/main.dol)"
  [[ "$installed_main_dol_sha256" == "$expected_main_dol_sha256" ]] ||
    fail "app-private GameData changed or is not the approved fixture"
}

before_apk_sha256="$(shasum -a 256 "$before_apk" | awk '{ print $1 }')"
after_apk_sha256="$(shasum -a 256 "$after_apk" | awk '{ print $1 }')"
[[ "$before_apk_sha256" != "$after_apk_sha256" ]] ||
  fail "before and after APKs must have different bytes"
before_version_code="$(apk_version_code "$before_apk")"
after_version_code="$(apk_version_code "$after_apk")"
[[ -n "$before_version_code" && -n "$after_version_code" ]] ||
  fail "could not read both APK version codes"
before_package="$(apk_package_name "$before_apk")"
after_package="$(apk_package_name "$after_apk")"
[[ "$before_package" == "$package" && "$after_package" == "$package" ]] ||
  fail "both APKs must use package $package"
require_version_upgrade="${KARTPAD_REQUIRE_VERSION_UPGRADE:-0}"
[[ "$require_version_upgrade" == 0 || "$require_version_upgrade" == 1 ]] ||
  fail "KARTPAD_REQUIRE_VERSION_UPGRADE must be 0 or 1"
if [[ "$require_version_upgrade" == 1 ]]; then
  ((after_version_code > before_version_code)) ||
    fail "after APK version code must be greater than before APK version code"
fi

install_and_validate_game_data "$before_apk" "$before_version_code"
before_state="$(state_digest)"
install_and_validate_game_data "$after_apk" "$after_version_code"
after_state="$(state_digest)"
[[ "$before_state" == "$after_state" ]] ||
  fail "app-private durable state changed across update-in-place"

echo "Android emulator update-in-place preservation passed: before_apk_sha256=$before_apk_sha256 after_apk_sha256=$after_apk_sha256 before_version_code=$before_version_code after_version_code=$after_version_code durable_state_preserved=yes game_data_preserved=yes"
