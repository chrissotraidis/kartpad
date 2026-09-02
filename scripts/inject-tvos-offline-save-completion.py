#!/usr/bin/env python3
"""Accept the title's offline post-save completion on tvOS."""

from __future__ import annotations

import argparse
from pathlib import Path


SIGNATURE = 'extern "C" void func_80672CC8(CpuContext* MKW_RESTRICT ctx)\n{'
ANCHOR = """[[maybe_unused]] loc_80672D14:
{
    if (((cr & 0x20000000u) == 0)) {"""
MARKER = "// tvOS has no WiiConnect24 service for this post-save completion"
REPLACEMENT = """[[maybe_unused]] loc_80672D14:
{
#if defined(__ENVIRONMENT_TV_OS_VERSION_MIN_REQUIRED__)
    // tvOS has no WiiConnect24 service for this post-save completion.
    if (r3 == 1) {
        goto loc_80672D18;
    }
#endif
    if (((cr & 0x20000000u) == 0)) {"""


def inject(path: Path) -> bool:
    source = path.read_text()
    if source.count(SIGNATURE) != 1:
        raise SystemExit(f"expected exactly one save-completion signature in {path}")

    marker_count = source.count(MARKER)
    if marker_count == 1:
        return False
    if marker_count != 0 or source.count(ANCHOR) != 1:
        raise SystemExit(f"partial, duplicate, or unexpected save-completion path in {path}")

    path.write_text(source.replace(ANCHOR, REPLACEMENT, 1))
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("function", type=Path)
    args = parser.parse_args()
    changed = inject(args.function)
    print(f"{'injected' if changed else 'verified'} tvOS save completion: {args.function}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
