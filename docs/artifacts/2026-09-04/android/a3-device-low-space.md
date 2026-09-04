# Android A3 real low-space preflight

Date: 2026-09-04

Branch: `codex/android-a3-device-low-space`

Baseline: `f58bd90529eb35dd3bd2a69f497c468bfc506d95`

## Falsifiable subgoal

Exercise KartPad's production Retro Rewind space probe against a genuinely
low-space Android app store before any archive acquisition. The requirement
must be derived from the sole profile, the disposable fill must be bounded by
host and guest safety guards, and the probe must report a real byte deficit
while leaving no archive state.

## Result

- Added a debug-only activity route that invokes the production
  `RetroRewindSpaceProbe` against the app's real `filesDir` and `cacheDir` and
  logs only bounded capacity/result values.
- Added a wiped-AVD harness that derives the current same-store requirement
  from `mkwii-rmcp01-rev0.json`, caps its filler at 2 GiB, refuses to proceed
  without 8 GiB of host reserve, and removes one explicit guest filler during
  cleanup.
- The API 36 ARM64 AVD began above the required threshold. A controlled 1,121
  MiB filler reduced available `/data` capacity to 4,186,030,080 bytes.
- The real production probe reported `INSUFFICIENT_SHARED_STORE` against the
  exact profile-derived 4,327,477,355-byte requirement. The harness verified
  `available < required` and found no `.zip` or `.part` acquisition state in
  app cache.
- The filler was deleted and the emulator shut down. The Android image does
  not expose a usable `fstrim` command, so its dedicated sparse host image
  retains allocated blocks for reuse; the host still has 44 GiB available.

## Verification

- `scripts/test-android-retro-rewind-low-space.sh`: pass.
- Final marker:
  `Android Retro Rewind low-space preflight passed: avd=KartPad_API_36_ARM64
  api=36 abi=arm64-v8a page_size=4096 required=4327477355
  available=4186030080 filler_mib=1121 archive_bytes=0`.
- Debug assemble and strict APK/privacy audit pass. The exact source-only APK
  is 33,843,921 bytes at SHA-256
  `dda33041fd82e4db874562313dad5bdd583d9d164199d87dad55acc287779e7d`.
- Shell syntax, ShellCheck with repository source resolution, and diff checks
  pass. No ADB target remains after cleanup.
- All eight A3 source contract runners, release Kotlin/Java compilation,
  API-28 lint, SunPad snapshot, and repository safety pass. Source verification
  validates 446 patch hunks and the WiiCompiled, SunPad, and WheelWizard pins,
  then stops at the unchanged ignored `rr-pulsar` mismatch (local
  `b566a5d...`, pinned `29e76d4...`); this work does not mutate that checkout.

The first ShellCheck pass rejected an ambiguous `A && B || fail` assertion.
The final harness uses an explicit conditional; no low-space run had begun
before that correction.

## Classification

**Pass for the production Android same-store preflight under a real controlled
byte deficit before archive acquisition.** This is not mid-download or
mid-extraction `ENOSPC`, does not execute the 1.86 GB official archive, and
does not satisfy gameplay or physical-hardware A3 rows. No production archive,
private data, device identifier, APK, or AAB was downloaded or published.
