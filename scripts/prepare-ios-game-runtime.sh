#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
absolute_from_repo() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "${repo_root}" "$1" ;;
  esac
}

translation_root="$(absolute_from_repo "${1:-private/g8-full-translation}")"
runtime_source="$(absolute_from_repo "${2:-build/g14-ios-game-runtime-source}")"
runtime_build="$(absolute_from_repo "${3:-build/g14-ios-game-runtime-build}")"
product="${4:-base}"
dawn_archive="${repo_root}/build/dependency-cache/dawn-ios-simulator-arm64-v20260603.191052.tar.gz"
dawn_sha256="feb5c4e07da90c47d2f279bf83c43bc67db01dac1138cb9af8ea9b5b50c67fbf"
discio_source="${KARTPAD_DISCIO_SOURCE_DIR:-${repo_root}/build/dolphin-ios-discio-iphonesimulator-source}"
discio_build="${KARTPAD_DISCIO_BUILD_DIR:-${repo_root}/build/dolphin-ios-discio-iphonesimulator-build}"
prepare_only="${KARTPAD_PREPARE_ONLY:-0}"
# The publishable game-pack app stages the runtime without any translation.
without_translation="${KARTPAD_PREPARE_WITHOUT_TRANSLATION:-0}"

case "${product}" in
  base) product_target="WiiCompiled" ;;
  retro-rewind) product_target="RetroRewind" ;;
  dual) product_target="KartPadDual" ;;
  *) echo "ERROR: product must be base, retro-rewind, or dual" >&2; exit 64 ;;
esac

if [[ "${prepare_only}" != "0" && "${prepare_only}" != "1" ]]; then
  echo "ERROR: KARTPAD_PREPARE_ONLY must be 0 or 1" >&2
  exit 64
fi
if [[ "${without_translation}" == "1" && "${prepare_only}" != "1" ]]; then
  echo "ERROR: KARTPAD_PREPARE_WITHOUT_TRANSLATION requires KARTPAD_PREPARE_ONLY=1" >&2
  exit 64
fi

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "ERROR: the iOS game-runtime build requires arm64 macOS" >&2
  exit 1
fi
if [[ "${without_translation}" != "1" ]]; then
  if [[ ! -f "${translation_root}/build_shards/shards.cmake" ]]; then
    echo "ERROR: missing real-title translation: ${translation_root}" >&2
    exit 1
  fi
  python3 "${repo_root}/scripts/inject-retro-rel-report-guard.py" --verify \
    "${translation_root}/functions/func_8000A440.cpp"
  python3 "${repo_root}/scripts/inject-retro-rel-report-guard.py" --verify-shards \
    "${translation_root}/build_shards"
fi
if [[ -e "${runtime_source}" || -e "${runtime_build}" ]]; then
  echo "ERROR: output already exists; choose fresh output paths" >&2
  exit 1
fi
if [[ "${prepare_only}" == "0" && ! -f "${dawn_archive}" ]]; then
  echo "ERROR: missing pinned Simulator Dawn archive; run scripts/build-dawn-ios-simulator.sh" >&2
  exit 1
fi
if [[ "${prepare_only}" == "0" ]]; then
  if [[ ! -f "${discio_source}/Source/Core/DiscIO/DiscExtractor.h" ||
        ! -f "${discio_build}/Source/Core/DiscIO/libdiscio.a" ]]; then
    echo "ERROR: missing iOS Simulator DiscIO dependency; run scripts/build-ios-discio-probe.sh" >&2
    exit 1
  fi
fi
if [[ "${prepare_only}" == "0" ]]; then
  actual_dawn_sha256="$(shasum -a 256 "${dawn_archive}" | awk '{print $1}')"
  if [[ "${actual_dawn_sha256}" != "${dawn_sha256}" ]]; then
    echo "ERROR: Simulator Dawn hash mismatch: ${actual_dawn_sha256}" >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "${runtime_source}")"
# Android and tvOS share generated/profile inputs, but each selects its own
# maintained source commit; platform changes are no longer layered as patches.
prepare_platform="${KARTPAD_PREPARE_PLATFORM:-ios}"
case "${prepare_platform}" in
  apple) prepare_platform=ios ;; # Preserve the historical selector spelling.
  ios|android|tvos) ;;
  *) echo "ERROR: unsupported preparation platform: ${prepare_platform}" >&2; exit 64 ;;
esac
python3 "${repo_root}/scripts/stage-maintained-runtime.py" "${prepare_platform}" "${runtime_source}"
# Retro Rewind release header and pinned sse2neon (shared with the
# cross-platform game-pack build).
PYTHONPATH="${repo_root}/builder" python3 -m kartpad_builder.runtime_stage extras "${runtime_source}"

if [[ "${prepare_only}" == "1" ]]; then
  echo "Prepared integrated iOS runtime source: ${runtime_source}"
  exit 0
fi

# Mach-O C symbols have a leading underscore. Publish both spellings for the
# translator's assembly blobs without changing their contents.
for blob_asm in \
    "${translation_root}/data_sections_init_blobs.S" \
    "${translation_root}/../mod/cpp/mod_data_patches_blobs.S"; do
  if [[ -f "${blob_asm}" ]] && rg -q '^\.globl k' "${blob_asm}" &&
     ! rg -q '^\.globl _k' "${blob_asm}"; then
    perl -0pi -e 's/^\.globl (k[^\n]+)\n\1:/\.globl $1\n.globl _$1\n$1:\n_$1:/mg' "${blob_asm}"
  fi
done

generated_link="$(dirname "${runtime_source}")/generated"
if [[ -e "${generated_link}" && ! -L "${generated_link}" ]]; then
  echo "ERROR: generated path exists and is not a symlink: ${generated_link}" >&2
  exit 1
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

cmake -S "${runtime_source}" -B "${runtime_build}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_SYSTEM_PROCESSOR=arm64 \
  -DCMAKE_OSX_SYSROOT=iphonesimulator \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
  -DMKW_AURORA_DIR="${runtime_source}/aurora-main" \
  -DAURORA_DAWN_PACKAGE_URL="file://${dawn_archive}" \
  -DMKW_TRANSLATED_SHARD_MANIFEST="${translation_root}/build_shards/shards.cmake" \
  -DMKW_KARTPAD_RUNTIME_INCLUDE="${repo_root}/runtime/include" \
  -DMKW_KARTPAD_REPO_ROOT="${repo_root}" \
  -DMKW_KARTPAD_DISCIO_SOURCE_DIR="${discio_source}" \
  -DMKW_KARTPAD_DISCIO_BUILD_DIR="${discio_build}" \
  -DMKW_TRANSLATED_COMPILE_JOBS=2
cmake --build "${runtime_build}" --target "${product_target}" --parallel 2

binary="${runtime_build}/KartPad.app/KartPad"
if [[ ! -x "${binary}" ]]; then
  echo "ERROR: missing linked Simulator runtime: ${binary}" >&2
  exit 1
fi
if ! xcrun vtool -show-build "${binary}" | rg -q 'platform IOSSIMULATOR'; then
  echo "ERROR: linked runtime is not an iOS Simulator Mach-O" >&2
  exit 1
fi
if otool -L "${binary}" | rg -q '/opt/homebrew|/usr/local'; then
  echo "ERROR: linked runtime contains a host-only library dependency" >&2
  exit 1
fi

echo "Built full translated iOS Simulator runtime: ${binary}"
shasum -a 256 "${binary}"
