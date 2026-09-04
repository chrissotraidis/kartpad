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

dawn_archive="$cache_root/dawn-android-aarch64.tar.gz"
fetch_locked \
  "https://github.com/encounter/dawn-build/releases/download/v20260603.191052/dawn-android-aarch64.tar.gz" \
  "$dawn_archive" 11645719 \
  27d910dee1201fd1e5b6ac567f0ba2306ebf2135e9f40b6929976c365d38b09b
dawn_root="$cache_root/dawn-v20260603.191052-android-aarch64"
if [[ ! -f "$dawn_root/lib/cmake/Dawn/DawnTargets.cmake" ]]; then
  mkdir -p "$dawn_root"
  tar -xzf "$dawn_archive" -C "$dawn_root"
fi
dawn_targets="$dawn_root/lib/cmake/Dawn/DawnTargets.cmake"
python3 - "$dawn_targets" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
absolute_log = "/usr/local/lib/android/sdk/ndk/29.0.14206865/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/28/liblog.so"
if absolute_log in text:
    text = text.replace(absolute_log, "log")
    path.write_text(text)
if "/usr/local/lib/android/sdk" in text:
    raise SystemExit("ERROR: Dawn metadata still contains its Linux CI SDK path")
if "log;" not in text:
    raise SystemExit("ERROR: sanitized Dawn metadata does not link logical Android log")
PY
sanitized_targets_sha256="$(shasum -a 256 "$dawn_targets" | awk '{print $1}')"
if [[ "$sanitized_targets_sha256" != \
      "950622eccd03a73154849a5f682347b1f69b5cb5847cc00857eb12459fee4591" ]]; then
  echo "ERROR: sanitized Dawn target metadata digest changed" >&2
  exit 1
fi

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

echo "SDL3 Android AAR: $(shasum -a 256 "$repo_root/android/app/libs/SDL3-3.4.4.aar" | awk '{print $1}')"
echo "Dawn archive: $(shasum -a 256 "$dawn_archive" | awk '{print $1}')"
echo "Dawn sanitized targets: $sanitized_targets_sha256"
echo "minizip-ng archive: $(shasum -a 256 "$minizip_archive" | awk '{print $1}')"
echo "DAWN_ANDROID_ROOT=$dawn_root"
echo "MINIZIP_ANDROID_ROOT=$minizip_root"
