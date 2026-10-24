#!/usr/bin/env bash
# Alternate A/B runs with a cold-booted emulator before every run (the emulator's
# host graphics memory grows with each app restart and skews later runs).
# Usage: ab.sh OUT A B ROUNDS
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
out=$1; a=$2; b=$3; n=${4:-3}
SDK=$HOME/Library/Android/sdk
export KP_SERIAL=${KP_SERIAL:-emulator-5554}
[[ "$KP_SERIAL" =~ ^emulator-([0-9]+)$ ]] || { echo 'A/B requires an emulator serial' >&2; exit 64; }
port=${BASH_REMATCH[1]}
A=("$SDK/platform-tools/adb" -s "$KP_SERIAL")
emulator_pid=
# Do not stop an emulator belonging to another test or wait on all qemu processes.
if "${A[@]}" get-state >/dev/null 2>&1; then
  echo "$KP_SERIAL is already running; stop your test emulator before starting A/B" >&2
  exit 1
fi
stop() {
  if [[ -n "$emulator_pid" ]]; then
    "${A[@]}" emu kill >/dev/null 2>&1 || true
    wait "$emulator_pid" || true
    emulator_pid=
  fi
}
trap stop EXIT
boot() {
  stop
  # Headless -gpu auto falls back to software rendering, which buries the game thread.
  "$SDK/emulator/emulator" -avd "${KP_AVD:-KartPad_API_36_ARM64}" -port "$port" -no-window -no-audio -no-boot-anim -no-snapshot -gpu host > "$out.emulator.log" 2>&1 &
  emulator_pid=$!
  deadline=$((SECONDS + 180))
  until [[ "$("${A[@]}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; do
    kill -0 "$emulator_pid" 2>/dev/null && (( SECONDS < deadline )) || { echo 'Emulator boot failed' >&2; exit 1; }
    sleep 2
  done
  # adbd can refuse the first root restart on a busy host.
  for _ in 1 2 3 4 5; do "${A[@]}" root >/dev/null 2>&1 && break; sleep 5; done
  sleep 3; "${A[@]}" wait-for-device; sleep 20
}
for i in $(seq 1 "$n"); do
  for v in "$a" "$b"; do
    boot
    tools/android-perf/deploy.sh "$v" >/dev/null 2>&1 || { echo "deploy $v failed" >> "$out"; exit 1; }
    r=$(tools/android-perf/bench.sh "$v-$i" 60 | tail -1)
    echo "$r, emulator RSS $(( $(ps -o rss= -p "$emulator_pid") / 1048576 )) GB" >> "$out"
  done
done
echo DONE >> "$out"
