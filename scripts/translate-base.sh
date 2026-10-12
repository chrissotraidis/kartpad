#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
image="${1:-${repo_root}/ref/Mario Kart Wii.wbfs}"
manifest="${repo_root}/tools/mkwii-rmcp01-base.yml"
output="${repo_root}/private/self-build/translation"
functions="${output}/functions"
metadata="${output}/base_translation_output.json"
shards="${output}/build_shards"
dotnet_bin="/opt/homebrew/opt/dotnet@8/bin/dotnet"
translator="${repo_root}/build/wiicompiled-fpscr/translator/src/Translator.Cli/bin/Release/net8.0/Translator.Cli.dll"
translation_jobs="${KARTPAD_TRANSLATION_JOBS:-2}"

[[ "${translation_jobs}" =~ ^[1-9][0-9]*$ ]] || {
  echo "ERROR: KARTPAD_TRANSLATION_JOBS must be a positive integer" >&2
  exit 64
}
# PadMint passes its compile job count, which can exceed the translator's
# useful parallelism on large Macs; use at most 8 rather than stopping.
(( translation_jobs <= 8 )) || translation_jobs=8
"${repo_root}/scripts/prepare-disc.sh" "${image}"
"${repo_root}/scripts/prepare-patched-translator.sh"

"${dotnet_bin}" "${translator}" translate-recursive 0x800060A4 \
  --project "${manifest}" --threads "${translation_jobs}" --prune-stale \
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
"${dotnet_bin}" "${translator}" generate-data-init --project "${manifest}"

blob_asm="${output}/data_sections_init_blobs.S"
if ! rg -q '^\.globl _kData_' "${blob_asm}"; then
  perl -0pi -e 's/^\.globl (kData_[^\n]+)\n\1:/\.globl $1\n.globl _$1\n$1:\n_$1:/mg' "${blob_asm}"
fi
"${dotnet_bin}" "${translator}" emit-build-shards \
  --project "${manifest}" \
  --base-metadata "${metadata}" \
  --base-functions-dir "${functions}" \
  --native-source-dir "${repo_root}/build/wiicompiled-fpscr/runtime/src" \
  --out "${shards}"
"${repo_root}/scripts/inject-retro-rel-report-guard.py" --inject-shards "${shards}"
"${repo_root}/scripts/inject-retro-rel-report-guard.py" --verify-shards "${shards}"


[[ -f "${functions}/func_8055531C.cpp" && -f "${shards}/shards.cmake" ]] || { echo "translate-base.sh: check failed (line 51)" >&2; exit 1; }
function_count="$(find "${functions}" -name 'func_*.cpp' -type f | wc -l | tr -d ' ')"
[[ "${function_count}" == 29637 ]] || {
  echo "ERROR: expected 29637 translated functions, found ${function_count}" >&2
  exit 70
}
rg -q '^set\(MKW_BASE_FUNCTION_COUNT 29065\)$' "${shards}/shards.cmake"
echo "Generated validated private RMCP01 base graph: ${function_count} functions"
