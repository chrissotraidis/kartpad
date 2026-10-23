#!/usr/bin/env python3
"""Portable ghost tests; optional local pack has pinned configs and private bodies."""
import argparse
import hashlib
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

FIXTURES = {
    "6.12.8": (
        "07f273dbd5e6a9bbbc8216f41513c227fbe765ef5fb1a141ec9a664977befcdb",
        "341cbc21a429ad0aadfb2d59e5f6f134c245e0b4450bdcaa3ee0b1df9beb49cd",
    ),
    "6.13.4": (
        "06aea3d6d4dab91c65f743c0958c365ea7e063061bcc2f78f7389fced90ed2ba",
        "831a63eab7fbf5642f0fb02b05e861278fef587ef1ae335e64e5c66721906c95",
    ),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    inputs = parser.add_mutually_exclusive_group()
    inputs.add_argument("--config-root", type=Path, help="Private directory containing ConfigRT/CT.pul")
    inputs.add_argument("--pack-root", type=Path, help="Private RetroRewind6 directory; also validate experts and transfer every destination")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    fixtures = []
    config_root = args.pack_root / "Binaries" if args.pack_root else args.config_root
    if config_root:
        hashes = []
        for name in ("ConfigRT.pul", "ConfigCT.pul"):
            path = config_root / name
            if path.stat().st_size > 8 * 1024 * 1024:
                raise SystemExit(f"{name} exceeds the config size limit")
            hashes.append(hashlib.sha256(path.read_bytes()).hexdigest())
            fixtures.append(str(path))
        version = next((v for v, expected in FIXTURES.items() if tuple(hashes) == expected), None)
        if version is None:
            raise SystemExit("Config pair does not match a pinned 6.12.8 or 6.13.4 fixture")
        fixtures.append(version)
    with tempfile.TemporaryDirectory(prefix="kartpad-retro-catalog-") as temporary:
        for test, arguments in (
            ("retro_catalog", fixtures),
            ("retro_pack", [str(args.pack_root.resolve()), version] if args.pack_root else []),
        ):
            binary = Path(temporary) / test
            subprocess.run(shlex.split(os.environ.get("CXX", "clang++")) + [
                "-std=c++20", "-O1", "-g", "-Wall", "-Wextra", "-Werror",
                "-fsanitize=address,undefined", "-I" + str(repo / "runtime/include"),
                str(repo / f"runtime/tests/{test}_tests.cpp"), "-o", str(binary),
            ], check=True)
            subprocess.run([str(binary), *arguments], check=True)


if __name__ == "__main__":
    main()
