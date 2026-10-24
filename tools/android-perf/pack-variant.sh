#!/usr/bin/env bash
# Game pack only, against an existing variant's app: build-variant.sh FROM first.
# Usage: [KARTPAD_GAME_PACK_PGO=generate|use=PROFILE] pack-variant.sh NAME FROM
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
name=$1; from="$PWD/build/perf/v-$2"; out="$PWD/build/perf/v-$name"; mkdir -p "$out"
stage=$(ls -td "$from"/app/2* | head -1)
cp "$from/app.apk" "$from/fingerprint" "$out/"
KARTPAD_GAME_PACK_JOBS=${KARTPAD_GAME_PACK_JOBS:-14} scripts/build-game-pack.sh android \
  "${KP_TRANSLATION:-private/self-build/retro-rewind/translation}" "$stage/out/libmain.so" \
  "$out/libkartpad_game.so" "$out/pack-work" > "$out/pack.log" 2>&1
ls -l "$out/app.apk" "$out/libkartpad_game.so"
