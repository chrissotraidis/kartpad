"""Exercise shake input in a disposable, already-installed Android debug fixture.

Usage: python3 scripts/test-android-shake-tricks.py emulator-5580
Build/install the fixture first. Changes its shake preference and restarts it;
never targets a physical phone. Tests real sensor events, UI and input release.
"""
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

if len(sys.argv) != 2 or not re.fullmatch(r"emulator-\d+", sys.argv[1]):
    sys.exit("Pass a disposable emulator serial, for example emulator-5580")
SERIAL = sys.argv[1]
SDK = Path(os.environ.get("ANDROID_SDK_ROOT", str(Path.home() / "Library/Android/sdk")))
ADB = str(SDK / "platform-tools/adb")


def run(*args):
    return subprocess.check_output([ADB, "-s", SERIAL, *args], text=True)


def nodes():
    run("shell", "uiautomator", "dump", "/sdcard/triage-ui.xml")
    return list(ET.fromstring(run("exec-out", "cat", "/sdcard/triage-ui.xml")).iter("node"))


def tap(label):
    current = nodes()
    hits = [n for n in current if label in (n.get("text"), n.get("content-desc"))]
    assert hits, (label, [(n.get("text"), n.get("content-desc")) for n in current])
    node = next((n for n in hits if n.get("clickable") == "true"), hits[0])
    x, y, x2, y2 = map(int, re.findall(r"\d+", node.get("bounds")))
    run("shell", "input", "tap", str((x + x2) // 2), str((y + y2) // 2))


def enabled():
    switch = next(n for n in nodes() if n.get("class") == "android.widget.Switch")
    return switch.get("checked") == "true"


def shake():
    run("emu", "sensor", "set", "acceleration", "0:9.8:0.2")
    time.sleep(1)
    run("emu", "sensor", "set", "acceleration", "0:35:0.2")
    time.sleep(.18)
    run("emu", "sensor", "set", "acceleration", "0:9.8:0.2")
    time.sleep(1)


def restart():
    run("shell", "am", "force-stop", "dev.kartpad.android")
    run("shell", "am", "start", "-W", "-n", "dev.kartpad.android/.KartPadActivity",
        "--ez", "dev.kartpad.android.TEST_MENU", "true",
        "--ez", "dev.kartpad.android.TEST_TOUCH_OVERLAY", "true")
    time.sleep(1.2)


def logs():
    return run("logcat", "-d", "-v", "brief", "KartPadMotion:D", "*:S")


restart()
tap("Controls")
tap("Shake to Trick…")
if not enabled():
    tap("Shake to Trick")
tap("CONTINUE PLAYING")
restart()
# An open native menu must suppress an enabled gesture.
run("logcat", "-c")
shake()
assert "shake pressed" not in logs()
tap("Controls")
tap("Shake to Trick…")
assert enabled(), "Enabled state did not survive relaunch"
tap("CONTINUE PLAYING")
run("logcat", "-c")
shake()
result = logs()
print(result)
assert "shake pressed buttons=1" in result and "shake released buttons=0" in result
# Turn off through Controls, verify no sensor-triggered input and persistence.
restart()
tap("Controls")
tap("Shake to Trick…")
tap("Shake to Trick")
assert not enabled()
tap("CONTINUE PLAYING")
run("logcat", "-c")
shake()
assert "shake pressed" not in logs()
restart()
tap("Controls")
tap("Shake to Trick…")
assert not enabled(), "Disabled state did not survive relaunch"
print("PASS: Controls placement, persistence on/off, actual sensor pulse/release, "
      "menu suppression, and disabled gesture")
