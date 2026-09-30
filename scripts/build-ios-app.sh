#!/usr/bin/env bash
# Build the publishable KartPad iPhone app: the runtime and app without any
# game code. PadMint adds the player's own game pack, built from their disc
# (scripts/build-game-pack.sh ios, then scripts/add-game-pack-to-ipa.sh).
#
# Usage: scripts/build-ios-app.sh [OUTPUT_ROOT]
#   KARTPAD_DISCIO_SOURCE_DIR / KARTPAD_DISCIO_BUILD_DIR: a physical-iOS DiscIO
#   build (scripts/build-ios-discio-probe.sh); defaults to the builder's.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$repo_root/version.json")"
out_root="${1:-$repo_root/build/ios-app}"
stage="$out_root/$(date +%Y%m%d-%H%M%S)"

if [[ -z "${KARTPAD_DISCIO_BUILD_DIR:-}" ]]; then
  discio_build="$(ls -d "$repo_root"/build/builder-dependencies/discio-iphoneos-*-build 2>/dev/null | tail -1)"
  [[ -n "$discio_build" ]] || { echo "ERROR: build the iOS DiscIO dependency first (scripts/build-ios-discio-probe.sh)" >&2; exit 66; }
  export KARTPAD_DISCIO_BUILD_DIR="$discio_build"
  export KARTPAD_DISCIO_SOURCE_DIR="${discio_build%-build}-source"
fi

KARTPAD_PREPARE_ONLY=1 KARTPAD_PREPARE_WITHOUT_TRANSLATION=1 \
  "$repo_root/scripts/prepare-ios-game-runtime.sh" none "$stage/runtime" "$stage/runtime-build" dual
if [[ -e "$stage/generated" ]]; then
  echo "ERROR: the publishable app must not see a generated graph: $stage/generated" >&2
  exit 1
fi
KARTPAD_IOS_GAME_PACK_APP=1 "$repo_root/scripts/build-ios-device-game-app.sh" \
  "$stage/runtime" "$stage/xcode" none dual

app="$stage/xcode/Release-iphoneos/KartPad.app"
# Local symbols include the hidden forwarders named after guest addresses; the
# game pack binds only to exported symbols, which stay.
xcrun strip -x "$app/KartPad"
ipa="$stage/out/KartPad-v$version-ios-unsigned.ipa"
# The builder's packager stamps version.json into Info.plist and adds licenses.
PYTHONPATH="$repo_root/builder" python3 - "$repo_root" "$app" "$ipa" <<'PY'
import sys
from pathlib import Path
from kartpad_builder.packaging import load_version, package_unsigned_ipa
repo, app, ipa = (Path(arg) for arg in sys.argv[1:])
version = load_version(repo)
provenance = {
    "schemaVersion": 1,
    "appVersion": version["version"],
    "appBuild": version["build"],
    "containsUserSuppliedTranslatedCode": False,
    "gamePack": "added by PadMint from the player's own disc",
    "softwareLicense": "GPL-3.0-only",
}
licenses = {name: repo / name for name in ("LICENSE", "RIGHTS_AND_LICENSES.md", "THIRD_PARTY_NOTICES.md")}
print(package_unsigned_ipa(app, ipa, provenance, licenses, version))
PY
echo "Publishable app (no game code): $ipa"
