#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"

sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
mkdir -p "$sdk_root" "$repo_root/.android-bootstrap"
jdk_archive="$repo_root/.android-bootstrap/$KARTPAD_ANDROID_JDK_ARCHIVE"
if [[ ! -f "$jdk_archive" ]]; then
  curl --fail --location --show-error --progress-bar \
    "$KARTPAD_ANDROID_JDK_URL" -o "$jdk_archive"
fi
jdk_bytes="$(stat -f '%z' "$jdk_archive")"
jdk_sha256="$(shasum -a 256 "$jdk_archive" | awk '{print $1}')"
if [[ "$jdk_bytes" != "$KARTPAD_ANDROID_JDK_BYTES" || \
      "$jdk_sha256" != "$KARTPAD_ANDROID_JDK_SHA256" ]]; then
  echo "ERROR: Temurin JDK archive failed its pinned size/hash check." >&2
  exit 1
fi
jdk_root="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION"
if [[ ! -x "$jdk_root/Contents/Home/bin/java" ]]; then
  jdk_staging="$repo_root/.android-bootstrap/jdk-staging"
  mkdir -p "$jdk_staging"
  tar -xzf "$jdk_archive" -C "$jdk_staging"
  extracted_jdk="$(find "$jdk_staging" -mindepth 1 -maxdepth 1 -type d -print -quit)"
  [[ -n "$extracted_jdk" ]] || { echo "ERROR: JDK archive was empty" >&2; exit 1; }
  mv "$extracted_jdk" "$jdk_root"
  rmdir "$jdk_staging"
fi
export JAVA_HOME="$jdk_root/Contents/Home"

archive="$repo_root/.android-bootstrap/$KARTPAD_ANDROID_CMDLINE_TOOLS_ARCHIVE"
archive_url="https://dl.google.com/android/repository/$KARTPAD_ANDROID_CMDLINE_TOOLS_ARCHIVE"
if [[ ! -f "$archive" ]]; then
  curl --fail --location --show-error --progress-bar "$archive_url" -o "$archive"
fi
actual_bytes="$(stat -f '%z' "$archive")"
actual_sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
if [[ "$actual_bytes" != "$KARTPAD_ANDROID_CMDLINE_TOOLS_BYTES" || \
      "$actual_sha256" != "$KARTPAD_ANDROID_CMDLINE_TOOLS_SHA256" ]]; then
  echo "ERROR: Android command-line tools archive failed its pinned size/hash check." >&2
  exit 1
fi

tools_root="$sdk_root/cmdline-tools/$KARTPAD_ANDROID_CMDLINE_TOOLS_REVISION"
if [[ ! -x "$tools_root/bin/sdkmanager" ]]; then
  staging="$repo_root/.android-bootstrap/cmdline-tools-$KARTPAD_ANDROID_CMDLINE_TOOLS_REVISION"
  mkdir -p "$staging"
  ditto -x -k "$archive" "$staging"
  mkdir -p "$(dirname "$tools_root")"
  mv "$staging/cmdline-tools" "$tools_root"
fi

sdkmanager="$tools_root/bin/sdkmanager"
packages=(
  "platform-tools"
  "platforms;android-$KARTPAD_ANDROID_COMPILE_SDK"
  "build-tools;$KARTPAD_ANDROID_BUILD_TOOLS"
  "ndk;$KARTPAD_ANDROID_NDK"
  "cmake;$KARTPAD_ANDROID_CMAKE"
  "emulator"
  "$KARTPAD_ANDROID_PHONE_IMAGE"
  "$KARTPAD_ANDROID_PS16K_IMAGE"
)

echo "Installing pinned Android packages into $sdk_root"
echo "If sdkmanager reports an unaccepted license, stop and accept it interactively in Android Studio; this script never accepts terms on your behalf."
"$sdkmanager" --sdk_root="$sdk_root" "${packages[@]}"

avdmanager="$tools_root/bin/avdmanager"
avd_root="${ANDROID_AVD_HOME:-$HOME/.android/avd}"
create_avd() {
  local name="$1"
  local package="$2"
  local device="$3"
  if [[ -f "$avd_root/$name.avd/config.ini" ]]; then
    echo "Keeping existing AVD $name"
    return
  fi
  printf 'no\n' | "$avdmanager" create avd --name "$name" \
    --package "$package" --device "$device"
}
create_avd "$KARTPAD_ANDROID_PHONE_AVD" "$KARTPAD_ANDROID_PHONE_IMAGE" "pixel_6"
create_avd "$KARTPAD_ANDROID_TABLET_AVD" "$KARTPAD_ANDROID_PHONE_IMAGE" "pixel_tablet"
create_avd "$KARTPAD_ANDROID_PS16K_AVD" "$KARTPAD_ANDROID_PS16K_IMAGE" "pixel_6"

"$repo_root/scripts/check-android-host.sh"
