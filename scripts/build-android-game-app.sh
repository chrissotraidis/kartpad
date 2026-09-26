#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
version_code_override="${KARTPAD_ANDROID_VERSION_CODE:-}"
version_name_override="${KARTPAD_ANDROID_VERSION_NAME:-}"
package_format="${KARTPAD_ANDROID_PACKAGE_FORMAT:-apk}"
profileable="${KARTPAD_ANDROID_PROFILEABLE:-0}"
native_tls="${KARTPAD_ANDROID_NATIVE_TLS_EXPERIMENT:-0}"
frame_capture="${KARTPAD_ANDROID_FRAME_CAPTURE:-0}"
case "$native_tls" in
  0|1) ;;
  *) echo "ERROR: KARTPAD_ANDROID_NATIVE_TLS_EXPERIMENT must be 0 or 1" >&2; exit 64 ;;
esac
if [[ "$native_tls" == 1 && "$version_name_override" != *-native-tls* ]]; then
  echo "ERROR: native TLS experiments require an explicit version name containing -native-tls" >&2
  exit 64
fi
case "$frame_capture" in
  0|1) ;;
  *) echo "ERROR: KARTPAD_ANDROID_FRAME_CAPTURE must be 0 or 1" >&2; exit 64 ;;
esac
if [[ "$frame_capture" == 1 && ( "$package_format" != apk-release || "$version_name_override" != *-capture ) ]]; then
  echo "ERROR: frame capture requires apk-release and an explicit version name ending in -capture" >&2
  exit 64
fi
case "$profileable" in
  0|1) ;;
  *) echo "ERROR: KARTPAD_ANDROID_PROFILEABLE must be 0 or 1" >&2; exit 64 ;;
esac
case "$package_format" in
  apk) package_task=assembleDebug; package_kind=APK ;;
  apk-release) package_task=assembleRelease; package_kind="private release APK" ;;
  aab) package_task=bundleRelease; package_kind="unsigned AAB" ;;
  *)
    echo "ERROR: KARTPAD_ANDROID_PACKAGE_FORMAT must be apk, apk-release or aab" >&2
    exit 64
    ;;
esac
if [[ -n "$version_code_override" &&
    ! "$version_code_override" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: KARTPAD_ANDROID_VERSION_CODE must be a positive integer" >&2
  exit 64
fi
if [[ -n "$version_name_override" &&
    ! "$version_name_override" =~ ^[0-9A-Za-z][0-9A-Za-z._-]{0,63}$ ]]; then
  echo "ERROR: KARTPAD_ANDROID_VERSION_NAME must contain 1-64 portable version characters" >&2
  exit 64
fi

absolute_from_repo() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$repo_root" "$1" ;;
  esac
}

translation_root="$(absolute_from_repo "${1:-private/g8-full-translation}")"
runtime_source="$(absolute_from_repo "${2:-build/android-game-runtime-source}")"
runtime_build="$(absolute_from_repo "${3:-build/android-game-runtime-build}")"
discio_jni_root="${KARTPAD_DISCIO_JNI_ROOT:-$repo_root/build/dolphin-android-discio-jni}"

python3 "$repo_root/scripts/inject-retro-rel-report-guard.py" --verify \
  "$translation_root/functions/func_8000A440.cpp"
python3 "$repo_root/scripts/inject-retro-rel-report-guard.py" --verify-shards \
  "$translation_root/build_shards"

native_target="WiiCompiled"
runtime_product="base"
if grep -Eq '^set\(MKW_HAVE_RETRO_REWIND_SHARDS ON\)' \
  "$translation_root/build_shards/shards.cmake"; then
  native_target="KartPadDual"
  runtime_product="dual"
fi

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
if [[ ! -d "$runtime_source" ]]; then
  "$repo_root/scripts/prepare-android-game-runtime.sh" \
    "$translation_root" "$runtime_source" "$runtime_build" "$runtime_product"
fi
python3 "$repo_root/scripts/stage-maintained-runtime.py" --verify android "$runtime_source"

if [[ ! -f "$runtime_source/include/sc_serial_contract.h" ||
      ! -f "$runtime_source/src/hle/sc.cpp" ]] ||
   ! grep -Fq 'RuntimeScSerial::Write' "$runtime_source/src/hle/sc.cpp"; then
  echo "ERROR: prepared runtime is missing the numeric console-serial ABI guard; use a fresh runtime source" >&2
  exit 1
fi
if [[ ! -f "$(dirname "$runtime_source")/generated/data_sections_init.cpp" ]]; then
  echo "ERROR: prepared runtime is not paired with its ignored generated graph" >&2
  exit 1
fi
if [[ ! -f "$discio_jni_root/arm64-v8a/libkartpad_discio.so" ]]; then
  if [[ -f "$repo_root/build/dolphin-android-discio-build/CMakeCache.txt" ]]; then
    KARTPAD_DISCIO_RESUME=1 "$repo_root/scripts/build-android-discio-probe.sh" \
      "$repo_root/ref/upstream/dolphin" \
      "$repo_root/build/dolphin-android-discio-source" \
      "$repo_root/build/dolphin-android-discio-build" \
      "$discio_jni_root"
  else
    "$repo_root/scripts/build-android-discio-probe.sh" \
      "$repo_root/ref/upstream/dolphin" \
      "$repo_root/build/dolphin-android-discio-source" \
      "$repo_root/build/dolphin-android-discio-build" \
      "$discio_jni_root"
  fi
fi
if ! grep -a -F -q 'ISO, WBFS or RVZ image' "$discio_jni_root/arm64-v8a/libkartpad_discio.so"; then
  echo "ERROR: $discio_jni_root/arm64-v8a/libkartpad_discio.so predates RVZ import." >&2
  echo "Rebuild it with scripts/build-android-discio-probe.sh into a fresh stage directory." >&2
  exit 1
fi

export JAVA_HOME="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
export DAWN_ANDROID_ROOT="$dawn_root"
export MINIZIP_ANDROID_ROOT="$minizip_root"
export MBEDTLS_ANDROID_ROOT="$mbedtls_root"

gradle_args=(
  --project-dir "$repo_root/android"
  --no-daemon
  -PkartpadGameRuntimeSource="$runtime_source"
  -PkartpadTranslatedShardManifest="$translation_root/build_shards/shards.cmake"
  -PkartpadAndroidNativeTarget="$native_target"
  -PkartpadDiscIoJniRoot="$discio_jni_root"
)
if [[ "$package_format" == apk-release ]]; then
  gradle_args+=("-PkartpadDiagnosticRelease=true")
fi
if [[ "$profileable" == 1 ]]; then
  gradle_args+=("-PkartpadProfileable=true")
  echo "Local profiling enabled; keep performance captures private."
fi
if [[ "$native_tls" == 1 ]]; then
  gradle_args+=("-PkartpadNativeTlsExperiment=true")
  echo "Private native TLS experiment: Android API29 minimum; not compatible with Android 9."
fi
if [[ "$frame_capture" == 1 ]]; then
  gradle_args+=("-PkartpadFrameCapture=true")
  echo "Private RenderDoc capture enabled; optimized native runtime, debuggable package."
fi
if [[ -n "$version_code_override" ]]; then
  gradle_args+=("-PkartpadVersionCode=$version_code_override")
fi
if [[ -n "$version_name_override" ]]; then
  gradle_args+=("-PkartpadVersionName=$version_name_override")
fi

"$repo_root/android/gradlew" "${gradle_args[@]}" \
  ":app:$package_task"

if [[ "$package_format" == apk ]]; then
  package_path="$repo_root/android/app/build/outputs/apk/debug/app-debug.apk"
elif [[ "$package_format" == apk-release ]]; then
  package_path="$repo_root/android/app/build/outputs/apk/release/app-release.apk"
else
  package_path="$repo_root/android/app/build/outputs/bundle/release/app-release.aab"
fi
if [[ ! -f "$package_path" ]]; then
  echo "ERROR: Gradle did not produce $package_path" >&2
  exit 1
fi
echo "Built local Android game $package_kind (do not publish): $package_path"
shasum -a 256 "$package_path"
