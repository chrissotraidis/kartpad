#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
adb="$sdk_root/platform-tools/adb"
lane="${1:-phone}"
case "$lane" in
  phone) user_rotation=1; expected_width=2400; expected_height=1080 ;;
  tablet) user_rotation=0; expected_width=2560; expected_height=1600 ;;
  *) echo "ERROR: lane must be phone or tablet" >&2; exit 64 ;;
esac

restore_orientation() {
  [[ "$lane" == phone ]] || return 0
  "$adb" emu sensor set acceleration 9.81:0:0 >/dev/null 2>&1 || true
  "$adb" shell settings put system accelerometer_rotation 0 >/dev/null 2>&1 || true
  "$adb" shell settings put system user_rotation 1 >/dev/null 2>&1 || true
}
trap restore_orientation EXIT

device_count="$("$adb" devices | sed -n '2,$p' | grep -c '[[:space:]]device$' || true)"
[[ "$device_count" == 1 ]] || {
  echo "ERROR: expected exactly one connected Android emulator/device" >&2
  exit 1
}

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
    grep -Fq 'text="Switch Game Version…"' "$tree" && return 0
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
  tap_label "$1"
  sleep 1
  dump_tree
}

open_submenu_action() {
  start_menu
  tap_label "$1"
  sleep 1
  dump_tree
  tap_label "$2"
  sleep 1
  dump_tree
}

top=(
  "KartPad"
  "Switch Game Version…"
  "Multiplayer…"
  "Show FPS Counter"
  "Controls"
  "Display"
  "Game Data & Saves"
  "Report a Problem…"
)

start_menu
assert_labels "${top[@]}"
assert_icon_count 7

start_menu
tap_label "Controls"
sleep 1
dump_tree
assert_labels \
  "Controller Player Setup…" \
  "Controller Button Mapping…" \
  "Touch Control Settings…" \
  "Motion Steering…" \
  "Experimental Wii Remote + Nunchuk…"
assert_icon_count 5

start_menu
tap_label "Display"
sleep 1
dump_tree
assert_labels "Aspect Ratio…" "Render Resolution…"
assert_icon_count 2

start_menu
tap_label "Game Data & Saves"
sleep 1
dump_tree
assert_labels \
  "Import or Reimport Wii Disc Image…" \
  "Import from Extracted Folder…" \
  "Remove Stored Game Data…" \
  "Manage Retro Rewind…" \
  "Manage Saves…" \
  "Manage Miis…"
assert_icon_count 6

open_top_action "Switch Game Version…"
assert_labels "Switch Game Version" "RESTART TO SELECTOR" "CANCEL"

open_top_action "Multiplayer…"
assert_labels "Multiplayer" "SET UP RETRO REWIND" "BACK"

open_top_action "Report a Problem…"
assert_labels "Report a Problem" "SHARE REPORT…" "REPORT ON GITHUB" "CANCEL"

start_menu
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
assert_labels "Controller Button Mapping" "A — A" "Z — LEFT SHOULDER"
"$adb" shell input swipe \
  "$((expected_width / 2))" "$((expected_height * 3 / 4))" \
  "$((expected_width / 2))" "$((expected_height / 4))" 300
sleep 1
dump_tree
assert_labels "RESET TO DEFAULT" "DONE"

open_submenu_action "Controls" "Touch Control Settings…"
assert_labels "Touch Control Settings" "MOVE CONTROLS" "RESET THIS DEVICE LAYOUT"

open_submenu_action "Controls" "Motion Steering…"
assert_labels "Motion Steering" "CONTINUE PLAYING"

open_submenu_action "Controls" "Experimental Wii Remote + Nunchuk…"
assert_labels "Experimental Wii Remote + Nunchuk" "BACK"

open_submenu_action "Display" "Aspect Ratio…"
assert_labels \
  "Aspect Ratio" \
  "Original 4:3" \
  "16:9 (Experimental)" \
  "Fill Screen (Experimental)"

open_submenu_action "Display" "Render Resolution…"
assert_labels "Render Resolution" "1× (Native)" "2×" "3×" "4×"

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
assert_labels "Manage Saves" "EXPORT SAVE BACKUP…" "RESTORE SAVE BACKUP…" "DONE"

open_submenu_action "Game Data & Saves" "Manage Miis…"
assert_labels \
  "Manage Miis (Experimental)" \
  "BACK"

open_submenu_action "Game Data & Saves" "Manage Retro Rewind…"
assert_labels "KartPad" "Retro Rewind 6.12.5"

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
final_row = next(node for node in nodes if node.attrib.get("text") == "Report a Problem…")
left, top, right, _ = bounds(heading)
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

echo "Android menu parity passed: lane=$lane top=8 controls=5 display=2 data=6 actions=16 safe-insets=pass"
