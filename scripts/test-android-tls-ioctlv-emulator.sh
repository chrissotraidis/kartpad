#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="${KARTPAD_ADB:-$sdk_root/platform-tools/adb}"
apk="${1:-$repo_root/android/app/build/outputs/apk/debug/app-debug.apk}"
package="dev.kartpad.android"
fixture_root="files/KartPadTlsIoctlvFixture"
completed_fixture_root="files/KartPadTlsIoctlvFixture.completed"
expected_main_dol_sha256="80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -x "$adb" ]] || fail "adb is unavailable at $adb"
[[ -f "$apk" ]] || fail "product APK is unavailable at $apk"
command -v openssl >/dev/null || fail "openssl is unavailable"

devices="$($adb devices -l)"
ready_count="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
[[ "$ready_count" == 1 ]] || fail "expected exactly one ready Android target"
serial="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { print $1; exit }')"
adb_target=("$adb" -s "$serial")
[[ "$("${adb_target[@]}" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] ||
  fail "the connected target is not an Android emulator"

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/kartpad-guest-tls.XXXXXX")"
server_pid=""
interrupt_server_pid=""
cleanup() {
  "${adb_target[@]}" shell am force-stop "$package" >/dev/null 2>&1 || true
  "${adb_target[@]}" shell run-as "$package" toybox rm -rf \
    "$fixture_root" "$completed_fixture_root" >/dev/null 2>&1 || true
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" 2>/dev/null || true
  fi
  if [[ -n "$interrupt_server_pid" ]]; then
    kill "$interrupt_server_pid" >/dev/null 2>&1 || true
    wait "$interrupt_server_pid" 2>/dev/null || true
  fi
  rm -rf "$temporary_root"
  "${adb_target[@]}" shell am start -W \
    -n "$package/.KartPadLaunchActivity" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Reinstall in place: the fixture must preserve app-private GameData and saves.
"${adb_target[@]}" install -r "$apk" >/dev/null
installed_main_dol_sha256="$("${adb_target[@]}" shell \
  "run-as $package sh -c 'sha256sum files/KartPad/GameData/sys/main.dol 2>/dev/null'" |
  awk '{ print $1 }' | tr -d '\r')"
[[ "$installed_main_dol_sha256" == "$expected_main_dol_sha256" ]] ||
  fail "app-private GameData is absent or its main.dol hash is not the approved fixture"
"${adb_target[@]}" shell run-as "$package" test ! -e \
  files/KartPad/NAND/rootca.pem ||
  fail "the emulator has a user-owned built-in Wii root CA; use a clean fixture profile"

openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout "$temporary_root/ca.key" -out "$temporary_root/ca.pem" \
  -subj /CN=KartPad-Guest-IOCTLV-Test-CA >/dev/null 2>&1
openssl req -newkey rsa:2048 -nodes \
  -keyout "$temporary_root/server.key" -out "$temporary_root/server.csr" \
  -subj /CN=kartpad.test -addext subjectAltName=DNS:kartpad.test \
  >/dev/null 2>&1
openssl x509 -req -days 1 -set_serial 2 \
  -in "$temporary_root/server.csr" \
  -CA "$temporary_root/ca.pem" -CAkey "$temporary_root/ca.key" \
  -copy_extensions copy -out "$temporary_root/server.pem" >/dev/null 2>&1
openssl x509 -in "$temporary_root/ca.pem" -outform DER \
  -out "$temporary_root/ca.der"

port="$(python3 -c \
  'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
openssl s_server -accept "127.0.0.1:$port" \
  -cert "$temporary_root/server.pem" -key "$temporary_root/server.key" \
  -www -quiet >"$temporary_root/server.log" 2>&1 &
server_pid="$!"
sleep 0.25
kill -0 "$server_pid" 2>/dev/null || fail "local TLS server did not start"

# A separate one-shot peer accepts TCP and resets the connection before TLS
# negotiation completes. The following good exchange must then succeed from a
# fresh product process, proving failed guest sessions/sockets do not poison
# the next connection.
interrupt_port_file="$temporary_root/interrupt-port"
python3 - "$interrupt_port_file" >"$temporary_root/interrupt-server.log" 2>&1 <<'PY' &
import socket
import struct
import sys
import time

port_file = sys.argv[1]
with socket.socket() as listener:
    listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    listener.bind(("0.0.0.0", 0))
    listener.listen(1)
    with open(port_file, "w", encoding="ascii") as output:
        output.write(str(listener.getsockname()[1]))
    connection, _ = listener.accept()
    with connection:
        time.sleep(0.5)
        connection.setsockopt(
            socket.SOL_SOCKET, socket.SO_LINGER, struct.pack("ii", 1, 0)
        )
PY
interrupt_server_pid="$!"
for _ in {1..100}; do
  [[ -s "$interrupt_port_file" ]] && break
  kill -0 "$interrupt_server_pid" 2>/dev/null ||
    fail "local interruption server exited before listening"
  sleep 0.05
done
[[ -s "$interrupt_port_file" ]] || fail "local interruption server did not listen"
interrupt_port="$(<"$interrupt_port_file")"
[[ "$interrupt_port" =~ ^[0-9]+$ ]] || fail "local interruption port is invalid"

"${adb_target[@]}" shell run-as "$package" toybox rm -rf \
  "$fixture_root" "$completed_fixture_root"
"${adb_target[@]}" shell run-as "$package" toybox mkdir -p "$fixture_root"
"${adb_target[@]}" exec-in run-as "$package" toybox tee \
  "$fixture_root/ca.der" <"$temporary_root/ca.der" >/dev/null

put_fixture_text() {
  local name="$1"
  local value="$2"
  printf '%s' "$value" | "${adb_target[@]}" exec-in run-as "$package" \
    toybox tee "$fixture_root/$name" >/dev/null
}
put_fixture_text address 10.0.2.2
put_fixture_text port "$port"
put_fixture_text check_builtin_root_missing 1

latest_transcript() {
  "${adb_target[@]}" shell \
    "run-as $package sh -c 'ls -t files/KartPad/Logs/*/console.log 2>/dev/null | head -n 1'" |
    tr -d '\r'
}

run_case() {
  local hostname="$1"
  local expected="$2"
  local marker="$3"
  local prerequisite_marker="${4:-}"
  local secondary_marker="${5:-}"
  local before_transcript
  local before_size=0
  local current_transcript=""

  put_fixture_text hostname "$hostname"
  put_fixture_text expected "$expected"
  before_transcript="$(latest_transcript)"
  if [[ -n "$before_transcript" ]]; then
    before_size="$("${adb_target[@]}" shell \
      "run-as $package stat -c %s '$before_transcript' 2>/dev/null" |
      tr -d '\r')"
    [[ "$before_size" =~ ^[0-9]+$ ]] || before_size=0
  fi
  "${adb_target[@]}" shell am force-stop "$package"
  "${adb_target[@]}" shell am start -W \
    -n "$package/.KartPadActivity" \
    --es "$package.RUNTIME_PROFILE" base >/dev/null

  for _ in {1..120}; do
    current_transcript="$(latest_transcript)"
    transcript_delta() {
      if [[ "$current_transcript" == "$before_transcript" ]]; then
        "${adb_target[@]}" exec-out run-as "$package" tail -c \
          "+$((before_size + 1))" "$current_transcript"
      else
        "${adb_target[@]}" exec-out run-as "$package" cat "$current_transcript"
      fi
    }
    if [[ -n "$current_transcript" ]] && transcript_delta |
          grep -Fq "$marker"; then
      if [[ -n "$prerequisite_marker" ]] &&
          ! transcript_delta | grep -Fq "$prerequisite_marker"; then
        sleep 0.5
        continue
      fi
      if [[ -n "$secondary_marker" ]] &&
          ! transcript_delta | grep -Fq "$secondary_marker"; then
        sleep 0.5
        continue
      fi
      if [[ -n "$prerequisite_marker" ]]; then
        transcript_delta | grep -F "$prerequisite_marker" | tail -n 1
      fi
      if [[ -n "$secondary_marker" ]]; then
        transcript_delta | grep -F "$secondary_marker" | tail -n 1
      fi
      transcript_delta | grep -F "$marker" | tail -n 1
      "${adb_target[@]}" shell am force-stop "$package"
      return 0
    fi
    sleep 0.5
  done

  echo "ERROR: product transcript did not report: $marker" >&2
  if [[ -n "$current_transcript" ]]; then
    "${adb_target[@]}" exec-out run-as "$package" tail -n 80 \
      "$current_transcript" >&2 || true
  fi
  return 1
}

put_fixture_text recovery_port "$port"
put_fixture_text port "$interrupt_port"
run_case kartpad.test 0 \
  "A5 guest TLS IOCTLV same-process recovery passed result=" \
  "A5 guest TLS IOCTLV fixture handshake=" \
  "A5 guest TLS IOCTLV trusted exchange passed response_bytes="
wait "$interrupt_server_pid"
interrupt_server_pid=""

put_fixture_text port "$port"
run_case wrong.kartpad.test -9 \
  "A5 guest TLS IOCTLV hostname rejection passed result=-9"

apk_sha256="$(shasum -a 256 "$apk" | awk '{ print $1 }')"
echo "Android product guest TLS IOCTLV emulator fixture passed: apk_sha256=$apk_sha256 same_process_handshake_recovered=yes private_key_on_device=no game_data_preserved=yes"
