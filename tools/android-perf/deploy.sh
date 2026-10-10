#!/usr/bin/env bash
# Install variant app over the existing install (data kept) and push its game pack.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
v=build/perf/v-$1; A="$HOME/Library/Android/sdk/platform-tools/adb -s ${KP_SERIAL:-emulator-5554}"
U=$($A shell stat -c %u /data/data/dev.kartpad.android | tr -d '\r')
$A shell am force-stop dev.kartpad.android
$A install -r "$v/app.apk" | tail -1
$A push "$v/libkartpad_game.so" /data/local/tmp/kp-pack.so >/dev/null
$A push "$v/fingerprint" /data/local/tmp/kp-pack.fp >/dev/null
$A shell "mv /data/local/tmp/kp-pack.so /data/data/dev.kartpad.android/files/gamepack/libkartpad_game.so && mv /data/local/tmp/kp-pack.fp /data/data/dev.kartpad.android/files/gamepack/libkartpad_game.so.fingerprint && chown -R $U:$U /data/data/dev.kartpad.android/files/gamepack && restorecon -R /data/data/dev.kartpad.android/files/gamepack >/dev/null 2>&1; cat /data/data/dev.kartpad.android/files/gamepack/libkartpad_game.so.fingerprint"
