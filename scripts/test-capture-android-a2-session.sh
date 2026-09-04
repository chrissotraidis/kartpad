#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
capture="$repo_root/scripts/capture-android-a2-session.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
fake_adb="$test_root/adb"
marker="$test_root/capture-start.txt"

cat >"$fake_adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

scenario="${FAKE_ADB_SCENARIO:-pass}"
if [[ "${1:-}" == devices ]]; then
  echo 'List of devices attached'
  echo 'PRIVATE-SERIAL device usb:1-1 product:sample model:Sample_Device'
  exit 0
fi
[[ "${1:-}" == -s && "${2:-}" == PRIVATE-SERIAL ]]
shift 2
if [[ "${1:-}" == logcat ]]; then
  if [[ "$scenario" == logcat-error ]]; then
    echo "error: device 'PRIVATE-SERIAL' disconnected" >&2
    exit 1
  fi
  cat <<'LOG'
PRIVATE_GAME_TEXT must never pass the sanitizer
[audio] host playback active: 32000 Hz, 2 channels, gain=1
[audio] non-silent PCM reached host playback: peak=4000, queued=3000 bytes
[audio] queue telemetry: checks=8192, empty-before-push=0, dropped-blocks=0, dropped-bytes=0, submitted-bytes=3145728, queued=8000, observed-range=[0,15000] bytes, limit=15360 bytes
[input] Android SDL controller channel 0 connected
surfaceCreated()
Standard gamepads suspended
surfaceDestroyed()
nativePause()
surfaceCreated()
nativeResume()
Standard gamepads resumed
LOG
  exit 0
fi
[[ "${1:-}" == shell ]]
shift
case "$*" in
  'getprop ro.kernel.qemu') echo 0 ;;
  'getprop ro.build.version.sdk') echo 36 ;;
  'getprop ro.product.cpu.abi') echo arm64-v8a ;;
  'getconf PAGE_SIZE') echo 4096 ;;
  'getprop ro.product.manufacturer') echo Example ;;
  'getprop ro.product.model') echo Device ;;
  'df -k /data')
    printf 'Filesystem 1K-blocks Used Available Use%% Mounted on\n'
    echo '/dev 16000000 8000000 8000000 50% /data'
    ;;
  'dumpsys input') echo '  Sources: 0x01000511' ;;
  'pm path dev.kartpad.android') echo 'package:/data/app/dev.kartpad.android/base.apk' ;;
  'cmd gpu vkjson') echo '{"deviceName":"Example GPU"}' ;;
  'cmd package list packages -U dev.kartpad.android')
    echo 'package:dev.kartpad.android uid:10123'
    ;;
  'date +%m-%d_%H:%M:%S.000') echo '09-04_12:34:56.000' ;;
  *) echo "unexpected fake ADB command: $*" >&2; exit 64 ;;
esac
EOF
chmod +x "$fake_adb"

run_capture() {
  FAKE_ADB_SCENARIO="${1:-pass}" \
    KARTPAD_ADB="$fake_adb" \
    KARTPAD_ANDROID_A2_CAPTURE_MARKER="$marker" \
    "$capture" "$2" 2>&1
}

start_output="$(run_capture pass start)"
[[ "$(<"$marker")" == '09-04 12:34:56.000' ]]
[[ "$start_output" != *'PRIVATE-SERIAL'* ]]

summary_output="$(run_capture pass summarize)"
[[ "$summary_output" == *'"automated_signal_matrix_passed": true'* ]]
[[ "$summary_output" != *'PRIVATE_GAME_TEXT'* ]]
[[ "$summary_output" != *'PRIVATE-SERIAL'* ]]

set +e
failure_output="$(run_capture logcat-error summarize)"
failure_status=$?
set -e
[[ "$failure_status" == 1 ]]
[[ "$failure_output" == *'UID-scoped logcat capture failed'* ]]
[[ "$failure_output" != *'automated_signal_matrix_passed'* ]]
[[ "$failure_output" != *'PRIVATE-SERIAL'* ]]

echo 'Android A2 UID-scoped capture contract passed (start, summarize, redaction).'
