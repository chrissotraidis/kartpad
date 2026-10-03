# Agent instructions

## Releases

**Ready-to-play exception (owner decision, 4 Oct 2026):** KartPad releases ready-to-play builds again, from v0.7.9. Each release, at the version in `version.json`, publishes:

- `KartPad-v…-android.apk`: the Android app with the game pack built in (`KARTPAD_ANDROID_BUNDLED_GAME_PACK=<pack> scripts/build-android-app.sh`, then `KARTPAD_ANDROID_ALLOW_GAME_PACK=1 scripts/derive-android-release-apk.sh`), signed with the existing Community Release key.
- `KartPad-v…-ios.ipa`: the iPhone/iPad app (`scripts/build-ios-app.sh`) with the iOS game pack added (`scripts/add-game-pack-to-ipa.sh`), unsigned.
- `KartPad-v…-macos-arm64.zip`: the Mac app.
- `KartPad-v…-ios-for-padmint.ipa` (the iPhone app without game code), the PadMint recipe (`padmint.json`), source, notices and `SHA256SUMS`, so PadMint keeps working for players who build their own.

The game pack must match the app's pack fingerprint. Never publish disc data, extracted game files, saves, console keys or signing material. This exception is for KartPad only; other Pad projects still publish through PadMint.

Before any public release, every artifact must pass the repo's own APK/IPA audits, and `python3 -m padmint audit <artifact>` may flag only translated game code (address-named functions) in the ready-to-play builds; any key, disc or private-path finding is a stop. The Android build must reach a race on an emulator or device, both as an update over the previous release and as a fresh install with a first-launch game-data import. A failure is a stop, not a note.
