#!/usr/bin/env python3
"""Stage tracked translator source, preserving only the destination's build caches."""
from __future__ import annotations

import argparse
import filecmp
from pathlib import Path
import shutil
import subprocess
import tempfile

CACHE_DIRECTORIES = (".git", "bin", "obj")


def _prune(path: Path) -> None:
    """Remove path but keep build caches beneath it, as rsync --delete with excludes does."""
    if path.is_dir() and not path.is_symlink():
        for child in path.iterdir():
            if child.name not in CACHE_DIRECTORIES:
                _prune(child)
        if not any(path.iterdir()):
            path.rmdir()
    else:
        path.unlink()


def _sync(source: Path, destination: Path) -> None:
    """Make destination match source (like rsync -a --delete), keeping build caches."""
    destination.mkdir(parents=True, exist_ok=True)
    wanted = {entry.name for entry in source.iterdir()}
    for existing in destination.iterdir():
        if existing.name in CACHE_DIRECTORIES or existing.name in wanted:
            continue
        _prune(existing)
    for entry in source.iterdir():
        target = destination / entry.name
        if entry.is_symlink():
            if target.is_symlink() and target.readlink() == entry.readlink():
                continue
            if target.exists() or target.is_symlink():
                shutil.rmtree(target) if target.is_dir() and not target.is_symlink() else target.unlink()
            target.symlink_to(entry.readlink())
        elif entry.is_dir():
            if target.exists() and not target.is_dir():
                target.unlink()
            _sync(entry, target)
        elif not target.is_file() or not filecmp.cmp(entry, target, shallow=False):
            if target.is_dir():
                shutil.rmtree(target)
            shutil.copy2(entry, target)


def stage(repo: Path, destination: Path) -> None:
    source = repo / "vendor/wiicompiled"
    names = subprocess.check_output(
        ["git", "-C", str(source), "ls-files", "--cached", "-z", "--", "."]
    ).decode().split("\0")
    # A complete filtered tree lets rsync --delete remove source dropped since
    # the previous stage. A files-from list alone does not provide that contract.
    with tempfile.TemporaryDirectory(prefix="kartpad-translator-source-") as temporary:
        filtered = Path(temporary)
        for name in filter(None, names):
            relative = Path(name)
            if relative.is_absolute() or ".." in relative.parts:
                raise ValueError(f"unsafe tracked translator path: {name}")
            if any(part in CACHE_DIRECTORIES for part in relative.parts):
                continue
            original = source / relative
            if not original.exists() and not original.is_symlink():
                continue  # A tracked working-tree deletion must disappear downstream.
            target = filtered / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            if original.is_symlink():
                target.symlink_to(original.readlink())
            else:
                shutil.copy2(original, target)
        if not (filtered / "translator/src/Translator.Cli/Translator.Cli.csproj").is_file():
            raise ValueError("missing tracked WiiCompiled translator source")
        _sync(filtered, destination)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    stage(Path(__file__).resolve().parents[1], args.destination)


if __name__ == "__main__":
    main()
