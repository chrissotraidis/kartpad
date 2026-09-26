# Android 0.5.1 release build: code229 (26 September 2026)

## State

Built, signed, audited and update-tested. **Not published**: no tag, GitHub release,
store upload or owner-device install exists from this work. The notices ZIP is
not yet packaged because `scripts/package-android-release-notices.py` still pins the
superseded code220 candidate (see "Notices packaging" below).

## Source and identity

- Compilation source: `de3a99c9054042f07e2840066b1bd06f4012659b` (clean tree; embedded
  `assets/kartpad-build.json` reports `source_dirty: false`).
- Android runtime: `ce9e90aea7682489da6b045e5b2b83f02a0f21f3` (clean). Other gitlinks at build time:
  iOS `cbe43de`, macOS `69cdba9`, tvOS `686a573`, all clean.
- Private translation: stabilization worktree `private/android-gx-direct-20260925/translation`
  (30030 files, fingerprint `b9b4d447…03e0`); Retro REL report guard verified.
- Clean full build: fresh `build/android229/{source,build}`; the previous Gradle
  `android/app/build` and `.cxx` trees were moved aside first, so all 788 native objects compiled
  from scratch. Gradle's Java/Kotlin build cache supplied 12 non-native tasks.
- Version 0.5.1, versionCode 229, arm64-v8a only, minSdk 28, targetSdk 36, not debuggable,
  `profileable shell=false`, zipalign (16 KiB pages) passed.
- Signer: single v3 signer `CN=KartPad Community Release`, certificate SHA-256
  `c1dbe0a0d72d830a5779476b346a750d0a37515adef992cad2f3863058f7f2f2` (the existing release key;
  same signer as public v0.5.0). No key was created or rotated.

## Assets

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `artifacts/release-051b/KartPad-v0.5.1-arm64.apk` | 169125606 | `89859d4d08492013fa8a979f9732e8a2a33f883142812770e75f6b956fae4b19` |
| Unsigned AAB (private, not a download) | 133315804 | `673df6a36bf0c63fb4ea443420837a7f05e2c96703ebe0b6e400ee5d632049dd` |

Native libraries in the APK: `libmain.so` `8180940e3cf4188a7132e55263785d9843f97b00145df54917a4990b0631d9de`
(new); `libSDL3.so`, `libc++_shared.so` and `libkartpad_discio.so` are byte-identical to code220.
Stripped libmain lacks `Aurora: Dear Imgui` and contains `persistent=%d ref=0x`.

## Verification

- `audit-android-bundle.sh` and `audit-android-package.sh` passed with
  `KARTPAD_ANDROID_EXPECTED_VERSION_NAME=0.5.1`, `…_VERSION_CODE=229`, `…_REQUIRE_RELEASE=1`.
- A second derivation from the same AAB produced byte-identical APK bytes.
- `test-android-debug-labels.py` (6 gated calls), `test-android-pipeline-workers.py` (8 cases),
  `test-shared-runtime-parity.py` (5 files, four pins) passed. The Android public-release, bundle-audit
  and update-in-place contract tests passed (8 tests, 5 subtests).
- `scripts/verify-sources.sh` passed with `KARTPAD_DISC_PATH` set to the main checkout's read-only WBFS.
  With no override it fails "supplied WBFS size changed" only because this worktree's
  `ref/Mario Kart Wii.wbfs` is a symlink and `stat` measures the link.

## Update-path result

A fresh disposable emulator (`KartPad_Release051b_20260926`, API36 arm64) installed the anonymously
downloaded public v0.5.0 APK (code135, 111773259 bytes, `63526e4d…da37`, same signer). The 2044
game-data files were staged into the app's `files/KartPad/GameData`; v0.5.0 then showed
"Mario Kart Wii — Ready to play". `adb install -r` of the code229 APK succeeded. All 2044 files were
byte-identical afterwards, and first-install time and data-directory inodes were unchanged. No uninstall or clear-data
was used.

After the update, code229 showed "Ready to play", launched the game, rendered the opening
sequence, and on-screen A touch input advanced to the New Licence screen. Logcat showed no crash
after about 2400 frames (about 10–23 fps under SwiftShader software rendering).

**Not verified:** a race or any gameplay beyond the licence screen, save-game behaviour,
Retro Rewind, online play, and physical-device performance. The emulator's frame rate says
nothing about phones. The owner's phone was attached over USB throughout. Every adb command
targeted `emulator-5584` by serial, and the phone was not touched. For that reason
`scripts/test-android-update-in-place-emulator.sh` (which requires exactly one device) was not used;
the same checks were performed by hand.

## Notices packaging (pending)

`package-android-release-notices.py` must be updated in a packaging-only commit before it can run:
`CODE = 229`; `APPROVED_SOURCE = "de3a99c9054042f07e2840066b1bd06f4012659b"`;
`APPROVED_APK = "89859d4d…4b19"`; `APPROVED_AAB = "673df6a3…49dd"`;
`APPROVED_NATIVE["lib/arm64-v8a/libmain.so"] = "8180940e…d9de"`; `APPROVED_SOURCE_ARCHIVE` = the
final source archive hash; the `physicalAcceptance`/`releaseTwin` text. The source archive's
`SOURCE-MANIFEST.json` must have `sourceRevision` de3a99c and
`candidateArtifacts["KartPad-v0.5.1-arm64.apk"] = {"bytes": 169125606, "sha256": "89859d4d…4b19"}`.
Native build for the packager: `android/app/.cxx/RelWithDebInfo/366c1u3d/arm64-v8a`.

## Private logs

`work/android229/`: `build.log`, `derive.log`, `repeat.log`, test logs, `verify-sources*.log`,
`emulator135-files.sha256`, `emulator229-files.sha256`, `pkg-*.txt`, `inodes-*.txt`,
`emulator-update-result.json`, screenshots and `v229-play-logcat.txt`.
