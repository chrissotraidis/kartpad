#!/usr/bin/env python3
"""Stage the selected pinned runtime source without patch replay or cache mutation."""
from __future__ import annotations

import argparse
import hashlib
import json
import stat
import sys
from pathlib import Path
import shutil
import subprocess

PLATFORMS = ("macos", "ios", "android", "tvos")


def git(root: Path, *args: str) -> str:
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def source_checkout(repo: Path, platform: str, *, initialize: bool) -> tuple[Path, str]:
    if platform not in PLATFORMS:
        raise ValueError(f"unsupported runtime platform: {platform}")
    relative = f"vendor/runtimes/{platform}"
    source = repo / relative
    entry = git(repo, "ls-files", "--stage", "--", relative).split()
    if len(entry) != 4 or entry[0] != "160000" or entry[2] != "0":
        raise ValueError(f"missing or conflicted runtime submodule pin: {relative}")
    expected = entry[1]
    if not (source / ".git").exists():
        if not initialize:
            raise ValueError(f"missing runtime source {relative}; initialize submodules and prepare fresh source")
        subprocess.run(["git", "-C", str(repo), "submodule", "update", "--init", "--", relative], check=True)
    actual = git(source, "rev-parse", "HEAD")
    if actual != expected:
        raise ValueError(
            f"{relative} is at {actual}, expected {expected}; review the source checkout "
            "and update its KartPad gitlink deliberately before building"
        )
    return source, actual


def maintained_files(source: Path) -> dict[str, Path]:
    # Copy only tracked source. Local edits/deletions are supported and enter the
    # builder fingerprint; new files must be git-added in the source submodule.
    # aurora-wiicompiled (Android) is the optional second graphics layer.
    paths = subprocess.check_output(
        ["git", "-C", str(source), "ls-files", "-z", "--", "runtime", "aurora-main", "aurora-wiicompiled"]
    ).decode().split("\0")
    if not (source / "runtime/CMakeLists.txt").is_file():
        raise ValueError(f"missing maintained runtime source: {source}")
    files = {}
    for name in filter(None, paths):
        relative_path = Path(name)
        if relative_path.is_absolute() or ".." in relative_path.parts:
            raise ValueError(f"unsafe tracked source path: {name}")
        original = source / relative_path
        if not original.exists() and not original.is_symlink():
            continue
        target_path = Path(*relative_path.parts[1:]) if relative_path.parts[0] == "runtime" else relative_path
        files[target_path.as_posix()] = original
    return files


def stage(repo: Path, platform: str, destination: Path) -> str:
    if destination.exists() or destination.is_symlink():
        raise ValueError(f"output already exists; choose a fresh path: {destination}")
    source, actual = source_checkout(repo, platform, initialize=True)
    files = maintained_files(source)
    destination.mkdir(parents=True)
    for name, original in files.items():
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        if original.is_symlink():
            target.symlink_to(original.readlink())
        else:
            shutil.copy2(original, target)
    return actual


PROFILE_HEADER = "third_party/kartpad-profile/kartpad_retro_rewind_release.h"
SSE2NEON_HEADER = "third_party/sse2neon/sse2neon.h"
SSE2NEON_SHA256 = "44b9fa3dec3a52ea473246e04b9f692a4e5b0ed654299eef7fe7ec3049e223e0"
ANDROID_TRACE_HEADER = "aurora-main/lib/kartpad_android_trace_scope.h"


def verify(repo: Path, platform: str, destination: Path, *, allow_missing_generated: bool = False) -> str:
    source, actual = source_checkout(repo, platform, initialize=False)
    if not destination.is_dir() or destination.is_symlink():
        raise ValueError(f"missing prepared source: {destination}; prepare a fresh runtime source")
    files = maintained_files(source)
    generated = {PROFILE_HEADER, SSE2NEON_HEADER}
    if platform == "android":
        generated.add(ANDROID_TRACE_HEADER)
    present = {p.relative_to(destination).as_posix() for p in destination.rglob("*")
               if p.is_file() or p.is_symlink()}
    expected = set(files) | generated
    missing = expected - present
    if present - expected or missing - (generated if allow_missing_generated else set()):
        raise ValueError(f"prepared source files differ (missing={sorted(expected - present)}, extra={sorted(present - expected)}); prepare a fresh runtime source")
    for name, original in files.items():
        if name in generated:
            continue
        prepared = destination / name
        if original.is_symlink():
            matches = prepared.is_symlink() and prepared.readlink() == original.readlink()
        else:
            matches = (not prepared.is_symlink() and prepared.is_file()
                       and original.read_bytes() == prepared.read_bytes()
                       and stat.S_IMODE(original.stat().st_mode) == stat.S_IMODE(prepared.stat().st_mode))
        if not matches:
            raise ValueError(f"prepared source differs: {name}; edit maintained source and prepare a fresh runtime source")
    for name in generated:
        path = destination / name
        if any(parent.is_symlink() for parent in (path, *path.parents)
               if parent == destination or destination in parent.parents):
            raise ValueError(f"unexpected generated source symlink: {name}; prepare a fresh runtime source")
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "builder"))
    from kartpad_builder.release_header import render_retro_rewind_header
    profile = json.loads((repo / "builder/profiles/mkwii-rmcp01-rev0.json").read_text())
    if PROFILE_HEADER not in missing and (destination / PROFILE_HEADER).read_bytes() != render_retro_rewind_header(profile).encode():
        raise ValueError("prepared release profile header differs; prepare a fresh runtime source")
    if SSE2NEON_HEADER not in missing and hashlib.sha256((destination / SSE2NEON_HEADER).read_bytes()).hexdigest() != SSE2NEON_SHA256:
        raise ValueError("prepared sse2neon header differs from pinned dependency; prepare a fresh runtime source")
    if platform == "android" and ANDROID_TRACE_HEADER not in missing and (destination / ANDROID_TRACE_HEADER).read_bytes() != (repo / "runtime/include/kartpad/android/trace_scope.h").read_bytes():
        raise ValueError("prepared Android trace header differs; prepare a fresh runtime source")
    return actual


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="Reject stale or modified prepared source before building")
    parser.add_argument("--allow-missing-generated", action="store_true",
                        help="With --verify, allow missing generated headers before safely restoring them")
    parser.add_argument("platform", choices=PLATFORMS)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    try:
        if args.allow_missing_generated and not args.verify:
            parser.error("--allow-missing-generated requires --verify")
        repo = Path(__file__).resolve().parents[1]
        revision = (verify(repo, args.platform, args.destination,
                           allow_missing_generated=args.allow_missing_generated)
                    if args.verify else stage(repo, args.platform, args.destination))
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"ERROR: {error}\n")
    print(f"{'Verified' if args.verify else 'Staged'} maintained {args.platform} runtime at {revision}: {args.destination}")


if __name__ == "__main__":
    main()
