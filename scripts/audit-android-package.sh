#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
apk="${1:-$repo_root/android/app/build/outputs/apk/debug/app-debug.apk}"
[[ -f "$apk" ]] || { echo "ERROR: APK does not exist: $apk" >&2; exit 1; }

aapt2="$sdk_root/build-tools/$KARTPAD_ANDROID_BUILD_TOOLS/aapt2"
zipalign="$sdk_root/build-tools/$KARTPAD_ANDROID_BUILD_TOOLS/zipalign"
readelf="$sdk_root/ndk/$KARTPAD_ANDROID_NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf"
for tool in "$aapt2" "$zipalign" "$readelf"; do
  [[ -x "$tool" ]] || { echo "ERROR: missing audit tool: $tool" >&2; exit 1; }
done

badging="$("$aapt2" dump badging "$apk")"
[[ "$badging" == *"package: name='dev.kartpad.android'"* ]]
[[ "$badging" == *"compileSdkVersion='36'"* ]]
[[ "$badging" == *"minSdkVersion:'28'"* ]]
[[ "$badging" == *"targetSdkVersion:'36'"* ]]
[[ "$badging" == *"native-code: 'arm64-v8a'"* ]]
permissions="$("$aapt2" dump permissions "$apk")"
permission_names="$(printf '%s\n' "$permissions" |
  sed -n "s/^uses-permission: name='\([^']*\)'.*$/\1/p" | sort)"
if [[ "$permission_names" != "android.permission.INTERNET" ]]; then
  echo "ERROR: KartPad Android permission set differs from the network-only allowlist" >&2
  exit 1
fi

members="$(unzip -Z1 "$apk")"
if printf '%s\n' "$members" | grep -Eq '^lib/(armeabi|armeabi-v7a|x86|x86_64)/'; then
  echo "ERROR: APK contains an unintended native ABI" >&2
  exit 1
fi
if printf '%s\n' "$members" | grep -Eiq '\.(iso|gcm|gcz|ciso|wbfs|wia|rvz|sav|gci|dtm|pcap|pcapng|mobileprovision|p12|key|pem|log)$'; then
  echo "ERROR: APK contains a forbidden private-data or signing extension" >&2
  exit 1
fi
for required in \
  lib/arm64-v8a/libSDL3.so \
  lib/arm64-v8a/libc++_shared.so \
  lib/arm64-v8a/libmain.so; do
  printf '%s\n' "$members" | grep -Fxq "$required" || {
    echo "ERROR: APK is missing $required" >&2
    exit 1
  }
done
native_members="$(printf '%s\n' "$members" | grep '^lib/arm64-v8a/.*\.so$' | sort)"
expected_native_members="$(printf '%s\n' \
  lib/arm64-v8a/libSDL3.so \
  lib/arm64-v8a/libc++_shared.so \
  lib/arm64-v8a/libmain.so | sort)"
[[ "$native_members" == "$expected_native_members" ]] || {
  echo "ERROR: APK native-library set differs from the A0 allowlist" >&2
  exit 1
}
asset_members="$(printf '%s\n' "$members" | grep '^assets/.' | sort || true)"
if [[ -n "$asset_members" ]]; then
  expected_asset_members="$(printf '%s\n' \
    assets/ThirdPartyLicenses/Minizip-NG.txt | sort)"
  if printf '%s\n' "$asset_members" | grep -Fxq assets/dsp/dsp_coef.bin; then
    expected_asset_members="$(printf '%s\n' \
    assets/ThirdPartyLicenses/Minizip-NG.txt \
    assets/dsp/dsp_coef.bin \
    assets/pipeline/initial_pipeline_cache.db \
    assets/wii/README.md \
    assets/wii/shared2/wc24/mbox/Readme.txt \
    assets/wii/shared2/wc24/mbox/wc24recv.ctl \
    assets/wii/shared2/wc24/mbox/wc24recv.mbx \
    assets/wii/shared2/wc24/mbox/wc24send.ctl \
    assets/wii/shared2/wc24/mbox/wc24send.mbx \
    assets/wii/shared2/wc24/misc.bin \
    assets/wii/shared2/wc24/nwc24dl.bin \
    assets/wii/shared2/wc24/nwc24fl.bin \
    assets/wii/shared2/wc24/nwc24fls.bin \
    assets/wii/shared2/wc24/nwc24msg.cbk \
    assets/wii/shared2/wc24/nwc24msg.cfg | sort)"
  fi
  [[ "$asset_members" == "$expected_asset_members" ]] || {
    echo "ERROR: APK asset set differs from the public runtime-resource allowlist" >&2
    exit 1
  }
fi

"$zipalign" -c -P 16 -v 4 "$apk" >/dev/null
audit_root="$repo_root/.android-bootstrap/audit"
mkdir -p "$audit_root"
for library in libSDL3.so libc++_shared.so libmain.so; do
  unzip -p "$apk" "lib/arm64-v8a/$library" > "$audit_root/$library"
  if "$readelf" -l "$audit_root/$library" |
      awk '$1 == "LOAD" && $NF != "0x4000" { bad = 1 } END { exit bad ? 0 : 1 }'; then
    echo "ERROR: $library contains a LOAD segment aligned below 16 KiB" >&2
    exit 1
  fi
done
dynamic="$("$readelf" -d -l "$audit_root/libmain.so")"
needed="$(printf '%s\n' "$dynamic" |
  sed -n 's/.*Shared library: \[\([^]]*\)\].*/\1/p' | sort)"
expected_needed="$(printf '%s\n' \
  libc++_shared.so libc.so libdl.so libm.so libSDL3.so \
  libandroid.so liblog.so libz.so | sort)"
[[ "$needed" == "$expected_needed" ]] || {
  echo "ERROR: libmain.so dependency set differs from the allowlist" >&2
  exit 1
}
[[ "$dynamic" == *"GNU_RELRO"* ]]
if ! printf '%s\n' "$dynamic" | grep -Eq 'GNU_STACK .* RW  0x0$'; then
  echo "ERROR: libmain.so does not have a non-executable stack" >&2
  exit 1
fi
main_symbols="$("$readelf" --wide --dyn-syms "$audit_root/libmain.so")"
sdl_symbols="$("$readelf" --wide --dyn-syms "$audit_root/libSDL3.so")"
[[ "$main_symbols" == *" SDL_main"* ]] || {
  echo "ERROR: libmain.so does not export SDL_main" >&2
  exit 1
}
for symbol in \
  Java_dev_kartpad_android_KartPadSurface_nativeBeginSurfaceMutation \
  Java_dev_kartpad_android_KartPadSurface_nativeEndSurfaceMutation \
  Java_dev_kartpad_android_RetroRewindArchiveExtractor_nativeExtract; do
  [[ "$main_symbols" == *" $symbol"* ]] || {
    echo "ERROR: libmain.so does not export $symbol" >&2
    exit 1
  }
done
[[ "$sdl_symbols" == *" JNI_OnLoad@@"* ]] || {
  echo "ERROR: libSDL3.so does not export its JNI registration entry" >&2
  exit 1
}
unzip -p "$apk" | strings > "$audit_root/apk.strings"
if grep -Eq '/Users/|Mario Kart Wii\.(iso|wbfs)|BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY' \
    "$audit_root/apk.strings"; then
  echo "ERROR: APK contains a private path, game-data name, or key marker" >&2
  exit 1
fi

echo "Android APK audit passed."
echo "apk_sha256=$(shasum -a 256 "$apk" | awk '{print $1}')"
