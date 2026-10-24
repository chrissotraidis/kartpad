#!/usr/bin/env bash
# Build the Android app's second game runtime: the same KartPad runtime on the
# WiiCompiled 0.9 graphics layer (vendor/runtimes/android/aurora-wiicompiled).
# Writes OUTPUT/arm64-v8a/libmain_wiicompiled.so for -PkartpadWiiCompiledRuntime=OUTPUT.
# Use the prepared runtime source and pack fingerprint of the classic app build,
# so one game pack serves both runtimes.
set -euo pipefail
if [[ $# -ne 3 ]]; then
  echo "Usage: $0 PREPARED_RUNTIME_SOURCE OUTPUT_DIR PACK_FINGERPRINT" >&2
  exit 64
fi
repo_root="$(git rev-parse --show-toplevel)"
runtime_source="$(cd "$1" && pwd)"
output="$2"
fingerprint="$3"
[[ -f "$runtime_source/aurora-wiicompiled/CMakeLists.txt" ]] || {
  echo "ERROR: $runtime_source has no aurora-wiicompiled; stage it from the current runtime pin" >&2
  exit 66
}
[[ ! -e "$output" ]] || { echo "ERROR: output exists; choose a new path" >&2; exit 73; }
source "$repo_root/scripts/android-toolchain-versions.sh"
prepare_output="$("$repo_root/scripts/prepare-android-dependencies.sh")"
export DAWN_ANDROID_ROOT="$(printf '%s\n' "$prepare_output" | sed -n 's/^DAWN_ANDROID_ROOT=//p')"
export MINIZIP_ANDROID_ROOT="$(printf '%s\n' "$prepare_output" | sed -n 's/^MINIZIP_ANDROID_ROOT=//p')"
export MBEDTLS_ANDROID_ROOT="$(printf '%s\n' "$prepare_output" | sed -n 's/^MBEDTLS_ANDROID_ROOT=//p')"
export JAVA_HOME="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
"$repo_root/android/gradlew" --project-dir "$repo_root/android" --no-daemon --max-workers=4 \
  -PkartpadGamePackApp=true -PkartpadPackFingerprint="$fingerprint" \
  -PkartpadGameRuntimeSource="$runtime_source" -PkartpadAndroidNativeTarget=KartPadDual \
  -PkartpadAuroraDir=aurora-wiicompiled :app:externalNativeBuildRelease
# Gradle keeps one CMake build per configuration; take the one on this layer and source.
library=""
native_build=""
for build in "$repo_root"/android/app/.cxx/RelWithDebInfo/*/arm64-v8a; do
  if grep -Fqx "KARTPAD_AURORA_DIR:STRING=aurora-wiicompiled" "$build/CMakeCache.txt" 2>/dev/null &&
     grep -Fqx "KARTPAD_GAME_RUNTIME_SOURCE:PATH=$runtime_source" "$build/CMakeCache.txt" 2>/dev/null; then
    native_build="$build"
    library="$repo_root/android/app/build/intermediates/cxx/RelWithDebInfo/$(basename "$(dirname "$build")")/obj/arm64-v8a/libmain.so"
  fi
done
[[ -f "$library" ]] || { echo "ERROR: the WiiCompiled runtime build was not found" >&2; exit 1; }
mkdir -p "$output/arm64-v8a"
cp "$library" "$output/arm64-v8a/libmain_wiicompiled.so"
echo "Native build: $native_build"
echo "WiiCompiled runtime: $output/arm64-v8a/libmain_wiicompiled.so"
