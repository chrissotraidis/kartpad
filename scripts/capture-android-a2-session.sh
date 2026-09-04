#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="${KARTPAD_ADB:-$sdk_root/platform-tools/adb}"
marker="${KARTPAD_ANDROID_A2_CAPTURE_MARKER:-$repo_root/.android-bootstrap/android-a2-physical-log-start.txt}"
preflight="$repo_root/scripts/check-android-physical-device.sh"
summarizer="$repo_root/scripts/summarize-android-a2-session.py"
mode="${1:-}"

if [[ "$mode" != start && "$mode" != summarize ]]; then
  echo "usage: $0 start|summarize" >&2
  exit 64
fi

KARTPAD_ADB="$adb" "$preflight" >&2

set +e
devices="$("$adb" devices -l 2>/dev/null)"
devices_status=$?
set -e
if (( devices_status != 0 )); then
  echo "ERROR: unable to revalidate the ADB target; no device serial was printed" >&2
  exit "$devices_status"
fi
serial="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { print $1; exit }')"
[[ -n "$serial" ]] || {
  echo "ERROR: the preflight target disappeared" >&2
  exit 1
}

adb_private() {
  local output
  local command_status
  set +e
  output="$("$adb" -s "$serial" "$@" 2>&1)"
  command_status=$?
  set -e
  if (( command_status != 0 )); then
    output="${output//$serial/<redacted>}"
    echo "ERROR: ADB command failed: $output" >&2
    return "$command_status"
  fi
  printf '%s\n' "$output" | tr -d '\r'
}

package_record="$(adb_private shell cmd package list packages -U dev.kartpad.android)"
uid="$(printf '%s\n' "$package_record" |
  sed -nE 's/^package:dev\.kartpad\.android uid:([0-9]+)$/\1/p')"
[[ "$uid" =~ ^[0-9]+$ ]] || {
  echo "ERROR: dev.kartpad.android is not installed for UID-scoped capture" >&2
  exit 1
}

if [[ "$mode" == start ]]; then
  device_time="$(adb_private shell date '+%m-%d_%H:%M:%S.000')"
  start_time="${device_time/_/ }"
  [[ "$start_time" =~ ^[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}$ ]] || {
    echo "ERROR: device returned an invalid logcat start timestamp" >&2
    exit 1
  }
  mkdir -p "$(dirname "$marker")"
  umask 077
  printf '%s\n' "$start_time" >"$marker"
  echo "Android A2 UID-scoped capture window started; run the physical test, then invoke: $0 summarize"
  exit 0
fi

[[ -f "$marker" ]] || {
  echo "ERROR: no A2 capture window exists; run '$0 start' first" >&2
  exit 1
}
IFS= read -r start_time <"$marker"
[[ "$start_time" =~ ^[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}$ ]] || {
  echo "ERROR: the A2 capture-window marker is invalid" >&2
  exit 1
}

# Raw app logs stay in Android's volatile log buffer. Only the fixed-schema
# sanitizer output reaches stdout; suppress ADB's own stderr because it may
# contain the private transport serial and replace it with a generic failure.
summary_tmp="$(mktemp)"
trap 'rm -f "$summary_tmp"' EXIT
set +e
"$adb" -s "$serial" logcat -d -v raw -T "$start_time" --uid="$uid" \
  2>/dev/null | "$summarizer" --require-signal-matrix >"$summary_tmp"
pipeline_status=("${PIPESTATUS[@]}")
set -e
if (( pipeline_status[0] != 0 )); then
  echo "ERROR: UID-scoped logcat capture failed; no device serial was printed" >&2
  exit "${pipeline_status[0]}"
fi
cat "$summary_tmp"
exit "${pipeline_status[1]}"
