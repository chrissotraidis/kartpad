#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import plistlib
import stat
import subprocess
import zipfile
from pathlib import Path


RELEASE_TAG = "v0.4.16-macos.1"
APP_VERSION = "0.4.16"
APP_BUILD = "35"
ZIP_TIMESTAMP = (2020, 1, 1, 0, 0, 0)


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Package the public KartPad macOS app.")
    parser.add_argument("app", type=Path)
    parser.add_argument("output", type=Path, nargs="?")
    parser.add_argument("--runtime-build", type=Path, required=True,
                        help="Exact runtime build containing pinned dependency notices")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    app = args.app.resolve()
    output = (args.output.resolve() if args.output else
              repo / "artifacts/KartPad-v0.4.16-macos.1-arm64.zip")
    if subprocess.check_output(
        ["git", "-C", str(repo), "status", "--porcelain", "--untracked-files=all"],
        text=True,
    ).strip():
        fail("public macOS packaging requires a clean tracked source tree")
    subprocess.run([str(repo / "scripts/audit-macos-package.sh"), str(app)], check=True)
    with (app / "Contents/Info.plist").open("rb") as handle:
        plist = plistlib.load(handle)
    if plist.get("CFBundleShortVersionString") != APP_VERSION:
        fail(f"expected app version {APP_VERSION}")
    if str(plist.get("CFBundleVersion")) != APP_BUILD:
        fail(f"expected app build {APP_BUILD}")
    source_commit = subprocess.check_output(
        ["git", "-C", str(repo), "rev-parse", "HEAD"], text=True
    ).strip()
    executable = app / "Contents/MacOS/KartPad"
    provenance = {
        "schemaVersion": 1,
        "releaseTag": RELEASE_TAG,
        "sourceCommit": source_commit,
        "appVersion": APP_VERSION,
        "appBuild": APP_BUILD,
        "bundleIdentifier": "dev.kartpad.app",
        "executableSHA256": hashlib.sha256(executable.read_bytes()).hexdigest(),
        "containsTranslatedGameCode": True,
        "containsGameData": False,
        "containsSigningMaterial": False,
        "signing": "ad-hoc",
        "maintainerAuthorizedFreeCommunityRelease": True,
        "upstreamRightsConfirmed": False,
        "rightsStatus": "community release; upstream and game-code rights unresolved",
    }
    extras = {
        "INSTALL_MACOS.md": repo / "docs/INSTALL_MACOS.md",
        "RELEASE_NOTES.md": repo / "docs/releases/v0.4.16-macos.1.md",
        "MULTIPLAYER.md": repo / "docs/MULTIPLAYER.md",
        "LICENSE": repo / "LICENSE",
        "LICENSES/GPL-3.0.txt": repo / "LICENSES/GPL-3.0.txt",
        "RIGHTS_AND_LICENSES.md": repo / "RIGHTS_AND_LICENSES.md",
        "THIRD_PARTY_NOTICES.md": repo / "THIRD_PARTY_NOTICES.md",
        "ThirdPartyLicenses/Aurora-MIT.txt": repo / "ref/upstream/Wiicompiled/aurora-main/LICENSE",
        "ThirdPartyLicenses/CryptoPP.txt": repo / "ref/upstream/Wiicompiled/runtime/third_party/cryptopp/License.txt",
        "ThirdPartyLicenses/PugiXML-MIT.txt": repo / "ref/upstream/Wiicompiled/runtime/third_party/pugixml/LICENSE.md",
        "ThirdPartyLicenses/TOML11-MIT.txt": repo / "ref/upstream/Wiicompiled/runtime/third_party/toml11/LICENSE",
        "ThirdPartyLicenses/WiiCompiled-GPL-3.0.txt": repo / "ref/upstream/Wiicompiled/LICENSE",
    }
    for label, filename in {
        "Abseil-Apache-2.0.txt": "abseil-cpp-src/LICENSE",
        "FreeType.txt": "freetype-src/LICENSE.TXT",
        "SDL3-Zlib.txt": "sdl-src/LICENSE.txt",
        "Tracy-BSD-3-Clause.txt": "tracy-src/LICENSE",
        "fmt-MIT.txt": "fmt-src/LICENSE",
        "imgui-MIT.txt": "imgui-src/LICENSE.txt",
        "libpng.txt": "png-src/LICENSE",
        "xxHash-BSD-2-Clause.txt": "xxhash-src/LICENSE",
        "zstd-BSD.txt": "zstd-src/LICENSE",
    }.items():
        extras[f"ThirdPartyLicenses/{label}"] = args.runtime_build / "_deps" / filename
    missing = [name for name, path in extras.items() if not path.is_file()]
    if missing:
        fail(f"missing release files: {', '.join(missing)}")
    entries: list[tuple[str, bytes, int]] = []
    for root, directory_names, file_names in os.walk(app, followlinks=False):
        root_path = Path(root)
        relative_root = root_path.relative_to(app).as_posix()
        directory_entry = "KartPad.app/" if relative_root == "." else \
            f"KartPad.app/{relative_root}/"
        entries.append((directory_entry, b"",
                        stat.S_IFDIR | stat.S_IMODE(root_path.stat().st_mode)))
        for directory_name in sorted(list(directory_names)):
            path = root_path / directory_name
            if path.is_symlink():
                entries.append((f"KartPad.app/{path.relative_to(app).as_posix()}",
                                os.readlink(path).encode(), stat.S_IFLNK | 0o777))
                directory_names.remove(directory_name)
        for file_name in sorted(file_names):
            path = root_path / file_name
            name = f"KartPad.app/{path.relative_to(app).as_posix()}"
            if path.is_symlink():
                entries.append((name, os.readlink(path).encode(),
                                stat.S_IFLNK | 0o777))
            else:
                entries.append((name, path.read_bytes(),
                                stat.S_IFREG | stat.S_IMODE(path.stat().st_mode)))
    for name, path in sorted(extras.items()):
        entries.append((name, path.read_bytes(),
                        stat.S_IFREG | stat.S_IMODE(path.stat().st_mode)))
    entries.append(("KartPadMacProvenance.json",
                    (json.dumps(provenance, indent=2, sort_keys=True) + "\n").encode(),
                    stat.S_IFREG | 0o644))
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(output.name + ".partial")
    if temporary.exists():
        temporary.unlink()
    with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name, data, unix_mode in sorted(entries):
            info = zipfile.ZipInfo(name, ZIP_TIMESTAMP)
            info.create_system = 3
            info.external_attr = unix_mode << 16
            if stat.S_ISDIR(unix_mode):
                info.external_attr |= 0x10
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data, compresslevel=9)
    os.replace(temporary, output)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    with zipfile.ZipFile(output) as archive:
        if archive.testzip() is not None:
            fail("ZIP integrity check failed")
    print(f"Public macOS ZIP: {output}")
    print(f"SHA-256: {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
