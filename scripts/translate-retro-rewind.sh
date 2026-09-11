#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
manifest="${repo_root}/tools/mkwii-rmcp01-retro-rewind.yml"
output="${repo_root}/private/self-build/retro-rewind/translation"
functions="${output}/functions"
metadata="${output}/base_translation_output.json"
base_manifest_dir="${output}/base"
base_manifest="${base_manifest_dir}/mkwii_base_manifest.json"
mod_output="${repo_root}/private/self-build/retro-rewind/mod"
shards="${output}/build_shards"
profile_input="${repo_root}/private/self-build/retro-rewind/input"
default_retro_root="${repo_root}/ref/upstream/rr-pulsar/PulsarPackCreator/Resources"
retro_root="${default_retro_root}"
payload=""
image="${repo_root}/ref/Mario Kart Wii.wbfs"
skip_retro_wfc=false
dotnet_bin="/opt/homebrew/opt/dotnet@8/bin/dotnet"
translator="${repo_root}/build/wiicompiled-fpscr/translator/src/Translator.Cli/bin/Release/net8.0/Translator.Cli.dll"
translation_jobs="${KARTPAD_TRANSLATION_JOBS:-2}"

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/translate-retro-rewind.sh (--payload FILE | --skip-retro-wfc) [--image FILE] [--retro-root DIR]

Retranslates the user-owned RMCP01 base with awareness of KartPad's pinned
Retro Rewind Code.pul, translates the static mod profile, and emits a separate
native build graph. --skip-retro-wfc is diagnostic only and may not be used for
an online-support claim.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      [[ $# -ge 2 ]] || { usage; exit 64; }
      image="$2"
      shift 2
      ;;
    --payload)
      [[ $# -ge 2 ]] || { usage; exit 64; }
      payload="$2"
      shift 2
      ;;
    --retro-root)
      [[ $# -ge 2 ]] || { usage; exit 64; }
      retro_root="$2"
      shift 2
      ;;
    --skip-retro-wfc)
      skip_retro_wfc=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

if [[ -n "${payload}" && "${skip_retro_wfc}" == true ]]; then
  echo "ERROR: choose either --payload or --skip-retro-wfc" >&2
  exit 64
fi
if [[ -z "${payload}" && "${skip_retro_wfc}" == false ]]; then
  echo "ERROR: an explicit local Retro-WFC payload is required" >&2
  usage
  exit 64
fi
[[ "${translation_jobs}" =~ ^[1-8]$ ]] || {
  echo "ERROR: KARTPAD_TRANSLATION_JOBS must be an integer from 1 through 8" >&2
  exit 64
}

retro_root="$(cd "${retro_root}" && pwd)"
image="$(cd "$(dirname "${image}")" && pwd)/$(basename "${image}")"
[[ -f "${image}" ]] || {
  echo "ERROR: missing disc image at ${image}" >&2
  exit 66
}
if [[ "${retro_root}" == "${default_retro_root}" ]]; then
  code_pul="${retro_root}/Code.pul"
else
  code_pul="${retro_root}/Binaries/Code.pul"
fi
[[ -f "${code_pul}" ]] || {
  echo "ERROR: missing Retro Rewind Code.pul at ${code_pul}" >&2
  exit 66
}
if [[ -n "${payload}" ]]; then
  payload="$(cd "$(dirname "${payload}")" && pwd)/$(basename "${payload}")"
  [[ -f "${payload}" ]] || {
    echo "ERROR: missing Retro-WFC payload at ${payload}" >&2
    exit 66
  }
fi

# The base translator reads Code.pul from the profile before translate-mod is
# invoked. Stage the selected file at the profile-owned private path so the
# base and mod legs are always built around identical patch addresses. A
# partial copy never becomes visible to the translator.
mkdir -p "${profile_input}/Binaries"
staged_code="${profile_input}/Binaries/Code.pul"
staged_code_partial="${staged_code}.partial.$$"
trap 'rm -f "${staged_code_partial}"' EXIT
cp "${code_pul}" "${staged_code_partial}"
cmp -s "${code_pul}" "${staged_code_partial}" || {
  echo "ERROR: staged Retro Rewind Code.pul does not match the selected input" >&2
  exit 74
}
mv -f "${staged_code_partial}" "${staged_code}"
trap - EXIT

"${repo_root}/scripts/prepare-disc.sh" "${image}"
"${repo_root}/scripts/prepare-patched-translator.sh"
mkdir -p "${output}" "${base_manifest_dir}"

"${dotnet_bin}" "${translator}" translate-recursive 0x800060A4 \
  --project "${manifest}" --profile retro-rewind \
  --threads "${translation_jobs}" --prune-stale \
  --output-metadata "${metadata}"
"${repo_root}/scripts/inject-g10-rkg-fixture-hook.py" \
  "${functions}/func_8051FC84.cpp"
for selection_function in 8083DFA8 80846C1C 8084E388 80643F48; do
  "${repo_root}/scripts/inject-online-rkg-selection-hooks.py" \
    "${functions}/func_${selection_function}.cpp"
done
"${repo_root}/scripts/inject-g10-camera-lifecycle-guard.py" \
  "${functions}/func_805A1A8C.cpp"
"${repo_root}/scripts/inject-retro-rel-report-guard.py" \
  "${functions}/func_8000A440.cpp"

"${dotnet_bin}" "${translator}" emit-base-manifest \
  --project "${manifest}" --profile retro-rewind \
  --out "${base_manifest_dir}" --functions-dir "${functions}" \
  --translation-output-metadata "${metadata}" --region P
[[ -f "${base_manifest}" ]] || {
  echo "ERROR: translator did not emit ${base_manifest}" >&2
  exit 70
}

translate_mod_args=(
  translate-mod --project "${manifest}" --profile retro-rewind
  --base-manifest "${base_manifest}"
  --base-translation-output-metadata "${metadata}"
  --code-pul "${code_pul}" --mod-root "${retro_root}"
  --mod-name "Retro Rewind" --region P --out "${mod_output}"
  --prefer-cached-inputs --emit-cpp --threads "${translation_jobs}"
)
if [[ "${skip_retro_wfc}" == true ]]; then
  translate_mod_args+=(--skip-retro-wfc)
else
  translate_mod_args+=(--retro-wfc-payload "${payload}")
fi
"${dotnet_bin}" "${translator}" "${translate_mod_args[@]}"

"${dotnet_bin}" "${translator}" generate-data-init \
  --project "${manifest}" --profile retro-rewind
"${dotnet_bin}" "${translator}" emit-build-shards \
  --project "${manifest}" --profile retro-rewind \
  --base-metadata "${metadata}" --base-functions-dir "${functions}" \
  --native-source-dir "${repo_root}/build/wiicompiled-fpscr/runtime/src" \
  --resolved-profile "${mod_output}/resolved_dispatch_profile.json" \
  --retro-cpp-dir "${mod_output}/cpp" --out "${shards}"

# Mach-O C symbols carry a leading underscore. Publish aliases immediately so
# an incremental Apple rebuild remains valid after the translator rewrites the
# assembly blobs; the full runtime-preparation path performs the same guarded
# normalization for a fresh build.
if [[ "$(uname -s)" == "Darwin" ]]; then
  for blob_asm in \
      "${output}/data_sections_init_blobs.S" \
      "${mod_output}/cpp/mod_data_patches_blobs.S"; do
    if [[ -f "${blob_asm}" ]] && rg -q '^\.globl k' "${blob_asm}" &&
       ! rg -q '^\.globl _k' "${blob_asm}"; then
      perl -0pi -e 's/^\.globl (k[^\n]+)\n\1:/\.globl $1\n.globl _$1\n$1:\n_$1:/mg' "${blob_asm}"
    fi
  done
fi

[[ -f "${mod_output}/resolved_dispatch_profile.json" ]]
[[ -f "${shards}/shards.cmake" ]]
rg -q '^set\(MKW_RETRO_REWIND_FUNCTION_COUNT [1-9][0-9]*\)$' \
  "${shards}/shards.cmake"
rg -q '^set\(MKW_HAVE_RETRO_REWIND_SHARDS ON\)$' "${shards}/shards.cmake"

echo "Generated validated private Retro Rewind native graph"
if [[ "${skip_retro_wfc}" == true ]]; then
  echo "NOTE: Retro-WFC payload lowering was intentionally skipped; online is not proven"
fi
