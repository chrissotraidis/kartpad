#!/usr/bin/env python3
"""Read-only APK/update identity check. Never installs, launches or clears data."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

PACKAGE = "dev.kartpad.android"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def run(*args):
    try:
        return subprocess.check_output([str(a) for a in args], stderr=subprocess.DEVNULL,
                                       timeout=120, text=True).strip()
    except (OSError, subprocess.SubprocessError):
        # Do not echo ADB serials, installed paths or unreviewed device output.
        raise ValueError("Inspection command failed; no device changes were attempted.") from None


def digest(path):
    value = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(block)
    return value.hexdigest()


def apk_info(path, build_tools):
    badging = run(build_tools / "aapt2", "dump", "badging", path)
    package_line = re.search(r"^package: (.+)$", badging, re.M)
    require(package_line is not None, "APK package metadata is missing.")
    fields = dict(re.findall(r"(\w+)='([^']*)'", package_line[1]))
    require(fields.get("name") == PACKAGE, "APK package is not KartPad.")
    require(fields.get("versionCode", "").isdigit(), "APK version code is invalid.")
    signed = run(build_tools / "apksigner", "verify", "--print-certs", path)
    certs = re.findall(r"^Signer #\d+ certificate SHA-256 digest: ([0-9a-fA-F]{64})$", signed, re.M)
    require(len(certs) == 1, "Expected exactly one verified APK signer.")
    sdk = re.search(r"^(?:minSdkVersion|sdkVersion):'(\d+)'$", badging, re.M)
    require(sdk is not None, "APK minimum API is missing.")
    return dict(package=PACKAGE, version_code=int(fields["versionCode"]),
                version_name=fields.get("versionName", ""), certificate_sha256=certs[0].lower(),
                sha256=digest(path), minimum_api=int(sdk[1]),
                arm64_only="native-code: 'arm64-v8a'" in badging.splitlines(),
                debuggable="application-debuggable" in badging)


def compare(candidate, installed):
    require(candidate["package"] == installed["package"], "Package mismatch.")
    require(candidate["certificate_sha256"] == installed["certificate_sha256"],
            "Signing certificate mismatch. Keep the existing app; do not uninstall or clear storage.")
    if candidate["sha256"] == installed["sha256"]:
        return "same_artifact"
    require(candidate["version_code"] > installed["version_code"],
            "Candidate is not a forward version update. Keep the installed app.")
    return "forward_update_identity_matches"


def device_target(adb):
    rows = [line.split() for line in run(adb, "devices").splitlines()[1:] if line.strip()]
    require(len(rows) == 1 and len(rows[0]) >= 2 and rows[0][1] == "device",
            "Connect exactly one authorized Android phone; no device changes were attempted.")
    return rows[0][0]


def connected_check(candidate, sdk, build_tools):
    adb = sdk / "platform-tools/adb"
    serial = device_target(adb)

    def shell(*args):
        return run(adb, "-s", serial, "shell", *args)

    require(shell("getprop", "ro.kernel.qemu") != "1", "An emulator is not phone acceptance.")
    api = shell("getprop", "ro.build.version.sdk")
    require(api.isdigit() and int(api) >= candidate["minimum_api"], "Phone API is unsupported.")
    require(shell("getprop", "ro.product.cpu.abi") == "arm64-v8a", "Phone ABI is unsupported.")
    packages = shell("pm", "list", "packages", PACKAGE).splitlines()
    if "package:" + PACKAGE not in packages:
        return "package_not_installed", None
    paths = shell("pm", "path", PACKAGE).splitlines()
    bases = [p[len("package:"):] for p in paths if p.startswith("package:/") and p.endswith("/base.apk")]
    require(len(bases) == 1, "Cannot identify the installed base APK; stop before installation.")
    with tempfile.TemporaryDirectory(prefix="kartpad-apk-inspection-") as tmp:
        installed_path = Path(tmp) / "installed.apk"
        run(adb, "-s", serial, "pull", bases[0], installed_path)
        installed = apk_info(installed_path, build_tools)
    return compare(candidate, installed), installed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    parser.add_argument("--sha256", required=True, help="Digest from the reviewed artifact evidence")
    target = parser.add_mutually_exclusive_group(required=True)
    target.add_argument("--installed-apk", type=Path, help="Offline comparison; does not inspect a phone")
    target.add_argument("--connected", action="store_true", help="Read the sole connected physical phone")
    args = parser.parse_args()
    sdk = Path(os.environ.get("ANDROID_SDK_ROOT", os.environ.get("ANDROID_HOME", str(Path.home()/"Library/Android/sdk"))))
    build_tools = sdk / "build-tools/36.0.0"
    try:
        require(re.fullmatch(r"[0-9a-fA-F]{64}", args.sha256) is not None, "Expected digest is invalid.")
        require(digest(args.apk) == args.sha256.lower(), "Candidate differs from the reviewed APK.")
        candidate = apk_info(args.apk, build_tools)
        require(candidate["arm64_only"] and not candidate["debuggable"], "Expected non-debuggable ARM64 candidate.")
        if args.installed_apk:
            installed = apk_info(args.installed_apk, build_tools)
            status = compare(candidate, installed)
        else:
            status, installed = connected_check(candidate, sdk, build_tools)
        print(json.dumps(dict(status=status, candidate=candidate, installed=installed,
                              connected_phone_checked=args.connected, device_changed=False), indent=2))
        print("Identity checks only: preserve/export saves before updating. Start with Character Graphics Test: Normal and Renderer Validation: Off. Gameplay and driver support remain unverified.", file=sys.stderr)
    except (ValueError, OSError) as error:
        message = str(error) if isinstance(error, ValueError) else "APK could not be read."
        parser.exit(1, "STOP: " + message + "\n")


if __name__ == "__main__":
    main()
