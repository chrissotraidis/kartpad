#!/usr/bin/env bash
# Race several new courses in a row on the Android emulator and record KartPad's
# memory after each, to catch memory that grows with every course (#510).
#
#   scripts/android-course-memory-loop.sh OUTPUT_DIR [ROUNDS]
#
# Start with the Original game on its title screen, 30 FPS Races off, on a
# 2400x1080 landscape emulator. On another screen, set KARTPAD_TAP_A and
# KARTPAD_TAP_START to the on-screen A and START buttons, e.g.
# KARTPAD_TAP_A="2049 556" KARTPAD_TAP_START="2065 236" on a Pixel 9 Pro XL.
# Set ANDROID_SERIAL when more than one device is connected.
# Each round goes Single Player -> Grand Prix -> the next cup, races about 35
# seconds into its first course, quits to the menu and writes one line to
# OUTPUT_DIR/results.txt with total PSS, native heap, graphics memory and the
# renderer's live texture count. Compare the first and last rounds.
set -euo pipefail
out=${1:?usage: $0 OUTPUT_DIR [ROUNDS]}; rounds=${2:-8}
mkdir -p "$out"
tap_a=${KARTPAD_TAP_A:-2197 580}; tap_start=${KARTPAD_TAP_START:-2203 280}
k(){ adb shell input keyevent "$1"; sleep 0.7; }
A(){ adb shell input tap $tap_a; sleep "${1:-3}"; }
measure(){
  m=$(adb logcat -d | grep KartPadGpuResources | tail -1 | grep -o "live_textures.*" || true)
  p=$(adb shell dumpsys meminfo dev.kartpad.android | awk '/TOTAL PSS/{print $3} /Native Heap:/{nh=$3} /Graphics:/{g=$2} END{print "native="nh" graphics="g}' | paste -s -d' ' -)
  echo "$(date +%T) round=$1 cup=$2 pss_kib=$p $m" | tee -a "$out/results.txt"
}
moves=("" "KEYCODE_DPAD_RIGHT" "KEYCODE_DPAD_DOWN KEYCODE_DPAD_LEFT" "KEYCODE_DPAD_RIGHT" "KEYCODE_DPAD_UP KEYCODE_DPAD_LEFT")
names=(mushroom flower shell banana)
for i in $(seq 1 "$rounds"); do
  c=$(( (i-1) % 4 )); idx=$(( i==1 ? 0 : c+1 )); [ $c -eq 0 ] && [ $i -gt 1 ] && idx=4
  A; A; A; A; A; A
  for mv in ${moves[$idx]}; do k "$mv"; done
  A 2; A 35
  adb exec-out screencap -p > "$out/race-$i.png"
  measure "$i" "${names[$c]}"
  adb shell input tap $tap_start; sleep 1.5; k KEYCODE_DPAD_DOWN; A 1.5; k KEYCODE_DPAD_UP; A 10
done
echo LOOP_DONE | tee -a "$out/results.txt"
