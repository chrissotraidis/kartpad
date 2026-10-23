#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
absolute_from_repo() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "${repo_root}" "$1" ;;
  esac
}
translation_root="$(absolute_from_repo "${1:-private/g8-full-translation}")"
runtime_source="$(absolute_from_repo "${2:-build/g7-game-runtime-source}")"
runtime_build="$(absolute_from_repo "${3:-build/g7-game-runtime-build}")"
product="${4:-base}"
dawn_archive="${repo_root}/build/dependency-cache/dawn-darwin-arm64-v20260603.191052.tar.gz"

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
python3 "${repo_root}/scripts/inject-retro-rel-report-guard.py" --verify \
  "${translation_root}/functions/func_8000A440.cpp"
python3 "${repo_root}/scripts/inject-mkw-texture-link-guard.py" --verify \
  "${translation_root}/functions/func_802289DC.cpp"
python3 "${repo_root}/scripts/inject-retro-rel-report-guard.py" --verify-shards \
  "${translation_root}/build_shards"
python3 "${repo_root}/scripts/inject-mkw-texture-link-guard.py" --verify-shards \
  "${translation_root}/build_shards"
if [[ ! -f "${dawn_archive}" ]]; then
  echo "ERROR: missing pinned Dawn archive: ${dawn_archive}" >&2
  exit 1
fi
if [[ -L "${runtime_source}" || -L "${runtime_build}" ]]; then
  echo "ERROR: runtime source/build must not be symlinks; choose fresh output paths" >&2
  exit 1
fi
if [[ -e "${runtime_build}" ]] &&
   { [[ ! -d "${runtime_source}" || ! -d "${runtime_build}" ||
        ! -f "${runtime_build}/CMakeCache.txt" || -L "${runtime_build}/CMakeCache.txt" ]] ||
     ! grep -Fqx "CMAKE_HOME_DIRECTORY:INTERNAL=${runtime_source}" "${runtime_build}/CMakeCache.txt"; }; then
  echo "ERROR: existing build does not belong to this runtime source; choose fresh output paths" >&2
  exit 1
fi

if [[ ! -e "${runtime_source}" ]]; then
  mkdir -p "$(dirname "${runtime_source}")"
  python3 "${repo_root}/scripts/stage-maintained-runtime.py" macos "${runtime_source}"
fi
# A repeated PadMint run shares this source and its CMake/Ninja cache. Restore
# missing generated headers after an interrupted download, then reject any
# stale or edited source before compiling; never remove an existing workspace.
python3 "${repo_root}/scripts/stage-maintained-runtime.py" --verify --allow-missing-generated macos "${runtime_source}"
PYTHONPATH="${repo_root}/builder" python3 -m kartpad_builder.runtime_stage extras "${runtime_source}"
python3 "${repo_root}/scripts/stage-maintained-runtime.py" --verify macos "${runtime_source}"

# Mach-O C symbols have a leading underscore. The translator's assembly blob
# labels are emitted in ELF/COFF spelling, so publish both spellings without
# changing the bytes or the generated C++ graph.
for blob_asm in \
    "${translation_root}/data_sections_init_blobs.S" \
    "${translation_root}/../mod/cpp/mod_data_patches_blobs.S"; do
  if [[ -f "${blob_asm}" ]] && grep -q '^\.globl k' "${blob_asm}" &&
     ! grep -q '^\.globl _k' "${blob_asm}"; then
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
