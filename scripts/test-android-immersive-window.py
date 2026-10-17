#!/usr/bin/env python3
"""Check SDL startup/resume/bar-rehide on an emulator with a built fixture APK.

Build with scripts/build-android-fixture.sh, then pass SERIAL and APK.
This installs the fixture over the emulator's existing debug-signed KartPad.
"""
import os
from pathlib import Path
import re
import subprocess
import sys
import time


def main():
    if len(sys.argv) != 3 or not re.fullmatch(r"emulator-\d+", sys.argv[1]):
        raise SystemExit("Usage: test-android-immersive-window.py emulator-PORT FIXTURE.apk")
    sdk = Path(os.environ.get("ANDROID_SDK_ROOT", Path.home() / "Library/Android/sdk"))
    adb = [str(sdk / "platform-tools/adb"), "-s", sys.argv[1]]

    def run(*args):
        return subprocess.check_output([*adb, *args], text=True)

    if run("shell", "getprop", "ro.kernel.qemu").strip() != "1":
        raise SystemExit("Refusing to modify a physical device")
    run("install", "-r", sys.argv[2])
    run("shell", "am", "force-stop", "dev.kartpad.android")
    activity = "dev.kartpad.android/.KartPadActivity"
    run("shell", "am", "start", "-W", "-n", activity,
        "--ez", "dev.kartpad.android.TEST_TOUCH_OVERLAY", "true")

    def check(label):
        # Let native SDL_CreateWindow's queued style command reach the UI thread.
        time.sleep(4)
        dump = run("shell", "dumpsys", "window", "windows")
        windows = re.split(r"\n  Window #", dump)
        window = next((w for w in windows
                       if "KartPadActivity}:" in w.splitlines()[0]
                       and "ty=BASE_APPLICATION" in w), None)
        assert window is not None, f"{label}: game Activity has no application window"
        flags = re.search(r"\n\s+fl=([^\n]+)", window)[1].split()
        assert "FULLSCREEN" in flags and "FORCE_NOT_FULLSCREEN" not in flags, (label, flags)
        ui = re.search(r"\n\s+vsysui=([^\n]+)", window)[1].split()
        assert {"FULLSCREEN", "HIDE_NAVIGATION", "IMMERSIVE_STICKY"} <= set(ui), (label, ui)
        print(f"PASS immersive window: {label}", flush=True)

    check("cold launch")
    run("shell", "input", "keyevent", "KEYCODE_HOME")
    time.sleep(1)
    run("shell", "am", "start", "-W", "-n", activity)
    check("resume")
    run("shell", "input", "swipe", "100", "0", "100", "100", "150")
    check("system-bar swipe")


if __name__ == "__main__":
    main()
