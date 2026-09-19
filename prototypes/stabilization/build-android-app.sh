#!/usr/bin/env bash
set -euo pipefail
# Deliberate local dependency override, confined to this prototype entry point.
# No installation, public signing, publication, or production lock update.
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
translation="${1:?Supply the existing validated private translation directory}"
export DAWN_ANDROID_ROOT="${2:?Supply the backported Dawn Android install directory}"
# Prevent an accidental rebuild against the unpatched prebuilt library.
python3 - "$DAWN_ANDROID_ROOT/lib/libwebgpu_dawn.a" <<'PY'
import hashlib, sys
from pathlib import Path
path = Path(sys.argv[1])
with path.open('rb') as stream:
    digest = hashlib.file_digest(stream, 'sha256').hexdigest()
if digest != '99cef2c445bb9fa9758dda2036887f29c6116629053d2b40b3107590881db43a':
    raise SystemExit('Dawn library differs from the reviewed prototype; review dependency evidence before building.')
PY
export MINIZIP_ANDROID_ROOT="${3:?Supply the pinned minizip source directory}"
export MBEDTLS_ANDROID_ROOT="${4:?Supply the pinned mbedTLS source directory}"
discio="${5:?Supply the existing DiscIO JNI directory}"
: "${JAVA_HOME:?Set JAVA_HOME to the pinned JDK}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
[[ -f android/app/libs/SDL3-3.4.4.aar ]] || { echo 'Prepare the pinned SDL AAR first.' >&2; exit 1; }
runtime="$repo_root/build/stabilization-android-20260919/runtime"
if [[ ! -e "$runtime" ]]; then
  bash scripts/prepare-android-game-runtime.sh "$translation" "$runtime" \
    "$repo_root/build/stabilization-android-20260919/unused-native-build" dual
fi
python3 scripts/stage-maintained-runtime.py --verify android "$runtime"
export CMAKE_BUILD_PARALLEL_LEVEL="${KARTPAD_PROTOTYPE_JOBS:-6}"
./android/gradlew --project-dir android --no-daemon --max-workers=4 \
  -PkartpadGameRuntimeSource="$runtime" \
  -PkartpadTranslatedShardManifest="$translation/build_shards/shards.cmake" \
  -PkartpadAndroidNativeTarget=KartPadDual -PkartpadDiscIoJniRoot="$discio" \
  -PkartpadDiagnosticRelease=true -PkartpadProfileable=true \
  -PkartpadVersionCode=130 -PkartpadVersionName=0.4.25-stabilization.8-prototype :app:assembleRelease
echo 'Local prototype only; verify the signer before considering any in-place device test.'
