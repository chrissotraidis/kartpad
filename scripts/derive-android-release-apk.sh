#!/usr/bin/env bash
# Derive a public-signing candidate only; never install, upload or generate keys.
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
release_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "${repo_root}/version.json" version)"
release_build="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]])' "${repo_root}/version.json" build)"
source "$repo_root/scripts/android-toolchain-versions.sh"
if [[ $# != 2 ]]; then
  echo "Usage: $0 INPUT.aab OUTPUT.apk" >&2
  echo "Required: KARTPAD_ANDROID_KEYSTORE, KARTPAD_ANDROID_KEY_ALIAS, KARTPAD_ANDROID_PASSWORD_FILE" >&2
  exit 64
fi
bundle="$1"
output="$2"
: "${KARTPAD_ANDROID_KEYSTORE:?Provide a persistent private release keystore}"
: "${KARTPAD_ANDROID_KEY_ALIAS:?Provide the release key alias}"
: "${KARTPAD_ANDROID_PASSWORD_FILE:?Provide a private password file (same key/store password)}"
[[ -f "$KARTPAD_ANDROID_KEYSTORE" && -f "$KARTPAD_ANDROID_PASSWORD_FILE" ]] || exit 66
if [[ "$KARTPAD_ANDROID_KEY_ALIAS" == androiddebugkey ]]; then
  echo "ERROR: the local Android debug identity is not a public release signer" >&2
  exit 65
fi
[[ ! -e "$output" ]] || { echo "ERROR: output exists; choose a new path" >&2; exit 73; }
export JAVA_HOME="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
bundletool="$repo_root/.android-bootstrap/dependencies/bundletool-all-1.18.1.jar"
export KARTPAD_ANDROID_EXPECTED_VERSION_NAME="${KARTPAD_ANDROID_EXPECTED_VERSION_NAME:-${release_version}}"
export KARTPAD_ANDROID_EXPECTED_VERSION_CODE="${KARTPAD_ANDROID_EXPECTED_VERSION_CODE:-${release_build}}"
export KARTPAD_ANDROID_REQUIRE_RELEASE=1
"$repo_root/scripts/audit-android-bundle.sh" "$bundle"
identity="$("$JAVA_HOME/bin/keytool" -list -v -keystore "$KARTPAD_ANDROID_KEYSTORE" \
  -alias "$KARTPAD_ANDROID_KEY_ALIAS" -storepass:file "$KARTPAD_ANDROID_PASSWORD_FILE")"
if [[ "$identity" == *'CN=Android Debug'* || "$KARTPAD_ANDROID_KEY_ALIAS" == androiddebugkey ]]; then
  echo "ERROR: the local Android debug identity is not a public release signer" >&2
  exit 65
fi
mkdir -p "$repo_root/.android-bootstrap" "$(dirname "$output")"
work="$(mktemp -d "$repo_root/.android-bootstrap/release-derive.XXXXXX")"
# Retain local intermediates for audit/recovery; the caller controls cleanup.
"$JAVA_HOME/bin/java" -jar "$bundletool" build-apks --bundle="$bundle" \
  --output="$work/release.apks" --mode=universal \
  --ks="$KARTPAD_ANDROID_KEYSTORE" --ks-key-alias="$KARTPAD_ANDROID_KEY_ALIAS" \
  --ks-pass="file:$KARTPAD_ANDROID_PASSWORD_FILE" \
  --key-pass="file:$KARTPAD_ANDROID_PASSWORD_FILE"
unzip -p "$work/release.apks" universal.apk > "$work/candidate.apk"
"$sdk_root/build-tools/$KARTPAD_ANDROID_BUILD_TOOLS/apksigner" verify \
  --verbose --print-certs "$work/candidate.apk"
"$repo_root/scripts/audit-android-package.sh" "$work/candidate.apk"
cp -n "$work/candidate.apk" "$output"
echo "Audited release-signing candidate: $output"
shasum -a 256 "$output"
stat -f 'apk_bytes=%z' "$output"
echo "No installation or publication was performed. Preserve the private signing identity."
