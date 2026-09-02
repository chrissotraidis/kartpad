#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 SIMULATOR_UDID /absolute/path/to/extracted/GameData" >&2
  exit 64
fi

simulator="$1"
source="$2"
if [[ "${source}" != /* || ! -d "${source}" ]]; then
  echo "ERROR: GameData must be an existing absolute directory" >&2
  exit 64
fi

expected_dol="80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"
expected_rel="16d9d146112541fefea701ecb5bc1a496f9d50e4a752fbb5b6778e7c6399f67d"
actual_dol="$(shasum -a 256 "${source}/sys/main.dol" | awk '{print $1}')"
actual_rel="$(shasum -a 256 "${source}/files/rel/StaticR.rel" | awk '{print $1}')"
if [[ "${actual_dol}" != "${expected_dol}" ||
      "${actual_rel}" != "${expected_rel}" ]]; then
  echo "ERROR: GameData does not match RMCP01 revision 0" >&2
  exit 65
fi

container="$(xcrun simctl get_app_container "${simulator}" dev.kartpad.app data)"
destination="${container}/Library/Caches/KartPad/GameData"
rm -rf "${destination}"
mkdir -p "$(dirname "${destination}")"
ditto "${source}" "${destination}"

test "$(shasum -a 256 "${destination}/sys/main.dol" | awk '{print $1}')" = "${expected_dol}"
test "$(shasum -a 256 "${destination}/files/rel/StaticR.rel" | awk '{print $1}')" = "${expected_rel}"
printf 'Staged validated GameData: %s\n' "${destination}"
