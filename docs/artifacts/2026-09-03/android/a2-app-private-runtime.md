# Android A2 app-private runtime evidence

Date: 2026-09-03

Base checkpoint: `d791221` (`codex/android-a2-runtime-link`)

Host: Apple Silicon macOS 26.6.2

Target: `KartPad_API_36_ARM64`, Android API 36, `arm64-v8a`, 4,096-byte pages,
gfxstream with host lavapipe

## Falsifiable subgoal

Package only the public runtime support files, install them before SDL loads,
route configuration, logs, NAND, and mutable renderer caches to Android
app-private storage, then start the complete Original runtime without staging
game data. The accepted outcome is initialization through the renderer and
guest constructors followed by the existing explicit missing-DVD failure.

## Package and storage boundary

Gradle's private game-runtime mode packages exactly 14 allowlisted public
assets: the DSP coefficient ROM, initial pipeline cache, and Wii bootstrap
files. `KartPadRuntimeResources` installs them through a versioned staging
directory at `files/KartPad/RuntimeResources/a2-v1` before
`SDLActivity.onCreate`. The strict APK audit now rejects any other asset set;
fixture mode continues to package no assets.

The Activity exports its exact `filesDir` and `cacheDir` to the native process
before SDL loads. The runtime uses those Context-derived paths without calling
SDL's Android JNI helpers during library static initialization. Durable config,
logs, NAND, and resource files resolve below `files/KartPad`; Dawn and Aurora
mutable databases resolve below `cache/KartPad`. No broad storage permission is
requested, and no private game data is in the APK.

## Failure-driven corrections

The first cold launch aborted inside `SDL_GetAndroidInternalStoragePath` with
`CallStaticObjectMethod received NULL jclass`: `libmain.so` static
initialization ran while SDL was still loading the library. Moving resource
installation ahead of SDL and passing Context-derived directories through the
process environment removes that initialization cycle.

The next launch reached guest-memory setup but failed with `ftruncate failed:
Invalid argument`. Android `ASharedMemory_create` already sizes the object and
does not accept the redundant resize used by the POSIX/iOS backings. Skipping
only that Android `ftruncate` preserves the shared-alias implementation.

## Accepted result

- Fresh runtime preparation with the complete patch stack: pass.
- Full private game-runtime Gradle build: pass.
- Strict package/native/private-data and exact public-asset audit: pass.
- Default source-only fixture build and zero-asset audit: pass.
- Cold API 36 launch from cleared app data: pass for this subgoal.
- Versioned public resource install: 14/14 files.
- Dynamic 4 GiB guest reservation and translated image load: pass.
- Main DOL constructors: 43 executed.
- StaticR constructors: 192 executed.
- Vulkan adapter/device/surface initialization: pass.
- Public pipeline seed: 1,199 rows merged, zero skipped.
- Mutable cache location: `cache/KartPad`, including Dawn and pipeline SQLite
  databases.
- Managed NAND location: `files/KartPad/NAND`.
- Missing private DVD data: explicit `No DVD root is configured` failure with
  diagnostics under `files/KartPad/Logs`.

The accepted local APK is 103,429,792 bytes with SHA-256
`49526a79b60bdc0f1b3ca51202f4b95c12b2fef3329a552a125a63f1863011c2`.
Its stripped `libmain.so` is 83,532,824 bytes with SHA-256
`3b78fba2aef646f13be698c5cbefa8b6a934e4a44feb1d6468329fddb74d2ef5`.
The private-path patch SHA-256 is
`7e47ebe0cad1a7664ed95b32eb21ad2f6d7925d10704ce69a6a6efd0dce6c351`.
The post-change default fixture APK also passes the same audit with SHA-256
`dcc02c1b618e1de4e32b135ff058159eadbd9632a19e74b9a64384de18c3128b`.

## Honest classification

**Pass for the A2 app-private resource/config/cache/NAND bridge and complete
runtime initialization without game data.** This is stronger than build-only
evidence but is not title, menu, rendered game frame, controller, race, result,
save/relaunch, game lifecycle, audio acceptance, performance, or physical-
device evidence. No APK/AAB was hosted or published. The next subgoal is to
stage the already validated ignored `RMCP01` DATA directory outside the APK,
write its app-private config path, and establish the first emulator game boot.
A2 remains open.
