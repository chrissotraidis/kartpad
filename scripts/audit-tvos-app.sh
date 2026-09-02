#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 || "$1" != /* || "$1" != *.app ]]; then
  echo "usage: $0 /absolute/path/to/KartPadTV.app [TVOSSIMULATOR|TVOS]" >&2
  exit 64
fi

app="$1"
expected_platform="${2:-TVOSSIMULATOR}"
case "${expected_platform}" in
  TVOSSIMULATOR)
    sdk="appletvsimulator"
    expected_bundle_platform="AppleTVSimulator"
    ;;
  TVOS)
    sdk="appletvos"
    expected_bundle_platform="AppleTVOS"
    required_developer_dir="/Applications/Xcode-27-beta-5.app/Contents/Developer"
    if [[ ! -d "${required_developer_dir}" ]] || ! command -v codesign >/dev/null 2>&1; then
      echo "ERROR: required Xcode 27 developer directory is missing: ${required_developer_dir}" >&2
      exit 66
    fi
    export DEVELOPER_DIR="${required_developer_dir}"
    ;;
  *)
    echo "expected platform must be TVOSSIMULATOR or TVOS" >&2
    exit 64
    ;;
esac

plist="${app}/Info.plist"
binary="${app}/KartPadTV"
profile="${app}/embedded.mobileprovision"
test -d "${app}"
test -x "${binary}"
test -f "${plist}"
test -f "${app}/PrivacyInfo.xcprivacy"
plutil -lint "${plist}" "${app}/PrivacyInfo.xcprivacy" >/dev/null

test "$(plutil -extract CFBundleIdentifier raw "${plist}")" = "dev.kartpad.app"
test "$(plutil -extract CFBundleExecutable raw "${plist}")" = "KartPadTV"
test "$(plutil -extract CFBundleShortVersionString raw "${plist}")" = "0.2.0"
test "$(plutil -extract MinimumOSVersion raw "${plist}")" = "17.0"
test "$(plutil -extract UIDeviceFamily.0 raw "${plist}")" = "3"

bundle_platforms="$(
  plutil -p "${plist}" |
    awk '
      /"CFBundleSupportedPlatforms" => \[/ { in_platforms = 1; next }
      in_platforms && /^  \]/ { exit }
      in_platforms && /=>/ {
        value = $3
        gsub(/^"|"$/, "", value)
        print value
      }
    '
)"
if [[ "${bundle_platforms}" != "${expected_bundle_platform}" ]]; then
  echo "tvOS app declares unsupported CFBundleSupportedPlatforms: ${bundle_platforms}" >&2
  exit 65
fi

if [[ "$(file -b "${binary}")" != *"Mach-O 64-bit executable arm64"* ]]; then
  echo "tvOS app is not an arm64 Mach-O executable" >&2
  exit 65
fi

expected_sdk="$(xcrun --sdk "${sdk}" --show-sdk-version)"
build_metadata="$(xcrun vtool -show-build "${binary}")"
if [[ "$(awk '/platform/{print $2; exit}' <<<"${build_metadata}")" != "${expected_platform}" ]] ||
   [[ "$(awk '/minos/{print $2; exit}' <<<"${build_metadata}")" != "17.0" ]] ||
   [[ "$(awk '/sdk/{print $2; exit}' <<<"${build_metadata}")" != "${expected_sdk}" ]]; then
  echo "binary is not an ${expected_platform} 17.0 artifact built with SDK ${expected_sdk}" >&2
  exit 65
fi
if [[ "${expected_platform}" == "TVOS" && "${expected_sdk}" != "27.0" ]]; then
  echo "device audit requires the Xcode 27 tvOS SDK, found ${expected_sdk}" >&2
  exit 65
fi

mobileprovision_paths=()
while IFS= read -r -d '' mobileprovision_path; do
  mobileprovision_paths+=("${mobileprovision_path}")
done < <(find "${app}" -iname '*.mobileprovision' -print0)

if [[ "${expected_platform}" == "TVOS" ]]; then
  if [[ ! -f "${profile}" ]] ||
     (( ${#mobileprovision_paths[@]} != 1 )) ||
     [[ "${mobileprovision_paths[0]:-}" != "${profile}" ]]; then
    echo "device tvOS app must contain only the root embedded.mobileprovision" >&2
    exit 70
  fi
  codesign --verify --deep --strict --verbose=2 "${app}"
  signature_details="$(codesign -d --verbose=4 "${app}" 2>&1)"
  printf '%s\n' "${signature_details}"
  signature_identifier="$(sed -n 's/^Identifier=//p' <<<"${signature_details}" | head -n 1)"
  signature_team="$(sed -n 's/^TeamIdentifier=//p' <<<"${signature_details}" | head -n 1)"
  if ! rg -q '^Authority=Apple Development:' <<<"${signature_details}" ||
     [[ "${signature_identifier}" != "dev.kartpad.app" ]] ||
     [[ "${signature_team}" != "HFHZAHV482" ]]; then
    echo "tvOS app is not signed by Apple Development for HFHZAHV482/dev.kartpad.app" >&2
    exit 65
  fi

  profile_plist="$(mktemp -t kartpad-tvos-profile)"
  entitlements_plist="$(mktemp -t kartpad-tvos-entitlements)"
  trap 'rm -f "${profile_plist}" "${entitlements_plist}"' EXIT
  security cms -D -i "${profile}" -o "${profile_plist}" >/dev/null
  profile_team="$(plutil -extract TeamIdentifier.0 raw "${profile_plist}")"
  profile_developer_team="$(
    /usr/libexec/PlistBuddy -c \
      'Print :Entitlements:com.apple.developer.team-identifier' "${profile_plist}"
  )"
  profile_app_identifier="$(plutil -extract Entitlements.application-identifier raw "${profile_plist}")"
  if [[ "${profile_team}" != "HFHZAHV482" ]] ||
     [[ "${profile_developer_team}" != "HFHZAHV482" ]] ||
     [[ "${profile_app_identifier}" != "HFHZAHV482.dev.kartpad.app" &&
        "${profile_app_identifier}" != "HFHZAHV482.*" ]]; then
    echo "embedded provisioning profile does not match HFHZAHV482/dev.kartpad.app" >&2
    exit 65
  fi
  codesign --display --entitlements :- "${app}" >"${entitlements_plist}" 2>/dev/null
  signed_app_identifier="$(plutil -extract application-identifier raw "${entitlements_plist}")"
  signed_developer_team="$(
    /usr/libexec/PlistBuddy -c \
      'Print :com.apple.developer.team-identifier' "${entitlements_plist}"
  )"
  if [[ "${signed_app_identifier}" != "HFHZAHV482.dev.kartpad.app" ]] ||
     [[ "${signed_developer_team}" != "HFHZAHV482" ]]; then
    echo "signed tvOS entitlements do not match HFHZAHV482/dev.kartpad.app" >&2
    exit 65
  fi
  printf 'embedded profile: %s (team=%s app-id=%s)\n' \
    "${profile}" "${profile_team}" "${profile_app_identifier}"
  printf 'signed entitlements: team=%s app-id=%s\n' \
    "${signed_developer_team}" "${signed_app_identifier}"
else
  if (( ${#mobileprovision_paths[@]} != 0 )); then
    echo "tvOS simulator app must not contain provisioning profiles" >&2
    exit 70
  fi
fi

while IFS= read -r dependency; do
  case "${dependency}" in
    /System/Library/PrivateFrameworks/*)
      echo "tvOS app contains a private framework dependency: ${dependency}" >&2
      exit 69
      ;;
    /System/Library/Frameworks/*|/usr/lib/*)
      ;;
    *)
      echo "tvOS app contains a non-system dependency: ${dependency}" >&2
      exit 69
      ;;
  esac
done < <(otool -L "${binary}" | tail -n +2 | awk '{print $1}')

if find "${app}" -type d -iname '*.appex' -print -quit | rg -q .; then
  echo "tvOS app contains a private app extension" >&2
  exit 69
fi

for forbidden in \
  '*.iso' '*.wbfs' '*.rvz' '*.wia' '*.gcz' '*.provisionprofile' \
  'GameData' 'NAND' 'main.dol' 'StaticR.rel' 'rksys.dat' 'Config.toml'; do
  forbidden_path="$(find "${app}" -iname "${forbidden}" -print -quit)"
  if [[ -n "${forbidden_path}" ]]; then
    echo "tvOS app contains forbidden private or signing data: ${forbidden}" >&2
    exit 70
  fi
done

binary_symbols="$(nm -gj "${binary}")"
for forbidden_path in \
  '/Users/' \
  '/private/var/' \
  'Downloads/' \
  'MarioKart.iso' \
  "${PWD}/"; do
  if rg -a -F -q "${forbidden_path}" "${binary}"; then
    echo "tvOS app embeds a private build or game-data path: ${forbidden_path}" >&2
    exit 70
  fi
done
if rg -a -F -q '\\Users\\' "${binary}"; then
  echo "tvOS app embeds a Windows-style private path" >&2
  exit 70
fi

for forbidden_api in \
  UIDocumentPickerViewController \
  UIDocumentPickerDelegate \
  UIApplicationOpenSettingsURLString \
  UIActivityViewController \
  UIFileSharingEnabled \
  LSSupportsOpeningDocumentsInPlace \
  MFMailComposeViewController; do
  if rg -a -F -q "${forbidden_api}" "${binary}" ||
     rg -F -q "${forbidden_api}" <<<"${binary_symbols}"; then
    echo "tvOS app contains a forbidden iOS API or document-sharing marker: ${forbidden_api}" >&2
    exit 69
  fi
done

required_contracts=(
  'GameData'
  'Config.toml'
  'KartPadMobileEnsureGameDataAvailable'
  'KartPadMobileReadClassicInputForPlayer'
)
for required_contract in "${required_contracts[@]}"; do
  if ! rg -a -F -q "${required_contract}" "${binary}"; then
    echo "tvOS app is missing the runtime contract: ${required_contract}" >&2
    exit 69
  fi
done

echo "tvOS ${expected_platform} runtime app audit passed: ${app}"
shasum -a 256 "${binary}" "${plist}" "${app}/PrivacyInfo.xcprivacy"
