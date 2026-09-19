#!/usr/bin/env python3
"""Give an archive-based Dawn build a stable identity independent of its parent Git repo."""
import argparse
import hashlib
from pathlib import Path

BASE_REVISION = "13abc3bc8ea2d3c2050f9e77a12d012108ceee24"


def pin(source: Path, patch: Path, *additional: Path) -> str:
    # Include the reviewed patch: never reuse incompatible upstream cache entries.
    contents = b"kartpad-dawn-source-v1\0" + BASE_REVISION.encode() + b"\0" + patch.read_bytes()
    for extra in additional:
        data = extra.read_bytes()
        contents += b"\0additional-patch\0" + len(data).to_bytes(8, "big") + data
    identity = hashlib.sha256(contents).hexdigest()[:40]
    cmake = source / "src/dawn/CMakeLists.txt"
    original = '    EXTRA_PARAMETERS "--dawn-dir"\n         "${Dawn_SOURCE_DIR}"\n'
    pinned = original + '         "--version-file" "${Dawn_SOURCE_DIR}/KARTPAD_DAWN_VERSION"\n'
    content = cmake.read_text()
    if pinned not in content:
        if content.count(original) != 1:
            raise ValueError("Dawn version generator changed; review before pinning")
        cmake.write_text(content.replace(original, pinned, 1))
    version = source / "KARTPAD_DAWN_VERSION"
    value = identity + "\n"
    if not version.exists() or version.read_text() != value:
        version.write_text(value)
    return identity


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("patch", type=Path, nargs="+")
    args = parser.parse_args()
    print(pin(args.source, *args.patch))
