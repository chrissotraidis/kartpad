#!/usr/bin/env bash
# Build an unsigned, separate diagnostic APK. Does not install or publish.
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
source "$repo_root/scripts/android-toolchain-versions.sh"
export JAVA_HOME="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home"
export ANDROID_HOME="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
export KARTPAD_PROBE_PYTHON="$(command -v python3)"
export KARTPAD_PROBE_DAWN_ROOT="$repo_root/.android-bootstrap/dependencies/dawn-v20260603.191052-android-aarch64"
# The normal Android dependency bootstrap owns downloads and CMake relocation.
# This diagnostic build verifies the pinned archive, then uses those installed inputs.
archive="$repo_root/.android-bootstrap/dependencies/dawn-android-aarch64.tar.gz"
[[ -f "$archive" ]] || { echo 'Run scripts/prepare-android-dependencies.sh first.' >&2; exit 66; }
[[ "$(shasum -a 256 "$archive" | cut -d ' ' -f 1)" == 27d910dee1201fd1e5b6ac567f0ba2306ebf2135e9f40b6929976c365d38b09b ]] || { echo "build-android-renderer-probe.sh: check failed (line 14)" >&2; exit 1; }
"$repo_root/android/gradlew" --project-dir "$repo_root/tools/renderer-probe/android" --no-daemon assembleRelease
