#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
image="${1:-${repo_root}/ref/Mario Kart Wii.wbfs}"
output="${2:-${repo_root}/private/self-build/disc}"
profile="${repo_root}/builder/profiles/mkwii-rmcp01-rev0.json"
expected_dol_sha256="80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"
expected_rel_sha256="16d9d146112541fefea701ecb5bc1a496f9d50e4a752fbb5b6778e7c6399f67d"

image_lower="$(printf '%s' "${image}" | tr '[:upper:]' '[:lower:]')"
case "${image_lower}" in
  *.iso|*.gcm|*.gcz|*.ciso|*.wbfs|*.wia|*.rvz) ;;
  *) echo "ERROR: unsupported disc-image extension: ${image}" >&2; exit 64 ;;
esac
[[ -f "${image}" ]] || { echo "ERROR: missing disc image: ${image}" >&2; exit 66; }
[[ "${output}" == "${repo_root}/private/"* ]] || {
  echo "ERROR: extracted output must stay under ${repo_root}/private" >&2
  exit 64
}

nodtool="$(command -v nodtool || true)"
if [[ -z "${nodtool}" && -x "${CARGO_HOME:-${HOME}/.cargo}/bin/nodtool" ]]; then
  nodtool="${CARGO_HOME:-${HOME}/.cargo}/bin/nodtool"
fi
[[ -n "${nodtool}" ]] || {
  echo "ERROR: nodtool 2.0.0-alpha.9 is required (cargo install nodtool --version 2.0.0-alpha.9 --locked)" >&2
  exit 69
}
[[ "$(${nodtool} --version)" == "nodtool 2.0.0-alpha.9 " ||
   "$(${nodtool} --version)" == "nodtool 2.0.0-alpha.9" ]] || {
  echo "ERROR: expected nodtool 2.0.0-alpha.9" >&2
  exit 65
}

validate_output() {
  local root="$1"
  for relative in sys/boot.bin sys/bi2.bin sys/apploader.img sys/fst.bin \
      sys/main.dol files/rel/StaticR.rel; do
    [[ -f "${root}/${relative}" ]] || {
      echo "ERROR: extracted data is missing ${relative}" >&2
      return 1
    }
  done
  [[ "$(xxd -p -l 8 "${root}/sys/boot.bin")" == "524d435030310000" ]] || {
    echo "ERROR: extracted data is not RMCP01 disc 0 revision 0" >&2
    return 1
  }
  [[ "$(xxd -p -s 24 -l 4 "${root}/sys/boot.bin")" == "5d1c9ea3" ]] || {
    echo "ERROR: extracted data has an invalid Wii disc magic" >&2
    return 1
  }
  [[ "$(shasum -a 256 "${root}/sys/main.dol" | awk '{print $1}')" == \
      "${expected_dol_sha256}" ]] || {
    echo "ERROR: extracted main.dol does not match the supported profile" >&2
    return 1
  }
  [[ "$(shasum -a 256 "${root}/files/rel/StaticR.rel" | awk '{print $1}')" == \
      "${expected_rel_sha256}" ]] || {
    echo "ERROR: extracted StaticR.rel does not match the supported profile" >&2
    return 1
  }
}

image_sha256="$(shasum -a 256 "${image}" | awk '{print $1}')"
if ! PYTHONPATH="${repo_root}/builder${PYTHONPATH:+:${PYTHONPATH}}" \
    python3 - "${profile}" "${image_sha256}" <<'PY'
import sys
from pathlib import Path

from kartpad_builder.profiles import ProfileError, load_profiles, select_profile

profile_path = Path(sys.argv[1])
try:
    select_profile(load_profiles(profile_path.parent), sys.argv[2], profile_path.stem)
except ProfileError:
    raise SystemExit(1)
PY
then
  echo "ERROR: disc-image SHA-256 is unsupported: ${image_sha256}" >&2
  exit 65
fi

if [[ -d "${output}" ]]; then
  validate_output "${output}"
  echo "Reused validated private RMCP01 extraction: ${output}"
  exit 0
fi
[[ ! -e "${output}" ]] || { echo "ERROR: output exists and is not a directory: ${output}" >&2; exit 73; }

mkdir -p "$(dirname "${output}")"
stage="${output}.partial.$RANDOM.$RANDOM"
[[ "${stage}" == "${repo_root}/private/"* ]]
cleanup() {
  if [[ -d "${stage}" && "${stage}" == "${repo_root}/private/"* ]]; then
    rm -rf -- "${stage}"
  fi
}
trap cleanup EXIT

# Accepted images are independently pinned by full SHA-256. nodtool's H0
# validation rejects the verified WBFS's first block despite the extracted
# DOL/REL matching the supported profile, so extraction remains read-only and
# is followed by strict output identity checks.
"${nodtool}" extract --quiet "${image}" "${stage}"
validate_output "${stage}"
mv "${stage}" "${output}"
printf '{\n  "schema": 1,\n  "discId": "RMCP01",\n  "revision": 0,\n  "imageSHA256": "%s",\n  "mainDolSHA256": "%s",\n  "staticRelSHA256": "%s",\n  "extractor": "nodtool 2.0.0-alpha.9"\n}\n' \
  "${image_sha256}" "${expected_dol_sha256}" "${expected_rel_sha256}" \
  > "${output}/kartpad-disc-manifest.json"
echo "Prepared validated private RMCP01 extraction: ${output}"
