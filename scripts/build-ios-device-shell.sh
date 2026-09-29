#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
build_dir="${1:-${repo_root}/build/ios-device-shell}"

if [[ "${build_dir}" != /* ]]; then
  echo "build directory must be absolute" >&2
  exit 64
fi

"${repo_root}/scripts/generate-g7-translated-fixture.sh" >/dev/null

cmake -S "${repo_root}" -B "${build_dir}" -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=16.0 \
  -DMKW_BUILD_IOS_SIMULATOR=OFF \
  -DMKW_BUILD_IOS_DEVICE=ON \
  -DBUILD_TESTING=OFF
cmake --build "${build_dir}" --config Debug --target KartPad -- \
  -sdk iphoneos CODE_SIGNING_ALLOWED=NO

"${repo_root}/scripts/audit-ios-shell.sh" \
  "${build_dir}/Debug-iphoneos/KartPad.app" IOS
