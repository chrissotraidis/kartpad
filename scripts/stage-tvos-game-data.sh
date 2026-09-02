#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 --simulator SIMULATOR_UDID GAME_DATA base|retro-rewind [RETRO_ROOT]" >&2
  echo "       $0 --device DEVICE_ID GAME_DATA base|retro-rewind [RETRO_ROOT]" >&2
}

if [[ $# -lt 4 || $# -gt 5 ]]; then
  usage
  exit 64
fi

target_kind="$1"
target="$2"
game_data="$3"
profile="$4"
retro_root="${5:-}"

case "${target_kind}" in
  --simulator|--device)
    ;;
  *)
    usage
    exit 64
    ;;
esac

if [[ -z "${target}" ]]; then
  echo "ERROR: target identifier must not be empty" >&2
  exit 64
fi

case "${profile}" in
  base)
    if [[ $# -ne 4 ]]; then
      echo "ERROR: base profile does not accept RETRO_ROOT" >&2
      exit 64
    fi
    runtime_profile="base"
    ;;
  retro-rewind)
    if [[ $# -ne 5 ]]; then
      echo "ERROR: retro-rewind profile requires RETRO_ROOT" >&2
      exit 64
    fi
    runtime_profile="retro_rewind"
    ;;
  *)
    echo "ERROR: profile must be base or retro-rewind" >&2
    exit 64
    ;;
esac

expected_dol="80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"
expected_rel="16d9d146112541fefea701ecb5bc1a496f9d50e4a752fbb5b6778e7c6399f67d"
expected_retro_version="6.12.4"
expected_code_pul_bytes=1718176
expected_code_pul_sha256="ea93f9b8bf6d7696a807c1da5be724f1b0ec3eea563c1fdc1adfab10cb6c98e2"
expected_retro_xml_bytes=20949
expected_retro_xml_sha256="9493911ddd39df695016e2cb7069df4a5f2b4c3a9eeef4d91ea00438ca7952df"

fail_validation() {
  echo "ERROR: $*" >&2
  exit 65
}

sha256() {
  shasum -a 256 "$1" | awk '{print $1}'
}

validate_game_data() {
  local root="$1"
  local dol="${root}/sys/main.dol"
  local rel="${root}/files/rel/StaticR.rel"

  if [[ "${root}" != /* || ! -d "${root}" ]]; then
    fail_validation "GameData must be an existing absolute directory"
  fi
  if [[ ! -f "${dol}" || ! -f "${rel}" ]]; then
    fail_validation "GameData is missing sys/main.dol or files/rel/StaticR.rel"
  fi

  if [[ "$(sha256 "${dol}")" != "${expected_dol}" ||
        "$(sha256 "${rel}")" != "${expected_rel}" ]]; then
    fail_validation "GameData does not match RMCP01 revision 0"
  fi
}

validate_retro_root() {
  local root="$1"
  local version="${root}/version.txt"
  local code_pul="${root}/Binaries/Code.pul"
  local retro_xml="${root}/xml/RetroRewind6.xml"
  local code_pul_bytes
  local retro_xml_bytes

  if [[ "${root}" != /* || ! -d "${root}" || "${root##*/}" != "RetroRewind6" ]]; then
    fail_validation "RETRO_ROOT must be an existing absolute RetroRewind6 directory"
  fi
  if [[ ! -f "${version}" || ! -f "${code_pul}" || ! -f "${retro_xml}" ]]; then
    fail_validation "RETRO_ROOT is missing version.txt, Binaries/Code.pul, or xml/RetroRewind6.xml"
  fi
  if ! cmp -s <(printf '%s' "${expected_retro_version}") "${version}" &&
     ! cmp -s <(printf '%s\n' "${expected_retro_version}") "${version}"; then
    fail_validation "RETRO_ROOT version.txt must be exactly ${expected_retro_version}"
  fi

  code_pul_bytes="$(wc -c < "${code_pul}")"
  retro_xml_bytes="$(wc -c < "${retro_xml}")"
  if [[ "${code_pul_bytes}" -ne "${expected_code_pul_bytes}" ||
        "${retro_xml_bytes}" -ne "${expected_retro_xml_bytes}" ]]; then
    fail_validation "RETRO_ROOT has an invalid pinned file size"
  fi
  if [[ "$(sha256 "${code_pul}")" != "${expected_code_pul_sha256}" ||
        "$(sha256 "${retro_xml}")" != "${expected_retro_xml_sha256}" ]]; then
    fail_validation "RETRO_ROOT does not match the pinned Retro Rewind 6.12.4 payload"
  fi
}

device_copy_to() {
  local attempt
  for attempt in 1 2 3; do
    if xcrun devicectl device copy to \
      --device "${target}" \
      --source "$1" \
      --destination "$2" \
      --domain-type appDataContainer \
      --domain-identifier dev.kartpad.app \
      --remove-existing-content false \
      --timeout 600; then
      return 0
    fi
    [[ "${attempt}" -lt 3 ]] && sleep 2
  done
  return 1
}

stage_device_tree() {
  local source_root="$1"
  local destination_root="$2"
  local entry
  local name
  local size_kb

  while IFS= read -r -d '' entry; do
    name="${entry##*/}"
    [[ "${name}" == ".svn" ]] && continue
    if [[ -d "${entry}" ]]; then
      [[ -n "$(find "${entry}" -mindepth 1 -print -quit)" ]] || continue
      size_kb="$(du -sk "${entry}" | awk '{print $1}')"
      if (( size_kb > 400000 )); then
        stage_device_tree "${entry}" "${destination_root}/${name}"
      else
        device_copy_to "${entry}" "${destination_root}/${name}"
      fi
    else
      device_copy_to "${entry}" "${destination_root}/${name}"
    fi
  done < <(find "${source_root}" -mindepth 1 -maxdepth 1 -print0)
}

validate_game_data "${game_data}"
if [[ "${profile}" == "retro-rewind" ]]; then
  validate_retro_root "${retro_root}"
fi

marker="$(mktemp "${TMPDIR:-/tmp}/kartpad-tvos-runtime-profile.XXXXXX")"
verify_dir=""
cleanup() {
  rm -f "${marker}"
  if [[ -n "${verify_dir}" ]]; then
    rm -rf "${verify_dir}"
  fi
}
trap cleanup EXIT
printf '%s\n' "${runtime_profile}" > "${marker}"

game_destination="Library/Caches/KartPad/GameData"
retro_destination="Library/Caches/KartPad/RetroRewind/RetroRewind6"
marker_destination="Library/Caches/KartPad/RuntimeProfile"

if [[ "${target_kind}" == "--simulator" ]]; then
  xcrun simctl terminate "${target}" dev.kartpad.app || true
  container="$(xcrun simctl get_app_container "${target}" dev.kartpad.app data)"
  cache_root="${container}/Library/Caches/KartPad"
  local_game_destination="${cache_root}/GameData"
  local_retro_destination="${cache_root}/RetroRewind/RetroRewind6"
  local_marker_destination="${cache_root}/RuntimeProfile"

  rm -rf "${local_game_destination}"
  mkdir -p "${cache_root}"
  ditto "${game_data}" "${local_game_destination}"
  if [[ "${profile}" == "retro-rewind" ]]; then
    rm -rf "${local_retro_destination}"
    mkdir -p "$(dirname "${local_retro_destination}")"
    ditto "${retro_root}" "${local_retro_destination}"
  fi
  ditto "${marker}" "${local_marker_destination}"

  validate_game_data "${local_game_destination}"
  if ! cmp -s "${marker}" "${local_marker_destination}"; then
    fail_validation "staged RuntimeProfile marker does not match ${runtime_profile}"
  fi
  if [[ "${profile}" == "retro-rewind" ]]; then
    validate_retro_root "${local_retro_destination}"
  fi
  printf 'Staged validated %s runtime data in %s\n' "${profile}" "${cache_root}"
  exit 0
fi

process_json="$(
  xcrun devicectl device info processes --quiet --json-output - --device "${target}"
)"
matching_pids="$(
  python3 -c '
import json
import sys

document = json.load(sys.stdin)
result = document.get("result", {})
processes = result.get("runningProcesses", []) if isinstance(result, dict) else []
for process in processes:
    if not isinstance(process, dict):
        continue
    executable = process.get("executable")
    pid = process.get("processIdentifier")
    if not isinstance(executable, str) or not executable.endswith("/KartPadTV.app/KartPadTV"):
        continue
    if isinstance(pid, int) and not isinstance(pid, bool):
        print(pid)
    elif isinstance(pid, str) and pid.isdigit():
        print(pid)
' <<<"${process_json}"
)"
while IFS= read -r pid; do
  [[ -n "${pid}" ]] || continue
  xcrun devicectl device process terminate --device "${target}" --pid "${pid}" --kill
done <<<"${matching_pids}"

stage_device_tree "${game_data}" "${game_destination}"
if [[ "${profile}" == "retro-rewind" ]]; then
  stage_device_tree "${retro_root}" "${retro_destination}"
fi
device_copy_to "${marker}" "${marker_destination}"

verify_dir="$(mktemp -d "${TMPDIR:-/tmp}/kartpad-tvos-stage-verify.XXXXXX")"
mkdir -p \
  "${verify_dir}/GameData/sys" \
  "${verify_dir}/GameData/files/rel"
xcrun devicectl device copy from \
  --device "${target}" \
  --source "${game_destination}/sys/main.dol" \
  --destination "${verify_dir}/GameData/sys/main.dol" \
  --domain-type appDataContainer \
  --domain-identifier dev.kartpad.app
xcrun devicectl device copy from \
  --device "${target}" \
  --source "${game_destination}/files/rel/StaticR.rel" \
  --destination "${verify_dir}/GameData/files/rel/StaticR.rel" \
  --domain-type appDataContainer \
  --domain-identifier dev.kartpad.app
xcrun devicectl device copy from \
  --device "${target}" \
  --source "${marker_destination}" \
  --destination "${verify_dir}/RuntimeProfile" \
  --domain-type appDataContainer \
  --domain-identifier dev.kartpad.app

validate_game_data "${verify_dir}/GameData"
if ! cmp -s "${marker}" "${verify_dir}/RuntimeProfile"; then
  fail_validation "staged RuntimeProfile marker does not match ${runtime_profile}"
fi
if [[ "${profile}" == "retro-rewind" ]]; then
  mkdir -p \
    "${verify_dir}/RetroRewind/RetroRewind6/Binaries" \
    "${verify_dir}/RetroRewind/RetroRewind6/xml"
  xcrun devicectl device copy from \
    --device "${target}" \
    --source "${retro_destination}/version.txt" \
    --destination "${verify_dir}/RetroRewind/RetroRewind6/version.txt" \
    --domain-type appDataContainer \
    --domain-identifier dev.kartpad.app
  xcrun devicectl device copy from \
    --device "${target}" \
    --source "${retro_destination}/Binaries/Code.pul" \
    --destination "${verify_dir}/RetroRewind/RetroRewind6/Binaries/Code.pul" \
    --domain-type appDataContainer \
    --domain-identifier dev.kartpad.app
  xcrun devicectl device copy from \
    --device "${target}" \
    --source "${retro_destination}/xml/RetroRewind6.xml" \
    --destination "${verify_dir}/RetroRewind/RetroRewind6/xml/RetroRewind6.xml" \
    --domain-type appDataContainer \
    --domain-identifier dev.kartpad.app
  validate_retro_root "${verify_dir}/RetroRewind/RetroRewind6"
fi
printf 'Staged validated %s runtime data on device %s\n' "${profile}" "${target}"
