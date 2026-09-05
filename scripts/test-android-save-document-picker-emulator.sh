#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "usage: $0 [APK]" >&2
  exit 64
fi

repo_root="$(git rev-parse --show-toplevel)"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="${KARTPAD_ADB:-$sdk_root/platform-tools/adb}"
apk="${1:-$repo_root/android/app/build/outputs/apk/debug/app-debug.apk}"
package="dev.kartpad.android"
active="files/KartPad/NAND/title/00010004/524d4350/data/rksys.dat"
backup_root="files/KartPad/SaveBackups"
recovery="$backup_root/rksys-documentui-fixture-recovery.dat"
pending="files/KartPad/PendingSaves/rksys.dat"
public_export="/sdcard/Download/KartPad-RMCP01-rksys.dat"
ui_tree="/sdcard/kartpad-save-document-picker.xml"
expected_main_dol_sha256="80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"
success=0
created_backup=""
recovery_created=0
public_export_owned=0
ui_tree_owned=0

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

[[ -x "$adb" ]] || fail "adb is unavailable at $adb"
[[ -f "$apk" ]] || fail "APK is unavailable at $apk"
devices="$($adb devices -l)"
ready_count="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { count++ } END { print count + 0 }')"
[[ "$ready_count" == 1 ]] || fail "expected exactly one ready Android target"
serial="$(printf '%s\n' "$devices" |
  awk 'NR > 1 && $2 == "device" { print $1; exit }')"
adb_target=("$adb" -s "$serial")
[[ "$("${adb_target[@]}" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] ||
  fail "the connected target is not an Android emulator"

# shellcheck disable=SC2329 # Invoked by the EXIT trap.
cleanup() {
  if [[ "$ui_tree_owned" == 1 ]]; then
    "${adb_target[@]}" shell rm -f "$ui_tree" >/dev/null 2>&1 || true
  fi
  if [[ "$public_export_owned" == 1 ]]; then
    "${adb_target[@]}" shell rm -f "$public_export" >/dev/null 2>&1 || true
  fi
  if [[ "$success" == 1 ]]; then
    if [[ "$recovery_created" == 1 ]]; then
      "${adb_target[@]}" shell run-as "$package" rm -f "$recovery" >/dev/null 2>&1 || true
    fi
    if [[ -n "$created_backup" ]]; then
      "${adb_target[@]}" shell run-as "$package" rm -f "$created_backup" >/dev/null 2>&1 || true
    fi
  elif [[ "$recovery_created" == 1 ]]; then
    echo "Recovery copy retained in app-private SaveBackups after incomplete test." >&2
  fi
  "${adb_target[@]}" shell am force-stop "$package" >/dev/null 2>&1 || true
  "${adb_target[@]}" shell am start -W \
    -n "$package/.KartPadLaunchActivity" >/dev/null 2>&1 || true
}
trap cleanup EXIT

dump_tree() {
  for _ in {1..10}; do
    if "${adb_target[@]}" shell uiautomator dump "$ui_tree" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  fail "could not capture Android UI hierarchy"
}

tree_contains_node() {
  local attribute="$1"
  local expected="$2"
  dump_tree
  "${adb_target[@]}" exec-out cat "$ui_tree" |
    ATTRIBUTE="$attribute" EXPECTED="$expected" python3 -c \
      'import os,sys,xml.etree.ElementTree as ET; root=ET.fromstring(sys.stdin.read()); raise SystemExit(0 if any(n.attrib.get(os.environ["ATTRIBUTE"])==os.environ["EXPECTED"] for n in root.iter("node")) else 1)'
}

wait_for_node() {
  local attribute="$1"
  local expected="$2"
  for _ in {1..30}; do
    if tree_contains_node "$attribute" "$expected"; then
      return 0
    fi
    sleep 1
  done
  fail "timed out waiting for UI $attribute: $expected"
}

wait_for_text() {
  wait_for_node text "$1"
}

tap_node() {
  local attribute="$1"
  local expected="$2"
  local coordinates
  dump_tree
  coordinates="$("${adb_target[@]}" exec-out cat "$ui_tree" |
    ATTRIBUTE="$attribute" EXPECTED="$expected" python3 -c \
      'import os,re,sys,xml.etree.ElementTree as ET; root=ET.fromstring(sys.stdin.read()); n=next((x for x in root.iter("node") if x.attrib.get(os.environ["ATTRIBUTE"])==os.environ["EXPECTED"]),None); assert n is not None, os.environ["EXPECTED"]; a=list(map(int,re.findall(r"\d+",n.attrib["bounds"]))); print((a[0]+a[2])//2,(a[1]+a[3])//2)')"
  read -r x y <<<"$coordinates"
  "${adb_target[@]}" shell input tap "$x" "$y"
  sleep 1
}

open_save_manager() {
  tap_node content-desc "Menu"
  wait_for_text "Game Data & Saves"
  tap_node text "Game Data & Saves"
  wait_for_text "Manage Saves…"
  tap_node text "Manage Saves…"
  wait_for_text "EXPORT SAVE BACKUP…"
}

private_sha256() {
  "${adb_target[@]}" exec-out run-as "$package" sha256sum "$1" | awk '{ print $1 }'
}

"${adb_target[@]}" install -r "$apk" >/dev/null
installed_main_dol_sha256="$(private_sha256 files/KartPad/GameData/sys/main.dol)"
[[ "$installed_main_dol_sha256" == "$expected_main_dol_sha256" ]] ||
  fail "app-private GameData changed or is not the approved fixture"
"${adb_target[@]}" shell run-as "$package" test -f "$active" ||
  fail "a real initialized Mario Kart Wii save is required"
"${adb_target[@]}" shell run-as "$package" test ! -e "$pending" ||
  fail "a pending save restore already exists"
"${adb_target[@]}" shell run-as "$package" test ! -e "$recovery" ||
  fail "the exact app-private recovery path already exists"
"${adb_target[@]}" shell test ! -e "$public_export" ||
  fail "the exact Downloads export path already exists"
"${adb_target[@]}" shell test ! -e "$ui_tree" ||
  fail "the exact UI-dump path already exists"
public_export_owned=1
ui_tree_owned=1

"${adb_target[@]}" shell run-as "$package" mkdir -p "$backup_root"
"${adb_target[@]}" shell run-as "$package" cp "$active" "$recovery"
recovery_created=1
active_before="$(private_sha256 "$active")"
recovery_sha256="$(private_sha256 "$recovery")"
[[ -n "$active_before" && "$active_before" == "$recovery_sha256" ]] ||
  fail "app-private recovery copy does not match the active save"
backups_before="$("${adb_target[@]}" shell run-as "$package" find "$backup_root" \
  -maxdepth 1 -type f | tr -d '\r' | sort)"

"${adb_target[@]}" shell am force-stop "$package"
"${adb_target[@]}" shell am start -W -n "$package/.KartPadActivity" >/dev/null
wait_for_node content-desc "Menu"
open_save_manager
tap_node text "EXPORT SAVE BACKUP…"
wait_for_text "SAVE"
tap_node text "SAVE"
wait_for_text "Save Backup Exported"

export_sha256="$("${adb_target[@]}" shell sha256sum "$public_export" |
  awk '{ print $1 }' | tr -d '\r')"
[[ -n "$export_sha256" && "$export_sha256" == "$active_before" ]] ||
  fail "system-picker export does not match the protected active save"
tap_node text "BACK"
"${adb_target[@]}" shell am force-stop "$package"
"${adb_target[@]}" shell am start -W -n "$package/.KartPadActivity" >/dev/null
wait_for_node content-desc "Menu"

open_save_manager
tap_node text "RESTORE SAVE BACKUP…"
wait_for_text "KartPad-RMCP01-rksys.dat"
tap_node text "KartPad-RMCP01-rksys.dat"
wait_for_text "Save Restore Scheduled"
"${adb_target[@]}" shell run-as "$package" test -f "$pending" ||
  fail "validated system-picker import was not staged"
tap_node text "RESTART NOW"
wait_for_text "Mario Kart Wii"

"${adb_target[@]}" shell am start -W -n "$package/.KartPadActivity" >/dev/null
for _ in {1..30}; do
  if "${adb_target[@]}" shell run-as "$package" test ! -e "$pending"; then
    break
  fi
  sleep 1
done
"${adb_target[@]}" shell run-as "$package" test ! -e "$pending" ||
  fail "pending restore was not applied on runtime restart"
"${adb_target[@]}" shell am force-stop "$package"

backups_after="$("${adb_target[@]}" shell run-as "$package" find "$backup_root" \
  -maxdepth 1 -type f | tr -d '\r' | sort)"
created_backup="$(comm -13 \
  <(printf '%s\n' "$backups_before") \
  <(printf '%s\n' "$backups_after"))"
[[ -n "$created_backup" && "$created_backup" != *$'\n'* ]] ||
  fail "restore did not create exactly one new prior-save backup"
[[ "$created_backup" == "$backup_root"/rksys-*.dat ]] ||
  fail "restore created an unexpected backup path"

active_after="$(private_sha256 "$active")"
automatic_backup_sha256="$(private_sha256 "$created_backup")"
[[ "$active_after" == "$export_sha256" ]] ||
  fail "restored active save does not match the exported bytes"
[[ "$automatic_backup_sha256" == "$active_before" ]] ||
  fail "automatic prior-save backup does not match the original bytes"

success=1
echo "Android save document-picker round trip passed: export=exact import=validated restart=applied backup=exact cleanup=armed"
