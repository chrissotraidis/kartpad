#!/usr/bin/env bash
# Build app + game pack for the current runtime working tree. Usage: build-variant.sh NAME
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
name=$1; out="$PWD/build/perf/v-$name"; mkdir -p "$out"
ORG_GRADLE_PROJECT_kartpadDiagnosticRelease=true ORG_GRADLE_PROJECT_kartpadProfileable=true ORG_GRADLE_PROJECT_kartpadVersionName=0.8.0-perf KARTPAD_ANDROID_PACKAGE_FORMAT=apk-release scripts/build-android-app.sh "$out/app" > "$out/app.log" 2>&1 || true
stage=$(ls -td "$out"/app/2* | head -1); mkdir -p "$stage/out"
cp android/app/build/outputs/apk/release/app-release.apk "$stage/out/"
unzip -o -q -j "$stage/out/app-release.apk" 'lib/arm64-v8a/libmain.so' -d "$stage/out"
cp android/app/build/intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib/arm64-v8a/libmain.so "$out/libmain.unstripped.so"
fp=$(sed -n 's/^Pack interface fingerprint: //p' "$out/app.log")
echo "fingerprint $fp"
KARTPAD_GAME_PACK_JOBS=14 scripts/build-game-pack.sh android "${KP_TRANSLATION:-private/self-build/retro-rewind/translation}" "$stage/out/libmain.so" "$out/libkartpad_game.so" "$out/pack-work" > "$out/pack.log" 2>&1
echo "$fp" > "$out/fingerprint"; cp "$stage/out/app-release.apk" "$out/app.apk"
ls -l "$out/app.apk" "$out/libkartpad_game.so"
