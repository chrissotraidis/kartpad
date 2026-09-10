#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import plistlib
import re
import subprocess
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


RELEASE_TAG = "v0.4.16-ios.1"
APP_VERSION = "0.4.16"
APP_BUILD = "35"
FORBIDDEN_SUFFIXES = {
    ".iso", ".gcm", ".gcz", ".ciso", ".wbfs", ".wia", ".rvz",
    ".gci", ".sav", ".log", ".mobileprovision", ".p12", ".p8",
    ".pem", ".key", ".cer",
}
REQUIRED_ENTRIES = {
    "Payload/KartPad.app/KartPad",
    "Payload/KartPad.app/Info.plist",
    "KartPadBuilderProvenance.json",
    "INSTALL_IPA.md",
    "RELEASE_NOTES.md",
    "LICENSES/GPL-3.0.txt",
    "RIGHTS_AND_LICENSES.md",
    "THIRD_PARTY_NOTICES.md",
    "ThirdPartyLicenses/Aurora-MIT.txt",
    "ThirdPartyLicenses/Dolphin-COPYING.txt",
    "ThirdPartyLicenses/Minizip-NG.txt",
    "ThirdPartyLicenses/SDL3-Zlib.txt",
    "ThirdPartyLicenses/WiiCompiled-GPL-3.0.txt",
}
ALLOWED_EMBEDDED_USER_PATH_PREFIXES = (
    b"/Users/runner/work/dawn-build/dawn-build/",
)


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: public IPA audit failed: {message}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit the exact public KartPad IPA.")
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--source-commit", help="Expected release commit")
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    ipa = args.ipa.resolve()
    if not ipa.is_file():
        fail(f"IPA not found: {ipa}")
    expected_commit = args.source_commit or subprocess.check_output(
        ["git", "-C", str(repo), "rev-parse", "HEAD"], text=True
    ).strip()

    with zipfile.ZipFile(ipa) as archive:
        bad_member = archive.testzip()
        if bad_member is not None:
            fail(f"ZIP integrity failure at {bad_member}")
        names = archive.namelist()
        name_set = set(names)
        missing = sorted(REQUIRED_ENTRIES - name_set)
        if missing:
            fail(f"missing required entries: {', '.join(missing)}")
        for name in names:
            path = PurePosixPath(name)
            if path.is_absolute() or ".." in path.parts or "__MACOSX" in path.parts:
                fail(f"unsafe archive path: {name}")
            lowered = name.lower()
            if Path(lowered).suffix in FORBIDDEN_SUFFIXES:
                fail(f"forbidden private or signing file: {name}")
            if "_codesignature" in path.parts or path.name == "embedded.mobileprovision":
                fail(f"signing residue found: {name}")
        app_roots = {
            "/".join(PurePosixPath(name).parts[:2])
            for name in names
            if len(PurePosixPath(name).parts) >= 2
            and PurePosixPath(name).parts[0] == "Payload"
            and PurePosixPath(name).parts[1].endswith(".app")
        }
        if app_roots != {"Payload/KartPad.app"}:
            fail("IPA must contain exactly one KartPad.app")

        import json

        provenance = json.loads(archive.read("KartPadBuilderProvenance.json"))
        expected_provenance = {
            "releaseTag": RELEASE_TAG,
            "sourceCommit": expected_commit,
            "appVersion": APP_VERSION,
            "appBuild": APP_BUILD,
            "containsTranslatedGameCode": True,
            "containsGameData": False,
            "containsSigningMaterial": False,
            "maintainerAuthorizedFreeCommunityRelease": True,
            "upstreamRightsConfirmed": False,
        }
        for key, expected in expected_provenance.items():
            if provenance.get(key) != expected:
                fail(f"unexpected provenance {key}: {provenance.get(key)!r}")

        with tempfile.TemporaryDirectory(prefix="kartpad-public-ipa-audit.") as temp:
            root = Path(temp)
            archive.extractall(root)
            for info in archive.infolist():
                mode = (info.external_attr >> 16) & 0o777
                extracted = root / info.filename
                if mode and extracted.is_file():
                    extracted.chmod(mode)
            app = root / "Payload/KartPad.app"
            subprocess.run(
                [str(repo / "scripts/audit-ios-game-app.sh"), str(app), "IOS"],
                check=True,
            )
            with (app / "Info.plist").open("rb") as handle:
                plist = plistlib.load(handle)
            if plist.get("CFBundleShortVersionString") != APP_VERSION:
                fail("unexpected CFBundleShortVersionString")
            if str(plist.get("CFBundleVersion")) != APP_BUILD:
                fail("unexpected CFBundleVersion")
            if subprocess.run(
                ["codesign", "--verify", "--strict", str(app)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            ).returncode == 0:
                fail("app is unexpectedly signed")
            binary = (app / "KartPad").read_bytes()
            if re.search(rb"/Volumes/|github_pat_|gh[pousr]_|AKIA[0-9A-Z]{16}", binary):
                fail("app executable exposes a private path or likely credential")
            for match in re.finditer(rb"/Users/", binary):
                if not any(
                    binary.startswith(prefix, match.start())
                    for prefix in ALLOWED_EMBEDDED_USER_PATH_PREFIXES
                ):
                    fail("app executable exposes a private user path")
            if hashlib.sha256(binary).hexdigest() != provenance.get("executableSHA256"):
                fail("executable hash does not match provenance")

    digest = hashlib.sha256(ipa.read_bytes()).hexdigest()
    print(f"Public unsigned IPA audit passed: {ipa}")
    print(f"Release: {RELEASE_TAG}; app: {APP_VERSION} ({APP_BUILD}); source: {expected_commit}")
    print(f"SHA-256: {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
