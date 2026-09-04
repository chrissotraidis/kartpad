# Android A3 mid-extraction ENOSPC

Date: 2026-09-04

Branch: `codex/android-a3-device-enospc`

Baseline: `33f6f94`

## Falsifiable subgoal

Prove the real Android JNI extraction/installation pipeline preserves an
existing validated Retro Rewind pack when storage becomes exhausted after
preflight. Use a bounded temporary filesystem and synthetic content, require
measured extraction progress before native `IO_FAILURE`, remove partial
staging, and reclaim every temporary emulator/storage artifact afterward.

## Result

- Added a debug-only two-phase device fixture. Preparation installs and
  validates a small existing pack through the production pipeline before the
  test filesystem is filled. Execution verifies a host-created synthetic ZIP,
  invokes the production JNI extractor, and revalidates the existing pack
  after failure.
- Added a guarded harness that creates its own temporary API 36 ARM64 AVD and a
  512 MiB ext4 loop filesystem mounted at the app-private KartPad support root.
  Ownership and SELinux context are derived from the installed package, and
  app access is proven before the fixture runs.
- The harness creates the replacement ZIP before applying a 368,544 KiB
  filler. The archive is only 391,907 bytes but declares and hashes a
  402,653,184-byte synthetic file, so extraction—not archive creation—must
  encounter the bounded filesystem limit.
- JNI extraction made 117,440,519 bytes of measured progress, then returned
  `IO_FAILURE`. The pipeline classified `EXTRACTION_FAILURE`, removed its exact
  partial staging directory, and the previous installed pack still passed its
  byte/hash contract.
- Cleanup force-stopped the app, unmounted the loop filesystem, deleted the
  loop image/archive, stopped the emulator, deleted the exact temporary AVD,
  and removed host fixtures. No ADB target or temporary AVD remains; host free
  space returned to 46 GiB.

## Verification

- `scripts/test-android-retro-rewind-enospc.sh`: pass.
- Final marker:
  `Android Retro Rewind ENOSPC extraction passed:
  avd=KartPad_API_36_ENOSPC api=36 abi=arm64-v8a filesystem_mib=512
  filler_kib=368544 payload_bytes=402653184 extracted_bytes=117440519
  existing=preserved staging=clean archive=synthetic`.
- Debug assemble and strict APK/privacy audit pass. The exact source-only APK
  is 33,843,921 bytes at SHA-256
  `120eb052dbe10d3967ff8a58ea3032526d5d1d2982e580ccdf92092d30b49e1a`.
- All eight A3 source contracts, source-only release compile, API-28 lint,
  private game-runtime debug Kotlin/Java compile, SunPad snapshot, repository
  safety, shell lint/syntax, and diff checks pass. Source verification validates
  446 patch hunks and the WiiCompiled, SunPad, and WheelWizard pins, then stops
  at the unchanged ignored `rr-pulsar` mismatch (local `b566a5d...`, pinned
  `29e76d4...`); this work does not mutate that checkout.

Discovery rejected two disproportionate alternatives before the passing run:
the emulator ignored a smaller partition request for its existing 6 GiB data
image, while filling that entire image would have required roughly 5 GiB. A
temporary 512 MiB loop filesystem reduced the bounded write budget and was
fully deleted after the run. One manual AVD cleanup initially used an unset SDK
variable; the exact named AVD was then deleted with the resolved pinned SDK
path before the automated test began. The emulator had also normalized one
pinned AVD config from `key=value` to `key = value`; restoring only that
mechanical formatting returned `check-android-host.sh` to green without
changing its image or userdata.

## Classification

**Pass for real Android mid-extraction storage exhaustion with measured JNI
progress, exact staging cleanup, and preservation of a previous validated
install.** This closes the synthetic emulator form of A3's full-disk fault; it
does not execute the official 1.86 GB archive, prove production-size peak
space, gameplay, mode switching, or physical hardware. No production archive,
private data, device identifier, APK, or AAB was downloaded or published.
