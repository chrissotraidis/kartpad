# Android A3 production mode chooser

Date: 2026-09-04

## Scope

This checkpoint replaces the debug-only Android runtime-profile intent with a
production-owned Original/Retro Rewind chooser that runs before SDL and the
translated runtime start. It covers the API 36 ARM64 emulator. It does not
claim a controller-driven Retro Rewind race or physical-device acceptance.

## Implementation

- `KartPadLaunchActivity` is the production launcher and presents the KartPad
  title, data requirement, and side-by-side Mario Kart Wii and Retro Rewind
  choices before native startup.
- Retro Rewind validation runs away from the UI thread. A valid pinned 6.12.5
  installation enables direct launch; a missing or invalid installation shows
  the download state and routes to the existing production installer.
- `KartPadActivity` receives one explicit production profile, independently
  validates Retro Rewind before exporting `KARTPAD_RUNTIME_PROFILE`, and still
  permits the pre-existing protected debug override in debug builds.
- The chooser finishes after selection because the translated runtime is
  process-global and is not restartable in place. It does not leave a screen
  behind the SDL activity that would imply an unsupported same-process switch.
- The SDL activity is not exported in the release manifest. Debug builds retain
  shell access protected by Android's `DUMP` permission for existing fixtures.
- The same lint run found an existing API-28 violation in a debug install
  fixture. Its Java 16 `Stream.toList()` call was replaced by the compatible
  collector without changing fixture behavior.

## Emulator evidence

The visible test used `KartPad_API_36_ARM64`, API 36, `arm64-v8a`, a 4 KiB page
size, and a 1280 by 720 test display.

- The initial vertical layout placed Retro Rewind below the fold. That result
  was rejected. The corrected side-by-side layout presents both complete
  choices and the validation status without scrolling.
- With the preserved production-size pack, the chooser reported `Retro Rewind
  6.12.5 is ready`. Selecting it logged `selected=retro_rewind`, the SDL owner
  logged `requested=retro_rewind installed=valid`, and the branded Retro Rewind
  title remained alive beyond 30 seconds.
- A cold return through the chooser selected Original, logged `selected=base`
  and `requested=base`, and reached the Original title beyond 30 seconds.
- A physical landscape flip recreated the chooser; both choices returned
  visible and enabled after validation.
- A debug-only missing-install state displayed `Download 6.12.5`; selecting it
  opened `RetroRewindInstallActivity`. No installed content was moved or
  deleted for that control.
- The Original save remained SHA-256
  `708c7a040e0cfe6cd815690e63f46d1678f17899bce0e786f7480030830f1d13`.
- The Retro save remained SHA-256
  `3c4aeacd0356a679f261571b53cddfd371a5dc3ff9602be39ca26bdef06ea40e`.
- No new missing-target crash record appeared during the exact-build switch.

## Verification

- Full dual-profile ARM64 debug build: pass.
- Android lint, including the API-28 surface: pass.
- Release main-manifest merge: pass; chooser exported, SDL activity private.
- Content, storage, install-pipeline, and worker-policy contracts: pass.
- Strict package/privacy audit: pass for the local-only APK at SHA-256
  `7088f683c9cc765c77a12203646af6d9ecdb13f1eb77f559b4bfdbc75e1caf94`.
- SunPad overlay snapshot: unchanged. Source verification reaches the known
  ignored `rr-pulsar` mismatch (`b566a5d` local versus `29e76d4` pinned) after
  all patch hunks and earlier references pass; this checkpoint does not mutate
  that user/reference checkout.

## Classification

**Pass for the production chooser and bounded emulator mode-switch gate.** The
app no longer relies on the debug profile extra for normal mode selection, and
the exact audited APK reaches the correct profile in both directions without
changing either save. A controller-driven Retro Rewind race/results/save,
trustworthy timing, physical controller/audio/rumble, physical Android
hardware, and release acceptance remain open. No APK, AAB, pack, save, disc,
or private capture was published.
