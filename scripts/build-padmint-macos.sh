#!/usr/bin/env bash
# Keep the compilation cache, but put each app beside PadMint's unique output.
set -euo pipefail

if [[ $# -ne 3 || "$2" != /* || "$3" != /* ]]; then
  echo "usage: $0 TRANSLATION /absolute/work /absolute/output.zip" >&2
  exit 64
fi
repo_root="$(git rev-parse --show-toplevel)"
translation="$1"
work="$2"
output="$3"
app="$(dirname "${output}")/KartPad.app"
if [[ -e "${output}" || -L "${output}" || -e "${app}" || -L "${app}" ]]; then
  echo "ERROR: personal app or ZIP already exists; choose a fresh output folder" >&2
  exit 73
fi
"${repo_root}/scripts/build-macos-app.sh" "${translation}" \
  "${work}/macos-source" "${work}/macos-build" "${app}" dual
/usr/bin/ditto -c -k --keepParent "${app}" "${output}"
