#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
snapshot="${repo_root}/apple/third_party/sunpad"
reference="${repo_root}/ref/sunpad"

files=(
  "apple/ios/SunPadGameOverlay.h"
  "apple/ios/SunPadGameOverlay.mm"
  "apple/shared/SunPadInputState.h"
  "apple/shared/SunPadInputMixer.h"
  "apple/shared/SunPadInputMixer.mm"
  "apple/shared/SunPadSettings.h"
  "apple/shared/SunPadSettings.mm"
  "apple/shared/SunPadDiagnostics.h"
  "apple/shared/SunPadDiagnostics.mm"
  "apple/ios/SunPadControllerSlots.h"
  "apple/shared/SunPadControllerMapping.h"
  "apple/shared/SunPadControllerMapping.mm"
)

for upstream in "${files[@]}"; do
  name="$(basename "${upstream}")"
  # KartPad has maintained three explicitly recorded adaptations since the
  # original import. Verify their reviewed bytes; do not claim they are verbatim.
  case "$name" in
    SunPadDiagnostics.mm) expected=da46cfc2d15e571c6e6b01960859cc63e07023d703d7785e2f872588c5016b4f ;;
    SunPadControllerMapping.h) expected=71054371f6a5a613e6ba54bb68f5505da93fe1038b10a0b0f9015e2bff17e5a3 ;;
    SunPadControllerMapping.mm) expected=1fa1a0405c4af28f1e5b0dd581802664cb8837198cd7093c9e55d99497f93dd4 ;;
    *) cmp "${reference}/${upstream}" "${snapshot}/${name}"; continue ;;
  esac
  actual="$(shasum -a 256 "${snapshot}/${name}" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    echo "Unreviewed KartPad overlay adaptation: $name" >&2
    exit 65
  fi
done

expected_commit="e43f0ea6b797e5110787171957c9dc3c6213269c"
actual_commit="$(git -C "${reference}" rev-parse HEAD)"
if [[ "${actual_commit}" != "${expected_commit}" ]]; then
  echo "SunPad reference moved: expected ${expected_commit}, found ${actual_commit}" >&2
  exit 65
fi

cmp "${reference}/LICENSE" "${repo_root}/LICENSES/GPL-3.0.txt"
echo "SunPad overlay baseline verified at ${expected_commit}, with three pinned KartPad adaptations"
