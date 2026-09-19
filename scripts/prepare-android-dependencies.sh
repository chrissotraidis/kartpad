#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cache_root="$repo_root/.android-bootstrap/dependencies"
mkdir -p "$cache_root" "$repo_root/android/app/libs"

fetch_locked() {
  local url="$1"
  local output="$2"
  local expected_bytes="$3"
  local expected_sha256="$4"
  if [[ ! -f "$output" ]]; then
    curl --fail --location --show-error --progress-bar "$url" -o "$output"
  fi
  local actual_bytes actual_sha256
  actual_bytes="$(stat -f '%z' "$output")"
  actual_sha256="$(shasum -a 256 "$output" | awk '{print $1}')"
  if [[ "$actual_bytes" != "$expected_bytes" || "$actual_sha256" != "$expected_sha256" ]]; then
    echo "ERROR: locked dependency check failed for $(basename "$output")" >&2
    exit 1
  fi
}

sdl_zip="$cache_root/SDL3-devel-3.4.4-android.zip"
fetch_locked \
  "https://github.com/libsdl-org/SDL/releases/download/release-3.4.4/SDL3-devel-3.4.4-android.zip" \
  "$sdl_zip" 16525764 \
  da67b5a43442e449511399c65aa86b724419f92850cf36a2a8c7de72eb992bc0
unzip -p "$sdl_zip" SDL3-3.4.4.aar > "$repo_root/android/app/libs/SDL3-3.4.4.aar.tmp"
mv "$repo_root/android/app/libs/SDL3-3.4.4.aar.tmp" \
   "$repo_root/android/app/libs/SDL3-3.4.4.aar"

# Android uses the reviewed maintained archive; Apple retains its own lock entries.
IFS=$'\t' read -r dawn_url dawn_bytes dawn_sha dawn_targets_sha dawn_library_sha dawn_version < <(
  python3 - "$repo_root/dependencies.lock.json" <<'PYLOCK'
import json, sys
entry = next(item for item in json.load(open(sys.argv[1]))["dependencies"] if item["name"] == "Dawn prebuilt")
print("\t".join(str(entry[key]) for key in ("androidArm64Url", "androidArm64Bytes", "androidArm64Sha256",
      "androidSanitizedDawnTargetsSha256", "androidLibrarySha256", "androidDawnVersionIdentity")))
PYLOCK
)
dawn_archive="$cache_root/dawn-android-${dawn_sha}.tar.gz"
fetch_locked "$dawn_url" "$dawn_archive" "$dawn_bytes" "$dawn_sha"
dawn_root="$cache_root/dawn-android-${dawn_sha:0:12}"
if [[ ! -e "$dawn_root" ]]; then
  mkdir -p "$dawn_root"
  tar -xzf "$dawn_archive" -C "$dawn_root"
fi
python3 - "$dawn_archive" "$dawn_root" "$dawn_targets_sha" "$dawn_library_sha" "$dawn_version" <<'PYDAWN'
from pathlib import Path, PurePosixPath
import hashlib, json, sys, tarfile
archive, root = Path(sys.argv[1]), Path(sys.argv[2])
with tarfile.open(archive) as package:
    seen = set()
    for member in package:
        relative = PurePosixPath(member.name)
        if not member.isfile() or relative.is_absolute() or ".." in relative.parts or member.name in seen:
            raise SystemExit("ERROR: invalid maintained Dawn archive member")
        seen.add(member.name)
        path = root / relative
        if path.is_symlink() or not path.is_file() or path.read_bytes() != package.extractfile(member).read():
            raise SystemExit(f"ERROR: extracted Dawn dependency differs: {member.name}")
for name, expected in (("lib/cmake/Dawn/DawnTargets.cmake", sys.argv[3]), ("lib/libwebgpu_dawn.a", sys.argv[4])):
    if hashlib.sha256((root / name).read_bytes()).hexdigest() != expected:
        raise SystemExit(f"ERROR: maintained Dawn lock differs: {name}")
if json.loads((root / "KARTPAD-DAWN.json").read_text())["dawnVersionIdentity"] != sys.argv[5]:
    raise SystemExit("ERROR: maintained Dawn version identity differs")
PYDAWN
sanitized_targets_sha256="$dawn_targets_sha"

minizip_commit="55db144e03027b43263e5ebcb599bf0878ba58de"
minizip_archive="$cache_root/minizip-ng-$minizip_commit.tar.gz"
fetch_locked \
  "https://github.com/zlib-ng/minizip-ng/archive/$minizip_commit.tar.gz" \
  "$minizip_archive" 772757 \
  e0fa42896ad244261f100fd06fae7c64f6054ce02d143f4d0f55df5fced9f63d
minizip_root="$cache_root/minizip-ng-$minizip_commit"
if [[ ! -f "$minizip_root/CMakeLists.txt" ]]; then
  temporary_minizip_root="$(mktemp -d "$cache_root/.minizip-ng-$minizip_commit.XXXXXX")"
  tar -xzf "$minizip_archive" -C "$temporary_minizip_root" --strip-components=1
  mv "$temporary_minizip_root" "$minizip_root"
fi
minizip_cmake_sha256="$(shasum -a 256 "$minizip_root/CMakeLists.txt" | awk '{print $1}')"
if [[ "$minizip_cmake_sha256" != \
      "7ed446837e293dbb61dd4e9a49566bde6408c7acd95c815e50680aeef4d60695" ]]; then
  echo "ERROR: extracted minizip-ng source digest changed" >&2
  exit 1
fi

mbedtls_version="4.1.1"
mbedtls_archive="$cache_root/mbedtls-$mbedtls_version.tar.bz2"
fetch_locked \
  "https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-$mbedtls_version/mbedtls-$mbedtls_version.tar.bz2" \
  "$mbedtls_archive" 7099934 \
  3359a349e23db3d5536fcee032ae7b2ecbfc08972fab643089b5cbf2a375c98c
mbedtls_root="$cache_root/mbedtls-$mbedtls_version"
if [[ ! -f "$mbedtls_root/CMakeLists.txt" ]]; then
  temporary_mbedtls_root="$(mktemp -d "$cache_root/.mbedtls-$mbedtls_version.XXXXXX")"
  tar -xjf "$mbedtls_archive" -C "$temporary_mbedtls_root" --strip-components=1
  mv "$temporary_mbedtls_root" "$mbedtls_root"
fi
mbedtls_cmake_sha256="$(shasum -a 256 "$mbedtls_root/CMakeLists.txt" | awk '{print $1}')"
if [[ "$mbedtls_cmake_sha256" != \
      "d2061d05fdd7fc6ebee7a1cd6fd6fbf4ebbf87ffb523a70125c7b4aeef98f3f4" ]]; then
  echo "ERROR: extracted Mbed TLS source digest changed" >&2
  exit 1
fi

bundletool_jar="$cache_root/bundletool-all-1.18.1.jar"
fetch_locked \
  "https://github.com/google/bundletool/releases/download/1.18.1/bundletool-all-1.18.1.jar" \
  "$bundletool_jar" 32505571 \
  675786493983787ffa11550bdb7c0715679a44e1643f3ff980a529e9c822595c

echo "SDL3 Android AAR: $(shasum -a 256 "$repo_root/android/app/libs/SDL3-3.4.4.aar" | awk '{print $1}')"
echo "Dawn archive: $(shasum -a 256 "$dawn_archive" | awk '{print $1}')"
echo "Dawn sanitized targets: $sanitized_targets_sha256"
echo "minizip-ng archive: $(shasum -a 256 "$minizip_archive" | awk '{print $1}')"
echo "Mbed TLS archive: $(shasum -a 256 "$mbedtls_archive" | awk '{print $1}')"
echo "Android bundletool: $(shasum -a 256 "$bundletool_jar" | awk '{print $1}')"
echo "DAWN_ANDROID_ROOT=$dawn_root"
echo "MINIZIP_ANDROID_ROOT=$minizip_root"
echo "MBEDTLS_ANDROID_ROOT=$mbedtls_root"
