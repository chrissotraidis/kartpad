#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "usage: $0 /absolute/path/to/runtime-build /absolute/path/to/KartPad.app [WiiCompiled|RetroRewind|KartPadDual]" >&2
  exit 64
fi

repo_root="$(git rev-parse --show-toplevel)"
runtime_build="$1"
output_app="$2"
runtime_target="${3:-WiiCompiled}"
case "${runtime_target}" in
  WiiCompiled|RetroRewind|KartPadDual) ;;
  *) echo "unsupported runtime target: ${runtime_target}" >&2; exit 64 ;;
esac
runtime_binary="${runtime_build}/${runtime_target}"
icon_file="${repo_root}/branding/exports/KartPad.icns"

if [[ "${runtime_build}" != /* || "${output_app}" != /* ]]; then
  echo "runtime-build and output-app paths must be absolute" >&2
  exit 64
fi
if [[ "${output_app}" != *.app ]]; then
  echo "output must end in .app: ${output_app}" >&2
  exit 64
fi
if [[ -e "${output_app}" ]]; then
  echo "refusing to overwrite existing output: ${output_app}" >&2
  exit 73
fi
for required in "${runtime_binary}" "${runtime_build}/dsp_coef.bin" \
  "${runtime_build}/initial_pipeline_cache.db" "${icon_file}"; do
  if [[ ! -f "${required}" ]]; then
    echo "missing package input: ${required}" >&2
    exit 66
  fi
done
if [[ ! -d "${runtime_build}/wii_bootstrap/shared2/wc24" ]]; then
  echo "missing Wii first-run bootstrap: ${runtime_build}/wii_bootstrap" >&2
  exit 66
fi
if [[ "$(file -b "${runtime_binary}")" != *"Mach-O 64-bit executable arm64"* ]]; then
  echo "runtime is not an arm64 Mach-O executable: ${runtime_binary}" >&2
  exit 65
fi

output_parent="$(dirname "${output_app}")"
mkdir -p "${output_parent}"
staging_root="$(mktemp -d "${output_parent}/.kartpad-package.XXXXXX")"
trap 'rm -rf "${staging_root}"' EXIT

staged_app="${staging_root}/KartPad.app"
contents="${staged_app}/Contents"
macos="${contents}/MacOS"
resources="${contents}/Resources"
runtime_resources="${resources}/Runtime"
frameworks="${contents}/Frameworks"
mkdir -p "${macos}" "${runtime_resources}" "${frameworks}"

cp "${runtime_binary}" "${macos}/KartPad"
chmod 0755 "${macos}/KartPad"
cp "${runtime_build}/dsp_coef.bin" "${runtime_resources}/dsp_coef.bin"
cp "${runtime_build}/initial_pipeline_cache.db" "${resources}/initial_pipeline_cache.db"
cp -R "${runtime_build}/wii_bootstrap" "${runtime_resources}/wii_bootstrap"
cp "${icon_file}" "${resources}/KartPad.icns"
ln -s ../Resources/Runtime/dsp_coef.bin "${macos}/dsp_coef.bin"
ln -s ../Resources/Runtime/wii_bootstrap "${macos}/wii_bootstrap"

plist="${contents}/Info.plist"
plutil -create xml1 "${plist}"
plutil -insert CFBundleDevelopmentRegion -string en "${plist}"
plutil -insert CFBundleDisplayName -string KartPad "${plist}"
plutil -insert CFBundleExecutable -string KartPad "${plist}"
plutil -insert CFBundleIconFile -string KartPad "${plist}"
plutil -insert CFBundleIdentifier -string dev.kartpad.app "${plist}"
plutil -insert CFBundleInfoDictionaryVersion -string 6.0 "${plist}"
plutil -insert CFBundleName -string KartPad "${plist}"
plutil -insert CFBundlePackageType -string APPL "${plist}"
plutil -insert NSLocalNetworkUsageDescription -string "KartPad connects to your selected private Wii server and other players on your local network." "${plist}"
plutil -insert CFBundleShortVersionString -string "${KARTPAD_VERSION:-0.4.15}" "${plist}"
plutil -insert CFBundleVersion -string "${KARTPAD_BUILD_NUMBER:-34}" "${plist}"
plutil -insert LSApplicationCategoryType -string public.app-category.games "${plist}"
plutil -insert LSMinimumSystemVersion -string 14.0 "${plist}"
plutil -insert NSHighResolutionCapable -bool true "${plist}"
# Native settings stay in NSScreen.visibleFrame; the optional desktop fullscreen
# mode can use the real display bounds, including the area around the notch.
plutil -insert NSPrefersDisplaySafeAreaCompatibilityMode -bool false "${plist}"
plutil -insert NSBluetoothAlwaysUsageDescription -string \
  "KartPad uses Bluetooth to pair and connect an experimental Wii Remote and Nunchuk." "${plist}"
plutil -insert NSPrincipalClass -string NSApplication "${plist}"

# Bundle every non-system dylib and rewrite absolute paths. Release builds are
# expected to be fully static apart from Apple libraries, but this keeps the
# package operation closed over any intentionally introduced runtime library.
queue=("${macos}/KartPad")
queue_index=0
while (( queue_index < ${#queue[@]} )); do
  target="${queue[queue_index]}"
  queue_index=$((queue_index + 1))
  while IFS= read -r dependency; do
    [[ -n "${dependency}" ]] || continue
    case "${dependency}" in
      /System/Library/*|/usr/lib/*)
        continue
        ;;
      @rpath/*|@loader_path/*|@executable_path/*)
        dependency_name="${dependency##*/}"
        if [[ ! -f "${frameworks}/${dependency_name}" ]]; then
          echo "unresolved bundled dependency ${dependency} from ${target}" >&2
          exit 69
        fi
        install_name_tool -change "${dependency}" "@rpath/${dependency_name}" "${target}"
        ;;
      /*)
        if [[ ! -f "${dependency}" ]]; then
          echo "missing linked dependency ${dependency} from ${target}" >&2
          exit 69
        fi
        dependency_name="$(basename "${dependency}")"
        bundled_dependency="${frameworks}/${dependency_name}"
        if [[ -f "${bundled_dependency}" ]]; then
          source_hash="$(shasum -a 256 "${dependency}" | awk '{print $1}')"
          bundled_hash="$(shasum -a 256 "${bundled_dependency}" | awk '{print $1}')"
          if [[ "${source_hash}" != "${bundled_hash}" ]]; then
            echo "dependency basename collision: ${dependency_name}" >&2
            exit 65
          fi
        else
          cp -L "${dependency}" "${bundled_dependency}"
          chmod u+w "${bundled_dependency}"
          install_name_tool -id "@rpath/${dependency_name}" "${bundled_dependency}"
          queue+=("${bundled_dependency}")
        fi
        install_name_tool -change "${dependency}" "@rpath/${dependency_name}" "${target}"
        ;;
      *)
        echo "unsupported linked dependency ${dependency} from ${target}" >&2
        exit 69
        ;;
    esac
  done < <(otool -L "${target}" | tail -n +2 | awk '{print $1}')
done

if ! otool -l "${macos}/KartPad" | rg -q '^\s*path @executable_path/\.\./Frameworks '; then
  install_name_tool -add_rpath '@executable_path/../Frameworks' "${macos}/KartPad"
fi

shopt -s nullglob
audit_targets=("${macos}/KartPad" "${frameworks}"/*.dylib)
for target in "${audit_targets[@]}"; do
  while IFS= read -r dependency; do
    case "${dependency}" in
      /System/Library/*|/usr/lib/*) ;;
      @rpath/*)
        test -f "${frameworks}/${dependency##*/}"
        ;;
      *)
        echo "package retained non-system dependency ${dependency} in ${target}" >&2
        exit 69
        ;;
    esac
  done < <(otool -L "${target}" | tail -n +2 | awk '{print $1}')
done

unsigned_runtime_hash="$(shasum -a 256 "${macos}/KartPad" | awk '{print $1}')"
source_commit="$(git -C "${repo_root}" rev-parse HEAD)"
fingerprint="${runtime_resources}/build-fingerprint.json"
printf '{\n  "SetupVersion": "%s",\n  "SourceCommit": "%s",\n  "UnsignedRuntimeSHA256": "%s"\n}\n' \
  "${KARTPAD_VERSION:-0.4.15}" "${source_commit}" "${unsigned_runtime_hash}" > "${fingerprint}"
ln -s ../Resources/Runtime/build-fingerprint.json "${macos}/build-fingerprint.json"

if find "${staged_app}" \( -name portable.txt -o -name UserData -o -name Config.toml \) -print -quit | rg -q .; then
  echo "package contains writable or developer-only runtime state" >&2
  exit 70
fi

codesign --force --deep --sign - \
  --entitlements "${repo_root}/apple/macos/KartPad.entitlements" "${staged_app}"
codesign --verify --deep --strict --verbose=2 "${staged_app}"
codesign -d --entitlements - "${staged_app}" 2>/dev/null | \
  rg -A2 -F '[Key] com.apple.security.device.bluetooth' | rg -q '\[Bool\] true'
plutil -lint "${plist}"
mv "${staged_app}" "${output_app}"

echo "Packaged KartPad: ${output_app}"
echo "Unsigned runtime SHA-256: ${unsigned_runtime_hash}"
