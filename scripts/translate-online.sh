#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 || "$1" != "--payload" ]]; then
  echo "usage: $0 --payload /absolute/path/to/payload.RMCPD00.bin" >&2
  exit 64
fi

repo_root="$(git rev-parse --show-toplevel)"
payload="$2"
manifest="${repo_root}/tools/mkwii-rmcp01-online.yml"
output="${repo_root}/private/self-build/online/translation"
functions="${output}/functions"
metadata="${output}/base_translation_output.json"
base_manifest_dir="${output}/base"
base_manifest="${base_manifest_dir}/mkwii_base_manifest.json"
mod_root="${repo_root}/private/self-build/online/empty-mod"
mod_output="${repo_root}/private/self-build/online/mod"
empty_code="${repo_root}/private/self-build/online/empty-code.pul"
shards="${output}/build_shards"
dotnet_bin="/opt/homebrew/opt/dotnet@8/bin/dotnet"
translator="${repo_root}/build/wiicompiled-fpscr/translator/src/Translator.Cli/bin/Release/net8.0/Translator.Cli.dll"
translation_jobs="${KARTPAD_TRANSLATION_JOBS:-2}"

[[ -f "${payload}" ]] || { echo "ERROR: missing WFC payload: ${payload}" >&2; exit 66; }
[[ "${translation_jobs}" =~ ^[1-8]$ ]] || {
  echo "ERROR: KARTPAD_TRANSLATION_JOBS must be an integer from 1 through 8" >&2
  exit 64
}
payload="$(cd "$(dirname "${payload}")" && pwd)/$(basename "${payload}")"

"${repo_root}/scripts/prepare-disc.sh"
"${repo_root}/scripts/prepare-patched-translator.sh"
mkdir -p "${output}" "${base_manifest_dir}" "${mod_root}" "$(dirname "${empty_code}")"
xxd -r -p "${repo_root}/tools/empty-kamek-v3.hex" "${empty_code}"

"${dotnet_bin}" "${translator}" translate-recursive 0x800060A4 \
  --project "${manifest}" --profile online \
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
  --project "${manifest}" --profile online \
  --out "${base_manifest_dir}" --functions-dir "${functions}" \
  --translation-output-metadata "${metadata}" --region P

"${dotnet_bin}" "${translator}" translate-mod \
  --project "${manifest}" --profile online \
  --base-manifest "${base_manifest}" \
  --base-translation-output-metadata "${metadata}" \
  --code-pul "${empty_code}" --mod-root "${mod_root}" \
  --mod-name "KartPad Online" --region P --out "${mod_output}" \
  --prefer-cached-inputs --emit-cpp --threads "${translation_jobs}" \
  --retro-wfc-payload "${payload}"

"${dotnet_bin}" "${translator}" generate-data-init \
  --project "${manifest}" --profile online
"${dotnet_bin}" "${translator}" emit-build-shards \
  --project "${manifest}" --profile online \
  --base-metadata "${metadata}" --base-functions-dir "${functions}" \
  --native-source-dir "${repo_root}/build/wiicompiled-fpscr/runtime/src" \
  --resolved-profile "${mod_output}/resolved_dispatch_profile.json" \
  --retro-cpp-dir "${mod_output}/cpp" --out "${shards}"

rg -q '^set\(MKW_RETRO_REWIND_FUNCTION_COUNT [1-9][0-9]*\)$' \
  "${shards}/shards.cmake"
rg -q '^set\(MKW_HAVE_RETRO_REWIND_SHARDS ON\)$' "${shards}/shards.cmake"
echo "Generated validated private KartPad Online native graph"
