# KartPad Android

Android is now a supported community platform. The first release is
[`v0.4.10-android.1`](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.10-android.1),
based on the physically tested Preview 15 runtime: Original gameplay with
Razer Kishi, automatic touch hiding, and owner-reported Retro Rewind 6.12.7
Retro WFC worldwide race play on Pixel 9 Pro XL. Read
[installation, update safety and known limits](../docs/INSTALL_ANDROID.md).
Sustained 60 FPS and complete device/controller coverage are not claimed.

[Android 0.4.13 preview 1](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.13-android-preview.1)
is an unstable testing update for rating transfer and diagnostics. Physical
acceptance remains pending. The commands below reproduce that tagged source;
for current development use `main` and choose explicit candidate version metadata.

## Build the full playable app on an Apple Silicon Mac

The current scripts target macOS ARM64, with Xcode command-line tools, Python 3,
and the pinned Builder/Android dependencies. Linux/Windows host builds are not
documented as validated. Allow substantial disk space for dependencies and the
private translated graph; the installed app's size is not the build-space cost.

```sh
git clone https://github.com/chrissotraidis/kartpad.git
cd kartpad
git checkout v0.4.13-android-preview.1
./scripts/build-user-ipa.sh bootstrap
./scripts/bootstrap-android-host.sh
./scripts/check-android-host.sh
```

The shared Builder bootstrap prepares the pinned source/tool inputs and optional
Retro profile; it does not build an IPA in this command. Android bootstrap never
accepts SDK licenses or edits unrelated shell/system configuration. If a license
is pending, review and accept it yourself before continuing.

Translate **only your own supported RMCP01 revision 0 image**. The shared
bootstrap prepares the following pinned Retro 6.12.7 input paths:

```sh
./scripts/translate-retro-rewind.sh \
  --image /absolute/path/to/your-owned-game.wbfs \
  --retro-root private/builder/retro-rewind-downloads/6.12.7-extracted/RetroRewind6 \
  --payload private/builder/retro-rewind-downloads/payload.RMCPD00.bin

KARTPAD_ANDROID_VERSION_NAME=0.4.13-android-preview.1 \
KARTPAD_ANDROID_VERSION_CODE=28 \
KARTPAD_ANDROID_PACKAGE_FORMAT=aab \
  ./scripts/build-android-game-app.sh private/self-build/retro-rewind/translation

KARTPAD_ANDROID_EXPECTED_VERSION_NAME=0.4.13-android-preview.1 \
  ./scripts/audit-android-bundle.sh android/app/build/outputs/bundle/release/app-release.aab
```

If you already have the authorized complete dual graph, pass its ignored path
instead (the maintainer uses `private/g8-full-translation`). Never upload that
graph, source image, extracted content, saves or signing keys. A fresh checkout
does not include them. Use fresh runtime-source/build paths after changing source
patches: the wrapper reuses an existing prepared source directory.

For a locally installable debug-signed APK, use the same build command with
`KARTPAD_ANDROID_PACKAGE_FORMAT=apk`; it writes
`android/app/build/outputs/apk/debug/app-debug.apk`. Audit it with
`KARTPAD_ANDROID_EXPECTED_VERSION_NAME=0.4.13-android-preview.1 ./scripts/audit-android-package.sh PATH.apk`.
That debug build is for personal testing, not public distribution, and cannot
update a differently signed public app. A source-only fixture is not the game.

For non-debuggable release APK derivation and signing, use
`scripts/derive-android-release-apk.sh` with your own persistent private keystore
and password file. The script uses pinned bundletool, audits both artifacts,
rejects the Android debug identity, and never installs or publishes anything.
Keep signing keys backed up securely outside Git: future in-place updates need
the same key. The unsigned AAB stays local; this is not a Google Play release.

```sh
KARTPAD_ANDROID_KEYSTORE=/absolute/private/path/kartpad-release.p12 \
KARTPAD_ANDROID_KEY_ALIAS=kartpad-release \
KARTPAD_ANDROID_PASSWORD_FILE=/absolute/private/path/password.txt \
  ./scripts/derive-android-release-apk.sh \
    android/app/build/outputs/bundle/release/app-release.aab \
    artifacts/KartPad-v0.4.13-android-preview.1-arm64.apk
```

The keystore and key must use the same password for this simple PKCS12 flow.
Do not put passwords in commands, Git, screenshots or issue reports. This
derivation audits a candidate; it does not authorize publication by itself.

Maintainers: [release packaging, notices and hosted verification](../docs/RELEASING_ANDROID.md).

## Source-only fixtures

These use no game data or generated game code. After the host bootstrap above,
run one disposable emulator lane at a time:

```sh
./scripts/run-android-fixture.sh KartPad_API_36_ARM64
./scripts/run-android-fixture.sh KartPad_API_35_PS16K_ARM64
./scripts/run-android-fixture.sh KartPad_API_36_TABLET_ARM64
```

The runner refuses an already connected Android target, wipes only the named
KartPad AVD, checks surface recreation, and stops the emulator afterward.
Outputs remain under ignored `.android-bootstrap/`. These are toolchain,
Vulkan, memory and scheduler checks; emulator timings do not prove physical
performance.

## Device tests and architecture

Use the [physical-device handoff](../docs/ANDROID-PHYSICAL-HANDOFF.md) for
read-only preflight, guarded installation, data preservation and sanitized
capture. Read [Android architecture and acceptance](../docs/ANDROID.md) for
runtime boundaries and the [maintenance board](../docs/MAINTENANCE-BOARD.md)
for current candidates. Older preview evidence remains in
[dated artifacts](../docs/artifacts/) and [iterations](../docs/iterations/).
