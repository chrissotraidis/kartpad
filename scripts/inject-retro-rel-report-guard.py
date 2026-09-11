#!/usr/bin/env python3
"""Guard the translated StaticR.rel error-report section-table read."""

from __future__ import annotations

import argparse
from pathlib import Path


SIGNATURE = 'extern "C" void func_8000A440(CpuContext* MKW_RESTRICT ctx)\n{'
HEADER_ENTRY = "    r4 = MemoryInline::FlatRead32(r28);"
TABLE_ENTRY = "    r30 = MemoryInline::FlatRead32((r28 + 16));\n    r29 = 0;"
MARKER = "// KartPad: validate StaticR.rel report table before dereference"
GUARD = """    // KartPad: validate StaticR.rel report table before dereference.
    // A malformed or overwritten REL must not turn its diagnostic path into
    // a native flat-memory crash on Apple or Android. Branch through the
    // generated cleanup block; never return before restoring the prologue.
    if (!RecompMod::TryGetRelReportSectionTable(r28, r30)) {
        goto loc_8000A51C;
    }
    r4 = MemoryInline::FlatRead32(r28);"""


def inject(path: Path) -> bool:
    source = path.read_text()
    if source.count(SIGNATURE) != 1:
        raise SystemExit(f"expected exactly one func_8000A440 signature in {path}")
    if '#include "recomp_mod_loader.h"' not in source:
        raise SystemExit(f"generated report function lacks recomp_mod_loader.h: {path}")

    marker_count = source.count(MARKER)
    if marker_count == 1:
        if GUARD not in source or source.count(TABLE_ENTRY) != 0:
            raise SystemExit(f"unsafe or partial existing REL report guard in {path}")
        return False
    if marker_count != 0 or source.count(HEADER_ENTRY) != 1 or source.count(TABLE_ENTRY) != 1:
        raise SystemExit(f"partial, duplicate, or unexpected REL report function in {path}")

    guarded = source.replace(HEADER_ENTRY, GUARD, 1)
    guarded = guarded.replace(TABLE_ENTRY, "    r29 = 0;", 1)
    path.write_text(guarded)
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("function", type=Path)
    args = parser.parse_args()
    changed = inject(args.function)
    print(f"{'injected' if changed else 'verified'} Retro REL report guard: {args.function}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
