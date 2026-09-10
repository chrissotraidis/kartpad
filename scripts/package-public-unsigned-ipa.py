#!/usr/bin/env python3
from __future__ import annotations

import argparse
import plistlib
import subprocess
import sys
from pathlib import Path


RELEASE_TAG = "v0.4.16-ios.1"
APP_VERSION = "0.4.16"
APP_BUILD = "35"


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Create the audited public KartPad unsigned community IPA."
    )
    parser.add_argument("app", type=Path, help="Path to the unsigned KartPad.app")
    parser.add_argument(
        "output",
        type=Path,
        nargs="?",
        help="Output IPA path (defaults to artifacts/KartPad-v0.4.16-ios.1-unsigned.ipa)",
    )
    args = parser.parse_args()

    repo = Path(__file__).resolve().parents[1]
    sys.path.insert(0, str(repo / "builder"))
    from kartpad_builder.packaging import audit_app, package_unsigned_ipa

    app = args.app.resolve()
    output = (
        args.output.resolve()
        if args.output
        else repo / "artifacts/KartPad-v0.4.16-ios.1-unsigned.ipa"
    )
    if subprocess.check_output(
        ["git", "-C", str(repo), "status", "--porcelain", "--untracked-files=all"],
        text=True,
    ).strip():
        fail("public IPA packaging requires a clean tracked source tree")
    source_commit = subprocess.check_output(
        ["git", "-C", str(repo), "rev-parse", "HEAD"], text=True
    ).strip()

    subprocess.run(
        [str(repo / "scripts/audit-ios-game-app.sh"), str(app), "IOS"], check=True
    )
    metadata = audit_app(app, (str(repo), str(Path.home())))
    with (app / "Info.plist").open("rb") as handle:
        plist = plistlib.load(handle)
    if plist.get("CFBundleShortVersionString") != APP_VERSION:
        fail(f"expected app version {APP_VERSION}")
    if str(plist.get("CFBundleVersion")) != APP_BUILD:
        fail(f"expected app build {APP_BUILD}")
    if subprocess.run(
        ["codesign", "--verify", "--strict", str(app)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0:
        fail("public IPA input app is still signed")

    xcode_build = app.parents[1]
    additional_entries = {
        "INSTALL_IPA.md": repo / "docs/INSTALL_IPA.md",
        "RELEASE_NOTES.md": repo / "docs/releases/v0.4.16-ios.1.md",
        "MULTIPLAYER.md": repo / "docs/MULTIPLAYER.md",
        "LICENSE": repo / "LICENSE",
        "LICENSES/GPL-3.0.txt": repo / "LICENSES/GPL-3.0.txt",
        "RIGHTS_AND_LICENSES.md": repo / "RIGHTS_AND_LICENSES.md",
        "THIRD_PARTY_NOTICES.md": repo / "THIRD_PARTY_NOTICES.md",
        "ThirdPartyLicenses/Abseil-Apache-2.0.txt": xcode_build / "_deps/abseil-cpp-src/LICENSE",
        "ThirdPartyLicenses/Aurora-MIT.txt": repo / "ref/upstream/Wiicompiled/aurora-main/LICENSE",
        "ThirdPartyLicenses/Dolphin-COPYING.txt": repo / "ref/upstream/dolphin/COPYING",
        "ThirdPartyLicenses/Dolphin-Externals.md": repo / "ref/upstream/dolphin/Externals/licenses.md",
        "ThirdPartyLicenses/FreeType.txt": xcode_build / "_deps/freetype-src/LICENSE.TXT",
        "ThirdPartyLicenses/Minizip-NG.txt": repo / "ref/upstream/dolphin/Externals/minizip-ng/minizip-ng/LICENSE",
        "ThirdPartyLicenses/SDL3-Zlib.txt": xcode_build / "_deps/sdl-src/LICENSE.txt",
        "ThirdPartyLicenses/Tracy-BSD-3-Clause.txt": xcode_build / "_deps/tracy-src/LICENSE",
        "ThirdPartyLicenses/WiiCompiled-GPL-3.0.txt": repo / "ref/upstream/Wiicompiled/LICENSE",
        "ThirdPartyLicenses/fmt-MIT.txt": xcode_build / "_deps/fmt-src/LICENSE",
        "ThirdPartyLicenses/imgui-MIT.txt": xcode_build / "_deps/imgui-src/LICENSE.txt",
        "ThirdPartyLicenses/libpng.txt": xcode_build / "_deps/png-src/LICENSE",
        "ThirdPartyLicenses/xxHash-BSD-2-Clause.txt": xcode_build / "_deps/xxhash-src/LICENSE",
        "ThirdPartyLicenses/zstd-BSD.txt": xcode_build / "_deps/zstd-src/LICENSE",
    }
    missing_notices = [name for name, path in additional_entries.items() if not path.is_file()]
    if missing_notices:
        fail(f"missing release notices: {', '.join(missing_notices)}")
    provenance = {
        "schemaVersion": 1,
        "releaseTag": RELEASE_TAG,
        "sourceCommit": source_commit,
        "appVersion": APP_VERSION,
        "appBuild": APP_BUILD,
        "bundleIdentifier": metadata["bundleIdentifier"],
        "executableSHA256": metadata["executableSHA256"],
        "containsTranslatedGameCode": True,
        "containsGameData": False,
        "containsSigningMaterial": False,
        "maintainerAuthorizedFreeCommunityRelease": True,
        "upstreamRightsConfirmed": False,
        "rightsStatus": "community release; upstream and game-code rights unresolved",
    }
    digest = package_unsigned_ipa(app, output, provenance, additional_entries)
    print(f"Public unsigned IPA: {output}")
    print(f"SHA-256: {digest}")
    print("This IPA must be re-signed and supplied with the user's own supported game image.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
