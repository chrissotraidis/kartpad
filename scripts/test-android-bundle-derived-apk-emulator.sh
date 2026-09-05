#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"

bundle="${1:-$repo_root/android/app/build/outputs/bundle/release/app-release.aab}"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="${KARTPAD_ADB:-$sdk_root/platform-tools/adb}"
aapt2="$sdk_root/build-tools/$KARTPAD_ANDROID_BUILD_TOOLS/aapt2"
apksigner="$sdk_root/build-tools/$KARTPAD_ANDROID_BUILD_TOOLS/apksigner"
zipalign="$sdk_root/build-tools/$KARTPAD_ANDROID_BUILD_TOOLS/zipalign"
java="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home/bin/java"
python="${KARTPAD_PYTHON:-python3}"
bundletool="$repo_root/.android-bootstrap/dependencies/bundletool-all-1.18.1.jar"
debug_keystore="${KARTPAD_ANDROID_LOCAL_TEST_KEYSTORE:-$HOME/.android/debug.keystore}"
package="dev.kartpad.android"
expected_main_dol_sha256="80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"
runtime_stability_seconds="${KARTPAD_ANDROID_RUNTIME_STABILITY_SECONDS:-15}"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

for tool in "$adb" "$aapt2" "$apksigner" "$zipalign" "$java"; do
  [[ -x "$tool" ]] || fail "required executable is unavailable: $tool"
done
command -v "$python" >/dev/null || fail "Python is unavailable: $python"
[[ -f "$bundle" ]] || fail "AAB is unavailable at $bundle"
[[ -f "$bundletool" ]] || fail "pinned bundletool is unavailable at $bundletool"
[[ -f "$debug_keystore" ]] || fail "local Android test keystore is unavailable"
[[ "$runtime_stability_seconds" =~ ^[0-9]+$ ]] ||
  fail "KARTPAD_ANDROID_RUNTIME_STABILITY_SECONDS must be an integer"
((runtime_stability_seconds >= 5 && runtime_stability_seconds <= 120)) ||
  fail "KARTPAD_ANDROID_RUNTIME_STABILITY_SECONDS must be between 5 and 120"

devices="$($adb devices -l)"
ready_count="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
[[ "$ready_count" == 1 ]] || fail "expected exactly one ready Android target"
serial="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { print $1; exit }')"
adb_target=("$adb" -s "$serial")
[[ "$("${adb_target[@]}" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] ||
  fail "the connected target is not an Android emulator"

temp_root="$(mktemp -d "$repo_root/.android-bootstrap/bundle-derived.XXXXXX")"
[[ "$temp_root" == "$repo_root/.android-bootstrap/bundle-derived."* ]] ||
  fail "temporary directory escaped the guarded Android bootstrap root"
restore_apk="$temp_root/installed-debug.apk"
restore_required=0
restore_install_args=(-r)

restore_selector() {
  "${adb_target[@]}" shell am force-stop "$package" >/dev/null 2>&1 || true
  "${adb_target[@]}" shell am start -W \
    -n "$package/.KartPadLaunchActivity" >/dev/null 2>&1 || true
}

cleanup() {
  local status=$?
  if [[ "$restore_required" == 1 && -f "$restore_apk" ]]; then
    "${adb_target[@]}" install "${restore_install_args[@]}" \
      "$restore_apk" >/dev/null 2>&1 || true
  fi
  restore_selector
  rm -rf -- "$temp_root"
  exit "$status"
}
trap cleanup EXIT

remote_exists() {
  local remote_path="$1"
  "${adb_target[@]}" shell \
    "run-as $package sh -c '[ -e \"$remote_path\" ]'"
}

file_digest() {
  local remote_file="$1"
  if remote_exists "$remote_file"; then
    "${adb_target[@]}" exec-out run-as "$package" sha256sum "$remote_file" |
      awk '{ print $1 }'
  else
    printf 'absent\n'
  fi
}

tree_digest() {
  local remote_root="$1"
  if remote_exists "$remote_root"; then
    "${adb_target[@]}" exec-out run-as "$package" tar -cf - "$remote_root" |
      shasum -a 256 | awk '{ print $1 }'
  else
    printf 'absent\n'
  fi
}

write_state_manifest() {
  local output="$1"
  {
    printf 'config=%s\n' "$(file_digest files/KartPad/Config.toml)"
    printf 'main_dol=%s\n' "$(file_digest files/KartPad/GameData/sys/main.dol)"
    printf 'nand=%s\n' "$(tree_digest files/KartPad/NAND)"
    printf 'saves=%s\n' "$(tree_digest files/KartPad/Saves)"
    printf 'preferences=%s\n' "$(tree_digest shared_prefs)"
    printf 'retro_version=%s\n' \
      "$(file_digest files/KartPad/RetroRewind/RetroRewind6/version.txt)"
  } >"$output"
}

state_digest() {
  shasum -a 256 "$1" | awk '{ print $1 }'
}

installed_version_code() {
  "${adb_target[@]}" shell dumpsys package "$package" |
    sed -n 's/^[[:space:]]*versionCode=\([0-9][0-9]*\).*/\1/p' |
    head -1 | tr -d '\r'
}

device_page_size() {
  local page_size
  page_size="$("${adb_target[@]}" shell getconf PAGE_SIZE 2>/dev/null |
    tr -d '\r' || true)"
  if [[ ! "$page_size" =~ ^[0-9]+$ ]]; then
    page_size="$("${adb_target[@]}" shell \
      "awk '/KernelPageSize:/{print \$2 * 1024; exit}' /proc/self/smaps" |
      tr -d '\r')"
  fi
  [[ "$page_size" == 4096 || "$page_size" == 16384 ]] ||
    fail "emulator page size is neither 4096 nor 16384"
  printf '%s\n' "$page_size"
}

original_mode_bounds() {
  local ui_tree="/sdcard/kartpad-bundle-derived.xml"
  "${adb_target[@]}" shell uiautomator dump "$ui_tree" >/dev/null 2>&1 || return 1
  "${adb_target[@]}" exec-out cat "$ui_tree" | "$python" -c '
import re
import sys
import xml.etree.ElementTree as ET

root = ET.fromstring(sys.stdin.read())
nodes = {node.attrib.get("resource-id"): node for node in root.iter("node")}
original = nodes.get("dev.kartpad.android:id/kartpad_mode_original")
retro = nodes.get("dev.kartpad.android:id/kartpad_mode_retro_rewind")
if original is None or retro is None or original.attrib.get("enabled") != "true":
    raise SystemExit(1)
match = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", original.attrib["bounds"])
if match is None:
    raise SystemExit(1)
print(" ".join(match.groups()))
'
}

selector_is_visible() {
  original_mode_bounds >/dev/null
}

wait_for_selector() {
  local ready=0
  for _ in {1..20}; do
    if selector_is_visible; then
      ready=1
      break
    fi
    sleep 1
  done
  [[ "$ready" == 1 ]] || fail "the production game selector did not become visible"
}

tap_original_mode() {
  local bounds
  bounds="$(original_mode_bounds)" ||
    fail "could not locate an enabled Original-game selector card"
  local left top right bottom
  read -r left top right bottom <<<"$bounds"
  "${adb_target[@]}" shell input tap \
    "$(((left + right) / 2))" "$(((top + bottom) / 2))"
}

exercise_original_runtime() {
  "${adb_target[@]}" logcat -c
  tap_original_mode
  local runtime_started=0
  for _ in {1..30}; do
    if "${adb_target[@]}" logcat -d -s SDL:V '*:S' |
        grep -Eq 'Running main function SDL_main from library .*/lib/arm64/libmain\.so'; then
      runtime_started=1
      break
    fi
    sleep 1
  done
  [[ "$runtime_started" == 1 ]] ||
    fail "bundle-derived release activity did not execute SDL_main from libmain.so"
  local initial_pid
  initial_pid="$("${adb_target[@]}" shell pidof "$package" 2>/dev/null |
    tr -d '\r' || true)"
  [[ "$initial_pid" =~ ^[0-9]+$ ]] ||
    fail "bundle-derived release runtime has no stable process"
  sleep "$runtime_stability_seconds"
  [[ "$("${adb_target[@]}" shell pidof "$package" | tr -d '\r')" == "$initial_pid" ]] ||
    fail "bundle-derived release runtime did not retain its process"
  local runtime_log
  runtime_log="$("${adb_target[@]}" logcat -d -v raw \
    SDL:V SDL/APP:I AndroidRuntime:E libc:F '*:S')"
  [[ "$runtime_log" == *'surfaceCreated()'* &&
     "$runtime_log" == *'Low latency audio enabled'* ]] ||
    fail "bundle-derived runtime did not initialize its surface and audio path"
  if printf '%s\n' "$runtime_log" |
      grep -Eq 'FATAL EXCEPTION|Fatal signal|CheckJNI|SIGABRT|SIGSEGV'; then
    fail "bundle-derived runtime emitted a fatal signature"
  fi
  local ui_tree="/sdcard/kartpad-bundle-runtime.xml"
  "${adb_target[@]}" shell uiautomator dump "$ui_tree" >/dev/null 2>&1 ||
    fail "could not capture the running touch overlay"
  local overlay_hierarchy
  overlay_hierarchy="$("${adb_target[@]}" exec-out cat "$ui_tree")"
  [[ "$overlay_hierarchy" == *'content-desc="Menu"'* ]] ||
    fail "running release runtime did not expose the KartPad menu control"
  local frame="$temp_root/runtime-frame.raw"
  local frame_ready=0
  for _ in {1..12}; do
    "${adb_target[@]}" exec-out screencap >"$frame"
    if "$repo_root/scripts/check-android-runtime-frame.py" "$frame" >/dev/null 2>&1; then
      frame_ready=1
      break
    fi
    [[ "$("${adb_target[@]}" shell pidof "$package" | tr -d '\r')" == "$initial_pid" ]] ||
      fail "bundle-derived release runtime exited while waiting for a rendered frame"
    sleep 5
  done
  if [[ "$frame_ready" != 1 ]]; then
    "$repo_root/scripts/check-android-runtime-frame.py" "$frame" >/dev/null || true
    fail "bundle-derived release runtime did not present a diverse frame"
  fi
  "${adb_target[@]}" shell toybox rm -f "$ui_tree" >/dev/null 2>&1 || true
  "${adb_target[@]}" shell am force-stop "$package"
}

"$repo_root/scripts/audit-android-bundle.sh" "$bundle" >/dev/null
bundle_sha256="$(shasum -a 256 "$bundle" | awk '{ print $1 }')"

installed_path="$("${adb_target[@]}" shell pm path "$package" |
  sed -n 's/^package://p' | head -1 | tr -d '\r')"
[[ -n "$installed_path" ]] || fail "KartPad is not installed on the emulator"
if ! "${adb_target[@]}" pull "$installed_path" "$restore_apk" \
    >/dev/null 2>&1; then
  fail "could not preserve the installed debug APK for recovery"
fi
[[ "$("$aapt2" dump badging "$restore_apk")" == *"package: name='$package'"* ]] ||
  fail "the recoverable installed APK has the wrong package identity"
restore_version="$(installed_version_code)"
[[ -n "$restore_version" ]] || fail "could not determine the installed version code"
[[ "$(file_digest files/KartPad/GameData/sys/main.dol)" == \
    "$expected_main_dol_sha256" ]] ||
  fail "app-private GameData is not the approved fixture"
restore_selector
wait_for_selector
before_manifest="$temp_root/before-state"
write_state_manifest "$before_manifest"
before_state="$(state_digest "$before_manifest")"

"$java" -jar "$bundletool" build-apks \
  --bundle="$bundle" \
  --output="$temp_root/app.apks" \
  --mode=universal \
  --ks="$debug_keystore" \
  --ks-pass=pass:android \
  --ks-key-alias=androiddebugkey \
  --key-pass=pass:android >/dev/null
unzip -q "$temp_root/app.apks" universal.apk -d "$temp_root"
derived_apk="$temp_root/universal.apk"
[[ -f "$derived_apk" ]] || fail "bundletool did not produce a universal APK"
derived_badging="$("$aapt2" dump badging "$derived_apk")"
[[ "$derived_badging" == *"package: name='$package'"* ]] ||
  fail "bundle-derived APK has the wrong package identity"
[[ "$derived_badging" != *"application-debuggable"* ]] ||
  fail "bundle-derived release APK is unexpectedly debuggable"
derived_version="$(printf '%s\n' "$derived_badging" |
  sed -n "s/^package: .*versionCode='\([0-9][0-9]*\)'.*/\1/p")"
derived_version_name="$(printf '%s\n' "$derived_badging" |
  sed -n "s/^package: .*versionName='\([^']*\)'.*/\1/p")"
[[ -n "$derived_version_name" ]] || fail "bundle-derived APK has no version name"
((derived_version >= restore_version)) ||
  fail "bundle-derived APK would downgrade the recoverable installed APK"
if ((derived_version > restore_version)); then
  restore_install_args=(-r -d)
fi
"$repo_root/scripts/audit-android-package.sh" "$derived_apk" >/dev/null
derived_apk_sha256="$(shasum -a 256 "$derived_apk" | awk '{ print $1 }')"

restore_required=1
"${adb_target[@]}" install -r "$derived_apk" >/dev/null
[[ "$(installed_version_code)" == "$derived_version" ]] ||
  fail "installed bundle-derived APK version does not match"

"${adb_target[@]}" shell input keyevent KEYCODE_WAKEUP >/dev/null
"${adb_target[@]}" shell wm dismiss-keyguard >/dev/null 2>&1 || true
restore_selector
wait_for_selector
exercise_original_runtime

device_spec="$temp_root/device-spec.json"
device_apks="$temp_root/device.apks"
"$java" -jar "$bundletool" get-device-spec \
  --output="$device_spec" --adb="$adb" --device-id="$serial" >/dev/null
"$java" -jar "$bundletool" build-apks \
  --bundle="$bundle" \
  --output="$device_apks" \
  --device-spec="$device_spec" \
  --ks="$debug_keystore" \
  --ks-pass=pass:android \
  --ks-key-alias=androiddebugkey \
  --key-pass=pass:android >/dev/null

split_members="$(unzip -Z1 "$device_apks" | sort)"
fixed_split_members="$(printf '%s\n' \
  splits/base-arm64_v8a.apk \
  splits/base-en.apk \
  splits/base-master.apk \
  toc.pb | sort)"
density_split="$(printf '%s\n' "$split_members" |
  grep -E '^splits/base-(ldpi|mdpi|hdpi|xhdpi|xxhdpi|xxxhdpi)\.apk$' || true)"
[[ "$(printf '%s\n' "$density_split" | grep -c .)" == 1 ]] ||
  fail "device APK set does not contain exactly one recognized density split"
expected_split_members="$(printf '%s\n' "$fixed_split_members" "$density_split" | sort)"
[[ "$split_members" == "$expected_split_members" ]] ||
  fail "device APK set differs from the exact base/ARM64/English/density contract"

split_root="$temp_root/device-splits"
mkdir -p "$split_root"
unzip -q "$device_apks" 'splits/*.apk' -d "$split_root"
master_apk="$split_root/splits/base-master.apk"
master_badging="$("$aapt2" dump badging "$master_apk")"
[[ "$master_badging" == *"package: name='$package'"* &&
   "$master_badging" == *"versionCode='$derived_version'"* &&
   "$master_badging" == *"versionName='$derived_version_name'"* ]] ||
  fail "device base split has the wrong package or version identity"
[[ "$master_badging" != *"application-debuggable"* ]] ||
  fail "device base split is unexpectedly debuggable"

split_signer=""
for split_apk in "$split_root"/splits/*.apk; do
  JAVA_HOME="$(dirname "$(dirname "$java")")" \
    "$apksigner" verify --verbose "$split_apk" >/dev/null
  "$zipalign" -c -P 16 -v 4 "$split_apk" >/dev/null
  current_signer="$(JAVA_HOME="$(dirname "$(dirname "$java")")" \
    "$apksigner" verify --print-certs "$split_apk" |
    sed -n 's/^Signer #1 certificate SHA-256 digest: //p')"
  [[ -n "$current_signer" ]] || fail "device split has no signer certificate digest"
  if [[ -z "$split_signer" ]]; then
    split_signer="$current_signer"
  else
    [[ "$current_signer" == "$split_signer" ]] ||
      fail "device APK splits do not share one signer certificate"
  fi
done

abi_split="$split_root/splits/base-arm64_v8a.apk"
for library in libSDL3.so libc++_shared.so libkartpad_discio.so libmain.so; do
  unzip -p "$bundle" "base/lib/arm64-v8a/$library" \
    >"$temp_root/bundle-$library"
  unzip -p "$abi_split" "lib/arm64-v8a/$library" \
    >"$temp_root/split-$library"
  cmp -s "$temp_root/bundle-$library" "$temp_root/split-$library" ||
    fail "device split changed $library bytes from the audited AAB"
done
if unzip -p "$device_apks" | strings |
    grep -Eq '/Users/|Mario Kart Wii\.(iso|wbfs)'; then
  fail "device APK set contains a private path or game-data name"
fi

if ! "$java" -jar "$bundletool" install-apks \
    --apks="$device_apks" --adb="$adb" --device-id="$serial" \
    >/dev/null 2>&1; then
  fail "bundletool could not install the device APK set"
fi
[[ "$(installed_version_code)" == "$derived_version" ]] ||
  fail "installed device APK set version does not match"
installed_paths="$("${adb_target[@]}" shell pm path "$package" | tr -d '\r')"
[[ "$(printf '%s\n' "$installed_paths" | grep -c '^package:')" == 4 &&
   "$installed_paths" == *'/base.apk'* &&
   "$installed_paths" == *'/split_config.arm64_v8a.apk'* &&
   "$installed_paths" == *'/split_config.en.apk'* &&
   "$installed_paths" == *'/split_config.'*'dpi.apk'* ]] ||
  fail "installed package is not the expected four-part device split set"
restore_selector
wait_for_selector
exercise_original_runtime

"${adb_target[@]}" install "${restore_install_args[@]}" "$restore_apk" >/dev/null
restore_required=0
[[ "$(installed_version_code)" == "$restore_version" ]] ||
  fail "recoverable debug APK version was not restored"
after_manifest="$temp_root/after-state"
write_state_manifest "$after_manifest"
after_state="$(state_digest "$after_manifest")"
if [[ "$before_state" != "$after_state" ]]; then
  changed_categories="$(awk -F= '
    NR == FNR { before[$1] = $2; next }
    before[$1] != $2 { print $1 }
  ' "$before_manifest" "$after_manifest" | paste -sd, -)"
  fail "app-private durable state changed across bundle-derived APK testing: ${changed_categories:-unknown}"
fi
restore_selector
wait_for_selector

echo "Android bundle-derived APK emulator test passed: aab_sha256=$bundle_sha256 derived_apk_sha256=$derived_apk_sha256 version_code=$derived_version page_size=$(device_page_size) release_non_debuggable=yes universal_selector_visible=yes universal_runtime_stable=yes universal_frame_diverse=yes device_splits=4 split_signer_consistent=yes split_native_bytes_exact=yes split_selector_visible=yes split_runtime_stable=yes split_frame_diverse=yes debug_apk_restored=yes durable_state_preserved=yes"
