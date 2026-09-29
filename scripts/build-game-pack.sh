#!/usr/bin/env bash
# Build a player's KartPad game pack: their own translated game code as one
# library that the published app loads (see include/game_pack.h in the runtime).
#
# Usage: scripts/build-game-pack.sh android TRANSLATION_ROOT APP_RUNTIME_LIB OUTPUT [WORK_DIR]
#   TRANSLATION_ROOT  the player's translation (scripts/translate-retro-rewind.sh output)
#   APP_RUNTIME_LIB   the published app's runtime library (lib/arm64-v8a/libmain.so)
#   OUTPUT            where to write the game pack (keep it private; never publish it)
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
usage() { echo "usage: $0 android TRANSLATION_ROOT APP_RUNTIME_LIB OUTPUT [WORK_DIR]" >&2; exit 64; }
[[ $# -ge 4 && $# -le 5 && "$1" == android ]] || usage
translation_root="$(cd "$2" && pwd)"
runtime_lib="$(cd "$(dirname "$3")" && pwd)/$(basename "$3")"
output="$4"
work="${5:-$repo_root/build/game-pack}"
manifest="$translation_root/build_shards/shards.cmake"
[[ -f "$manifest" ]] || { echo "ERROR: missing translation: $manifest" >&2; exit 1; }
[[ -f "$runtime_lib" ]] || { echo "ERROR: missing app runtime library: $runtime_lib" >&2; exit 1; }
python3 "$repo_root/scripts/inject-retro-rel-report-guard.py" --verify-shards "$translation_root/build_shards"

version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$repo_root/version.json")"
definitions="$(paste -sd ';' "$repo_root/android/app/src/main/cpp/translated-definitions.txt")"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ndk="$sdk_root/ndk/$KARTPAD_ANDROID_NDK"
[[ -f "$ndk/build/cmake/android.toolchain.cmake" ]] || { echo "ERROR: Android NDK $KARTPAD_ANDROID_NDK not found under $sdk_root" >&2; exit 1; }
jobs="${KARTPAD_GAME_PACK_JOBS:-${CMAKE_BUILD_PARALLEL_LEVEL:-4}}"

# The runtime supplies headers and the pack project; no graphics libraries are built.
stage="$work/$(date +%Y%m%d-%H%M%S)"
KARTPAD_PREPARE_PLATFORM=android KARTPAD_PREPARE_ONLY=1 KARTPAD_PREPARE_WITHOUT_TRANSLATION=1 \
  "$repo_root/scripts/prepare-ios-game-runtime.sh" none "$stage/runtime" "$stage/runtime-build" dual

cmake -S "$stage/runtime/game_pack" -B "$stage/build" -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$ndk/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM="android-$KARTPAD_ANDROID_MIN_SDK" \
  -DANDROID_STL=c++_shared -DCMAKE_BUILD_TYPE=Release \
  -DMKW_TRANSLATED_SHARD_MANIFEST="$manifest" \
  -DMKW_GAME_PACK_RUNTIME="$runtime_lib" \
  -DMKW_KARTPAD_RUNTIME_INCLUDE="$repo_root/runtime/include" \
  -DKARTPAD_APP_VERSION="$version" \
  -DMKW_GAME_PACK_DEFINITIONS="$definitions"
cmake --build "$stage/build" --target kartpad_game --parallel "$jobs"

mkdir -p "$(dirname "$output")"
"$ndk/toolchains/llvm/prebuilt/$(uname -s | tr '[:upper:]' '[:lower:]')-x86_64/bin/llvm-strip" \
  --strip-unneeded -o "$output" "$stage/build/libkartpad_game.so"
echo "Game pack for KartPad $version (private; never publish): $output"
