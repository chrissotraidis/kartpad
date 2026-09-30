#!/usr/bin/env bash
# Build the publishable KartPad Android app: the runtime and app without any
# game code. Players add their own game pack, built by PadForge from their disc
# (vendor/runtimes/android/runtime/game_pack). Nothing here reads a disc or a
# translation.
#
# Usage: scripts/build-android-app.sh [OUTPUT_ROOT]
#   KARTPAD_ANDROID_PACKAGE_FORMAT=apk (debug, default), apk-release, or aab
#   (the release bundle; sign it with scripts/derive-android-release-apk.sh)
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
package_format="${KARTPAD_ANDROID_PACKAGE_FORMAT:-apk}"
case "$package_format" in
  apk) package_task=assembleDebug; package_path="$repo_root/android/app/build/outputs/apk/debug/app-debug.apk" ;;
  apk-release) package_task=assembleRelease; package_path="$repo_root/android/app/build/outputs/apk/release/app-release-unsigned.apk" ;;
  aab) package_task=bundleRelease; package_path="$repo_root/android/app/build/outputs/bundle/release/app-release.aab" ;;
  *) echo "ERROR: KARTPAD_ANDROID_PACKAGE_FORMAT must be apk, apk-release or aab" >&2; exit 64 ;;
esac
out_root="${1:-$repo_root/build/android-app}"
stage="$out_root/$(date +%Y%m%d-%H%M%S)"
runtime_source="$stage/runtime"
discio_jni_root="${KARTPAD_DISCIO_JNI_ROOT:-$repo_root/build/dolphin-android-discio-jni}"

"$repo_root/scripts/check-android-host.sh"
prepare_output="$("$repo_root/scripts/prepare-android-dependencies.sh")"
dawn_root="$(printf '%s\n' "$prepare_output" | sed -n 's/^DAWN_ANDROID_ROOT=//p')"
minizip_root="$(printf '%s\n' "$prepare_output" | sed -n 's/^MINIZIP_ANDROID_ROOT=//p')"
mbedtls_root="$(printf '%s\n' "$prepare_output" | sed -n 's/^MBEDTLS_ANDROID_ROOT=//p')"
if [[ -z "$dawn_root" || -z "$minizip_root" || -z "$mbedtls_root" ]]; then
  echo "ERROR: dependency preparation did not report native dependency roots" >&2
  exit 1
fi

# A fresh stage of the pinned runtime, with no generated graph beside it.
KARTPAD_PREPARE_PLATFORM=android KARTPAD_PREPARE_ONLY=1 KARTPAD_PREPARE_WITHOUT_TRANSLATION=1 \
  "$repo_root/scripts/prepare-ios-game-runtime.sh" none "$runtime_source" "$stage/runtime-build" dual
cp "$repo_root/runtime/include/kartpad/android/trace_scope.h" \
  "$runtime_source/aurora-main/lib/kartpad_android_trace_scope.h"
python3 "$repo_root/scripts/stage-maintained-runtime.py" --verify android "$runtime_source"
# The game pack interface this app accepts (pack ABI 3): computed by the same
# function, from the same staged runtime, as every PadForge-built pack.
pack_fingerprint="$(PYTHONPATH="$repo_root/builder" python3 -m kartpad_builder.pack_fingerprint android "$runtime_source")"
echo "Pack interface fingerprint: $pack_fingerprint"
if [[ -e "$stage/generated" ]]; then
  echo "ERROR: the publishable app must not see a generated graph: $stage/generated" >&2
  exit 1
fi

if [[ ! -f "$discio_jni_root/arm64-v8a/libkartpad_discio.so" ]]; then
  "$repo_root/scripts/build-android-discio-probe.sh" \
    "$repo_root/ref/upstream/dolphin" \
    "$repo_root/build/dolphin-android-discio-source" \
    "$repo_root/build/dolphin-android-discio-build" \
    "$discio_jni_root"
fi

export JAVA_HOME="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
export DAWN_ANDROID_ROOT="$dawn_root"
export MINIZIP_ANDROID_ROOT="$minizip_root"
export MBEDTLS_ANDROID_ROOT="$mbedtls_root"

"$repo_root/android/gradlew" --project-dir "$repo_root/android" --no-daemon \
  -PkartpadGamePackApp=true \
  -PkartpadPackFingerprint="$pack_fingerprint" \
  -PkartpadGameRuntimeSource="$runtime_source" \
  -PkartpadAndroidNativeTarget=KartPadDual \
  -PkartpadDiscIoJniRoot="$discio_jni_root" \
  ":app:$package_task"

[[ -f "$package_path" ]] || { echo "ERROR: Gradle did not produce $package_path" >&2; exit 1; }
mkdir -p "$stage/out"
cp "$package_path" "$stage/out/"
# The game pack links against exactly this runtime library.
if [[ "$package_format" == aab ]]; then
  unzip -o -q -j "$package_path" 'base/lib/arm64-v8a/libmain.so' -d "$stage/out"
else
  unzip -o -q -j "$package_path" 'lib/arm64-v8a/libmain.so' -d "$stage/out"
fi
echo "Runtime for game packs: $stage/out/libmain.so"
echo "Publishable app (no game code): $stage/out/$(basename "$package_path")"
