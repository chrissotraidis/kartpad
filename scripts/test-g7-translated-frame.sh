#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
build_dir="${repo_root}/build/g7-translated-frame-arm64"
generated_source="${repo_root}/generated/g7/translation/functions/func_80001000.cpp"
expected_sha256="$(cat "${repo_root}/fixtures/g7/func_80001000.sha256")"
output="${1:-${repo_root}/docs/artifacts/2026-08-28/g7-translated-frame.png}"

"${repo_root}/scripts/generate-g7-translated-fixture.sh" >/dev/null
test "$(shasum -a 256 "${generated_source}" | awk '{print $1}')" = "${expected_sha256}"

cmake -S "${repo_root}" -B "${build_dir}" -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0
cmake --build "${build_dir}" --target KartPadG7Frame --parallel 4

app_binary="${build_dir}/KartPadG7Frame.app/Contents/MacOS/KartPadG7Frame"
test -x "${app_binary}"
echo "appBinary=${app_binary}"
echo "output=${output}"
