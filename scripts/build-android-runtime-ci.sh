#!/usr/bin/env bash
# Compile the full maintained Android runtime without private game inputs.
# Requires JDK 17 and the pinned SDK/NDK/CMake from android-toolchain-versions.sh.
# This is compile/link evidence only: no game pack, disc importer, signing or upload.
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
stage="${1:?Usage: scripts/build-android-runtime-ci.sh FRESH_STAGE}"
mkdir -p "$stage"
stage="$(cd "$stage" && pwd)"
runtime_source="$stage/runtime"

prepare_output="$("$repo_root/scripts/prepare-android-dependencies.sh")"
echo "$prepare_output"
export DAWN_ANDROID_ROOT="$(printf '%s\n' "$prepare_output" | sed -n 's/^DAWN_ANDROID_ROOT=//p')"
export MINIZIP_ANDROID_ROOT="$(printf '%s\n' "$prepare_output" | sed -n 's/^MINIZIP_ANDROID_ROOT=//p')"
export MBEDTLS_ANDROID_ROOT="$(printf '%s\n' "$prepare_output" | sed -n 's/^MBEDTLS_ANDROID_ROOT=//p')"
test -n "$DAWN_ANDROID_ROOT" && test -n "$MINIZIP_ANDROID_ROOT" && test -n "$MBEDTLS_ANDROID_ROOT"

python3 "$repo_root/scripts/stage-maintained-runtime.py" android "$runtime_source"
PYTHONPATH="$repo_root/builder" python3 -m kartpad_builder.runtime_stage extras "$runtime_source"
cp "$repo_root/runtime/include/kartpad/android/trace_scope.h" \
  "$runtime_source/aurora-main/lib/kartpad_android_trace_scope.h"
python3 "$repo_root/scripts/stage-maintained-runtime.py" --verify android "$runtime_source"
pack_fingerprint="$(PYTHONPATH="$repo_root/builder" python3 -m kartpad_builder.pack_fingerprint android "$runtime_source")"
"$repo_root/android/gradlew" --project-dir "$repo_root/android" --no-daemon --max-workers=2 \
  -PkartpadGamePackApp=true -PkartpadPackFingerprint="$pack_fingerprint" \
  -PkartpadGameRuntimeSource="$runtime_source" -PkartpadAndroidNativeTarget=KartPadDual \
  :app:assembleDebug
