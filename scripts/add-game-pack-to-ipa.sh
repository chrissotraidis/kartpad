#!/usr/bin/env bash
# Put a player's game pack inside the published (empty) KartPad IPA. The
# result is unsigned; the player's sideloading tool signs it as usual.
# It contains their own game code, so it is private: never publish it.
#
# Usage: scripts/add-game-pack-to-ipa.sh EMPTY_IPA GAME_PACK OUTPUT_IPA
set -euo pipefail

[[ $# -eq 3 ]] || { echo "usage: $0 EMPTY_IPA GAME_PACK OUTPUT_IPA" >&2; exit 64; }
empty_ipa="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
pack="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
output="$3"
[[ -f "$empty_ipa" && -f "$pack" ]] || { echo "ERROR: missing input" >&2; exit 66; }
[[ ! -e "$output" ]] || { echo "ERROR: output exists: $output" >&2; exit 73; }

work="$(mktemp -d)"
trap 'rm -r "$work"' EXIT
(cd "$work" && unzip -q "$empty_ipa")
app="$work/Payload/KartPad.app"
[[ -x "$app/KartPad" ]] || { echo "ERROR: not a KartPad IPA: $empty_ipa" >&2; exit 65; }
[[ ! -e "$app/Frameworks/libkartpad_game.dylib" ]] || { echo "ERROR: this IPA already has a game pack" >&2; exit 65; }
mkdir -p "$app/Frameworks"
install -m 0755 "$pack" "$app/Frameworks/libkartpad_game.dylib"
mkdir -p "$(dirname "$output")"
output="$(cd "$(dirname "$output")" && pwd)/$(basename "$output")"
(cd "$work" && zip -qry "$output" Payload)
echo "Your KartPad with your game pack (private; never publish): $output"
