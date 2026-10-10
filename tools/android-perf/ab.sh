#!/usr/bin/env bash
# Alternate A/B runs with a cold-booted emulator before every run (the emulator's
# host graphics memory grows with each app restart and skews later runs).
# Usage: ab.sh OUT A B ROUNDS
cd "$(git rev-parse --show-toplevel)"
out=$1; a=$2; b=$3; n=${4:-3}
SDK=$HOME/Library/Android/sdk; A="$SDK/platform-tools/adb"
boot() {
  "$A" emu kill >/dev/null 2>&1
  while pgrep -f qemu-system >/dev/null; do sleep 2; done
  "$SDK/emulator/emulator" @${KP_AVD:-KartPad_API_36_ARM64} -no-window -no-audio -no-boot-anim -no-snapshot-save -gpu auto > /tmp/kartpad-perf-emu.log 2>&1 &
  "$A" wait-for-device
  until [ "$("$A" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
  "$A" root >/dev/null; sleep 3; "$A" wait-for-device; sleep 20
}
for i in $(seq 1 "$n"); do
  for v in "$a" "$b"; do
    boot
    tools/android-perf/deploy.sh "$v" >/dev/null 2>&1 || { echo "deploy $v failed" >> "$out"; exit 1; }
    r=$(tools/android-perf/bench.sh "$v-$i" 60 2>/dev/null | tail -1)
    echo "$r, emulator RSS $(( $(ps -o rss= -p $(pgrep -f qemu-system | head -1)) / 1048576 )) GB" >> "$out"
  done
done
echo DONE >> "$out"
