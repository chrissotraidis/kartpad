#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="$sdk_root/platform-tools/adb"
emulator="$sdk_root/emulator/emulator"
avdmanager="$sdk_root/cmdline-tools/$KARTPAD_ANDROID_CMDLINE_TOOLS_REVISION/bin/avdmanager"
temporary_avd="KartPad_API_36_ENOSPC"
package="dev.kartpad.android"
component="$package/.RetroRewindWorkerFixtureActivity"
mountpoint="/data/user/0/$package/files/KartPad"
image="/data/local/tmp/kartpad-enospc.img"
pushed_archive="/data/local/tmp/RetroRewindEnospcFixture.zip"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/kartpad-android-enospc.XXXXXX")"
host_archive="$test_root/RetroRewindEnospcFixture.zip"
metadata="$test_root/metadata"
emulator_pid=""
avd_created=0

cleanup() {
  "$adb" shell am force-stop "$package" >/dev/null 2>&1 || true
  "$adb" shell umount "$mountpoint" >/dev/null 2>&1 || true
  "$adb" shell rm -f "$image" "$pushed_archive" >/dev/null 2>&1 || true
  "$adb" emu kill >/dev/null 2>&1 || true
  if [[ -n "$emulator_pid" ]]; then
    wait "$emulator_pid" 2>/dev/null || true
  fi
  if [[ "$avd_created" == 1 ]]; then
    "$avdmanager" delete avd --name "$temporary_avd" >/dev/null 2>&1 || true
  fi
  find "$test_root" -depth -delete
}
trap cleanup EXIT

if "$adb" devices | sed -n '2,$p' | grep -q '[[:space:]]device$'; then
  echo "ERROR: an Android device/emulator is already connected; preserve the one-emulator rule" >&2
  exit 1
fi
if [[ -e "$HOME/.android/avd/$temporary_avd.ini" ||
      -d "$HOME/.android/avd/$temporary_avd.avd" ]]; then
  echo "ERROR: temporary AVD already exists: $temporary_avd" >&2
  exit 1
fi
host_available_kib="$(df -Pk "$repo_root" | awk 'NR == 2 {print $4}')"
if (( host_available_kib * 1024 < 8 * 1024 * 1024 * 1024 )); then
  echo "ERROR: host lacks the required 8 GiB reserve" >&2
  exit 1
fi

python3 - "$repo_root/builder/profiles/mkwii-rmcp01-rev0.json" \
  "$host_archive" "$metadata" <<'PY'
import hashlib
import json
from pathlib import Path
import sys
import zipfile

profile_path, archive_path, metadata_path = map(Path, sys.argv[1:])
with profile_path.open(encoding="utf-8") as stream:
    retro = json.load(stream)["retroRewind"]
payload_bytes = 384 * 1024 * 1024
chunk = bytes(1024 * 1024)
payload_digest = hashlib.sha256()
with zipfile.ZipFile(archive_path, "w", zipfile.ZIP_DEFLATED, allowZip64=True) as archive:
    root = retro["root"]
    archive.writestr(f"{root}/", b"")
    archive.writestr(f"{root}/version.txt", f"{retro['version']}\n".encode())
    archive.writestr(f"{root}/fixture/", b"")
    with archive.open(f"{root}/fixture/large.bin", "w", force_zip64=True) as output:
        for _ in range(payload_bytes // len(chunk)):
            output.write(chunk)
            payload_digest.update(chunk)
archive_data = archive_path.read_bytes()
metadata_path.write_text(
    "\n".join((
        str(len(archive_data)),
        hashlib.sha256(archive_data).hexdigest(),
        str(payload_bytes),
        payload_digest.hexdigest(),
    )) + "\n",
    encoding="utf-8",
)
PY
archive_bytes="$(sed -n '1p' "$metadata")"
archive_sha256="$(sed -n '2p' "$metadata")"
payload_bytes="$(sed -n '3p' "$metadata")"
payload_sha256="$(sed -n '4p' "$metadata")"

"$repo_root/scripts/build-android-fixture.sh"
"$repo_root/scripts/audit-android-package.sh"
export JAVA_HOME="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home"
printf 'no\n' | "$avdmanager" create avd --force --name "$temporary_avd" \
  --package "$KARTPAD_ANDROID_PHONE_IMAGE" --device pixel_7 >/dev/null
avd_created=1
emulator_log="$repo_root/.android-bootstrap/emulator-$temporary_avd.raw.log"
"$emulator" "@$temporary_avd" -no-window -no-audio -no-boot-anim -no-snapshot \
  -gpu auto -wipe-data >"$emulator_log" 2>&1 &
emulator_pid=$!

"$adb" wait-for-device
booted=0
for _ in {1..60}; do
  if [[ "$("$adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
    booted=1
    break
  fi
  sleep 2
done
[[ "$booted" == 1 ]] || { echo "ERROR: emulator did not finish booting" >&2; exit 1; }
"$adb" root >/dev/null
"$adb" wait-for-device

apk="$repo_root/android/app/build/outputs/apk/debug/app-debug.apk"
"$adb" install -r "$apk" >/dev/null
uid="$("$adb" shell stat -c %u "/data/user/0/$package" | tr -d '\r')"
context="$("$adb" shell ls -Zd "/data/user/0/$package/cache" |
  awk '{print $1}' | tr -d '\r')"
[[ "$uid" =~ ^[0-9]+$ && "$context" == u:object_r:app_data_file:* ]] || {
  echo "ERROR: could not derive bounded app storage ownership" >&2
  exit 1
}

"$adb" shell mkdir -p "$mountpoint"
"$adb" shell truncate -s 536870912 "$image"
"$adb" shell mke2fs -t ext4 -F "$image" >/dev/null
"$adb" shell mount -o loop "$image" "$mountpoint"
"$adb" shell chown "$uid:$uid" "$mountpoint"
"$adb" shell chmod 700 "$mountpoint"
"$adb" shell chcon "$context" "$mountpoint"
"$adb" shell run-as "$package" touch files/KartPad/app-access-check
"$adb" shell run-as "$package" rm files/KartPad/app-access-check

"$adb" push "$host_archive" "$pushed_archive" >/dev/null
"$adb" shell run-as "$package" cp "$pushed_archive" "cache/$(basename "$pushed_archive")"

wait_for_marker() {
  local expected="$1"
  local marker=""
  for _ in {1..60}; do
    marker="$("$adb" logcat -d -v raw KartPadFixture:I AndroidRuntime:E '*:S' |
      grep -F "$expected" | tail -1 || true)"
    [[ -n "$marker" ]] && { printf '%s\n' "$marker"; return 0; }
    sleep 1
  done
  echo "ERROR: fixture marker was not observed: $expected" >&2
  "$adb" logcat -d -v brief KartPadFixture:V AndroidRuntime:E libc:F '*:S' >&2
  return 1
}

"$adb" logcat -c
"$adb" shell am start -W -n "$component" \
  --ez dev.kartpad.android.TEST_RETRO_REWIND_ENOSPC_PREPARE true >/dev/null
wait_for_marker "A3 ENOSPC fixture prepared existing=valid" >/dev/null
"$adb" shell am force-stop "$package"

available_kib="$("$adb" shell df -k "$mountpoint" | awk 'NR == 2 {print $4}' |
  tr -d '\r')"
[[ "$available_kib" =~ ^[0-9]+$ ]] || {
  echo "ERROR: could not read bounded filesystem capacity" >&2
  exit 1
}
target_kib=$((128 * 1024))
fill_kib=$((available_kib - target_kib))
if (( fill_kib <= 0 || fill_kib > 512 * 1024 )); then
  echo "ERROR: bounded ENOSPC filler is outside its 512 MiB safety cap" >&2
  exit 1
fi
"$adb" shell fallocate -l "$((fill_kib * 1024))" "$mountpoint/.enospc-fill"

"$adb" logcat -c
"$adb" shell am start -W -n "$component" \
  --ez dev.kartpad.android.TEST_RETRO_REWIND_ENOSPC_RUN true \
  --el dev.kartpad.android.TEST_RETRO_REWIND_ARCHIVE_BYTES "$archive_bytes" \
  --es dev.kartpad.android.TEST_RETRO_REWIND_ARCHIVE_SHA256 "$archive_sha256" \
  --el dev.kartpad.android.TEST_RETRO_REWIND_PAYLOAD_BYTES "$payload_bytes" \
  --es dev.kartpad.android.TEST_RETRO_REWIND_PAYLOAD_SHA256 "$payload_sha256" \
  >/dev/null
marker="$(wait_for_marker "A3 ENOSPC extraction passed existing=preserved")"
extracted="$(printf '%s\n' "$marker" |
  sed -n 's/.*extracted=\([0-9][0-9]*\).*/\1/p')"
[[ "$marker" == *"error=IO_FAILURE"* && "$extracted" =~ ^[0-9]+$ ]] || {
  echo "ERROR: bounded filesystem did not produce a measured native IO failure" >&2
  exit 1
}
if (( extracted <= 0 || extracted >= payload_bytes )); then
  echo "ERROR: ENOSPC did not interrupt active extraction" >&2
  exit 1
fi

echo "Android Retro Rewind ENOSPC extraction passed: avd=$temporary_avd api=36 abi=arm64-v8a filesystem_mib=512 filler_kib=$fill_kib payload_bytes=$payload_bytes extracted_bytes=$extracted existing=preserved staging=clean archive=synthetic"
