#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
probe="$repo_root/scripts/check-android-physical-device.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT
fake_adb="$test_root/adb"

cat >"$fake_adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

scenario="${FAKE_ADB_SCENARIO:-pass}"
if [[ "${1:-}" == devices ]]; then
  if [[ "$scenario" == devices-error ]]; then
    echo "error while enumerating PRIVATE-SERIAL" >&2
    exit 1
  fi
  echo 'List of devices attached'
  case "$scenario" in
    absent) ;;
    unauthorized) echo 'PRIVATE-SERIAL unauthorized usb:1-1' ;;
    *) echo 'PRIVATE-SERIAL device usb:1-1 product:sample model:Sample_Device' ;;
  esac
  exit 0
fi

[[ "${1:-}" == -s && "${2:-}" == PRIVATE-SERIAL && "${3:-}" == shell ]]
shift 3
if [[ "$scenario" == disconnect ]]; then
  echo "error: device 'PRIVATE-SERIAL' not found" >&2
  exit 1
fi
case "$*" in
  'getprop ro.kernel.qemu') [[ "$scenario" == emulator ]] && echo 1 || echo 0 ;;
  'getprop ro.build.version.sdk') [[ "$scenario" == old-api ]] && echo 27 || echo 36 ;;
  'getprop ro.product.cpu.abi') [[ "$scenario" == wrong-abi ]] && echo x86_64 || echo arm64-v8a ;;
  'getconf PAGE_SIZE') [[ "$scenario" == wrong-page ]] && echo 8192 || echo 16384 ;;
  'getprop ro.product.manufacturer') echo 'Example Corp' ;;
  'getprop ro.product.model') echo 'Model 1' ;;
  'df -k /data')
    echo 'Filesystem 1K-blocks Used Available Use% Mounted on'
    [[ "$scenario" == low-space ]] && echo '/dev 8000000 7000000 1000000 88% /data' || echo '/dev 16000000 8000000 8000000 50% /data'
    ;;
  'dumpsys input')
    [[ "$scenario" == no-controller ]] || printf '  Sources: 0x01000511\n'
    ;;
  'pm path dev.kartpad.android')
    [[ "$scenario" == minimal ]] && exit 1
    echo 'package:/data/app/dev.kartpad.android/base.apk'
    ;;
  'cmd gpu vkjson')
    [[ "$scenario" == minimal ]] && exit 1
    echo '{"deviceName":"Example GPU","apiVersion":1}'
    ;;
  *) echo "unexpected fake adb command: $*" >&2; exit 64 ;;
esac
EOF
chmod +x "$fake_adb"

run_case() {
  local scenario="$1"
  local expected_status="$2"
  local expected_text="$3"
  local output
  local status
  set +e
  output="$(FAKE_ADB_SCENARIO="$scenario" KARTPAD_ADB="$fake_adb" "$probe" 2>&1)"
  status=$?
  set -e
  [[ "$status" == "$expected_status" ]] || {
    echo "ERROR: scenario $scenario returned $status, expected $expected_status" >&2
    echo "$output" >&2
    exit 1
  }
  grep -Fq "$expected_text" <<<"$output" || {
    echo "ERROR: scenario $scenario omitted expected text: $expected_text" >&2
    echo "$output" >&2
    exit 1
  }
  if grep -Fq 'PRIVATE-SERIAL' <<<"$output"; then
    echo "ERROR: scenario $scenario exposed the ADB serial" >&2
    exit 1
  fi
}

run_case pass 0 'input_controller_candidates=1'
run_case minimal 0 'package=not-installed input_controller_candidates=1 vulkan_inventory=unavailable'
run_case no-controller 0 'no gamepad/joystick source is visible'
run_case absent 1 'ready=0 unavailable=0'
run_case unauthorized 1 'ready=0 unavailable=1'
run_case devices-error 1 'unable to enumerate ADB targets'
run_case emulator 1 'is an emulator'
run_case disconnect 1 'adb shell command failed'
run_case old-api 1 'below KartPad'
run_case wrong-abi 1 'expected arm64-v8a'
run_case wrong-page 1 'expected 4096 or 16384'
run_case low-space 1 'A2 preflight requires'

echo 'Android physical-device preflight contract passed (12 cases; ADB serial redacted).'
