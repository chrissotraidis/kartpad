#!/usr/bin/env bash
set -euo pipefail
# A local dependency experiment. Does not change the production dependency lock.
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
seed="${1:?Supply the populated pinned Dawn source tree}"
archive="${2:?Supply the pinned Dawn source archive}"
protoc="${3:?Supply the host protoc executable}"
output="${4:-$repo_root/work/stabilization/dawn-reproduction}"
[[ ! -e "$output" ]] || { echo 'Choose a fresh output directory.' >&2; exit 1; }
[[ -x "$protoc" ]] || { echo 'Host protoc is not executable.' >&2; exit 1; }
mkdir -p "$output"
python3 - "$seed" "$archive" "$output" <<'PY'
from pathlib import Path, PurePosixPath
import hashlib, json, shutil, sys, tarfile
seed,archive,output=map(lambda x:Path(x).resolve(),sys.argv[1:])
expected='713bea5b92d4f6c5175752fd7cbf1c3c5ce36598ff5dd98685d8a1216614ebba'
assert hashlib.sha256(archive.read_bytes()).hexdigest()==expected, 'Wrong Dawn archive'
destination=output/'source'
shutil.copytree(seed,destination,symlinks=True)
checked=0
with tarfile.open(archive) as package:
    for member in package:
        if not member.isfile(): continue
        rel=PurePosixPath(*PurePosixPath(member.name).parts[1:])
        assert not rel.is_absolute() and '..' not in rel.parts
        source=destination/rel
        assert source.is_file() and not source.is_symlink(), str(rel)
        assert source.read_bytes()==package.extractfile(member).read(), f'Baseline differs: {rel}'
        checked+=1
(output/'baseline.json').write_text(json.dumps({'commit':'13abc3bc8ea2d3c2050f9e77a12d012108ceee24','archive_sha256':expected,'verified_baseline_files':checked},indent=2)+'\n')
PY
python3 prototypes/stabilization/verify-dawn-dependencies.py "$output/source" > "$output/dependencies.json"
patch --batch -p1 -d "$output/source" < prototypes/stabilization/dependencies/dawn-optional-debug-utils.patch
patch --batch -p1 -d "$output/source" < prototypes/stabilization/dependencies/dawn-swiftshader-dynamic-state.patch
python3 prototypes/stabilization/pin-dawn-version.py "$output/source" \
  prototypes/stabilization/dependencies/dawn-optional-debug-utils.patch \
  prototypes/stabilization/dependencies/dawn-swiftshader-dynamic-state.patch > "$output/version.txt"
sdk="${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}"
path_flags="-O3 -DNDEBUG -ffile-prefix-map=$repo_root=KartPad -fmacro-prefix-map=$repo_root=KartPad"
cmake -S "$output/source" -B "$output/build" -G Ninja \
  -C "$output/source/.github/workflows/dawn-ci.cmake" -C cmake/dawn-kartpad-ci.cmake \
  -DCMAKE_TOOLCHAIN_FILE="$sdk/ndk/29.0.14206865/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-28 -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS_RELEASE="$path_flags" -DCMAKE_CXX_FLAGS_RELEASE="$path_flags" \
  -DDAWN_ENABLE_OPENGLES=OFF -DDAWN_ENABLE_VULKAN=ON -DDAWN_ENABLE_NULL=ON \
  -DDAWN_BUILD_TESTS=OFF -DDAWN_BUILD_MONOLITHIC_LIBRARY=STATIC \
  -DDAWN_FETCH_DEPENDENCIES=OFF -DWITH_PROTOC="$protoc"
cmake --build "$output/build" --parallel "${KARTPAD_PROTOTYPE_JOBS:-8}"
cmake --install "$output/build" --prefix "$output/install"
shasum -a 256 "$output/install/lib/libwebgpu_dawn.a" > "$output/library.sha256"
echo "Local Android Dawn prototype: $output/install"
