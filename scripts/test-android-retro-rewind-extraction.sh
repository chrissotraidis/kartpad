#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
prepare_output="$("${repo_root}/scripts/prepare-android-dependencies.sh")"
minizip_root="$(printf '%s\n' "${prepare_output}" |
  sed -n 's/^MINIZIP_ANDROID_ROOT=//p')"
if [[ -z "${minizip_root}" ]]; then
  echo "ERROR: dependency preparation did not report MINIZIP_ANDROID_ROOT" >&2
  exit 1
fi

test_root="$(mktemp -d "${TMPDIR:-/tmp}/kartpad-archive-extract.XXXXXX")"
cleanup() {
  find "${test_root}" -depth -delete
}
trap cleanup EXIT
fixtures="${test_root}/fixtures"
work="${test_root}/work"
build="${repo_root}/build/android-retro-rewind-extraction-tests"
mkdir -p "${fixtures}" "${work}" "${build}"

python3 - "${fixtures}" <<'PY'
from pathlib import Path
import stat
import sys
import warnings
import zipfile

root = Path(sys.argv[1])

def create(name, entries):
    with zipfile.ZipFile(root / f"{name}.zip", "w", zipfile.ZIP_DEFLATED) as archive:
        for path, content, mode in entries:
            info = zipfile.ZipInfo(path)
            info.create_system = 3
            info.external_attr = mode << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, content)

valid = [
    ("RetroRewind6/", b"", stat.S_IFDIR | 0o700),
    ("RetroRewind6/version.txt", b"6.12.5\n", stat.S_IFREG | 0o600),
    ("foreign.txt", b"ignored", stat.S_IFREG | 0o600),
]
create("valid", valid)
create("traversal", [("RetroRewind6/../escape", b"x", stat.S_IFREG | 0o600)])
warnings.filterwarnings("ignore", message="Duplicate name:.*")
create("duplicate", [
    ("RetroRewind6/version.txt", b"one", stat.S_IFREG | 0o600),
    ("RetroRewind6/version.txt", b"two", stat.S_IFREG | 0o600),
])
create("alias", [
    ("RetroRewind6/item/", b"", stat.S_IFDIR | 0o700),
    ("RetroRewind6/item", b"file", stat.S_IFREG | 0o600),
])
create("symlink", [("RetroRewind6/link", b"target", stat.S_IFLNK | 0o777)])
create("slash-data", [("RetroRewind6/not-a-directory/", b"x", stat.S_IFREG | 0o600)])
create("missing", [("Other/file", b"x", stat.S_IFREG | 0o600)])
create("entry-limit", [
    (f"RetroRewind6/{index}", b"x", stat.S_IFREG | 0o600)
    for index in range(11)
])
create("cancel", [
    ("RetroRewind6/one", b"one", stat.S_IFREG | 0o600),
    ("RetroRewind6/two", b"two", stat.S_IFREG | 0o600),
])
corrupt = root / "corrupt.zip"
with zipfile.ZipFile(corrupt, "w", zipfile.ZIP_STORED) as archive:
    info = zipfile.ZipInfo("RetroRewind6/data")
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | 0o600) << 16
    archive.writestr(info, b"known-content", compress_type=zipfile.ZIP_STORED)
data = bytearray(corrupt.read_bytes())
offset = data.index(b"known-content")
data[offset] ^= 0x01
corrupt.write_bytes(data)

create("encrypted", [("RetroRewind6/data", b"data", stat.S_IFREG | 0o600)])
encrypted = root / "encrypted.zip"
data = bytearray(encrypted.read_bytes())
local = data.index(b"PK\x03\x04")
central = data.index(b"PK\x01\x02")
data[local + 6] |= 0x01
data[central + 8] |= 0x01
encrypted.write_bytes(data)

create("invalid-utf8", [("RetroRewind6/bad-name", b"data", stat.S_IFREG | 0o600)])
invalid_utf8 = root / "invalid-utf8.zip"
data = bytearray(invalid_utf8.read_bytes())
needle = b"RetroRewind6/bad-name"
first = data.index(needle)
second = data.index(needle, first + 1)
data[first + len(needle) - 1] = 0xff
data[second + len(needle) - 1] = 0xff
invalid_utf8.write_bytes(data)
PY

cmake -S "${repo_root}/runtime/tests/retro_rewind_archive_extract" -B "${build}" \
  -DKARTPAD_REPO_ROOT="${repo_root}" \
  -DMINIZIP_SOURCE_DIR="${minizip_root}" >/dev/null
cmake --build "${build}" --target kartpad_archive_extract_test --parallel 2 >/dev/null
"${build}/kartpad_archive_extract_test" "${fixtures}" "${work}"
echo "Android Retro Rewind archive extraction passed."
