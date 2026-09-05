#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
"$repo_root/scripts/check-android-host.sh"
prepare_output="$("$repo_root/scripts/prepare-android-dependencies.sh")"
echo "$prepare_output"
dawn_root="$(printf '%s\n' "$prepare_output" | sed -n 's/^DAWN_ANDROID_ROOT=//p')"
minizip_root="$(printf '%s\n' "$prepare_output" | sed -n 's/^MINIZIP_ANDROID_ROOT=//p')"
mbedtls_root="$(printf '%s\n' "$prepare_output" | sed -n 's/^MBEDTLS_ANDROID_ROOT=//p')"
if [[ -z "$dawn_root" || -z "$minizip_root" || -z "$mbedtls_root" ]]; then
  echo "ERROR: dependency preparation did not report native dependency roots" >&2
  exit 1
fi

export JAVA_HOME="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
export DAWN_ANDROID_ROOT="$dawn_root"
export MINIZIP_ANDROID_ROOT="$minizip_root"
export MBEDTLS_ANDROID_ROOT="$mbedtls_root"

"$repo_root/android/gradlew" --project-dir "$repo_root/android" \
  --no-daemon :app:assembleDebug
