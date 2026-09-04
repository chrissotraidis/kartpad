#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
absolute_from_repo() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "${repo_root}" "$1" ;;
  esac
}
runtime_ref="${repo_root}/ref/upstream/Wiicompiled/runtime"
translation_root="$(absolute_from_repo "${1:-private/g8-full-translation}")"
runtime_source="$(absolute_from_repo "${2:-build/g7-game-runtime-source}")"
runtime_build="$(absolute_from_repo "${3:-build/g7-game-runtime-build}")"
product="${4:-base}"
dawn_archive="${repo_root}/build/dependency-cache/dawn-darwin-arm64-v20260603.191052.tar.gz"
sse2neon_url="https://raw.githubusercontent.com/DLTcollab/sse2neon/13a42df35dc7fcc94f987568e7274a998bb6cc86/sse2neon.h"
sse2neon_sha256="44b9fa3dec3a52ea473246e04b9f692a4e5b0ed654299eef7fe7ec3049e223e0"

case "${product}" in
  base) product_target="WiiCompiled" ;;
  retro-rewind) product_target="RetroRewind" ;;
  dual) product_target="KartPadDual" ;;
  *) echo "ERROR: product must be base, retro-rewind, or dual" >&2; exit 64 ;;
esac

if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "ERROR: the G7 game-runtime spike requires arm64 macOS" >&2
  exit 1
fi
if [[ ! -f "${translation_root}/build_shards/shards.cmake" ]]; then
  echo "ERROR: missing real-title translation: ${translation_root}" >&2
  exit 1
fi
if [[ ! -f "${dawn_archive}" ]]; then
  echo "ERROR: missing pinned Dawn archive: ${dawn_archive}" >&2
  exit 1
fi
if [[ -e "${runtime_source}" || -e "${runtime_build}" ]]; then
  echo "ERROR: output already exists; choose fresh output paths" >&2
  exit 1
fi

mkdir -p "$(dirname "${runtime_source}")"
cp -R "${runtime_ref}" "${runtime_source}"
# Build against a disposable Aurora copy so performance instrumentation never
# mutates the immutable pinned reference checkout.
cp -R "${repo_root}/ref/upstream/Wiicompiled/aurora-main" \
  "${runtime_source}/aurora-main"
patch --batch -p1 -d "${runtime_source}/aurora-main" < \
  "${repo_root}/patches/aurora-present-telemetry.patch"
patch --batch -p1 -d "${runtime_source}/aurora-main" < \
  "${repo_root}/patches/aurora-gx-resolve-snapshot-copy-src.patch"
patch -p1 -d "${runtime_source}" < "${repo_root}/patches/wiicompiled-apple-runtime.patch"
patch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-rfl-alarm-context.patch"
patch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-experimental-wiimote-preset.patch"
patch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-macos-cursor-visibility.patch"
patch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-apple-network-tls.patch"
patch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-local-wfc-test-route.patch"
patch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-offline-kd-services.patch"
patch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-blocking-stream-recv-wait.patch"
patch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-mii-seed.patch"
patch -p1 -d "${runtime_source}" < "${repo_root}/patches/wiicompiled-macos-shell.patch"
patch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-retro-apple-product.patch"
for dual_patch in \
    wiicompiled-dual-profile-registry.patch \
    wiicompiled-dual-profile-mod-loader.patch \
    wiicompiled-dual-product-selection.patch \
    wiicompiled-dual-product-target.patch; do
  patch --batch -p1 -d "${runtime_source}" < "${repo_root}/patches/${dual_patch}"
done
patch --batch -p1 -d "${runtime_source}" < \
  "${repo_root}/patches/wiicompiled-present-telemetry.patch"

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

# Mach-O C symbols have a leading underscore. The translator's assembly blob
# labels are emitted in ELF/COFF spelling, so publish both spellings without
# changing the bytes or the generated C++ graph.
for blob_asm in \
    "${translation_root}/data_sections_init_blobs.S" \
    "${translation_root}/../mod/cpp/mod_data_patches_blobs.S"; do
  if [[ -f "${blob_asm}" ]] && rg -q '^\.globl k' "${blob_asm}" &&
     ! rg -q '^\.globl _k' "${blob_asm}"; then
    perl -0pi -e 's/^\.globl (k[^\n]+)\n\1:/\.globl $1\n.globl _$1\n$1:\n_$1:/mg' "${blob_asm}"
  fi
done

generated_link="${repo_root}/build/generated"
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
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DMKW_AURORA_DIR="${runtime_source}/aurora-main" \
  -DAURORA_DAWN_PACKAGE_URL="file://${dawn_archive}" \
  -DMKW_TRANSLATED_SHARD_MANIFEST="${translation_root}/build_shards/shards.cmake" \
  -DMKW_KARTPAD_RUNTIME_INCLUDE="${repo_root}/runtime/include" \
  -DMKW_KARTPAD_REPO_ROOT="${repo_root}" \
  -DMKW_TRANSLATED_COMPILE_JOBS=2
cmake --build "${runtime_build}" --target "${product_target}" --parallel 4

echo "Built translated Mario Kart Wii runtime: ${runtime_build}/${product_target}"
