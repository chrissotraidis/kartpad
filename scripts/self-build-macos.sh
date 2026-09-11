#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
image="${1:-${repo_root}/ref/Mario Kart Wii.wbfs}"
profile="${repo_root}/builder/profiles/mkwii-rmcp01-rev0.json"
retro_version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["retroRewind"]["version"])' "${profile}")"
retro_directory="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["retroRewind"]["root"])' "${profile}")"
retro_cache="${repo_root}/private/builder/retro-rewind-downloads"
retro_root="${retro_cache}/${retro_version}-extracted/${retro_directory}"
payload="${retro_cache}/payload.RMCPD00.bin"

"${repo_root}/scripts/build-user-ipa.sh" bootstrap
KARTPAD_DISC_PATH="${image}" "${repo_root}/scripts/verify-sources.sh"
"${repo_root}/scripts/check-repo-safety.sh"
"${repo_root}/scripts/translate-retro-rewind.sh" \
  --image "${image}" --retro-root "${retro_root}" --payload "${payload}"
"${repo_root}/scripts/build-macos-app.sh" \
  "${repo_root}/private/self-build/retro-rewind/translation" \
  "${repo_root}/build/self-build-macos-source" \
  "${repo_root}/build/self-build-macos-build" \
  "${repo_root}/build/KartPad.app" dual

app="${repo_root}/build/KartPad.app"
prepared_data="${repo_root}/private/self-build/disc"
KARTPAD_SELF_BUILD_GAME_DATA_ROOT="${prepared_data}" \
KARTPAD_SELF_BUILD_RETRO_REWIND_ROOT="${retro_root}" \
  "${app}/Contents/MacOS/KartPad"

config="${HOME}/Library/Application Support/KartPad/Config.toml"
expected_setting="dvd_root = \"${prepared_data}\""
if [[ ! -f "${config}" ]] || ! rg -F -q "${expected_setting}" "${config}"; then
  echo "ERROR: self-build did not configure the validated game-data root" >&2
  exit 70
fi
expected_retro_setting="retro_rewind_root = \"${retro_root}\""
if ! rg -F -q "${expected_retro_setting}" "${config}"; then
  echo "ERROR: self-build did not configure the validated Retro Rewind root" >&2
  exit 70
fi

echo "KartPad dual-game macOS self-build complete and configured: ${app}"
