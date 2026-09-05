#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
android_sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="$android_sdk_root/platform-tools/adb"
apk="$repo_root/android/app/build/outputs/apk/debug/app-debug.apk"
fixture_root="/data/user/0/dev.kartpad.android/files/KartPadTlsFixture"

[[ -x "$adb" ]] || {
  echo "ERROR: adb is unavailable at $adb" >&2
  exit 1
}
"$adb" get-state >/dev/null

"$repo_root/scripts/build-android-fixture.sh"

temporary_root="$(mktemp -d "${TMPDIR:-/tmp}/kartpad-emulator-tls.XXXXXX")"
server_pid=""
cleanup() {
  "$adb" shell am force-stop dev.kartpad.android >/dev/null 2>&1 || true
  "$adb" shell pm clear dev.kartpad.android >/dev/null 2>&1 || true
  if [[ -n "$server_pid" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
    wait "$server_pid" 2>/dev/null || true
  fi
  rm -rf "$temporary_root"
}
trap cleanup EXIT

openssl req -x509 -newkey rsa:2048 -nodes -days 1 \
  -keyout "$temporary_root/ca.key" -out "$temporary_root/ca.pem" \
  -subj /CN=KartPad-Emulator-Test-CA >/dev/null 2>&1
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

port="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
openssl s_server -accept "127.0.0.1:$port" \
  -cert "$temporary_root/server.pem" -key "$temporary_root/server.key" \
  -www -quiet >"$temporary_root/server.log" 2>&1 &
server_pid="$!"
sleep 0.25
kill -0 "$server_pid"

"$adb" shell am force-stop dev.kartpad.android
"$adb" install -r "$apk" >/dev/null
"$adb" shell pm clear dev.kartpad.android >/dev/null
"$adb" shell run-as dev.kartpad.android mkdir -p "$fixture_root"
"$adb" exec-in run-as dev.kartpad.android sh -c \
  "'cat > $fixture_root/ca.der'" < "$temporary_root/ca.der"
printf '%s' "$port" | "$adb" exec-in run-as dev.kartpad.android sh -c \
  "'cat > $fixture_root/port'"

run_case() {
  local hostname="$1"
  local expected="$2"
  local marker="$3"
  printf '%s' "$hostname" | "$adb" exec-in run-as dev.kartpad.android sh -c \
    "'cat > $fixture_root/hostname'"
  printf '%s' "$expected" | "$adb" exec-in run-as dev.kartpad.android sh -c \
    "'cat > $fixture_root/expected'"
  "$adb" logcat -c
  "$adb" shell am start -W -n dev.kartpad.android/.KartPadActivity >/dev/null
  for _ in {1..60}; do
    if "$adb" logcat -d -s KartPadFixture:I '*:S' | grep -Fq "$marker"; then
      "$adb" logcat -d -s KartPadFixture:I '*:S' | grep -F "$marker" | tail -1
      "$adb" shell am force-stop dev.kartpad.android
      return 0
    fi
    sleep 0.2
  done
  "$adb" logcat -d -s KartPadFixture:V '*:S' | tail -40 >&2
  return 1
}

run_case kartpad.test 0 "A5 TLS loopback trusted handshake passed"
run_case wrong.kartpad.test -9 "A5 TLS loopback hostname rejection passed"
echo "Android ARM64 emulator TLS loopback fixture passed."
