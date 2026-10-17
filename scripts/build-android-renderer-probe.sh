#!/usr/bin/env bash
# Build an unsigned, separate diagnostic APK. Does not install or publish.
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
source "$repo_root/scripts/android-toolchain-versions.sh"
export JAVA_HOME="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home"
export ANDROID_HOME="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
export KARTPAD_PROBE_PYTHON="$(command -v python3)"
# Use the same hash-verified Dawn build as the game, including its CMake relocation.
prepared="$("$repo_root/scripts/prepare-android-dependencies.sh")"
export KARTPAD_PROBE_DAWN_ROOT="$(printf '%s\n' "$prepared" | sed -n 's/^DAWN_ANDROID_ROOT=//p')"
[[ -n "$KARTPAD_PROBE_DAWN_ROOT" ]] || { echo 'Dawn preparation did not report a root.' >&2; exit 66; }
"$repo_root/android/gradlew" --project-dir "$repo_root/tools/renderer-probe/android" --no-daemon assembleRelease
