#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
build_dir="${repo_root}/build/g7-aurora-translated-gx"
capture_path="${build_dir}/g7-aurora-translated-gx.bmp"
dawn_archive="${repo_root}/build/dependency-cache/dawn-darwin-arm64-v20260603.191052.tar.gz"

"${repo_root}/scripts/generate-g7-translated-fixture.sh" >/dev/null
test "$(shasum -a 256 "${repo_root}/generated/g7/translation/functions/func_80001000.cpp" | awk '{print $1}')" = \
  "$(cat "${repo_root}/fixtures/g7/func_80001000.sha256")"

cmake_args=(
  -S "${repo_root}"
  -B "${build_dir}"
  -G Ninja
  -DCMAKE_BUILD_TYPE=RelWithDebInfo
  -DCMAKE_OSX_ARCHITECTURES=arm64
  -DMKW_BUILD_AURORA_G7_FIXTURES=ON
)
if [[ -f "${dawn_archive}" ]]; then
  cmake_args+=("-DAURORA_DAWN_PACKAGE_URL=file://${dawn_archive}")
fi

cmake "${cmake_args[@]}"
cmake --build "${build_dir}" --target kartpad_g7_aurora_translated_gx --parallel 4
"${build_dir}/kartpad_g7_aurora_translated_gx" "${capture_path}"
test -s "${capture_path}"

pixel_offset="$(od -An -tu4 -j 10 -N 4 "${capture_path}" | tr -d '[:space:]')"
width="$(od -An -tu4 -j 18 -N 4 "${capture_path}" | tr -d '[:space:]')"
height="$(od -An -tu4 -j 22 -N 4 "${capture_path}" | tr -d '[:space:]')"
file_size="$(stat -f '%z' "${capture_path}")"
center_offset="$((pixel_offset + (height - 1 - height / 2) * width * 4 + (width / 2) * 4))"
first_pixel="$(od -An -tx1 -v -j "${pixel_offset}" -N 4 "${capture_path}" | tr -d '[:space:]')"
center_pixel="$(od -An -tx1 -v -j "${center_offset}" -N 4 "${capture_path}" | tr -d '[:space:]')"
last_pixel="$(od -An -tx1 -v -j "$((file_size - 4))" -N 4 "${capture_path}" | tr -d '[:space:]')"

if (( width == 0 || height == 0 )); then
  echo "ERROR: translated GX capture has invalid dimensions ${width}x${height}" >&2
  exit 1
fi
if [[ "${first_pixel}" != "302010ff" || "${last_pixel}" != "302010ff" ]]; then
  echo "ERROR: expected translated #102030ff background, got ${first_pixel}/${last_pixel}" >&2
  exit 1
fi
if [[ "${center_pixel}" != "000000ff" ]]; then
  echo "ERROR: expected translated GX triangle at capture center, got ${center_pixel}" >&2
  exit 1
fi

echo "Validated translated PPC -> checked memory -> GX -> Aurora -> Dawn -> Metal: ${width}x${height}"
echo "background BGRA=302010ff center-triangle BGRA=000000ff"
shasum -a 256 "${capture_path}"
