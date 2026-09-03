#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 3 || "$1" != /* || "$1" != *.app ]]; then
  echo "usage: $0 /absolute/path/to/KartPad.app [TVOS|TVOSSIMULATOR] [bundle-id]" >&2
  exit 64
fi
app="$1"
expected_platform="${2:-TVOS}"
expected_bundle_identifier="${3:-dev.kartpad.tv}"
case "${expected_platform}" in TVOS|TVOSSIMULATOR) ;; *) exit 64 ;; esac

plist="${app}/Info.plist"
binary="${app}/KartPad"
assets_car="${app}/Assets.car"
settings_bundle="${app}/Settings.bundle/Root.plist"
test -d "${app}"
test -x "${binary}"
test -f "${plist}"
test -f "${app}/PrivacyInfo.xcprivacy"
test -f "${assets_car}"
test -f "${settings_bundle}"
test -f "${app}/initial_pipeline_cache.db"
test -f "${app}/dsp_coef.bin"
plutil -lint "${plist}" "${app}/PrivacyInfo.xcprivacy" "${settings_bundle}" >/dev/null
test "$(plutil -extract CFBundleIdentifier raw "${plist}")" = \
  "${expected_bundle_identifier}"
test "$(plutil -extract CFBundleExecutable raw "${plist}")" = "KartPad"
test "$(plutil -extract MinimumOSVersion raw "${plist}")" = "17.0"
test "$(plutil -extract GCSupportsControllerUserInteraction raw "${plist}")" = "true"
test "$(plutil -extract GCSupportedGameControllers.0.ProfileName raw "${plist}")" = "ExtendedGamepad"
test "$(plutil -extract CFBundleIcons.CFBundlePrimaryIcon raw "${plist}")" = "App Icon - Small"
test "$(plutil -extract TVTopShelfImage.TVTopShelfPrimaryImage raw "${plist}")" = "Top Shelf Image"
test "$(plutil -extract UIApplicationSceneManifest.UISceneConfigurations.UIWindowSceneSessionRoleApplication.0.UISceneDelegateClassName raw "${plist}")" = "SDLUIKitSceneDelegate"
test "$(plutil -extract PreferenceSpecifiers.1.Key raw "${settings_bundle}")" = \
  "KartPadTVRuntimeProfile"
test "$(plutil -extract PreferenceSpecifiers.1.DefaultValue raw "${settings_bundle}")" = "base"
test "$(plutil -extract PreferenceSpecifiers.2.Key raw "${settings_bundle}")" = \
  "SunPadAspectRatioMode"
test "$(plutil -extract PreferenceSpecifiers.2.DefaultValue raw "${settings_bundle}")" = "0"

asset_info="$(xcrun assetutil --info "${assets_car}")"
for asset in '"Name" : "App Icon - Small"' \
             '"RenditionName" : "background-large.png"' \
             '"RenditionName" : "circuit-large.png"' \
             '"RenditionName" : "mark-large.png"' \
             '"Name" : "Top Shelf Image"'; do
  rg -F -q "${asset}" <<<"${asset_info}" || {
    echo "ERROR: tvOS Assets.car is missing required rendition: ${asset}" >&2
    exit 69
  }
done

build_metadata="$(xcrun vtool -show-build "${binary}")"
test "$(awk '/platform/{print $2; exit}' <<<"${build_metadata}")" = "${expected_platform}"
test "$(awk '/minos/{print $2; exit}' <<<"${build_metadata}")" = "17.0"

for forbidden in '*.wbfs' '*.iso' '*.rvz' '*.wia' '*.gcz' 'rksys.dat' \
                 '*.mobileprovision' 'opening.bnr' 'banner.bin' 'icon.bin' \
                 'GameData' 'NAND'; do
  if [[ -n "$(find "${app}" -name "${forbidden}" -print -quit)" ]]; then
    echo "ERROR: tvOS app contains forbidden private/signing data: ${forbidden}" >&2
    exit 70
  fi
done
while IFS= read -r dependency; do
  case "${dependency}" in /System/Library/*|/usr/lib/*) ;; *)
    echo "ERROR: tvOS app contains non-system dependency: ${dependency}" >&2
    exit 69 ;;
  esac
done < <(otool -L "${binary}" | tail -n +2 | awk '{print $1}')
if rg -a -q '/Users/[^/]+/|/tmp/kartpad-tvos-' "${binary}"; then
  echo "ERROR: tvOS app exposes a private build path" >&2
  exit 69
fi

symbols="$(nm -gj "${binary}")"
for required in \
  _KartPadMobileEnsureGameDataAvailable \
  _KartPadMobileSelectedRuntimeProfile \
  _KartPadMobileRuntimeHostInstall \
  _KartPadMobileReadClassicInputForPlayer \
  '_OBJC_CLASS_$_KartPadPhysicalControllers' \
  '_OBJC_CLASS_$_SDLUIKitSceneDelegate'; do
  rg -F -q "${required}" <<<"${symbols}" || {
    echo "ERROR: tvOS app is missing required symbol: ${required}" >&2
    exit 69
  }
done
for contract in \
  'KartPad for Apple TV' \
  'KartPadTVRuntimeProfile' \
  'Download Official Pack' \
  'The pack may be purged by tvOS and can be downloaded again.'; do
  rg -a -F -q "${contract}" "${binary}" || {
    echo "ERROR: tvOS app is missing contract: ${contract}" >&2
    exit 69
  }
done

echo "tvOS ${expected_platform} full-game app audit passed: ${app}"
shasum -a 256 "${binary}" "${app}/PrivacyInfo.xcprivacy"
