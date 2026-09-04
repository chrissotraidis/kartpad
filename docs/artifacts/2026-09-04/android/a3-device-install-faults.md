# Android A3 device install fault execution

Date: 2026-09-04

Branch: `codex/android-a3-device-install-faults`

Baseline: `9a6c5f6877ee8560953000d8bff2b855e024e2f4`

## Falsifiable subgoal

Upgrade the existing-valid-install fault from a host-only Java contract to the
real Android app-private filesystem and JNI extraction path. A bounded
synthetic update must preserve the prior validated install when its archive is
rejected or activation fails, then replace it atomically when every check
passes, on both supported emulator page-size lanes.

## Result

- A debug-only fixture loads the APK's real `libmain.so`, creates tiny ZIPs in
  app cache, and calls the production Java/JNI install pipeline. It does not
  weaken or replace the production release contract.
- The fixture installs and revalidates an initial synthetic pack, appends a
  corrupt byte and proves rejection before extraction, and revalidates the
  untouched active pack.
- A pre-existing token-scoped rollback destination injects an activation
  failure after extraction/validation. The pipeline reports
  `ACTIVATION_FAILURE`, deletes only its staging tree, and retains the prior
  valid install.
- A final validated replacement uses the real same-volume atomic swap. It
  is then moved into the precise single-rollback/no-active-install crash state
  alongside stale staging. Startup recovery restores that validated pack and
  deletes the stale staging, with no transient directory left behind.
- All fixture implementation and triggers live in the debug source set. The
  release Kotlin/Java graph compiles and API-28 lint passes without the device
  fixture class.

## Verification

- `scripts/run-android-fixture.sh KartPad_API_36_ARM64`: pass on a wiped API 36
  ARM64 AVD with 4 KiB pages.
- `scripts/run-android-fixture.sh KartPad_API_35_PS16K_ARM64`: pass on a wiped
  API 35 ARM64 AVD with 16 KiB pages.
- Both final runs observed
  `A3 device install faults passed existing=preserved replacement=valid
  recovery=restored`, then
  passed the existing 4 GiB guest-memory, scheduler/fiber, SDL controller,
  resumable-transfer, unique-worker, Vulkan present, orientation, and three
  background/foreground recreation checks.
- All eight Android A3 source contract runners pass: version, download,
  extraction, pipeline, worker policy, space, content, and storage.
- Source-only release Kotlin/Java compile, API-28 release lint, debug assemble,
  strict APK/privacy audit, SunPad snapshot, repository safety, shell syntax,
  shell lint, and diff checks pass.
- Source verification validates all 446 patch hunks and the WiiCompiled,
  SunPad, and WheelWizard pins, then reaches the unchanged ignored
  `ref/upstream/rr-pulsar` mismatch: local `b566a5d...` versus pinned
  `29e76d4...`. This checkpoint does not mutate that user/private checkout.
- The exact source-only debug APK is 33,843,921 bytes at SHA-256
  `f9f9a83182b9de5ff76f6751355677c3f97c90eb6246b7bdffb87c95c7b95b65`.
- Both emulators were shut down and `adb devices` is empty.

The first compile correctly rejected checked `IOException` calls inside a
non-throwing verifier lambda. Capturing the expected size and digest before
the lambda fixed that source error; the fixture behavior did not change.

## Classification

**Pass for existing-valid-install preservation, atomic replacement, and the
single-rollback process-death recovery state through Android's real app-private
filesystem, JNI extractor, validation, and activation paths on 4 KiB and 16
KiB emulator lanes.** This does not prove
the 1.86 GB official archive, real storage exhaustion, normal mode routing,
Retro Rewind gameplay, or physical hardware. No production archive, private
data, device identifier, APK, or AAB was downloaded or published.
