#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || "$1" != /* || "$1" != *.app ]]; then
  echo "usage: $0 /absolute/path/to/KartPad.app" >&2
  exit 64
fi

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
app="$1"
contents="${app}/Contents"
plist="${contents}/Info.plist"
if [[ ! -d "${app}" || ! -f "${plist}" ]]; then
  echo "not a macOS app bundle: ${app}" >&2
  exit 66
fi

plutil -lint "${plist}" >/dev/null
executable_name="$(plutil -extract CFBundleExecutable raw "${plist}")"
bundle_identifier="$(plutil -extract CFBundleIdentifier raw "${plist}")"
icon_name="$(plutil -extract CFBundleIconFile raw "${plist}")"
executable="${contents}/MacOS/${executable_name}"

test "${bundle_identifier}" = "dev.kartpad.app"
test "$(plutil -extract CFBundleShortVersionString raw "${plist}")" = "0.4.16"
test "$(plutil -extract CFBundleVersion raw "${plist}")" = "35"
test "$(plutil -extract NSBluetoothAlwaysUsageDescription raw "${plist}")" = \
  "KartPad uses Bluetooth to pair and connect an experimental Wii Remote and Nunchuk."
test -x "${executable}"
test -f "${contents}/Resources/${icon_name%.icns}.icns"
cmp "${contents}/Resources/${icon_name%.icns}.icns" "${repo_root}/branding/exports/KartPad.icns"
test "$(readlink "${contents}/MacOS/dsp_coef.bin")" = \
  "../Resources/Runtime/dsp_coef.bin"
test "$(readlink "${contents}/MacOS/build-fingerprint.json")" = \
  "../Resources/Runtime/build-fingerprint.json"
test "$(readlink "${contents}/MacOS/wii_bootstrap")" = \
  "../Resources/Runtime/wii_bootstrap"
test -f "${contents}/Resources/Runtime/dsp_coef.bin"
test -f "${contents}/Resources/Runtime/build-fingerprint.json"
if [[ ! -f "${contents}/Resources/initial_pipeline_cache.db" ]]; then
  echo "package lacks its read-only initial pipeline cache resource" >&2
  exit 66
fi
test -d "${contents}/Resources/Runtime/wii_bootstrap/shared2/wc24"
if [[ "$(file -b "${executable}")" != *"Mach-O 64-bit executable arm64"* ]]; then
  echo "main executable is not arm64 Mach-O" >&2
  exit 65
fi
if [[ "$(plutil -extract LSMinimumSystemVersion raw "${plist}")" != "14.0" ]] ||
   [[ "$(vtool -show-build "${executable}" | awk '/minos/{print $2; exit}')" != "14.0" ]]; then
  echo "bundle or executable deployment target is not macOS 14.0" >&2
  exit 65
fi

for forbidden in portable.txt UserData Config.toml '*.wbfs' '*.iso' '*.rvz' '*.wia' '*.gcz'; do
  if find "${app}" -name "${forbidden}" -print -quit | rg -q .; then
    echo "package contains forbidden private or writable state: ${forbidden}" >&2
    exit 70
  fi
done

if find "${app}" -name '*\\*' -print -quit | rg -q .; then
  echo "package contains a Windows-style path component" >&2
  exit 70
fi

while IFS= read -r macho; do
  while IFS= read -r dependency; do
    case "${dependency}" in
      /System/Library/*|/usr/lib/*) ;;
      @rpath/*)
        test -f "${contents}/Frameworks/${dependency##*/}"
        ;;
      *)
        echo "non-portable dependency ${dependency} in ${macho}" >&2
        exit 69
        ;;
    esac
  done < <(otool -L "${macho}" | tail -n +2 | awk '{print $1}')
done < <(find "${contents}/MacOS" "${contents}/Frameworks" -type f -perm -111 -print)

if rg -F -q "${HOME}/" < <(
  find "${contents}/MacOS" "${contents}/Frameworks" -type f -perm -111 -print0 | \
    xargs -0 strings
); then
  echo "package embeds the builder's home-directory path" >&2
  exit 70
fi

# The installed Apple layout must keep durable data and regenerable caches in
# their distinct platform directories. The focused runtime contract proves the
# resolver behavior; these markers make the package audit reject an older
# runtime that predates that contract.
for runtime_marker in "Application Support" "Caches" "KartPad Startup"; do
  if ! rg -F -x -q "${runtime_marker}" < <(strings "${executable}"); then
    echo "package runtime lacks required product marker: ${runtime_marker}" >&2
    exit 70
  fi
done

executable_strings="$(strings "${executable}")"
for shell_contract in \
  "KartPad Settings" \
  "KartPad Controls" \
  "Original Mario Kart Wii" \
  "Retro Rewind" \
  "chooseRetroRewindData:" \
  "RMCP01-r0-retro-rewind" \
  "KartPadRuntimeProfile" \
  "Quit and reopen KartPad to switch games. Your saves and settings are preserved." \
  "Player Identity" \
  "Mii Appearance" \
  "showPlayerNameEditor" \
  "showLicenseManager" \
  "Save for Next Launch" \
  "Experimental Wii Remote + Nunchuk" \
  "Wii Remote + Nunchuk (Experimental)" \
  "Use item" \
  "Left Shift (Classic L)" \
  "Select / minus" \
  "Runtime settings bar" \
  "showControls:" \
  "Render resolution" \
  "Controller mappings remain available from Controller settings in the in-game F10 bar." \
  "Changes are saved safely and apply the next time KartPad launches." \
  "Game Data Required" \
  "Choose Extracted Mario Kart Wii Data" \
  "Choose Game Data" \
  "showControllerSettings:" \
  "guestMemoryStrategy=flat-mach-vm" \
  "schema=3" \
  "sessionTailLimitBytes=4096" \
  "currentSessionTailBegin" \
  "previousSessionTailBegin" \
  "reviewWarning=Review this report before sharing. Arbitrary runtime text may still require review." \
  "KartPad currently supports RMCP01 (PAL), disc 0, revision 0 only." \
  "80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05" \
  "Show KartPad Data" \
  "Show KartPad Cache" \
  "Save Diagnostics Report" \
  "privacy=personal paths are replaced; game data, translated code, save contents, credentials, device identifiers, signing material, and unbounded logs are omitted"; do
  if ! rg -F -q "${shell_contract}" <<<"${executable_strings}"; then
    echo "package runtime lacks native shell contract: ${shell_contract}" >&2
    exit 70
  fi
done

codesign --verify --deep --strict --verbose=2 "${app}"
codesign -d --entitlements - "${app}" 2>/dev/null | \
  rg -A2 -F '[Key] com.apple.security.device.bluetooth' | rg -q '\[Bool\] true'
app_hash="$(find "${app}" -type f -print0 | sort -z | xargs -0 shasum -a 256 | shasum -a 256 | awk '{print $1}')"
echo "macOS package audit passed: ${app}"
echo "Bundle content hash: ${app_hash}"
