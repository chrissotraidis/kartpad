# Agent instructions

## Releases

Releases publish only apps **without game code**: the empty Android app (`scripts/build-android-app.sh`), the empty iPhone app (`scripts/build-ios-app.sh`), the PadMint recipe (`padmint.json`) and `SHA256SUMS`, all at the version in `version.json`. Players add their own game pack with PadMint (owner's release formula, 29 Sep 2026: https://github.com/chrissotraidis/padmint/blob/main/docs/DECISIONS.md, D5 and D6). Never publish a game pack, a personal build, translated code, disc data, keys or signing material.

Before any public release, every artifact must pass PadMint's content check (`python3 -m padmint audit <artifact>`) and the repo's own APK/IPA audits, and the empty apps must reach a race with a PadMint-made pack on a device or emulator. A failure is a stop, not a note.
