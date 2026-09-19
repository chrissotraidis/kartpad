#!/usr/bin/env python3
"""Symbolize an exported relative PC only after exact ELF BuildID verification."""
import argparse
import os
from pathlib import Path
import re
import subprocess


def symbolize(symbols: Path, build_id: str, relative_pc: str, toolchain: Path) -> str:
    if not re.fullmatch(r"[0-9a-fA-F]{8,128}", build_id):
        raise ValueError("A retained tombstone's exact hexadecimal BuildID is required")
    if not re.fullmatch(r"(?:0x)?[0-9a-fA-F]{1,16}", relative_pc):
        raise ValueError("relative PC must be a hexadecimal ELF-relative address")
    notes = subprocess.check_output([str(toolchain / "llvm-readelf"), "--notes", str(symbols)], text=True)
    ids = re.findall(r"Build ID:\s*([0-9a-fA-F]+)", notes)
    if len(ids) != 1 or ids[0].lower() != build_id.lower():
        raise ValueError("ELF BuildID mismatch or missing: refusing misleading symbolization")
    return subprocess.check_output([str(toolchain / "llvm-symbolizer"), "--inlines", "--demangle",
        "--obj=" + str(symbols), hex(int(relative_pc, 16))], text=True)


def main():
    sdk = Path(os.environ.get("ANDROID_SDK_ROOT", str(Path.home() / "Library/Android/sdk")))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--symbols", type=Path, required=True, help="exact retained unstripped .so")
    parser.add_argument("--build-id", required=True, help="BuildID from the reporter's frame")
    parser.add_argument("--relative-pc", required=True, help="relative_pc_hex from the same frame")
    parser.add_argument("--toolchain", type=Path, default=sdk / "ndk/29.0.14206865/toolchains/llvm/prebuilt/darwin-x86_64/bin")
    args = parser.parse_args()
    try:
        print(symbolize(args.symbols, args.build_id, args.relative_pc, args.toolchain), end="")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Symbolization failed: {error}\n")


if __name__ == "__main__":
    main()
