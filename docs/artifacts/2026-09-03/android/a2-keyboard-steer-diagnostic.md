# Android A2 keyboard-steer diagnostic

Date: 2026-09-03

Base checkpoint: `dbb138e` (`codex/android-a2-rkg-race`)

Target: `KartPad_API_36_ARM64`, Android API 36, `arm64-v8a`, 4,096-byte
pages, gfxstream with host lavapipe

## Falsifiable subgoal

Keep the debug-only RKG fixture's deterministic throttle while allowing
Android keyboard steering, then determine whether either that hybrid or a
previously proven native staff stream can complete a real player Time Trial.

## Opt-in boundary

The Android-only runtime patch recognizes
`KARTPAD_RKG_KEYBOARD_STEER_V2=1`. While the existing validated RKG fixture is
armed, this mode retains constant A/accelerate, takes only the Classic left
stick from the keyboard bridge, disables fixture tricks, and publishes the
matching raw axes. It does not change menu input, release builds, Apple
runtime patches, ordinary keyboard/controller input, or the default RKG
stream.

`KartPadActivity` sets the mode only in a debug game build when both the
validated app-private `TestInput.rkg` and the separate regular-file marker
`TestInput.keyboard-steer` exist. The marker contains no private input. With
the marker absent, both keyboard-steer environment variables are explicitly
cleared. Cold-launch logs proved both branches: `keyboard steer=true` with the
marker and `keyboard steer=false` without it.

## Runtime results

The hybrid run reached the real Luigi Circuit player HUD and accepted Android
`A`/`D` steering while the fixture held acceleration. Coarse accessibility
key pulses could recover the kart from grass to the track, but could not keep
it on the racing line for three laps. The run was stopped without a forced
finish and is rejected as completion, results, save, controller, or physical
device evidence.

Two normal RKG-steering controls were then run with the marker absent:

- GCN Mario Circuit used the exact staff card and Mario / Standard Bike M /
  Manual. It diverged into the outside wall by guest time `17.244`, lap 1/3.
- SNES Mario Circuit 3 used the exact `01:38.880` staff card and Mario /
  Standard Kart M / Manual configuration that previously completed through
  the native macOS live-player path. It hit the outside block by guest time
  `10.749`, lap 1/3.

The latter falsifies the strongest available natural-completion hypothesis on
Android. No forced-finish variable was enabled in any run.

The all-cups precondition was generated from the app's ignored save using the
existing guarded tool. It changed only the documented GP completion word and
core CRC. After testing, the original 2,867,200-byte save was restored and
verified byte-for-byte at SHA-256
`07c4ff00b6eb686cff3b7c7bc365c0e453a99f1a1f8ad6ef9238679a73a71155`.
The RKG was disabled and the keyboard marker removed before shutdown. No save,
RKG, game data, or runtime capture is committed or packaged.

## Build and classification

The full private Original debug APK builds with the Android-only patch. The
local APK is 103,430,368 bytes with SHA-256
`6b4e750366661056e42470f995f833fd132c26643eb5f86761a371b85e710b3c`.
Its stripped 83,533,400-byte `libmain.so` has SHA-256
`9d6cf6a59d553c57dbb9db3ddf7e7925eba6da300d2c92212c2a92363f76ced4`.
Game debug and release Kotlin compilation, `lintDebug`, the strict APK audit,
the repository safety audit, patch dry-run, and `git diff --check` pass. A
fresh prepared source applied the patch and matched the exercised `kpad.cpp`
byte-for-byte. The broader source verifier accepted 395 hunks and the pinned
WiiCompiled, SunPad, and WheelWizard checkouts before stopping on the existing
ignored rr-pulsar checkout mismatch (`b566a5d` local versus `29e76d4` pinned).
No APK or AAB was hosted or published.

Classification: **Pass for a separately gated Android debug steering
diagnostic; fail for complete player-race automation.** A2 remains open for a
complete player race/results/save/relaunch, real controller, and physical
Android hardware.
