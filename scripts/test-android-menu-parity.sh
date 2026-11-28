#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="$sdk_root/platform-tools/adb"
lane="${1:-phone}"
case "$lane" in
  # long_page_icons: rows with icons that fit on screen in the eight-row top and Game Data pages.
  phone) user_rotation=1; expected_width=2400; expected_height=1080; long_page_icons=7 ;;
  tablet) user_rotation=0; expected_width=2560; expected_height=1600; long_page_icons=8 ;;
  *) echo "ERROR: lane must be phone or tablet" >&2; exit 64 ;;
esac

restore_orientation() {
  [[ "$lane" == phone ]] || return 0
  "$adb" emu sensor set acceleration 9.81:0:0 >/dev/null 2>&1 || true
  "$adb" shell settings put system accelerometer_rotation 0 >/dev/null 2>&1 || true
  "$adb" shell settings put system user_rotation 1 >/dev/null 2>&1 || true
}
emulator_targets="$("$adb" devices 2>/dev/null | awk '$1 ~ /^emulator-[0-9]+$/ && $2 == "device" {print $1}')"
emulator_count="$(printf '%s\n' "$emulator_targets" | awk 'NF {count++} END {print count+0}')"
[[ "$emulator_count" == 1 ]] || {
  echo "ERROR: expected exactly one authorized Android emulator; no physical device will be modified" >&2
  exit 1
}
export ANDROID_SERIAL="$emulator_targets"
[[ "$("$adb" shell getprop ro.kernel.qemu | tr -d '\r')" == 1 ]] || {
  echo "ERROR: target is not an emulator" >&2
  exit 1
}
trap restore_orientation EXIT

"$repo_root/scripts/build-android-fixture.sh"
apk="$repo_root/android/app/build/outputs/apk/debug/app-debug.apk"
"$adb" install -r "$apk" >/dev/null
"$adb" shell input keyevent KEYCODE_WAKEUP >/dev/null
"$adb" shell wm dismiss-keyguard >/dev/null 2>&1 || true
"$adb" shell settings put system accelerometer_rotation 0
"$adb" shell settings put system user_rotation "$user_rotation"

artifact_root="$repo_root/.android-bootstrap/menu-parity-$lane"
mkdir -p "$artifact_root"
tree="$artifact_root/hierarchy.xml"

dump_tree() {
  for _ in {1..10}; do
    if "$adb" shell uiautomator dump /sdcard/kartpad-menu-parity.xml >/dev/null 2>&1 &&
        "$adb" exec-out cat /sdcard/kartpad-menu-parity.xml >"$tree"; then
      return 0
    fi
    sleep 1
  done
  echo "ERROR: could not capture menu hierarchy" >&2
  return 1
}

start_menu() {
  "$adb" shell am force-stop dev.kartpad.android
  "$adb" shell am start -W -n dev.kartpad.android/.KartPadActivity \
    --ez dev.kartpad.android.TEST_MENU true >/dev/null
  for _ in {1..20}; do
    dump_tree
    grep -Fq 'text="Return to KartPad Menu"' "$tree" && return 0
    sleep 1
  done
  echo "ERROR: KartPad menu did not open" >&2
  return 1
}

assert_labels() {
  python3 - "$tree" "$@" <<'PY'
import sys
import xml.etree.ElementTree as ET

tree, *expected = sys.argv[1:]
actual = {
    node.attrib.get("text", "")
    for node in ET.parse(tree).getroot().iter("node")
    if node.attrib.get("text")
}
missing = [label for label in expected if label not in actual]
if missing:
    raise SystemExit(f"ERROR: menu labels missing: {missing}; visible={sorted(actual)}")
PY
}

assert_checked_label() {
  python3 - "$tree" "$1" "${2:-true}" <<'PY'
import sys
import xml.etree.ElementTree as ET

tree, expected, checked = sys.argv[1:]
for node in ET.parse(tree).getroot().iter("node"):
    if node.attrib.get("text") == expected:
        if node.attrib.get("checked") != checked:
            raise SystemExit(f"ERROR: {expected!r} was not selected after relaunch")
        break
else:
    raise SystemExit(f"ERROR: selected label {expected!r} missing after relaunch")
PY
}

scroll_to_labels() {
  for _ in {1..8}; do
    if assert_labels "$@" 2>/dev/null; then return 0; fi
    "$adb" shell input swipe \
      "${scroll_x:-$((expected_width / 2))}" "$((expected_height * 3 / 4))" \
      "${scroll_x:-$((expected_width / 2))}" "$((expected_height / 4))" 300
    dump_tree
  done
  assert_labels "$@"
}

# The in-game menu is a card at the right edge; a swipe over the game closes it.
menu_scroll_to_labels() {
  scroll_x=$((expected_width - 400)) scroll_to_labels "$@"
}

assert_icon_count() {
  local expected="$1"
  local actual
  actual="$(python3 - "$tree" <<'PY'
import sys
import xml.etree.ElementTree as ET

print(sum(
    node.attrib.get("class") == "android.widget.ImageView"
    for node in ET.parse(sys.argv[1]).getroot().iter("node")
))
PY
)"
  [[ "$actual" == "$expected" ]] || {
    echo "ERROR: visible menu icon count $actual != $expected" >&2
    exit 1
  }
}

tap_label() {
  local label="$1"
  local coordinates
  coordinates="$(python3 - "$tree" "$label" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

tree, expected = sys.argv[1:]
for node in ET.parse(tree).getroot().iter("node"):
    if node.attrib.get("text") == expected:
        left, top, right, bottom = map(int, re.findall(r"\d+", node.attrib["bounds"]))
        print((left + right) // 2, (top + bottom) // 2)
        break
else:
    raise SystemExit(f"ERROR: cannot tap missing menu label {expected!r}")
PY
)"
  read -r x y <<<"$coordinates"
  "$adb" shell input tap "$x" "$y"
}

open_top_action() {
  start_menu
  menu_scroll_to_labels "$1"
  tap_label "$1"
  sleep 1
  dump_tree
}

open_submenu_action() {
  start_menu
  tap_label "$1"
  sleep 1
  dump_tree
  menu_scroll_to_labels "$2"
  tap_label "$2"
  sleep 1
  dump_tree
}

top=(
  "KartPad"
  "Return to KartPad Menu"
  "Multiplayer…"
  "Controls"
  "Speed & Graphics"
  "Display"
  "Game Data & Saves"
)

start_menu
assert_labels "${top[@]}"
assert_icon_count "$long_page_icons"
# Sound… pushed the last row below the fold on a 2400x1080 phone.
menu_scroll_to_labels "Report a Problem…"

start_menu
tap_label "Controls"
sleep 1
dump_tree
assert_labels \
  "Controller Player Setup…" \
  "Controller Button Mapping…" \
  "Touch Control Settings…" \
  "Shake to Trick…" \
  "Motion Steering…" \
  "Experimental Wii Remote + Nunchuk…"
assert_icon_count 6

start_menu
tap_label "Display"
sleep 1
dump_tree
assert_labels "Show FPS Counter" "FPS Counter Size" "Aspect Ratio" "Render Resolution"
menu_scroll_to_labels "Disable Bloom"
tap_label "Disable Bloom"
dump_tree
grep -Fq 'content-desc="Disable Bloom, on"' "$tree"
tap_label "Disable Bloom"
dump_tree
grep -Fq 'content-desc="Disable Bloom, off"' "$tree"
menu_scroll_to_labels "App Icon"

start_menu
tap_label "Speed & Graphics"
sleep 1
dump_tree
assert_labels "Speed" "Best Quality" "Recommended for This Phone" "30 FPS Races" "Simpler Computer Karts"
# The Speed presets write the two switches, and Speed reads Custom when they match none.
tap_label "Speed"
sleep 1
dump_tree
tap_label $'Smoothest\n30 FPS races and simpler computer karts. For phones that slow down in races.'
sleep 1
dump_tree
grep -Fq 'content-desc="Speed, Smoothest"' "$tree"
grep -Fq 'content-desc="30 FPS Races, on"' "$tree"
grep -Fq 'content-desc="Simpler Computer Karts, on"' "$tree"
tap_label "Simpler Computer Karts"
sleep 1
dump_tree
grep -Fq 'content-desc="Speed, Custom"' "$tree"
tap_label "Speed"
sleep 1
dump_tree
tap_label $'Best Quality\n60 FPS races with full-detail computer karts.'
sleep 1
dump_tree
grep -Fq 'content-desc="Speed, Best Quality"' "$tree"
grep -Fq 'content-desc="30 FPS Races, off"' "$tree"
grep -Fq 'content-desc="Simpler Computer Karts, off"' "$tree"
# 120 FPS Races shows only while the Beta engine runs, which the fixture doesn't.
menu_scroll_to_labels "Graphics Diagnostics…"

start_menu
tap_label "Game Data & Saves"
sleep 1
dump_tree
assert_labels \
  "Import or Reimport Wii Disc Image…" \
  "Import from Extracted Folder…" \
  "Manage Retro Rewind…" \
  "Manage Saves…" \
  "Player Identity…"
assert_icon_count "$long_page_icons"
menu_scroll_to_labels "Remove Stored Game Data…"

open_top_action "Return to KartPad Menu"
assert_labels "Mario Kart Wii" "Paused" "Resume Game  →" "Retro Rewind" "Next launch" "Use on Next Launch  →"

open_top_action "Multiplayer…"
assert_labels "Multiplayer" "Local Split-Screen…" "Controller Setup…" "Experimental Server Settings…" "BACK"

open_top_action "Report a Problem…"
assert_labels "Report a Problem" "Send to"
# The report is now a scrollable Activity, not the old three-button dialog.
for label in "Open GitHub Draft" "Share Report…" "Back to Game"; do
  scroll_to_labels "$label"
done

start_menu
tap_label "Display"
sleep 1
dump_tree
fps_before="$("$adb" exec-out run-as dev.kartpad.android \
  cat shared_prefs/kartpad_touch_controls.xml 2>/dev/null || true)"
if grep -Eq '<boolean name="show_fps" value="false"[[:space:]]*/>' \
    <<<"$fps_before"; then
  expected_fps_value=true
else
  expected_fps_value=false
fi
tap_label "Show FPS Counter"
sleep 1
fps_preferences="$("$adb" exec-out run-as dev.kartpad.android \
  cat shared_prefs/kartpad_touch_controls.xml)"
grep -Eq "<boolean name=\"show_fps\" value=\"$expected_fps_value\"[[:space:]]*/>" \
  <<<"$fps_preferences" || {
  echo "ERROR: Show FPS Counter did not persist the toggled state" >&2
  exit 1
}

open_submenu_action "Controls" "Controller Button Mapping…"
assert_labels "Controller Button Mapping" "A — ACCELERATE / CONFIRM — A"
scroll_to_labels "ZR — REAR VIEW — LEFT SHOULDER"
scroll_to_labels "RESET TO DEFAULT" "DONE"

open_submenu_action "Controls" "Touch Control Settings…"
assert_labels "Touch Control Settings" "Touch auto-accelerate"
auto_accelerate_before="$(python3 - "$tree" <<'PY'
import sys, xml.etree.ElementTree as ET
print(next(n.attrib['checked'] for n in ET.parse(sys.argv[1]).iter('node') if n.attrib.get('text') == 'Touch auto-accelerate'))
PY
)"
if [[ "$auto_accelerate_before" == true ]]; then tap_label "Touch auto-accelerate"; fi
# The switch saves with SharedPreferences.apply(); let it reach disk before the force-stop.
sleep 2
open_submenu_action "Controls" "Touch Control Settings…"
assert_checked_label "Touch auto-accelerate" false
"$adb" exec-out run-as dev.kartpad.android cat shared_prefs/kartpad_touch_controls.xml |
  grep -Eq '<boolean name="auto_accelerate" value="false"[[:space:]]*/>'
if [[ "$auto_accelerate_before" == true ]]; then tap_label "Touch auto-accelerate"; fi
scroll_to_labels "MOVE CONTROLS" "RESET THIS DEVICE LAYOUT"

open_submenu_action "Controls" "Motion Steering…"
assert_labels "Motion Steering" "CONTINUE PLAYING"

open_submenu_action "Controls" "Experimental Wii Remote + Nunchuk…"
assert_labels "Experimental Wii Remote + Nunchuk" "BACK"

open_submenu_action "Display" "Aspect Ratio"
assert_labels \
  "Aspect Ratio" \
  "Original 4:3" \
  "16:9 (Experimental)" \
  "Fill Screen (Experimental)"

open_submenu_action "Display" "Render Resolution"
assert_labels "Render Resolution" "1× (Native)" "1.5×" "2×" "3×" "4×"

open_submenu_action "Display" "FPS Counter Size"
assert_labels "FPS Counter Size" "Small" "Medium" "Large"
tap_label "Large"
sleep 1
fps_preferences="$("$adb" exec-out run-as dev.kartpad.android \
  cat shared_prefs/kartpad_touch_controls.xml)"
grep -Eq '<int name="fps_size" value="2"[[:space:]]*/>' <<<"$fps_preferences" || {
  echo "ERROR: FPS counter size did not persist Large" >&2
  exit 1
}
open_submenu_action "Display" "FPS Counter Size"
assert_checked_label "Large"

open_submenu_action "Game Data & Saves" "Remove Stored Game Data…"
assert_labels "Remove Stored Game Data?" "REMOVE" "CANCEL"

open_submenu_action "Game Data & Saves" "Import or Reimport Wii Disc Image…"
assert_labels "Game Data & Saves" "Disc-image import is unavailable in this build."

open_submenu_action "Game Data & Saves" "Import from Extracted Folder…"
if ! "$adb" shell dumpsys activity activities | grep -Eq \
    'topResumedActivity=.*com.google.android.documentsui'; then
  echo "ERROR: extracted-folder action did not reach Android DocumentsUI" >&2
  exit 1
fi

open_submenu_action "Game Data & Saves" "Manage Saves…"
assert_labels "Choose Save Profile" "Original Mario Kart Wii" "Retro Rewind" "Retro Rewind (Separate Save)"
tap_label "Original Mario Kart Wii"
dump_tree
assert_labels "Manage Saves • Original Mario Kart Wii"
scroll_to_labels "EXPORT SAVE BACKUP…" "RESTORE SAVE BACKUP…" "DONE"

open_submenu_action "Game Data & Saves" "Player Identity…"
assert_labels \
  "Player Identity" "Edit Mii Name…" "Rename or Delete Licenses…" "Mii Appearance…" \
  "BACK"

open_submenu_action "Game Data & Saves" "Manage Retro Rewind…"
retro_version="$(sed -nE 's/.*String VERSION = "([^"]+)";.*/\1/p' \
  "$repo_root/android/app/src/main/java/dev/kartpad/android/RetroRewindRelease.java")"
[[ -n "$retro_version" ]] || { echo "ERROR: missing pinned Retro Rewind version" >&2; exit 1; }
assert_labels "KartPad" "Retro Rewind $retro_version"

if [[ "$lane" == phone ]]; then
  "$adb" shell cmd window user-rotation free >/dev/null
  "$adb" shell settings put system accelerometer_rotation 1
  "$adb" emu sensor set acceleration 9.81:0:0 >/dev/null
  for _ in {1..20}; do
    dump_tree
    grep -Fq 'rotation="1"' "$tree" && break
    sleep 1
  done
  grep -Fq 'rotation="1"' "$tree" || {
    echo "ERROR: phone emulator did not restore canonical landscape" >&2
    exit 1
  }
  start_menu
  "$adb" logcat -c
  "$adb" emu sensor set acceleration -9.81:0:0 >/dev/null
  for _ in {1..20}; do
    dump_tree
    if grep -Fq 'rotation="3"' "$tree" &&
        ! grep -Fq 'content-desc="KartPad"' "$tree"; then
      break
    fi
    sleep 1
  done
  grep -Fq 'rotation="3"' "$tree" || {
    echo "ERROR: phone emulator did not enter opposite landscape" >&2
    exit 1
  }
  ! grep -Fq 'content-desc="KartPad"' "$tree" || {
    echo "ERROR: open menu survived a landscape configuration change" >&2
    exit 1
  }
  grep -Fq 'content-desc="Menu"' "$tree" || {
    echo "ERROR: menu trigger missing after landscape configuration change" >&2
    exit 1
  }
  "$adb" logcat -d -v brief KartPadFixture:I '*:S' | grep -Fq \
    'A4 menu inset transition passed neutral=0x0 owners=0' || {
    echo "ERROR: inset transition did not prove neutral touch state" >&2
    exit 1
  }
  start_menu
  insets="$artifact_root/window-insets.txt"
  "$adb" shell dumpsys window >"$insets"
  python3 - "$tree" "$insets" "$expected_width" <<'PY'
import re
import sys
import xml.etree.ElementTree as ET

tree_path, insets_path, width_text = sys.argv[1:]
width = int(width_text)
nodes = list(ET.parse(tree_path).getroot().iter("node"))

def bounds(node):
    return tuple(map(int, re.findall(r"\d+", node.attrib["bounds"])))

heading = next(node for node in nodes if node.attrib.get("content-desc") == "KartPad")
left, top, right, _ = bounds(heading)
# The menu scrolls, so measure the lowest row the card shows.
final_row = max((node for node in nodes if node.attrib.get("text") and bounds(node)[0] >= left),
                key=lambda node: bounds(node)[3])
_, _, _, bottom = bounds(final_row)
window = open(insets_path, encoding="utf-8").read()
cutout = re.search(
    r"mDisplayCutout=DisplayCutout\{insets=Rect\((\d+), (\d+) - (\d+), (\d+)\)",
    window,
)
status = re.search(r"type=statusBars frame=\[0,0\]\[\d+,(\d+)\]", window)
navigation = re.search(r"type=navigationBars frame=\[0,(\d+)\]", window)
if not (cutout and status and navigation):
    raise SystemExit("ERROR: could not parse opposite-landscape safe insets")
cutout_right = int(cutout.group(3))
status_bottom = int(status.group(1))
navigation_top = int(navigation.group(1))
if cutout_right <= 0:
    raise SystemExit("ERROR: opposite landscape did not place cutout on menu edge")
if top < status_bottom or width - right < cutout_right or bottom > navigation_top:
    raise SystemExit(
        "ERROR: menu crossed safe bounds: "
        f"card=[{left},{top}][{right},{bottom}] "
        f"status={status_bottom} cutoutRight={cutout_right} navigation={navigation_top}"
    )
print(
    "PASS: opposite-landscape menu safe bounds "
    f"card=[{left},{top}][{right},{bottom}] "
    f"status={status_bottom} cutoutRight={cutout_right} navigation={navigation_top}"
)
PY
fi

echo "Android menu parity passed: lane=$lane top=8 controls=5 display=6 graphics=3 data=7 actions=18 safe-insets=pass"
