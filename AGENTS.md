# Agent instructions

## Releases

Releases publish only apps **without game code**: the empty Android app (`scripts/build-android-app.sh`), the empty iPhone app (`scripts/build-ios-app.sh`), the PadForge recipe (`padforge.json`) and `SHA256SUMS`, all at the version in `version.json`. Players add their own game pack with PadForge (owner's release formula, 29 Sep 2026: https://github.com/chrissotraidis/padforge/blob/main/docs/DECISIONS.md, D5 and D6). Never publish a game pack, a personal build, translated code, disc data, keys or signing material.

Before any public release, every artifact must pass PadForge's content check (`python3 -m padforge audit <artifact>`) and the repo's own APK/IPA audits, and the empty apps must reach a race with a PadForge-made pack on a device or emulator. A failure is a stop, not a note.
