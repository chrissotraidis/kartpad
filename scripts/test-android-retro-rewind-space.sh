#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# shellcheck source=android-toolchain-versions.sh
source "${repo_root}/scripts/android-toolchain-versions.sh"
java_home="${repo_root}/.android-bootstrap/jdk-${KARTPAD_ANDROID_JDK_VERSION}/Contents/Home"
classes="${repo_root}/build/android-retro-rewind-space-tests"

if [[ ! -x "${java_home}/bin/javac" || ! -x "${java_home}/bin/java" ]]; then
  echo "ERROR: pinned Android JDK is unavailable; run scripts/bootstrap-android-host.sh" >&2
  exit 1
fi

mkdir -p "${classes}"
find "${classes}" -type f -delete
"${java_home}/bin/javac" -Werror -Xlint:all -d "${classes}" \
  "${repo_root}/android/app/src/main/java/dev/kartpad/android/RetroRewindRelease.java" \
  "${repo_root}/android/app/src/main/java/dev/kartpad/android/RetroRewindSpacePreflight.java" \
  "${repo_root}/android/app/src/test/java/dev/kartpad/android/RetroRewindSpacePreflightTestMain.java"
"${java_home}/bin/java" -cp "${classes}" \
  dev.kartpad.android.RetroRewindSpacePreflightTestMain
echo "Android Retro Rewind space preflight passed."
