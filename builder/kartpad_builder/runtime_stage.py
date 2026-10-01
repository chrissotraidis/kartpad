"""Stage the pinned runtime source for one platform, on any host.

Shared by the Mac app builds (scripts/prepare-ios-game-runtime.sh) and the
cross-platform game-pack build, so every build compiles the same headers.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path

from .release_header import render_retro_rewind_header
from .errors import BuildError

SSE2NEON_URL = "https://raw.githubusercontent.com/DLTcollab/sse2neon/13a42df35dc7fcc94f987568e7274a998bb6cc86/sse2neon.h"
SSE2NEON_SHA256 = "44b9fa3dec3a52ea473246e04b9f692a4e5b0ed654299eef7fe7ec3049e223e0"
PROFILE = "builder/profiles/mkwii-rmcp01-rev0.json"


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _sse2neon(repo: Path) -> Path:
    cached = repo / f"build/dependency-cache/sse2neon-{SSE2NEON_SHA256}.h"
    if not cached.is_file() or _sha256(cached) != SSE2NEON_SHA256:
        cached.parent.mkdir(parents=True, exist_ok=True)
        partial = cached.with_suffix(".partial")
        with urllib.request.urlopen(SSE2NEON_URL) as response:
            partial.write_bytes(response.read())
        if _sha256(partial) != SSE2NEON_SHA256:
            raise ValueError("sse2neon hash mismatch")
        partial.replace(cached)
    return cached


def stage_extras(repo: Path, destination: Path) -> None:
    """Restore missing generated headers on retry; preserve and check existing ones."""
    profile = json.loads((repo / PROFILE).read_text())
    header = destination / "third_party/kartpad-profile/kartpad_retro_rewind_release.h"
    release = render_retro_rewind_header(profile).encode()
    target = destination / "third_party/sse2neon/sse2neon.h"
    expected = {header: hashlib.sha256(release).hexdigest(), target: SSE2NEON_SHA256}
    missing = []
    for path, digest in expected.items():
        # Never follow an edited generated path, including symlinked folders.
        if any(p.is_symlink() for p in (destination, destination / "third_party", path.parent, path)):
            raise BuildError(f"generated runtime header has a symlink: {path}; choose a fresh build workspace")
        if path.exists():
            # Earlier Windows builds wrote the generated profile with CRLF.
            contents = path.read_bytes() if path.is_file() else b""
            if path == header:
                contents = contents.replace(b"\r\n", b"\n")
            if not path.is_file() or hashlib.sha256(contents).hexdigest() != digest:
                raise BuildError(f"generated runtime header differs from its pinned input: {path}; "
                                 "your file was preserved; choose a fresh build workspace")
        else:
            missing.append(path)
    # Finish the verified download before publishing either missing header.
    dependency = _sse2neon(repo).read_bytes() if target in missing else None
    for path in missing:
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix=".padmint-", dir=path.parent) as temporary:
            staged = Path(temporary) / path.name
            staged.write_bytes(release if path == header else dependency)
            staged.replace(path)


def stage(repo: Path, platform: str, destination: Path) -> None:
    subprocess.run([sys.executable, str(repo / "scripts/stage-maintained-runtime.py"),
                    platform, str(destination)], check=True)
    stage_extras(repo, destination)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("what", choices=("extras",), help="extras: release header and sse2neon")
    parser.add_argument("destination", type=Path)
    args = parser.parse_args()
    stage_extras(Path(__file__).resolve().parents[2], args.destination)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
