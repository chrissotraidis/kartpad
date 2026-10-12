#!/usr/bin/env bash
# Game-thread CPU per frame in Grand Prix race 1 (Luigi Circuit, 12 racers, player idle).
set -u
export KP_SERIAL=${KP_SERIAL:-emulator-5554}
A="$HOME/Library/Android/sdk/platform-tools/adb -s $KP_SERIAL"
UI="python3 $(dirname "$0")/ui.py"
label=${1:-run}; window=${2:-30}
$A shell am force-stop dev.kartpad.android; sleep 1
$A logcat -c
$A shell am start -n dev.kartpad.android/.KartPadLaunchActivity >/dev/null 2>&1; sleep 6
$UI tap 2007 398 w10 A w3 A w4 A w3 A w2 A w2 A w2 A w2 A w2 A w2 A w2 A w2
sleep 55
P=$($A shell pidof dev.kartpad.android | tr -d '\r')
T=$($A logcat -d --pid=$P -s KartPadPerf | tail -1 | awk '{print $4}')
cpu(){ $A shell "awk '{print \$14, \$15}' /proc/$P/task/$T/stat" | tr -d '\r' | tr ' ' ','; }
c0=$(cpu); t0=$(date +%s); $A logcat -c; sleep "$window"; c1=$(cpu); t1=$(date +%s)
fps=$($A logcat -d --pid=$P -s KartPadPerf | sed -n 's/.* fps=\([0-9.]*\).*/\1/p' | awk '{s+=$1;n++} END{if(n) printf "%.2f", s/n; else print 0}')
$UI shot bench-$label >/dev/null
python3 - "$label" "$c0" "$c1" "$t0" "$t1" "$fps" <<'EOF'
import sys
label=sys.argv[1]; u0,s0=map(int,sys.argv[2].split(',')); u1,s1=map(int,sys.argv[3].split(',')); secs=int(sys.argv[5])-int(sys.argv[4]); fps=float(sys.argv[6])
u=(u1-u0)*10; k=(s1-s0)*10; fr=secs*fps
print(f"{label}: fps {fps:.1f}, user {u/fr:.2f} ms/frame, kernel {k/fr:.2f} ms/frame, total {(u+k)/fr:.2f}")
