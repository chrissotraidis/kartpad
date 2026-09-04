# Android A3 official production install

Date: 2026-09-04

Branch: `codex/android-a3-production-install`

Baseline: `6756442`

## Falsifiable subgoal

On a freshly wiped API 36 ARM64 emulator, drive the release-owned installer
through the official Retro Rewind 6.12.5 download, exact verification, native
extraction, activation, cache cleanup, process restart, and offline installed-
content validation. Treat emulator execution as emulator evidence only.

## Result

- The wiped emulator exposed 5,258,480 KiB of app-store space, exceeding the
  profile-derived 4,327,477,355-byte initial requirement. Its network was
  Android-validated before the production control was activated.
- The real foreground worker downloaded all 1,859,041,899 bytes from the
  profile-generated official HTTPS URL. The resulting archive matched SHA-256
  `d8f7c61636ef76f8a451f4071ec5bbdcfea9d5f2500cfc6c245431f04580f9d9`.
- The first production run exposed a cold-worker defect: native extraction
  threw `UnsatisfiedLinkError` because no SDL activity had loaded `libmain.so`.
  The extractor now owns a lazy, process-idempotent JNI load. The existing
  non-SDL device pipeline fixture deliberately omits manual loading and passes
  from a cold process.
- The preserved verified archive then exposed a second recovery defect:
  preflight charged the already-occupied archive a second time and rejected
  Retry. Capacity evaluation now accepts bounded reusable archive bytes and
  requires only the remaining transfer bytes plus the unchanged expansion cap
  and 256 MiB reserve. Host boundary tests cover full and partial cache credit.
- Installing the patched APK with `-r` preserved the verified cache. Retry
  reused it, entered JNI extraction, atomically activated 2,110,038,016 bytes
  of content, and displayed `Retro Rewind is ready` only after the production
  validator passed.
- The archive was deleted after success. `Code.pul` is exactly 1,723,600 bytes
  at SHA-256
  `622485319fd01746c705e5c1b08b2551e36368d8abd70138ee843dc8a0a0a293`;
  `RetroRewind6.xml` matches
  `faf88234f81e16a85403d2a86d25e2ef4b261aedb553a312b532e60a11b28200`.
- After force-stop and airplane mode, a cold installer launch revalidated the
  installed pack and again reported version 6.12.5 ready without network
  access.

## Verification

- Focused archive-download, space, installation-pipeline, and worker-policy
  host tests pass.
- Source-only debug assemble and strict APK/privacy audit pass. The patched APK
  is SHA-256
  `fca7cf95024310b40471b2b750e6571b1fb94fb31faa03abfd8af3bf9424358d`.
- The cold non-SDL device pipeline emitted
  `A3 device install faults passed existing=preserved replacement=valid
  recovery=restored` before the production retry.
- The production UI ended at `Retro Rewind is ready`; an offline cold relaunch
  ended at the same validated state. No WorkManager, application-runtime, or
  installer error remained after the patched retry.

## Classification

**Pass for the official production-size Retro Rewind 6.12.5 installation and
offline revalidation on an API 36 ARM64 emulator.** This is not Retro Rewind
gameplay, Original/Retro mode switching, physical-device acceptance, or public
release authorization. No APK/AAB or private game data was published.
