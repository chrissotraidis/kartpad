#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
source_root="${1:-${repo_root}/ref/upstream/dolphin}"
work_source="${2:-${repo_root}/build/dolphin-android-discio-source}"
work_build="${3:-${repo_root}/build/dolphin-android-discio-build}"
stage_root="${4:-${repo_root}/build/dolphin-android-discio-jni}"
resume="${KARTPAD_DISCIO_RESUME:-0}"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ndk_root="${sdk_root}/ndk/29.0.14206865"
cmake_bin="${sdk_root}/cmake/3.31.6/bin/cmake"
ninja_bin="${sdk_root}/cmake/3.31.6/bin/ninja"

if [[ "${resume}" != "0" && "${resume}" != "1" ]]; then
  echo "ERROR: KARTPAD_DISCIO_RESUME must be 0 or 1" >&2
  exit 64
fi
if [[ "$(git -C "${source_root}" rev-parse HEAD^{commit})" != \
      "4f8af23db516d8b6e9cd00e7b261a65b026514a8" ]]; then
  echo "ERROR: Dolphin source is not the pinned KartPad revision" >&2
  exit 65
fi
if [[ -n "$(git -C "${source_root}" status --porcelain)" ]]; then
  echo "ERROR: Dolphin source must be clean" >&2
  exit 65
fi
for required in \
  "${ndk_root}/build/cmake/android.toolchain.cmake" \
  "${cmake_bin}" "${ninja_bin}" \
  "${source_root}/Source/Core/DiscIO/DiscExtractor.h"; do
  if [[ ! -e "${required}" ]]; then
    echo "ERROR: missing Android DiscIO prerequisite: ${required}" >&2
    exit 66
  fi
done
if [[ "${resume}" == "0" && ( -e "${work_source}" || -e "${work_build}" ) ]]; then
  echo "ERROR: work source/build already exists; choose fresh paths" >&2
  exit 73
fi

if [[ "${resume}" == "0" ]]; then
  mkdir -p "$(dirname "${work_source}")" "$(dirname "${work_build}")"
  cp -R "${source_root}" "${work_source}"
  patch --batch -p1 -d "${work_source}" < \
    "${repo_root}/patches/dolphin-android-discio-probe.patch"
elif [[ ! -f "${work_build}/CMakeCache.txt" ]]; then
  echo "ERROR: DiscIO resume build is not configured" >&2
  exit 66
fi

path_map_flags="-ffile-prefix-map=${work_source}=Dolphin -fmacro-prefix-map=${work_source}=Dolphin -ffile-prefix-map=${repo_root}=KartPad -fmacro-prefix-map=${repo_root}=KartPad -ffile-prefix-map=${sdk_root}=AndroidSDK -fmacro-prefix-map=${sdk_root}=AndroidSDK"
"${cmake_bin}" -S "${work_source}" -B "${work_build}" -G Ninja \
  -DCMAKE_MAKE_PROGRAM="${ninja_bin}" \
  -DCMAKE_TOOLCHAIN_FILE="${ndk_root}/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-28 \
  -DANDROID_STL=c++_shared \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="${path_map_flags}" \
  -DCMAKE_CXX_FLAGS="${path_map_flags}" \
  -DENABLE_QT=OFF \
  -DENABLE_NOGUI=OFF \
  -DENABLE_CLI_TOOL=OFF \
  -DENABLE_TESTS=OFF \
  -DENABLE_VULKAN=OFF \
  -DENABLE_CUBEB=OFF \
  -DENABLE_LLVM=OFF \
  -DENABLE_AUTOUPDATE=OFF \
  -DENABLE_ANALYTICS=OFF \
  -DENABLE_SDL=OFF \
  -DUSE_DISCORD_PRESENCE=OFF \
  -DUSE_MGBA=OFF \
  -DUSE_RETRO_ACHIEVEMENTS=OFF \
  -DUSE_UPNP=OFF \
  -DUSE_SYSTEM_LIBS=OFF \
  -DKARTPAD_ANDROID_DISCIO_PROBE_SOURCE="${repo_root}/tests/ios_discio_probe.cpp" \
  -DKARTPAD_ANDROID_DISCIO_JNI_SOURCE="${repo_root}/android/app/src/main/cpp/kartpad_discio_jni.cpp"
"${cmake_bin}" --build "${work_build}" --target \
  kartpad-android-discio-probe kartpad_discio --parallel 2

binary="${work_build}/kartpad-android-discio-probe"
if [[ ! -f "${binary}" ]]; then
  echo "ERROR: missing Android DiscIO probe: ${binary}" >&2
  exit 65
fi
if ! "${ndk_root}/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf" -h \
    "${binary}" | rg -q 'Machine:[[:space:]]+AArch64'; then
  echo "ERROR: DiscIO probe is not AArch64" >&2
  exit 65
fi
if rg -a -F -q "${work_source}" "${binary}"; then
  echo "ERROR: DiscIO probe exposes its private build path" >&2
  exit 65
fi

jni_library="${work_build}/libkartpad_discio.so"
if [[ ! -f "${jni_library}" ]]; then
  echo "ERROR: missing Android DiscIO JNI library: ${jni_library}" >&2
  exit 65
fi
mkdir -p "${stage_root}/arm64-v8a"
install -m 0644 "${jni_library}" \
  "${stage_root}/arm64-v8a/libkartpad_discio.so"

echo "Built pinned Android DiscIO probe: ${binary}"
shasum -a 256 "${binary}"
echo "Staged Android DiscIO JNI library: ${stage_root}/arm64-v8a/libkartpad_discio.so"
shasum -a 256 "${stage_root}/arm64-v8a/libkartpad_discio.so"
