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
runtime_ref="${repo_root}/ref/upstream/Wiicompiled/runtime"
dawn_archive="${repo_root}/build/dependency-cache/dawn-ios-simulator-arm64-v20260603.191052.tar.gz"
dawn_sha256="feb5c4e07da90c47d2f279bf83c43bc67db01dac1138cb9af8ea9b5b50c67fbf"
discio_source="${KARTPAD_DISCIO_SOURCE_DIR:-${repo_root}/build/dolphin-ios-discio-iphonesimulator-source}"
discio_build="${KARTPAD_DISCIO_BUILD_DIR:-${repo_root}/build/dolphin-ios-discio-iphonesimulator-build}"
sse2neon_url="https://raw.githubusercontent.com/DLTcollab/sse2neon/13a42df35dc7fcc94f987568e7274a998bb6cc86/sse2neon.h"
sse2neon_sha256="44b9fa3dec3a52ea473246e04b9f692a4e5b0ed654299eef7fe7ec3049e223e0"
prepare_only="${KARTPAD_PREPARE_ONLY:-0}"

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

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "ERROR: the iOS game-runtime build requires arm64 macOS" >&2
  exit 1
fi
if [[ ! -f "${translation_root}/build_shards/shards.cmake" ]]; then
  echo "ERROR: missing real-title translation: ${translation_root}" >&2
  exit 1
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
cp -R "${runtime_ref}" "${runtime_source}"
PYTHONPATH="${repo_root}/builder" python3 -m kartpad_builder.release_header \
  "${repo_root}/builder/profiles/mkwii-rmcp01-rev0.json" \
  "${runtime_source}/third_party/kartpad-profile/kartpad_retro_rewind_release.h"
# Keep the immutable pinned Aurora checkout untouched. The iOS product builds
# against this disposable copy so its opaque letterbox fix is reproducible.
cp -R "${repo_root}/ref/upstream/Wiicompiled/aurora-main" \
  "${runtime_source}/aurora-main"
patch --batch -p1 -d "${runtime_source}/aurora-main" < \
  "${repo_root}/patches/aurora-present-telemetry.patch"
patch --batch -p1 -d "${runtime_source}/aurora-main" < \
  "${repo_root}/patches/aurora-gx-resolve-snapshot-copy-src.patch"
patch --batch -p1 -d "${runtime_source}/aurora-main" < \
  "${repo_root}/patches/aurora-ios-opaque-letterbox.patch"
patch --batch -p1 -d "${runtime_source}/aurora-main" < \
  "${repo_root}/patches/aurora-ios-simulator-single-pipeline-worker.patch"
patch --batch -p1 -d "${runtime_source}" < "${repo_root}/patches/wiicompiled-apple-runtime.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-rfl-alarm-context.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-experimental-wiimote-preset.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-apple-network-tls.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-local-wfc-test-route.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-offline-kd-services.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-blocking-stream-recv-wait.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-mii-seed.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-ios-arm64-fibers.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-present-telemetry.patch"
patch --batch -p1 -d "${runtime_source}" < "${repo_root}/patches/wiicompiled-ios-app-integration.patch"
patch --batch -p1 -d "${runtime_source}" < "${repo_root}/patches/wiicompiled-ios-first-launch-gate.patch"
patch --batch -p1 -d "${runtime_source}" < "${repo_root}/patches/wiicompiled-ios-touch-core-buttons.patch"
patch --batch -p1 -d "${runtime_source}" < "${repo_root}/patches/wiicompiled-ios-settings-bridge.patch"
patch --batch -p1 -d "${runtime_source}" < "${repo_root}/patches/wiicompiled-ios-physical-controllers.patch"
patch --batch -p1 -d "${runtime_source}" < "${repo_root}/patches/wiicompiled-ios-motion-steering.patch"
patch --batch -p1 -d "${runtime_source}" < "${repo_root}/patches/wiicompiled-ios-discio-import.patch"
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-retro-apple-product.patch"
for dual_patch in \
    wiicompiled-dual-profile-registry.patch \
    wiicompiled-dual-profile-mod-loader.patch \
    wiicompiled-dual-product-selection.patch \
    wiicompiled-dual-product-target.patch; do
  patch --batch -p1 -d "${runtime_source}" < "${repo_root}/patches/${dual_patch}"
done

mkdir -p "${runtime_source}/third_party/sse2neon"
cached_sse2neon="${repo_root}/build/dependency-cache/sse2neon-${sse2neon_sha256}.h"
if [[ -f "${cached_sse2neon}" ]] &&
   [[ "$(shasum -a 256 "${cached_sse2neon}" | awk '{print $1}')" == "${sse2neon_sha256}" ]]; then
  cp "${cached_sse2neon}" "${runtime_source}/third_party/sse2neon/sse2neon.h"
else
  curl --fail --location --silent --show-error \
    "${sse2neon_url}" -o "${runtime_source}/third_party/sse2neon/sse2neon.h"
  mkdir -p "$(dirname "${cached_sse2neon}")"
  cp "${runtime_source}/third_party/sse2neon/sse2neon.h" "${cached_sse2neon}"
fi
actual_sse2neon_sha256="$(shasum -a 256 "${runtime_source}/third_party/sse2neon/sse2neon.h" | awk '{print $1}')"
if [[ "${actual_sse2neon_sha256}" != "${sse2neon_sha256}" ]]; then
  echo "ERROR: sse2neon hash mismatch: ${actual_sse2neon_sha256}" >&2
  exit 1
fi

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
