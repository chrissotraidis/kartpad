#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
absolute_from_repo() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "${repo_root}" "$1" ;;
  esac
}

runtime_source="$(absolute_from_repo "${1:-build/tvos-game-runtime-source}")"
xcode_build="$(absolute_from_repo "${2:-build/tvos-game-app-xcode}")"
translation_root="$(absolute_from_repo "${3:-private/builder/dual-pipeline-smoke/translation}")"
sdk="${4:-appletvos}"
bundle_identifier="${KARTPAD_TVOS_BUNDLE_IDENTIFIER:-dev.kartpad.tv}"
if [[ ! "${bundle_identifier}" =~ ^[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+$ ]]; then
  echo "ERROR: invalid KARTPAD_TVOS_BUNDLE_IDENTIFIER: ${bundle_identifier}" >&2
  exit 64
fi
case "${sdk}" in
  appletvos)
    dawn_archive="${repo_root}/build/dependency-cache/dawn-tvos-arm64-v20260603.191052.tar.gz"
    output_suffix="appletvos"
    expected_platform="TVOS"
    ;;
  appletvsimulator)
    dawn_archive="${repo_root}/build/dependency-cache/dawn-tvos-simulator-arm64-v20260603.191052.tar.gz"
    output_suffix="appletvsimulator"
    expected_platform="TVOSSIMULATOR"
    ;;
  *) echo "usage: $0 [runtime-source] [xcode-build] [translation-root] [appletvos|appletvsimulator]" >&2; exit 64 ;;
esac

python3 "${repo_root}/scripts/stage-maintained-runtime.py" --verify tvos "${runtime_source}"

if [[ ! -f "${runtime_source}/CMakeLists.txt" ]] ||
   ! rg -q 'mkw_configure_kartpad_tvos' "${runtime_source}/cmake/PublicProducts.cmake"; then
  echo "ERROR: prepare the integrated source with scripts/prepare-tvos-game-runtime.sh" >&2
  exit 66
fi
if [[ ! -f "${translation_root}/build_shards/shards.cmake" ]]; then
  echo "ERROR: missing dual Original/Retro Rewind translation: ${translation_root}" >&2
  exit 66
fi
python3 "${repo_root}/scripts/inject-retro-rel-report-guard.py" --verify \
  "${translation_root}/functions/func_8000A440.cpp"
python3 "${repo_root}/scripts/inject-mkw-texture-link-guard.py" --verify \
  "${translation_root}/functions/func_802289DC.cpp"
python3 "${repo_root}/scripts/inject-retro-rel-report-guard.py" --verify-shards \
  "${translation_root}/build_shards"
python3 "${repo_root}/scripts/inject-mkw-texture-link-guard.py" --verify-shards \
  "${translation_root}/build_shards"
if [[ ! -f "${dawn_archive}" ]]; then
  echo "ERROR: missing pinned tvOS Dawn archive; run scripts/build-dawn-tvos.sh ${sdk}" >&2
  exit 66
fi
dawn_sha256="$(shasum -a 256 "${dawn_archive}" | awk '{print $1}')"
minizip_source="${repo_root}/ref/upstream/dolphin/Externals/minizip-ng/minizip-ng"
if [[ ! -f "${minizip_source}/CMakeLists.txt" ]]; then
  echo "ERROR: missing pinned minizip-ng source in the Dolphin reference" >&2
  exit 66
fi

generated_link="$(dirname "${runtime_source}")/generated"
if [[ -e "${generated_link}" && ! -L "${generated_link}" ]]; then
  echo "ERROR: generated path exists and is not a symlink: ${generated_link}" >&2
  exit 73
fi
previous_generated_target=""
if [[ -L "${generated_link}" ]]; then
  previous_generated_target="$(readlink "${generated_link}")"
fi
restore_generated_link() {
  if [[ -n "${previous_generated_target}" ]]; then
    ln -sfn "${previous_generated_target}" "${generated_link}"
  elif [[ -L "${generated_link}" ]]; then
    rm "${generated_link}"
  fi
}
trap restore_generated_link EXIT
ln -sfn "${translation_root}" "${generated_link}"

plutil -lint "${repo_root}/apple/tvos/RuntimeInfo.plist" \
  "${repo_root}/apple/ios/PrivacyInfo.xcprivacy" >/dev/null
path_map_flags="-ffile-prefix-map=${repo_root}=KartPad -fmacro-prefix-map=${repo_root}=KartPad"
version_cmake_args=()
if [[ -n "${KARTPAD_TVOS_MARKETING_VERSION:-}" ]]; then
  version_cmake_args+=("-DKARTPAD_TVOS_MARKETING_VERSION=${KARTPAD_TVOS_MARKETING_VERSION}")
fi
if [[ -n "${KARTPAD_TVOS_BUILD_NUMBER:-}" ]]; then
  version_cmake_args+=("-DKARTPAD_TVOS_BUILD_NUMBER=${KARTPAD_TVOS_BUILD_NUMBER}")
fi
cmake -S "${runtime_source}" -B "${xcode_build}" -G Xcode \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CONFIGURATION_TYPES=Release \
  -DCMAKE_SYSTEM_NAME=tvOS \
  -DCMAKE_SYSTEM_PROCESSOR=arm64 \
  -DCMAKE_OSX_SYSROOT="${sdk}" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
  -DCMAKE_C_FLAGS_RELEASE="-O3 -DNDEBUG ${path_map_flags}" \
  -DCMAKE_CXX_FLAGS_RELEASE="-O3 -DNDEBUG ${path_map_flags}" \
  -DCMAKE_OBJC_FLAGS_RELEASE="-O3 -DNDEBUG ${path_map_flags}" \
  -DCMAKE_OBJCXX_FLAGS_RELEASE="-O3 -DNDEBUG ${path_map_flags}" \
  -DMKW_AURORA_DIR="${runtime_source}/aurora-main" \
  -DAURORA_DAWN_PACKAGE_URL="file://${dawn_archive}" \
  -DKARTPAD_TVOS_DAWN_SHA256="${dawn_sha256}" \
  -DKARTPAD_TVOS_BUNDLE_IDENTIFIER="${bundle_identifier}" \
  -DMKW_TRANSLATED_SHARD_MANIFEST="${translation_root}/build_shards/shards.cmake" \
  -DMKW_KARTPAD_RUNTIME_INCLUDE="${repo_root}/runtime/include" \
  -DMKW_KARTPAD_REPO_ROOT="${repo_root}" \
  -DMKW_KARTPAD_MINIZIP_SOURCE_DIR="${minizip_source}" \
  "${version_cmake_args[@]}" \
  -DMKW_TRANSLATED_COMPILE_JOBS=2
if [[ "${sdk}" = "appletvos" ]]; then
  project="${xcode_build}/mkw_recompiled.xcodeproj/project.pbxproj"
  if ! rg -F -q -- "'-mcpu=generic' -Xclang -target-feature -Xclang -rcpc" \
      "${project}"; then
    echo "ERROR: tvOS runtime targets are missing the A12-safe compiler baseline" >&2
    exit 69
  fi
fi
cmake --build "${xcode_build}" --config Release --target KartPadDual -- \
  -quiet -sdk "${sdk}" CODE_SIGNING_ALLOWED=NO

app="${xcode_build}/Release-${output_suffix}/KartPad.app"
"${repo_root}/scripts/audit-tvos-app.sh" \
  "${app}" "${expected_platform}" "${bundle_identifier}"
echo "Built native dual-mode tvOS app: ${app}"
