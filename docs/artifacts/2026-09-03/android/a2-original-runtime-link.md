# Android A2 Original runtime link evidence

Date: 2026-09-03

Base checkpoint: `74b35b2` (`codex/android-a1-elf-scheduler`)

Host: Apple Silicon macOS 26.6.2

Target: Android API 28+, `arm64-v8a`, NDK 29.0.14206865

## Falsifiable subgoal

Compile and package the complete ignored Original translated graph through the
real Android Gradle app module. Require the packaged library to export SDL and
KartPad surface entry points and pass the existing strict package audit. Do not
classify this as boot or gameplay evidence.

## Private input boundary

The ignored shard manifest reports 29,065/29,065 Original functions and no
Retro Rewind functions. Its SHA-256 is
`f5c2371c4d2af9e416e26aacdf9288e2d1f10c499b5fcbdd94b6208e4db5ca18`.
Preparation reads the graph only from the ignored private directory. Legacy
registration metadata and the data-blob assembly section are normalized into
the ignored build directory; the translator-owned graph is never modified.
No extracted game DATA directory is read or packaged in this slice.

## Result

- Fresh Android runtime preparation: pass.
- Production shared runtime compile: pass.
- All 29,065 Original translated functions: pass.
- ELF AArch64 production fiber object: pass.
- Final `libmain.so` link: pass.
- Gradle `:app:assembleDebug` game-runtime mode: pass in 9m19s after the final
  path-remapping change.
- Default fixture-mode Gradle build after surface-owner changes: pass.
- Strict APK audit: pass.

The packaged APK is 103,425,387 bytes with SHA-256
`5d96c31ef91ead5d7ada0977c1853d39b4fcc7f57ea8f4fe3439c1de89ac9e13`.
Its stripped `libmain.so` is 83,529,560 bytes with SHA-256
`a1b15ee74f77fd891f7d885c6602bf23bd73c9b6e4cfcfc56ce1ee2279089165`
and Build ID `469d0b33cb76217c7c4e3580859f2ecc13d8cdc7`.

The APK contains exactly `libmain.so`, `libSDL3.so`, and `libc++_shared.so` for
`arm64-v8a`. It passes ZIP and native 16 KiB alignment, expected dynamic
dependencies, RELRO, non-executable stack, no-permission policy, SDL/JNI export
checks, forbidden-extension checks, and whole-package absolute-path/private-key
scanning. The first audit correctly failed on compiler-emitted absolute paths;
Android-owner prefix maps removed them before the accepted package was built.

## Honest classification

**Pass for the first A2 compile/link/package subgoal only.** The artifact was
not hosted or published. No game data was staged, and no game boot, frame,
audio, controller, race, result, save, relaunch, lifecycle, performance, or
physical-device behavior was exercised. The next subgoal is an Android
app-private config/cache/data bridge followed by a privately staged emulator
boot. A2 remains open.
