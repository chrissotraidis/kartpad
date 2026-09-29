#!/usr/bin/env python3
"""Fail if a game pack keeps its own copy of runtime state that lives in the app.

Header variables (C++ inline variables, thread_local ones, statics inside inline
functions) must exist once, in the app; the runtime declares them extern for
packs (MKW_GAME_PACK_MODULE). A pack with its own copy runs but reads state the
app never sets. The only allowed duplicates are per-target lookup caches that
latch after the function registry is published.

Usage: check-game-pack-state.py NM PACK APP_RUNTIME
  NM           an nm that reads the pack (llvm-nm for Android, nm on a Mac)
  PACK         the unstripped game pack
  APP_RUNTIME  the app's runtime (libmain.so or the KartPad executable)
"""
import subprocess
import sys
from pathlib import Path

ALLOWED = ("ResolveDirectCpuTargetInfoCached",)
DATA_TYPES = set("BbDdVvSs")


def symbols(nm, path, dynamic):
    args = [nm, "--defined-only"] + (["-D"] if dynamic else []) + [path]
    run = subprocess.run(args, capture_output=True, text=True)
    if run.returncode != 0 and dynamic:
        # Mach-O has no separate dynamic table: exported means external.
        run = subprocess.run([nm, "--defined-only", "-g", path], capture_output=True, text=True)
    if run.returncode != 0:
        sys.exit(run.stderr.strip())
    out = run.stdout
    result = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 3:
            result[parts[2]] = parts[1]
    return result


def _demangler(nm):
    """llvm-cxxfilt beside the nm in use (NDK, Xcode), else c++filt, else none."""
    tool = Path(nm)
    for candidate in (tool.with_name("llvm-cxxfilt" + tool.suffix), Path("c++filt")):
        try:
            subprocess.run([str(candidate), "--version"], capture_output=True, check=False)
            return str(candidate)
        except OSError:
            continue
    return None


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    nm, pack, app = sys.argv[1:]
    pack_data = {name for name, kind in symbols(nm, pack, False).items() if kind in DATA_TYPES}
    app_defined = set(symbols(nm, app, True)) | set(symbols(nm, app, False))
    cxxfilt = _demangler(nm)
    demangle = (lambda names: subprocess.run(
        [cxxfilt], input="\n".join(names), capture_output=True, text=True).stdout.split("\n")) \
        if cxxfilt else list
    shared = sorted(pack_data & app_defined)
    bad = [readable for name, readable in zip(shared, demangle(shared))
           if not any(allowed in readable for allowed in ALLOWED)]
    if bad:
        print("ERROR: the game pack has its own copy of app runtime state:", file=sys.stderr)
        for readable in bad:
            print(f"  {readable}", file=sys.stderr)
        return 1
    # C++ thread_local accessors (_ZTW...) are never exported by the app; the
    # runtime headers must declare pack-side thread-locals with __thread.
    undefined = subprocess.run([nm, "-u", pack], check=True, capture_output=True, text=True).stdout.split()
    wrappers = sorted({name for name in undefined if name.lstrip("_").startswith("ZTW")} - app_defined)
    if wrappers:
        print("ERROR: the game pack calls thread-local accessors the app does not export:", file=sys.stderr)
        for readable in demangle(wrappers):
            print(f"  {readable}", file=sys.stderr)
        return 1
    print(f"Game pack state check passed ({len(shared)} allowed lookup caches).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
