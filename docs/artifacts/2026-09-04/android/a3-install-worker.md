# Android A3 durable install worker

Date: 2026-09-04

Branch: `codex/android-a3-install-worker`

Baseline: `93e5a1c5724e9c1f0d9c1ae45d66abb4378a5c42`

## Falsifiable subgoal

Join the existing Retro Rewind space, download, extraction, validation, and
atomic-activation owners behind one unique foreground-capable Android job.
Prove that duplicate enqueue does not duplicate work and that the exact
persisted request restarts and finishes after its application process is
force-stopped. Do not download or publish the production archive.

## Result

- Locked AndroidX WorkManager 2.11.1 and added one unique
  `kartpad-retro-rewind-install` job using `ExistingWorkPolicy.KEEP`.
  Production work requires a connected network and carries a fresh
  app-private staging token.
- The worker performs startup recovery, exact free-space preflight, pinned
  acquisition, bounded extraction, installed-content validation, atomic
  activation, and verified-cache cleanup in that order. Network transport
  failure retries; HTTP, integrity, storage, extraction, and validation faults
  fail closed; cancellation reaches the synchronous download/extraction
  callbacks.
- Work phase and byte counts are persisted through WorkManager progress data.
  The Android data-sync foreground notification displays the same bounded
  download/extraction progress. A stable facade exposes unique enqueue and
  cancellation for the future A4 setup UI.
- The merged manifest declares WorkManager's foreground service as
  `dataSync`. The strict package audit allows exactly INTERNET,
  ACCESS_NETWORK_STATE, FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC,
  RECEIVE_BOOT_COMPLETED, WAKE_LOCK, and WorkManager's app-scoped
  `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; it rejects any other used or
  declared permission.
- Debug source-only builds have a bounded worker fixture. Enqueuing it twice
  starts exactly one UUID. A separate 30-second fixture is killed by
  `am force-stop`; a plain activity relaunch restarts the same UUID at
  attempt 1 and completes it. Debug fixture entry points are disabled when the
  private game-runtime configuration is selected.

## Verification

- Worker retry/failure policy and all seven existing Android A3 download,
  pipeline, extraction, free-space, content, and storage contract runners pass
  with the pinned JDK. The download test also requires exact final progress.
- Wiped API 36 / 4 KiB and API 35 / 16 KiB ARM64 AVDs each observed exactly one
  worker start after two unique-work enqueues, plus completion at attempt 0.
  Both also passed the existing JNI extraction, memory, scheduler/fiber,
  controller, Vulkan, orientation, and repeated lifecycle markers.
- On a separate wiped API 36 AVD, work UUID
  `1fe6dfba-9f9d-42e0-a825-77668a62a9cf` started at attempt 0, the KartPad
  process was confirmed absent after force-stop, and the same UUID restarted
  at attempt 1 and completed. The harness required exactly two starts and no
  KartPad/Android fatal marker.
- Public source-only assemble, release Kotlin/Java compilation, API-28 lint,
  and private game-runtime Kotlin/Java configuration compilation pass.
  The strict package/privacy audit passes. No ADB target remains.
- The 22-test builder suite passes with its expected unavailable-private-input
  skip. The pinned SunPad snapshot, repository safety, shell syntax/lint, and
  diff checks pass. The broad source verifier reaches all 446 patch hunks and
  then reports the previously documented ignored `rr-pulsar` checkout
  mismatch (`b566a5d` local versus `29e76d4` locked); this checkpoint does
  not alter that checkout.
- The exact source-only debug APK is 33,843,921 bytes with SHA-256
  `5ee1edf08ceb2173f9fc32824872c1489d80e1fddf6dd8f41738a73b5cfa19a7`.

## Classification

**Pass for unique foreground orchestration, persisted phase/byte progress,
cancellation/retry policy, duplicate suppression, and real app-process-death
restart on the emulator.** This does not prove resumable partial HTTP transfer,
the 1.86 GB production download, activity/UI cancellation, network loss during
the production job, complete Retro Rewind gameplay, or physical hardware.
A2 and A3 remain open. No APK/AAB, production archive, private data, device
identifier, or raw log was published.
