#!/usr/bin/env python3
"""Portable catalog tests; optional locally retained 6.12.8 configs stay private."""
import argparse
import hashlib
import os
from pathlib import Path
import shlex
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config-root", type=Path, help="Optional private directory containing ConfigRT/CT.pul")
    args = parser.parse_args()
    repo = Path(__file__).resolve().parents[1]
    fixtures = []
    if args.config_root:
        for name, expected in (
            ("ConfigRT.pul", "07f273dbd5e6a9bbbc8216f41513c227fbe765ef5fb1a141ec9a664977befcdb"),
            ("ConfigCT.pul", "341cbc21a429ad0aadfb2d59e5f6f134c245e0b4450bdcaa3ee0b1df9beb49cd"),
        ):
            path = args.config_root / name
            if path.stat().st_size > 8 * 1024 * 1024 or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                raise SystemExit(f"{name} does not match the pinned 6.12.8 fixture")
            fixtures.append(str(path))
    with tempfile.TemporaryDirectory(prefix="kartpad-retro-catalog-") as temporary:
        binary = Path(temporary) / "catalog-tests"
        subprocess.run(shlex.split(os.environ.get("CXX", "clang++")) + [
            "-std=c++20", "-O1", "-g", "-Wall", "-Wextra", "-Werror",
            "-fsanitize=address,undefined", "-I" + str(repo / "runtime/include"),
            str(repo / "runtime/tests/retro_catalog_tests.cpp"), "-o", str(binary),
        ], check=True)
        subprocess.run([str(binary), *fixtures], check=True)


if __name__ == "__main__":
    main()
