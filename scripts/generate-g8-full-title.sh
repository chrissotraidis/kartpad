#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "${repo_root}"

dotnet_bin="/opt/homebrew/opt/dotnet@8/bin/dotnet"
translator_dll="${repo_root}/build/wiicompiled-fpscr/translator/src/Translator.Cli/bin/Release/net8.0/Translator.Cli.dll"
manifest="${repo_root}/private/g8-full-mkwii.yml"
output="${repo_root}/private/g8-full-translation"
functions="${output}/functions"
metadata="${output}/base_translation_output.json"
shards="${output}/build_shards"

"${repo_root}/scripts/prepare-patched-translator.sh"
"${dotnet_bin}" "${translator_dll}" translate-recursive 0x800060A4 \
  --project "${manifest}" --threads 8 --prune-stale \
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
"${dotnet_bin}" "${translator_dll}" generate-data-init --project "${manifest}"
# generate-data-init rewrites the assembly payload table in ELF/COFF spelling.
# Preserve the Mach-O aliases applied by prepare-g7-game-runtime.sh on every
# regeneration so a clean incremental Apple link still exports the C symbols.
blob_asm="${output}/data_sections_init_blobs.S"
if ! rg -q '^\.globl _kData_' "${blob_asm}"; then
  perl -0pi -e 's/^\.globl (kData_[^\n]+)\n\1:/\.globl $1\n.globl _$1\n$1:\n_$1:/mg' "${blob_asm}"
fi
"${dotnet_bin}" "${translator_dll}" emit-build-shards \
  --project "${manifest}" \
  --base-metadata "${metadata}" \
  --base-functions-dir "${functions}" \
  --native-source-dir "${repo_root}/build/wiicompiled-fpscr/runtime/src" \
  --out "${shards}"

test -f "${functions}/func_8055531C.cpp"
test -f "${shards}/shards.cmake"
function_count="$(find "${functions}" -name 'func_*.cpp' -type f | wc -l | tr -d ' ')"
echo "Generated full DOL+StaticR title graph: ${function_count} functions"
