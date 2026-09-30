"""The pack interface fingerprint: one value for the app build and the pack build.

A game pack compiles the runtime's headers into every translated function and
binds to the app's exports. The app accepts a pack built with the same
fingerprint (pack ABI 3), so an app update that changes none of these inputs
keeps working with the player's pack:

- every header a pack can include from the staged runtime and KartPad's
  runtime/include;
- the pack project (game_pack/) and the runtime's CMake, which set the
  definitions that reach those headers in the app build;
- the platform's pack definitions and the app build files that apply the
  app-side ones;
- the translation identity: the translator source KartPad pins and the
  compatibility profiles (which also pin Retro Rewind).

Left out on purpose: the app version, and the compiler (a pack built with the
NDK or with LLVM on Linux arm64 must match the same app). Every pack, reused or
new, is still checked against the app's exports (check-game-pack-state.py).
Line endings are normalized, so a Windows checkout gives the same value.
"""
from __future__ import annotations

import argparse
import hashlib
import subprocess
from pathlib import Path

SCHEMA = b"kartpad-pack-fingerprint-1"
HEADER_SUFFIXES = (".h", ".hh", ".hpp", ".hxx", ".inc", ".inl", ".ipp", ".def")
HEADER_DIRS = ("include", "src", "third_party", "aurora-main/include")
WHOLE = ("game_pack", "cmake", "CMakeLists.txt")
APP_BUILD_FILES = {
    "android": ("android/app/src/main/cpp/CMakeLists.txt", "android/app/src/main/cpp/translated-definitions.txt"),
    "ios": ("scripts/build-ios-device-game-app.sh",),
}
IOS_DEFINITIONS = ("KARTPAD_UNOBSERVED_FP_STATUS=1",)


def definitions(repo: Path, platform: str) -> list[str]:
    """The platform definitions a pack is compiled with (the app build's own)."""
    if platform == "android":
        text = (repo / "android/app/src/main/cpp/translated-definitions.txt").read_text()
        return [line.strip() for line in text.splitlines() if line.strip()]
    if platform == "ios":
        return list(IOS_DEFINITIONS)
    raise ValueError(f"unknown platform: {platform}")


def _files(runtime: Path, repo: Path, platform: str) -> list[tuple[str, Path]]:
    chosen: dict[str, Path] = {}
    for relative in HEADER_DIRS:
        base = runtime / relative
        if base.is_dir():
            for path in base.rglob("*"):
                if path.is_file() and path.suffix.lower() in HEADER_SUFFIXES:
                    chosen[f"runtime/{path.relative_to(runtime).as_posix()}"] = path
    for relative in WHOLE:
        base = runtime / relative
        paths = [base] if base.is_file() else (p for p in base.rglob("*") if p.is_file()) if base.is_dir() else []
        for path in paths:
            chosen[f"runtime/{path.relative_to(runtime).as_posix()}"] = path
    for path in (repo / "runtime/include").rglob("*"):
        if path.is_file():
            chosen[f"kartpad/{path.relative_to(repo).as_posix()}"] = path
    for path in sorted((repo / "builder/profiles").glob("*.json")):
        chosen[f"kartpad/{path.relative_to(repo).as_posix()}"] = path
    for relative in APP_BUILD_FILES[platform]:
        chosen[f"kartpad/{relative}"] = repo / relative
    return sorted(chosen.items())


def _translator(repo: Path) -> bytes:
    """The translator commit KartPad pins (its vendor/wiicompiled gitlink)."""
    record = subprocess.check_output(["git", "-C", str(repo), "ls-files", "--stage", "--", "vendor/wiicompiled"])
    fields = record.split()
    if len(fields) < 2 or fields[0] != b"160000":
        raise ValueError("vendor/wiicompiled is not a pinned gitlink")
    return fields[1]


def fingerprint(repo: Path, platform: str, runtime: Path) -> str:
    """Lowercase hex SHA-256 of the pack interface for one staged runtime."""
    digest = hashlib.sha256(SCHEMA + b"\0" + platform.encode() + b"\0")
    digest.update(b"translator\0" + _translator(repo) + b"\0")
    for definition in definitions(repo, platform):
        digest.update(b"define\0" + definition.encode() + b"\0")
    for name, path in _files(runtime, repo, platform):
        data = path.read_bytes().replace(b"\r\n", b"\n")
        digest.update(name.encode() + b"\0" + str(len(data)).encode() + b"\0" + data)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Print the pack interface fingerprint of a staged runtime.")
    parser.add_argument("platform", choices=("android", "ios"))
    parser.add_argument("runtime", type=Path, help="The staged runtime the app or pack is built from")
    args = parser.parse_args()
    print(fingerprint(Path(__file__).resolve().parents[2], args.platform, args.runtime.resolve()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
