#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=android-toolchain-versions.sh
source "$repo_root/scripts/android-toolchain-versions.sh"
bundle="${1:-$repo_root/android/app/build/outputs/bundle/release/app-release.aab}"
[[ -f "$bundle" ]] || { echo "ERROR: AAB does not exist: $bundle" >&2; exit 1; }

bundletool="$repo_root/.android-bootstrap/dependencies/bundletool-all-1.18.1.jar"
java="$repo_root/.android-bootstrap/jdk-$KARTPAD_ANDROID_JDK_VERSION/Contents/Home/bin/java"
sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
readelf="$sdk_root/ndk/$KARTPAD_ANDROID_NDK/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-readelf"
for tool in "$java" "$readelf"; do
  [[ -x "$tool" ]] || { echo "ERROR: missing bundle audit tool: $tool" >&2; exit 1; }
done
[[ -f "$bundletool" ]] || { echo "ERROR: missing pinned bundletool: $bundletool" >&2; exit 1; }
[[ "$(stat -f '%z' "$bundletool")" == 32505571 ]] || {
  echo "ERROR: pinned bundletool byte count changed" >&2
  exit 1
}
[[ "$(shasum -a 256 "$bundletool" | awk '{ print $1 }')" == \
    675786493983787ffa11550bdb7c0715679a44e1643f3ff980a529e9c822595c ]] || {
  echo "ERROR: pinned bundletool hash changed" >&2
  exit 1
}

"$java" -jar "$bundletool" validate --bundle="$bundle" >/dev/null
manifest="$($java -jar "$bundletool" dump manifest --bundle="$bundle")"
expected_version_name="${KARTPAD_ANDROID_EXPECTED_VERSION_NAME:-0.4.0-android-preview.2}"
[[ "$manifest" == *'package="dev.kartpad.android"'* ]]
[[ "$manifest" == *"android:versionName=\"$expected_version_name\""* ]] || {
  echo "ERROR: AAB version name is not $expected_version_name" >&2
  exit 1
}
[[ "$manifest" == *'android:compileSdkVersion="36"'* ]]
[[ "$manifest" == *'<uses-sdk android:minSdkVersion="28" android:targetSdkVersion="36"/>'* ]]
permission_names="$(printf '%s\n' "$manifest" |
  sed -n 's/.*<uses-permission android:name="\([^"]*\)".*/\1/p' | sort)"
expected_permission_names="$(printf '%s\n' \
  android.permission.ACCESS_NETWORK_STATE \
  android.permission.FOREGROUND_SERVICE \
  android.permission.FOREGROUND_SERVICE_DATA_SYNC \
  android.permission.INTERNET \
  android.permission.POST_NOTIFICATIONS \
  android.permission.RECEIVE_BOOT_COMPLETED \
  android.permission.WAKE_LOCK \
  dev.kartpad.android.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION | sort)"
[[ "$permission_names" == "$expected_permission_names" ]] || {
  echo "ERROR: AAB permission set differs from the allowlist" >&2
  exit 1
}

members="$(unzip -Z1 "$bundle")"
for required in \
  BundleConfig.pb \
  base/manifest/AndroidManifest.xml \
  base/lib/arm64-v8a/libSDL3.so \
  base/lib/arm64-v8a/libc++_shared.so \
  base/lib/arm64-v8a/libmain.so; do
  printf '%s\n' "$members" | grep -Fxq "$required" || {
    echo "ERROR: AAB is missing $required" >&2
    exit 1
  }
done
if printf '%s\n' "$members" | grep -Eq '^META-INF/.*\.(RSA|DSA|EC|SF|MF)$'; then
  echo "ERROR: AAB is signed; the audited output must be pre-signing" >&2
  exit 1
fi
if printf '%s\n' "$members" | grep -Eq '^base/lib/(armeabi|armeabi-v7a|x86|x86_64)/'; then
  echo "ERROR: AAB contains an unintended native ABI" >&2
  exit 1
fi
if printf '%s\n' "$members" | grep -Eiq \
    '\.(iso|gcm|gcz|ciso|wbfs|wia|rvz|sav|gci|dtm|pcap|pcapng|mobileprovision|p12|key|pem|log)$'; then
  echo "ERROR: AAB contains a forbidden private-data or signing extension" >&2
  exit 1
fi

native_members="$(printf '%s\n' "$members" | grep '^base/lib/arm64-v8a/.*\.so$' | sort)"
expected_native_members="$(printf '%s\n' \
  base/lib/arm64-v8a/libSDL3.so \
  base/lib/arm64-v8a/libc++_shared.so \
  base/lib/arm64-v8a/libkartpad_discio.so \
  base/lib/arm64-v8a/libmain.so | sort)"
[[ "$native_members" == "$expected_native_members" ]] || {
  echo "ERROR: AAB native-library set differs from the product allowlist" >&2
  exit 1
}
asset_members="$(printf '%s\n' "$members" | grep '^base/assets/.' | sort)"
expected_asset_members="$(printf '%s\n' \
  base/assets/ThirdPartyLicenses/Mbed-TLS.txt \
  base/assets/ThirdPartyLicenses/Minizip-NG.txt \
  base/assets/dsp/dsp_coef.bin \
  base/assets/pipeline/initial_pipeline_cache.db \
  base/assets/wii/README.md \
  base/assets/wii/shared2/wc24/mbox/Readme.txt \
  base/assets/wii/shared2/wc24/mbox/wc24recv.ctl \
  base/assets/wii/shared2/wc24/mbox/wc24recv.mbx \
  base/assets/wii/shared2/wc24/mbox/wc24send.ctl \
  base/assets/wii/shared2/wc24/mbox/wc24send.mbx \
  base/assets/wii/shared2/wc24/misc.bin \
  base/assets/wii/shared2/wc24/nwc24dl.bin \
  base/assets/wii/shared2/wc24/nwc24fl.bin \
  base/assets/wii/shared2/wc24/nwc24fls.bin \
  base/assets/wii/shared2/wc24/nwc24msg.cbk \
  base/assets/wii/shared2/wc24/nwc24msg.cfg | sort)"
[[ "$asset_members" == "$expected_asset_members" ]] || {
  echo "ERROR: AAB asset set differs from the public runtime-resource allowlist" >&2
  exit 1
}

audit_root="$repo_root/.android-bootstrap/audit-aab"
mkdir -p "$audit_root"
for library in libSDL3.so libc++_shared.so libkartpad_discio.so libmain.so; do
  unzip -p "$bundle" "base/lib/arm64-v8a/$library" > "$audit_root/$library"
  if "$readelf" -l "$audit_root/$library" |
      awk '$1 == "LOAD" && $NF != "0x4000" { bad = 1 } END { exit bad ? 0 : 1 }'; then
    echo "ERROR: AAB $library contains a LOAD segment aligned below 16 KiB" >&2
    exit 1
  fi
done

dynamic="$($readelf -d -l "$audit_root/libmain.so")"
needed="$(printf '%s\n' "$dynamic" |
  sed -n 's/.*Shared library: \[\([^]]*\)\].*/\1/p' | sort)"
expected_needed="$(printf '%s\n' \
  libc++_shared.so libc.so libdl.so libm.so libSDL3.so \
  libandroid.so liblog.so libz.so | sort)"
[[ "$needed" == "$expected_needed" ]] || {
  echo "ERROR: AAB libmain.so dependency set differs from the allowlist" >&2
  exit 1
}
[[ "$dynamic" == *"GNU_RELRO"* ]]
printf '%s\n' "$dynamic" | grep -Eq 'GNU_STACK .* RW  0x0$' || {
  echo "ERROR: AAB libmain.so does not have a non-executable stack" >&2
  exit 1
}
main_symbols="$($readelf --wide --dyn-syms "$audit_root/libmain.so")"
sdl_symbols="$($readelf --wide --dyn-syms "$audit_root/libSDL3.so")"
[[ "$main_symbols" == *" SDL_main"* ]] || fail=1
for symbol in \
  Java_dev_kartpad_android_KartPadSurface_nativeBeginSurfaceMutation \
  Java_dev_kartpad_android_KartPadSurface_nativeEndSurfaceMutation \
  Java_dev_kartpad_android_RetroRewindArchiveExtractor_nativeExtract; do
  [[ "$main_symbols" == *" $symbol"* ]] || fail=1
done
[[ "${fail:-0}" == 0 ]] || {
  echo "ERROR: AAB libmain.so is missing an expected export" >&2
  exit 1
}
[[ "$sdl_symbols" == *" JNI_OnLoad@@"* ]] || {
  echo "ERROR: AAB libSDL3.so is missing JNI registration" >&2
  exit 1
}

unzip -p "$bundle" | strings > "$audit_root/aab.strings"
if grep -Eq '/Users/|Mario Kart Wii\.(iso|wbfs)' "$audit_root/aab.strings"; then
  echo "ERROR: AAB contains a private path or game-data name" >&2
  exit 1
fi
key_markers="$(grep -E -- '-----(BEGIN|END) (RSA |EC |OPENSSH )?PRIVATE KEY-----' \
  "$audit_root/aab.strings" | sort || true)"
private_key_suffix='PRIVATE KEY-----'
expected_key_markers="$(
  # The release AAB contains three parser copies in its runtime libraries and
  # repeats those code strings in native debug-symbol metadata.
  for ((index = 0; index < 6; ++index)); do
    printf '%s\n' \
      "-----BEGIN EC $private_key_suffix" \
      "-----BEGIN $private_key_suffix" \
      "-----BEGIN RSA $private_key_suffix" \
      "-----END EC $private_key_suffix" \
      "-----END $private_key_suffix" \
      "-----END RSA $private_key_suffix"
  done | sort
)"
[[ "$key_markers" == "$expected_key_markers" ]] || {
  echo "ERROR: AAB contains an unexpected private-key marker" >&2
  exit 1
}

echo "Android unsigned AAB audit passed."
echo "aab_sha256=$(shasum -a 256 "$bundle" | awk '{ print $1 }')"
