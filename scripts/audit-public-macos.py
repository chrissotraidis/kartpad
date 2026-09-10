#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import posixpath
import plistlib
import stat
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


RELEASE_TAG = "v0.4.16-macos.1"
APP_VERSION = "0.4.16"
APP_BUILD = "35"
FORBIDDEN_SUFFIXES = {".iso", ".wbfs", ".rvz", ".wia", ".gcz", ".gcm", ".ciso",
                      ".sav", ".p12", ".p8", ".pem", ".key", ".cer"}
REQUIRED_ENTRIES = {
    "KartPad.app/Contents/Info.plist",
    "KartPad.app/Contents/MacOS/KartPad",
    "KartPadMacProvenance.json",
    "INSTALL_MACOS.md",
    "RELEASE_NOTES.md",
    "LICENSE",
    "LICENSES/GPL-3.0.txt",
    "RIGHTS_AND_LICENSES.md",
    "ThirdPartyLicenses/Aurora-MIT.txt",
    "ThirdPartyLicenses/WiiCompiled-GPL-3.0.txt",
    "ThirdPartyLicenses/Abseil-Apache-2.0.txt",
    "ThirdPartyLicenses/FreeType.txt",
    "ThirdPartyLicenses/SDL3-Zlib.txt",
    "ThirdPartyLicenses/Tracy-BSD-3-Clause.txt",
    "ThirdPartyLicenses/fmt-MIT.txt",
    "ThirdPartyLicenses/imgui-MIT.txt",
    "ThirdPartyLicenses/libpng.txt",
    "ThirdPartyLicenses/xxHash-BSD-2-Clause.txt",
    "ThirdPartyLicenses/zstd-BSD.txt",
}
EXPECTED_SYMLINKS = {
    "KartPad.app/Contents/MacOS/build-fingerprint.json":
        "../Resources/Runtime/build-fingerprint.json",
    "KartPad.app/Contents/MacOS/dsp_coef.bin":
        "../Resources/Runtime/dsp_coef.bin",
    "KartPad.app/Contents/MacOS/wii_bootstrap":
        "../Resources/Runtime/wii_bootstrap",
}


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: public macOS audit failed: {message}")


def extract_unix_archive(archive: zipfile.ZipFile, root: Path) -> None:
    for info in archive.infolist():
        destination = root / info.filename
        unix_mode = info.external_attr >> 16
        if info.is_dir():
            destination.mkdir(parents=True, exist_ok=True)
            destination.chmod(stat.S_IMODE(unix_mode))
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        if stat.S_ISLNK(unix_mode):
            target = archive.read(info).decode()
            expected = EXPECTED_SYMLINKS.get(info.filename)
            if target != expected:
                fail(f"unexpected symlink: {info.filename} -> {target}")
            normalized = posixpath.normpath(
                posixpath.join(posixpath.dirname(info.filename), target))
            if normalized.startswith("../") or normalized == "..":
                fail(f"symlink escapes archive: {info.filename}")
            os.symlink(target, destination)
            continue
        destination.write_bytes(archive.read(info))
        destination.chmod(stat.S_IMODE(unix_mode))


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit the exact public KartPad macOS ZIP.")
    parser.add_argument("archive", type=Path)
    parser.add_argument("--source-commit")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    archive_path = args.archive.resolve()
    expected_commit = args.source_commit or subprocess.check_output(
        ["git", "-C", str(repo), "rev-parse", "HEAD"], text=True
    ).strip()
    with zipfile.ZipFile(archive_path) as archive:
        if archive.testzip() is not None:
            fail("ZIP integrity failure")
        names = archive.namelist()
        missing = REQUIRED_ENTRIES - set(names)
        if missing:
            fail(f"missing required entries: {', '.join(sorted(missing))}")
        for name in names:
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts or "__MACOSX" in path.parts:
                fail(f"unsafe archive path: {name}")
            if Path(name.lower()).suffix in FORBIDDEN_SUFFIXES:
                fail(f"forbidden private or signing file: {name}")
            if "UserData" in path.parts or path.name in {"portable.txt", "Config.toml"}:
                fail(f"writable runtime state found: {name}")
        provenance = json.loads(archive.read("KartPadMacProvenance.json"))
        expected = {
            "releaseTag": RELEASE_TAG, "sourceCommit": expected_commit,
            "appVersion": APP_VERSION, "appBuild": APP_BUILD,
            "containsTranslatedGameCode": True, "containsGameData": False,
            "containsSigningMaterial": False, "signing": "ad-hoc",
            "maintainerAuthorizedFreeCommunityRelease": True,
            "upstreamRightsConfirmed": False,
        }
        for key, value in expected.items():
            if provenance.get(key) != value:
                fail(f"unexpected provenance {key}: {provenance.get(key)!r}")
        with tempfile.TemporaryDirectory(prefix="kartpad-public-macos-audit.") as temp:
            root = Path(temp)
            extract_unix_archive(archive, root)
            if set(EXPECTED_SYMLINKS) - set(names):
                fail("archive lacks required runtime-resource symlinks")
            app = root / "KartPad.app"
            subprocess.run([str(repo / "scripts/audit-macos-package.sh"), str(app)], check=True)
            with (app / "Contents/Info.plist").open("rb") as handle:
                plist = plistlib.load(handle)
            if plist.get("CFBundleShortVersionString") != APP_VERSION or str(plist.get("CFBundleVersion")) != APP_BUILD:
                fail("unexpected app version")
            executable = app / "Contents/MacOS/KartPad"
            if hashlib.sha256(executable.read_bytes()).hexdigest() != provenance["executableSHA256"]:
                fail("executable hash does not match provenance")
    digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    print(f"Public macOS ZIP audit passed: {archive_path}")
    print(f"Release: {RELEASE_TAG}; app: {APP_VERSION} ({APP_BUILD}); source: {expected_commit}")
    print(f"SHA-256: {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
