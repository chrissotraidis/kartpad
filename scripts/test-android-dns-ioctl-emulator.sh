#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="${KARTPAD_ADB:-$sdk_root/platform-tools/adb}"
apk="${1:-$repo_root/android/app/build/outputs/apk/debug/app-debug.apk}"
package="dev.kartpad.android"
fixture_root="files/KartPadDnsIoctlFixture"
expected_main_dol_sha256="80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -x "$adb" ]] || fail "adb is unavailable at $adb"
[[ -f "$apk" ]] || fail "product APK is unavailable at $apk"

devices="$($adb devices -l)"
ready_count="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
[[ "$ready_count" == 1 ]] || fail "expected exactly one ready Android target"
serial="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { print $1; exit }')"
adb_target=("$adb" -s "$serial")
[[ "$("${adb_target[@]}" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] ||
  fail "the connected target is not an Android emulator"

# Invoked through the EXIT trap below.
# shellcheck disable=SC2329
cleanup() {
  "${adb_target[@]}" shell am force-stop "$package" >/dev/null 2>&1 || true
  "${adb_target[@]}" shell run-as "$package" toybox rm -rf \
    "$fixture_root" >/dev/null 2>&1 || true
  "${adb_target[@]}" shell am start -W \
    -n "$package/.KartPadLaunchActivity" >/dev/null 2>&1 || true
}
trap cleanup EXIT

"${adb_target[@]}" install -r "$apk" >/dev/null
installed_main_dol_sha256="$("${adb_target[@]}" shell \
  "run-as $package sh -c 'sha256sum files/KartPad/GameData/sys/main.dol 2>/dev/null'" |
  awk '{ print $1 }' | tr -d '\r')"
[[ "$installed_main_dol_sha256" == "$expected_main_dol_sha256" ]] ||
  fail "app-private GameData is absent or its main.dol hash is not the approved fixture"

"${adb_target[@]}" shell run-as "$package" toybox rm -rf "$fixture_root"
"${adb_target[@]}" shell run-as "$package" toybox mkdir -p "$fixture_root"
printf 'localhost' | "${adb_target[@]}" exec-in run-as "$package" \
  toybox tee "$fixture_root/node" >/dev/null
printf '127.0.0.1' | "${adb_target[@]}" exec-in run-as "$package" \
  toybox tee "$fixture_root/expected_ipv4" >/dev/null

latest_transcript() {
  "${adb_target[@]}" shell \
    "run-as $package sh -c 'ls -t files/KartPad/Logs/*/console.log 2>/dev/null | head -n 1'" |
    tr -d '\r'
}

before_transcript="$(latest_transcript)"
before_size=0
if [[ -n "$before_transcript" ]]; then
  before_size="$("${adb_target[@]}" shell \
    "run-as $package stat -c %s '$before_transcript' 2>/dev/null" | tr -d '\r')"
  [[ "$before_size" =~ ^[0-9]+$ ]] || before_size=0
fi

"${adb_target[@]}" shell am force-stop "$package"
"${adb_target[@]}" shell am start -W \
  -n "$package/.KartPadActivity" --es "$package.RUNTIME_PROFILE" base >/dev/null

marker="A5 guest DNS IOCTL fixture passed request_marshaled=yes worker_resolved=yes guest_hostent=yes"
current_transcript=""
for _ in {1..120}; do
  current_transcript="$(latest_transcript)"
  if [[ -n "$current_transcript" ]]; then
    if [[ "$current_transcript" == "$before_transcript" ]]; then
      transcript_delta="$("${adb_target[@]}" exec-out run-as "$package" \
        tail -c "+$((before_size + 1))" "$current_transcript")"
    else
      transcript_delta="$("${adb_target[@]}" exec-out run-as "$package" \
        cat "$current_transcript")"
    fi
    if grep -Fq "$marker" <<<"$transcript_delta"; then
      grep -F "$marker" <<<"$transcript_delta" | tail -n 1
      apk_sha256="$(shasum -a 256 "$apk" | awk '{ print $1 }')"
      echo "Android product guest DNS IOCTL emulator fixture passed: apk_sha256=$apk_sha256 game_data_preserved=yes"
      exit 0
    fi
    if grep -Fq "Android guest DNS IOCTL fixture failed" <<<"$transcript_delta"; then
      echo "$transcript_delta" | tail -n 80 >&2
      fail "product reported a DNS IOCTL fixture failure"
    fi
  fi
  sleep 0.5
done

[[ -z "$current_transcript" ]] || "${adb_target[@]}" exec-out run-as "$package" \
  tail -n 80 "$current_transcript" >&2 || true
fail "product transcript did not report the DNS IOCTL fixture pass marker"
