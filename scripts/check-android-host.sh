#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"

failures=0

fail() {
  echo "ERROR: $*" >&2
  failures=$((failures + 1))
}

pass() {
  echo "PASS: $*"
}

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  fail "A0 currently requires an Apple Silicon macOS host"
else
  pass "Apple Silicon host ($(sw_vers -productVersion))"
fi

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
if [[ ! -d "$sdk_root" ]]; then
  fail "Android SDK root does not exist: $sdk_root"
fi

java_home="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home"
if [[ ! -x "$java_home/bin/java" ]]; then
  fail "pinned Temurin JDK $KARTPAD_ANDROID_JDK_VERSION is unavailable"
else
  java_version="$("$java_home/bin/java" -version 2>&1 | sed -n '1p')"
  if [[ "$java_version" != *'version "17.0.20.1"'* ]]; then
    fail "pinned Temurin JDK $KARTPAD_ANDROID_JDK_VERSION required, found: $java_version"
  else
    pass "$java_version"
  fi
fi

require_file() {
  local description="$1"
  local path="$2"
  if [[ -x "$path" || -f "$path" ]]; then
    pass "$description"
  else
    fail "$description missing at $path"
  fi
}

require_directory() {
  local description="$1"
  local path="$2"
  if [[ -d "$path" ]]; then
    pass "$description"
  else
    fail "$description missing at $path"
  fi
}

require_file "sdkmanager ${KARTPAD_ANDROID_CMDLINE_TOOLS_REVISION}" \
  "$sdk_root/cmdline-tools/$KARTPAD_ANDROID_CMDLINE_TOOLS_REVISION/bin/sdkmanager"
require_file "adb" "$sdk_root/platform-tools/adb"
require_file "emulator" "$sdk_root/emulator/emulator"
require_directory "Android platform ${KARTPAD_ANDROID_COMPILE_SDK}" \
  "$sdk_root/platforms/android-$KARTPAD_ANDROID_COMPILE_SDK"
require_directory "Build Tools ${KARTPAD_ANDROID_BUILD_TOOLS}" \
  "$sdk_root/build-tools/$KARTPAD_ANDROID_BUILD_TOOLS"
require_directory "NDK ${KARTPAD_ANDROID_NDK}" \
  "$sdk_root/ndk/$KARTPAD_ANDROID_NDK"
require_directory "CMake ${KARTPAD_ANDROID_CMAKE}" \
  "$sdk_root/cmake/$KARTPAD_ANDROID_CMAKE"
require_directory "$KARTPAD_ANDROID_PHONE_IMAGE" \
  "$sdk_root/system-images/android-36/google_apis/arm64-v8a"
require_directory "$KARTPAD_ANDROID_PS16K_IMAGE" \
  "$sdk_root/system-images/android-35/google_apis_ps16k/arm64-v8a"

avd_root="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
require_file "AVD $KARTPAD_ANDROID_PHONE_AVD" \
  "$avd_root/$KARTPAD_ANDROID_PHONE_AVD.avd/config.ini"
require_file "AVD $KARTPAD_ANDROID_PS16K_AVD" \
  "$avd_root/$KARTPAD_ANDROID_PS16K_AVD.avd/config.ini"
if [[ -f "$avd_root/$KARTPAD_ANDROID_PHONE_AVD.avd/config.ini" ]] &&
   ! grep -Eq '^image\.sysdir\.1=.*android-36/google_apis/arm64-v8a' \
      "$avd_root/$KARTPAD_ANDROID_PHONE_AVD.avd/config.ini"; then
  fail "AVD $KARTPAD_ANDROID_PHONE_AVD does not use the pinned API 36 ARM64 image"
fi
if [[ -f "$avd_root/$KARTPAD_ANDROID_PS16K_AVD.avd/config.ini" ]] &&
   ! grep -Eq '^image\.sysdir\.1=.*android-35/google_apis_ps16k/arm64-v8a' \
      "$avd_root/$KARTPAD_ANDROID_PS16K_AVD.avd/config.ini"; then
  fail "AVD $KARTPAD_ANDROID_PS16K_AVD does not use the pinned 16 KiB ARM64 image"
fi

if [[ -x "$sdk_root/platform-tools/adb" ]]; then
  pass "$("$sdk_root/platform-tools/adb" version | sed -n '1p')"
fi
if [[ -x "$sdk_root/emulator/emulator" ]]; then
  emulator_version="$("$sdk_root/emulator/emulator" -version 2>/dev/null | sed -n '1p' || true)"
  [[ -n "$emulator_version" ]] && pass "$emulator_version"
fi

if (( failures != 0 )); then
  echo "Android host validation failed with $failures finding(s)." >&2
  echo "Run scripts/bootstrap-android-host.sh explicitly to install pinned public tools." >&2
  exit 1
fi

grep -Fqx 'distributionUrl=https\://services.gradle.org/distributions/gradle-8.13-bin.zip' \
  "$repo_root/android/gradle/wrapper/gradle-wrapper.properties" || \
  fail "Gradle wrapper is not pinned to 8.13"
grep -Fq 'id("com.android.application") version "8.13.2"' \
  "$repo_root/android/build.gradle.kts" || fail "Android Gradle Plugin is not pinned to 8.13.2"
grep -Fq 'id("org.jetbrains.kotlin.android") version "2.2.21"' \
  "$repo_root/android/build.gradle.kts" || fail "Kotlin plugin is not pinned to 2.2.21"

if (( failures != 0 )); then
  echo "Android host validation failed with $failures finding(s)." >&2
  exit 1
fi

echo "Android host validation passed."
