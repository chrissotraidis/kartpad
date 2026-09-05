#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="${KARTPAD_ADB:-$sdk_root/platform-tools/adb}"
apk="${1:-$repo_root/.android-bootstrap/hardware-preview/KartPad-0.4.0-android-preview.2-v7-arm64.apk}"
package="dev.kartpad.android"
expected_sha256="${KARTPAD_ANDROID_EXPECTED_PREVIEW_SHA256:-cfb32065650a15e9d3ddab9aa2705ea62e9930626445c7e568e1ef29b8e53420}"
expected_version_code=7
expected_version_name="0.4.0-android-preview.2"
allow_update="${KARTPAD_ANDROID_ALLOW_PREVIEW_UPDATE:-0}"
minimum_free_kib="${KARTPAD_ANDROID_PREVIEW_MIN_FREE_KIB:-6291456}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -x "$adb" ]] || fail "adb is unavailable at the configured path"
[[ -f "$apk" ]] || fail "hardware preview APK is unavailable"
[[ "$allow_update" == 0 || "$allow_update" == 1 ]] ||
  fail "KARTPAD_ANDROID_ALLOW_PREVIEW_UPDATE must be 0 or 1"
[[ "$minimum_free_kib" =~ ^[0-9]+$ ]] ||
  fail "KARTPAD_ANDROID_PREVIEW_MIN_FREE_KIB must be an integer"
(( minimum_free_kib >= 6291456 )) ||
  fail "KARTPAD_ANDROID_PREVIEW_MIN_FREE_KIB must be at least 6291456"
actual_sha256="$(shasum -a 256 "$apk" | awk '{ print $1 }')"
[[ "$actual_sha256" == "$expected_sha256" ]] ||
  fail "hardware preview APK does not match the approved digest"
"$repo_root/scripts/audit-android-package.sh" "$apk" >/dev/null

# This must pass before any package mutation. It rejects emulators, unsupported
# ABI/API/page sizes, insufficient space, and ambiguous/unauthorized targets.
KARTPAD_ADB="$adb" KARTPAD_ANDROID_A2_MIN_FREE_KIB="$minimum_free_kib" \
  "$repo_root/scripts/check-android-physical-device.sh" >&2

devices="$($adb devices -l 2>/dev/null)"
serial="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { print $1; exit }')"
[[ -n "$serial" ]] || fail "the preflight target disappeared"

adb_private() {
  local output
  local command_status
  set +e
  output="$("$adb" -s "$serial" "$@" 2>&1)"
  command_status=$?
  set -e
  if ((command_status != 0)); then
    echo "ERROR: ADB command failed; target serial and device output were suppressed" >&2
    return "$command_status"
  fi
  printf '%s\n' "$output" | tr -d '\r'
}

installed_paths="$(adb_private shell pm path "$package" 2>/dev/null || true)"
install_required=1
if [[ -n "$installed_paths" ]]; then
  installed_base="$(printf '%s\n' "$installed_paths" |
    sed -n 's/^package://p' | grep '/base\.apk$' | head -1 || true)"
  [[ -n "$installed_base" ]] ||
    fail "existing KartPad installation has no readable base APK"
  inspect_root="$(mktemp -d "$repo_root/.android-bootstrap/physical-preview.XXXXXX")"
  [[ "$inspect_root" == "$repo_root/.android-bootstrap/physical-preview."* ]] ||
    fail "temporary inspection directory escaped the guarded root"
  # shellcheck disable=SC2329 # Invoked by the EXIT trap.
  cleanup_inspection() {
    rm -rf -- "$inspect_root"
  }
  trap cleanup_inspection EXIT
  if ! "$adb" -s "$serial" pull "$installed_base" \
      "$inspect_root/installed.apk" >/dev/null 2>&1; then
    fail "could not inspect the existing KartPad package"
  fi
  installed_sha256="$(shasum -a 256 "$inspect_root/installed.apk" |
    awk '{ print $1 }')"
  if [[ "$installed_sha256" == "$expected_sha256" ]]; then
    install_required=0
  elif [[ "$allow_update" != 1 ]]; then
    fail "a different KartPad build is installed; set KARTPAD_ANDROID_ALLOW_PREVIEW_UPDATE=1 only after preserving any test save"
  fi
fi

if [[ "$install_required" == 1 ]]; then
  if ! "$adb" -s "$serial" install -r "$apk" >/dev/null 2>&1; then
    fail "preview installation failed; the existing package was not uninstalled or cleared"
  fi
fi

package_dump="$(adb_private shell dumpsys package "$package")"
installed_version_code="$(printf '%s\n' "$package_dump" |
  sed -n 's/^[[:space:]]*versionCode=\([0-9][0-9]*\).*/\1/p' | head -1)"
installed_version_name="$(printf '%s\n' "$package_dump" |
  sed -n 's/^[[:space:]]*versionName=//p' | head -1)"
[[ "$installed_version_code" == "$expected_version_code" ]] ||
  fail "installed KartPad version code is not the approved preview"
[[ "$installed_version_name" == "$expected_version_name" ]] ||
  fail "installed KartPad version name is not the approved preview"

adb_private shell am force-stop "$package" >/dev/null
adb_private shell am start -W \
  -n "$package/.KartPadLaunchActivity" >/dev/null
selector_ready=0
ui_tree="/sdcard/kartpad-physical-preview.xml"
for _ in {1..20}; do
  if adb_private shell uiautomator dump "$ui_tree" >/dev/null 2>&1; then
    hierarchy="$(adb_private exec-out cat "$ui_tree")"
    if [[ "$hierarchy" == *'content-desc="Mario Kart Wii'* &&
       "$hierarchy" == *'content-desc="Retro Rewind'* ]]; then
      selector_ready=1
      break
    fi
  fi
  sleep 1
done
adb_private shell toybox rm -f "$ui_tree" >/dev/null 2>&1 || true
[[ "$selector_ready" == 1 ]] || fail "physical device did not present the game selector"

KARTPAD_ADB="$adb" "$repo_root/scripts/capture-android-a2-session.sh" start >&2
echo "Android hardware preview ready: version_name=$expected_version_name version_code=$expected_version_code apk_sha256=$expected_sha256 selector_visible=yes capture_started=yes adb_serial=redacted"
echo "MANUAL: import owned game data, run the complete physical checklist, then invoke scripts/capture-android-a2-session.sh summarize"
