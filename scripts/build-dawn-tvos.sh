#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
lockfile="${repo_root}/dependencies.lock.json"

if [[ "$#" -ne 3 ]]; then
  echo "usage: $0 appletvos|appletvsimulator WORK_DIR OUTPUT_ARCHIVE" >&2
  exit 64
fi

platform="$1"
case "${platform}" in
  appletvos)
    cmake_system="tvOS"
    sdk="appletvos"
    platform_name="tvOS"
    ;;
  appletvsimulator)
    cmake_system="tvOS"
    sdk="appletvsimulator"
    platform_name="tvOS Simulator"
    ;;
  *)
    echo "ERROR: unsupported tvOS platform: ${platform}" >&2
    exit 64
    ;;
esac

work_dir="$2"
package_path="$3"
if [[ "${work_dir}" != /* || "${package_path}" != /* ]]; then
  echo "ERROR: WORK_DIR and OUTPUT_ARCHIVE must be absolute paths" >&2
  exit 64
fi

path_values="$(
  python3 - "${repo_root}" "${work_dir}" "${package_path}" <<'PY'
import sys
from pathlib import Path

repo = Path(sys.argv[1]).resolve()
work = Path(sys.argv[2]).resolve()
package = Path(sys.argv[3]).resolve()
tmp = Path("/tmp").resolve()

if work == repo or repo in work.parents:
    raise SystemExit("WORK_DIR must not be inside the repository")
if package == tmp or (tmp not in package.parents and work not in package.parents):
    raise SystemExit("OUTPUT_ARCHIVE must be under WORK_DIR or /tmp")
if package == work or package == repo or repo in package.parents:
    raise SystemExit("OUTPUT_ARCHIVE must not be inside the repository")

print(f"{work}\t{package}")
PY
)" || {
  echo "ERROR: invalid build paths" >&2
  exit 64
}
IFS=$'\t' read -r work_dir package_path <<< "${path_values}"
mkdir -p "${work_dir}" "$(dirname -- "${package_path}")"

lock_values="$(
  python3 - "${lockfile}" <<'PY'
import json
import re
import sys

lock_path = sys.argv[1]
try:
    with open(lock_path, encoding="utf-8") as handle:
        lock = json.load(handle)
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"cannot read dependencies.lock.json: {error}")

if lock.get("schemaVersion") != 1 or not isinstance(lock.get("dependencies"), list):
    raise SystemExit("unsupported dependencies.lock.json schema")

dependencies = {
    item.get("name"): item
    for item in lock["dependencies"]
    if isinstance(item, dict) and isinstance(item.get("name"), str)
}
dawn = dependencies.get("Dawn prebuilt")
sdl = dependencies.get("SDL 3")
if dawn is None or sdl is None:
    raise SystemExit("missing Dawn source or SDL 3 lock entry")

commit = dawn.get("sourceCommit")
dawn_archive = dawn.get("sourceArchive")
dawn_url = dawn.get("sourceArchiveUrl")
dawn_sha = dawn.get("sourceArchiveSha256")
sdl_version = sdl.get("version")
sdl_archive = sdl.get("sourceArchive")
sdl_url = sdl.get("sourceArchiveUrl")
sdl_sha = sdl.get("sourceArchiveSha256")

if not isinstance(commit, str) or re.fullmatch(r"[0-9a-f]{40}", commit) is None:
    raise SystemExit("invalid Dawn source commit pin")
if dawn_archive != f"dawn-{commit}.tar.gz":
    raise SystemExit("invalid Dawn source archive pin")
if dawn_url != f"https://github.com/google/dawn/archive/{commit}.tar.gz":
    raise SystemExit("invalid Dawn source archive URL pin")
if not isinstance(dawn_sha, str) or re.fullmatch(r"[0-9a-f]{64}", dawn_sha) is None:
    raise SystemExit("invalid Dawn source archive hash pin")

if sdl_version != "3.4.4":
    raise SystemExit("SDL 3 pin must be exactly 3.4.4")
if sdl_archive != "SDL3-3.4.4.tar.gz":
    raise SystemExit("invalid SDL source archive pin")
if sdl_url != "https://github.com/libsdl-org/SDL/releases/download/release-3.4.4/SDL3-3.4.4.tar.gz":
    raise SystemExit("invalid SDL source archive URL pin")
if not isinstance(sdl_sha, str) or re.fullmatch(r"[0-9a-f]{64}", sdl_sha) is None:
    raise SystemExit("invalid SDL source archive hash pin")

print("\t".join((commit, dawn_archive, dawn_url, dawn_sha,
                 sdl_version, sdl_archive, sdl_url, sdl_sha)))
PY
)" || {
  echo "ERROR: invalid dependency pin in dependencies.lock.json" >&2
    exit 1
}
IFS=$'\t' read -r dawn_commit dawn_archive dawn_url dawn_sha \
  sdl_version sdl_archive sdl_url sdl_sha <<< "${lock_values}"

deployment_target="17.0"
sdk_path="$(xcrun --sdk "${sdk}" --show-sdk-path)"
if [[ ! -d "${sdk_path}" ]]; then
  echo "ERROR: ${sdk} SDK is unavailable: ${sdk_path}" >&2
  exit 1
fi

download_dir="${work_dir}/downloads"
source_archive="${download_dir}/${dawn_archive}"
sdl_archive_path="${download_dir}/${sdl_archive}"
source_dir="${work_dir}/dawn-source"
sdl_source_dir="${work_dir}/sdl-source"
sdl_build_dir="${work_dir}/sdl-${platform}-build"
sdl_artifact="${sdl_build_dir}/libSDL3.a"
host_build_dir="${work_dir}/dawn-host-protoc-build"
target_build_dir="${work_dir}/dawn-${platform}-build"
install_dir="${work_dir}/dawn-${platform}-install"
target_path_map_flags="-ffile-prefix-map=${work_dir}=Dawn -fmacro-prefix-map=${work_dir}=Dawn"

download_and_verify() {
  local url="$1"
  local archive_path="$2"
  local expected_sha="$3"
  local label="$4"

  mkdir -p "$(dirname -- "${archive_path}")"
  if [[ ! -f "${archive_path}" ]]; then
    curl --fail --location --silent --show-error \
      "${url}" -o "${archive_path}"
  fi
  if [[ ! -f "${archive_path}" ]]; then
    echo "ERROR: ${label} archive is missing: ${archive_path}" >&2
    exit 1
  fi
  local actual_sha
  actual_sha="$(shasum -a 256 "${archive_path}" | awk '{print $1}')"
  if [[ "${actual_sha}" != "${expected_sha}" ]]; then
    echo "ERROR: ${label} archive hash mismatch: ${actual_sha}" >&2
    exit 1
  fi
  echo "${label} archive: ${archive_path} (${actual_sha})"
}

download_and_verify "${dawn_url}" "${source_archive}" "${dawn_sha}" "Dawn ${dawn_commit}"
download_and_verify "${sdl_url}" "${sdl_archive_path}" "${sdl_sha}" "SDL ${sdl_version}"

if [[ ! -e "${source_dir}" ]]; then
  mkdir -p "${source_dir}"
  tar -xzf "${source_archive}" --strip-components=1 -C "${source_dir}"
fi
if [[ ! -f "${source_dir}/CMakeLists.txt" ||
      ! -f "${source_dir}/.github/workflows/dawn-ci.cmake" ]]; then
  echo "ERROR: incomplete Dawn source directory: ${source_dir}" >&2
  exit 1
fi

if [[ ! -e "${sdl_source_dir}" ]]; then
  mkdir -p "${sdl_source_dir}"
  tar -xzf "${sdl_archive_path}" --strip-components=1 -C "${sdl_source_dir}"
fi
if [[ ! -f "${sdl_source_dir}/CMakeLists.txt" ]]; then
  echo "ERROR: incomplete SDL source directory: ${sdl_source_dir}" >&2
  exit 1
fi

echo "SDL ${sdl_version} ${platform_name}: ${cmake_system}, ${sdk}, arm64, deployment ${deployment_target}"
cmake -S "${sdl_source_dir}" -B "${sdl_build_dir}" -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME="${cmake_system}" \
  -DCMAKE_OSX_SYSROOT="${sdk}" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${deployment_target}" \
  -DCMAKE_SYSTEM_PROCESSOR=arm64 \
  -DSDL_SHARED=OFF \
  -DSDL_STATIC=ON \
  -DSDL_TESTS=OFF \
  -DSDL_TEST_LIBRARY=OFF \
  -DSDL_EXAMPLES=OFF \
  -DSDL_INSTALL=OFF
cmake --build "${sdl_build_dir}" --target SDL3-static --parallel 4
if [[ ! -f "${sdl_artifact}" ]]; then
  echo "ERROR: SDL ${sdl_version} artifact is missing: ${sdl_artifact}" >&2
  exit 1
fi

if [[ ! -x "${host_build_dir}/protoc" ]]; then
  cmake -S "${source_dir}" -B "${host_build_dir}" -G Ninja \
    -C "${source_dir}/.github/workflows/dawn-ci.cmake" \
    -C "${repo_root}/cmake/dawn-kartpad-ci.cmake" \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build "${host_build_dir}" --target protoc --parallel 4
fi

echo "Dawn ${platform_name}: ${cmake_system}, ${sdk}, arm64, deployment ${deployment_target}"
cmake -S "${source_dir}" -B "${target_build_dir}" -G Ninja \
  -C "${source_dir}/.github/workflows/dawn-ci.cmake" \
  -C "${repo_root}/cmake/dawn-kartpad-ci.cmake" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME="${cmake_system}" \
  -DCMAKE_OSX_SYSROOT="${sdk}" \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="${deployment_target}" \
  -DCMAKE_SYSTEM_PROCESSOR=arm64 \
  -DCMAKE_C_FLAGS="${target_path_map_flags}" \
  -DCMAKE_CXX_FLAGS="${target_path_map_flags}" \
  -DCMAKE_OBJC_FLAGS="${target_path_map_flags}" \
  -DCMAKE_OBJCXX_FLAGS="${target_path_map_flags}" \
  -DWITH_PROTOC="${host_build_dir}/protoc"
cmake --build "${target_build_dir}" --parallel 4
cmake --install "${target_build_dir}" --prefix "${install_dir}"

if [[ ! -f "${install_dir}/lib/libwebgpu_dawn.a" ||
      ! -f "${install_dir}/lib/cmake/Dawn/DawnConfig.cmake" ]]; then
  echo "ERROR: Dawn ${platform_name} install tree is incomplete" >&2
  exit 1
fi

ZERO_AR_DATE=1 ranlib "${install_dir}/lib/libwebgpu_dawn.a"
find "${install_dir}" -exec touch -h -t 198001010000 {} +
(
  cd "${install_dir}"
  find . -print | LC_ALL=C sort |
    COPYFILE_DISABLE=1 tar -cf - --no-recursion --uid 0 --gid 0 \
      --uname root --gname root --format=ustar -T -
) | gzip -n -9 > "${package_path}"

echo "Dawn ${platform_name} package: ${package_path}"
shasum -a 256 "${package_path}"
