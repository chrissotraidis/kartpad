# Android third pass: controlled native TLS build

## Decision

Build a private API-29 baseline/candidate comparison from main `cedb338` and unchanged Android runtime `b57c59b89a059e0f7f93b18f86cc44d58f8e9adb`. Baseline forces `-femulated-tls`; candidate forces `-fno-emulated-tls`. Both are release-mode, profileable, same generated base/Retro graph and dependencies. Do not combine the earlier scalar adapter patch, prewarm policy changes, or arithmetic relaxations. Public builds still default to API 28. This is an experiment, not a validated performance fix.

The actual code-93 public library imports `__emutls_get_address`; the earlier Pixel profile attributes 3.12% self time there, plus 2.51% in `pthread_getspecific`. The latter is not exclusively guest context work. Native TLS is a measured cost-removal hypothesis, not a plausible explanation for every slowdown or a promise of 60 FPS. Android supports ELF TLS from API 29; see [Bionic developer changes](https://android.googlesource.com/platform/bionic/+/refs/heads/android15-tests-release/android-changes-for-ndk-developers.md#elf-tls-available-for-api-level-29).

## New evidence from older attachments

Read all three #198 archives together, including [initial capture](https://github.com/user-attachments/files/32086838/KartPad-private-diagnostics.zip) and [middle capture](https://github.com/user-attachments/files/32126623/KartPad-private-diagnostics.zip), rather than only the latest export.

- Code 63 contains a base exit sample of 2,149,662 KiB PSS / 2,411,172 KiB RSS (about 2.05 / 2.30 GiB).
- Code 64 contains a still larger base exit sample: 2,570,716 KiB PSS / 2,831,392 KiB RSS (about 2.45 / 2.70 GiB), timestamp 1789147103056. The corresponding preceding base session starts at 1789146817 and runs about 286 seconds. Its last recorded frame sample is 23.49 FPS, queue zero, 1,238 pipelines created, main-thread occupancy 95.0%, present total 2.867 ms. Exit reason is user-requested, not low-memory death.
- A separate code-64 base exit is explicitly `not_responding` at 1789146812098. Its preceding session starts at 1789146789. Last recorded game sample is 60.35 FPS, 48.5% main-thread occupancy, 875 pipelines still queued. Therefore low sustained game FPS and the UI ANR are not interchangeable diagnoses. These are preceding samples, not a captured stack at the instant of failure.
- The following warm-cache run still takes 84.6 seconds to prewarm 1,254 pipelines despite 2,869/2,870 Dawn blob-cache hits and zero stores. It then records roughly 24–26 FPS with queue zero. A high blob-hit ratio does not prove cheap pipeline creation, and prewarm completion does not resolve the warmed CPU bottleneck.
- Health samples report thermal status zero in these sessions. That does not prove constant CPU clocks or exclude power/thermal constraints.

PSS/RSS from ApplicationExitInfo are last OS samples, not necessarily peaks or values at exit. The archives cannot partition the large footprint into guest RAM, driver pipeline objects, graphics buffers, native heap, and mapped code. Read [Android memory assessment](https://developer.android.com/topic/performance/memory/guide/tools-overview). Do not equate a 27 MiB disk cache with total renderer memory.

The earlier #137 archive adds finite vertex draw records but no decisive corruption signature. The #123 online console adds a 17.3-second/1,596-pipeline prewarm on a different setup; it supplies no matched control for the Helio session. Keep geometry, online, and startup failures separate.

## Concrete diagnostic gap

`KartPadExitDiagnostics.kt` exports exit reason and memory metadata but deliberately does not export `ApplicationExitInfo.getTraceInputStream()`. The older ANR therefore remains unlocalized. For a reproduced hardware hang, collect a private ANR/Perfetto capture with UI-thread scheduling and native stacks. A later bounded exporter enhancement could include app-specific traces with explicit private handling; it is not part of this TLS comparison. [Android ANR diagnosis](https://developer.android.com/topic/performance/anrs/diagnose-and-fix-anrs) distinguishes blocked threads, scheduling starvation, and system resource pressure.

## Validation and hardware gate

The API-36 ARM64 emulator dynamically loads each API-29 shared-library variant. Across 448,000 scalar cases, special/random values, random FPSCR, four host rounding modes, nested contexts and two OS threads, both produce matching result/exception/write-state digests. This is arithmetic/context evidence, not game performance or full scheduler acceptance.

On hardware: verify installed signer/version and preserve data; run baseline → native → baseline-repeat using increasing version codes. Keep the same game/profile, 1x resolution, aspect, track, save, camera and input route. Separate startup/prewarm measurements from repeated warmed runs. Allow equivalent cooling and match cache state without clearing user data. Record frame-time tails, main CPU stacks, TLS self time, memory categories and thermal state. Reject a candidate that gains a little FPS but regresses geometry, audio, resume, base/Retro switching or memory. Retain the old install artifact; never downgrade or uninstall to restore it.

The next memory experiment should measure pipeline residency and compilation concurrency separately. Merely reducing workers does not reduce the final number of resident pipelines. Draw-time creation can introduce new stalls; [Khronos pipeline management](https://docs.vulkan.org/samples/latest/samples/performance/pipeline_cache/README.html) documents this tradeoff.
