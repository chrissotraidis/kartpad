# Android second-pass candidate assessment

The next performance comparison should test **native thread-local storage across the Android runtime**, rather than lead with the previous single-adapter context-reuse change. Independently, the Helio G85 archive contains a substantial process-memory observation that warrants elevating memory attribution. These are two different hypotheses, not a claim that either will fix every Android problem.

This was a passive source/log investigation. Production code, package settings and installed apps were unchanged. Small compiler probes were emitted locally for inspection; no game APK or emulator session was started. The source comparison uses current-main Android runtime `b57c59b89a059e0f7f93b18f86cc44d58f8e9adb` and iOS runtime `e9b3a8218444994e276ae54eedafe56d6141ed2e`. The earlier context-reuse candidate `535924a` remains separate.

## What the Apple comparison actually tells us

The guest ISA headers, guest-memory implementation in `runtime/src/memory.cpp`, and GX texture-cache implementation in `aurora-main/lib/gx/gx.cpp` have no source differences between these platform pins. The renderer backend, platform integration, synchronization and compiled machine code still differ. Android already avoids some redundant NI-mode application that iOS retains. There is no evidence that simply copying the iOS arithmetic implementation would improve Android.

The comparison does reveal a build-level cost that can affect many runtime paths. The Android app explicitly sets `minSdk = 28`. Since NDK r26, Android's compiler selects native ELF TLS automatically for minimum API29 or newer, and retains software-emulated TLS for older targets. Thus even a modern phone running this API28-targeted binary pays the older lookup cost; installing it on a newer OS does not recompile that native code. This is thread-local storage, unrelated to network TLS encryption. [AOSP linker documentation](https://android.googlesource.com/platform/bionic/+/refs/heads/android15-tests-release/android-changes-for-ndk-developers.md#elf-tls-available-for-api-level-29)

The current public code93 APK was also downloaded and inspected without installation. Its SHA-256 is `ed81b26dffe407b7ca430505756db194456dacb28c5789c9bcdda3b587459a78`; its packaged `libmain.so` imports `__emutls_get_address`. This confirms that software TLS is present in the actual current release, not only in a source reconstruction. It does not quantify current hot-path cost. [Public artifact](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.22-android.1)

## Compiler evidence and proposed first candidate

The same unchanged baseline scalar header was compiled with NDK29, O2, no fast math and disabled FP contraction. An additional shared-library-style comparison used API29 and `-fPIC` on both sides, changing only `-femulated-tls` versus the compiler's native default.

| Compiler probe | Calls to `__emutls_get_address` in emitted probe file | TLS descriptor call sites | Thread-pointer reads |
| --- | ---: | ---: | ---: |
| API29, PIC, forced emulation | 3 | 0 | 0 |
| API29, PIC, native default | 0 | 3 | 2 |

These counts describe emitted functions in the small probe file, not unconditional dynamic calls per arithmetic instruction. The native path still has descriptor calls; it is not zero-cost. This verifies the proposed code-generation difference without changing arithmetic or using the prior context patch. Probe files remain local under `/tmp/kartpad-android-second-pass/`.

The existing physical Pixel sample identified `__emutls_get_address` at 3.12% and `pthread_getspecific` at 2.51% of sampled on-CPU work across threads. That makes this more grounded than a generic compiler flag change. Those historical leaf shares neither prove all `pthread_getspecific` calls belong to guest TLS nor measure current code93. Even eliminating all of that roughly5.6% share would imply only about1.06x speedup under a simplistic unchanged-work model—not a path from25 FPS to60 FPS. The value of the experiment is its breadth, clean isolation and possible reduction in CPU/power cost. [Pixel profile](../2026-09-08/pixel-hardware-cpu-profile.md)

The recommended pair is:

- **Control:** current baseline source, private API29-minimum build, forced emulated TLS.
- **Candidate:** identical source and settings, private API29-minimum build, native TLS.

Use `b57c59b` runtime source for both; do not bundle context reuse, renderer changes, fast math, new CPU affinity or a worker-count change. Rebuild all generated/native translation units that share inline TLS variables consistently; repackaging an existing `.so` cannot perform this experiment. Preserve exact symbols and verify final ELF TLS symbols/relocations, not just the shell compiler command.

Before phone installation, this pair requires arithmetic/context differentials, cross-thread and fiber-switch checks, startup/lifecycle validation and native/package audits. The existing package and bundle audit scripts explicitly require minimum API28; a private API29 lane needs an explicit expected-minimum parameter retaining28 as the public default, rather than removing that check. The phone's installed version and signer must be checked for compatible in-place updates.

Native ELF TLS requires Android10/API29+. Do not silently change support for Android9/API28 in the public app. This pass makes no such support decision. The current owner phone is expected to be newer based on earlier evidence, but its actual OS and installation must be refreshed when attached.

## Memory is a stronger concern than the first summary conveyed

The previously downloaded latest #198 archive contains two base-profile code64 exit records with very different memory samples:

| Record | Exit reason | PSS | RSS |
| --- | --- | ---: | ---: |
| Earlier base run | User requested | 1,667,521 KiB, about1.59 GiB | 1,925,948 KiB, about1.84 GiB |
| Later base run | User requested | 523,316 KiB, about511 MiB | 652,588 KiB, about637 MiB |

These are historical OS samples associated with different runs, not a controlled before/after comparison, memory peaks, a demonstrated leak or an LMK diagnosis. Android documents exit-record PSS/RSS as the last sampled values, which can predate death. They nevertheless establish that memory is not entirely unmeasured in the supplied evidence. The first report's statement about absent memory telemetry applies to the POCO single-session text, not this Helio archive. [Reporter archive](https://github.com/chrissotraidis/kartpad/issues/198#issuecomment-5639411647), [ApplicationExitInfo memory semantics](https://developer.android.com/reference/android/app/ApplicationExitInfo#getPss())

Renderer source provides concrete attribution targets:

- Four main buffer capacities total37 MiB:24 uniform,3 vertex,2 index and8 storage. Three staging buffers of the same aggregate capacity add111 MiB. That is148 MiB of declared buffer capacity before textures, depth snapshots, driver allocations and other data. It is not a resident-memory measurement and does not explain1.84 GiB on its own.
- Pipeline prewarm reconstructs the cached pipeline set with the full worker pool—six workers in the reviewed phone logs. Compiled pipeline objects are retained in `g_pipelines` until shutdown; no normal eviction was found there.
- Current texture caching already includes idle-revision pruning and object-cache soft limits. Claiming that the port simply lacks texture-cache cleanup would be wrong. Memory growth must be attributed before adding another eviction scheme.
- Guest virtual-address aliases share physical backing. The size of the virtual reservation must not be mistaken for resident RAM or “fixed” by breaking guest address ranges.

This suggests a **second, separate candidate**: restrict speculative background prewarm while retaining prioritized on-demand compilation. Its purpose would be to test transient compilation pressure and residency of unused pipelines. Merely using fewer workers would mostly change startup contention and transient allocations; compiling the same final set would not necessarily reduce steady-state residency. Avoiding unused prewarm is a different policy with a possible first-use stutter tradeoff.

That candidate is less ready than native TLS. Before implementing it, record app memory and created-pipeline counts at chooser, post-launch, first race and repeat race. The historical1.84 GiB record could include translated code, driver allocations, textures or other native state; source inspection alone does not attribute it to pipeline objects. Keep this measurement in both first-candidate runs so it informs the next decision without combining two interventions.

Source references: [buffer capacities](https://github.com/chrissotraidis/wiicompiled/blob/b57c59b89a059e0f7f93b18f86cc44d58f8e9adb/aurora-main/lib/gfx/common.hpp), [staging allocation](https://github.com/chrissotraidis/wiicompiled/blob/b57c59b89a059e0f7f93b18f86cc44d58f8e9adb/aurora-main/lib/gfx/common.cpp), [pipeline lifecycle](https://github.com/chrissotraidis/wiicompiled/blob/b57c59b89a059e0f7f93b18f86cc44d58f8e9adb/aurora-main/lib/gfx/pipeline_cache.cpp), [existing texture pruning](https://github.com/chrissotraidis/wiicompiled/blob/b57c59b89a059e0f7f93b18f86cc44d58f8e9adb/aurora-main/lib/gx/gx.cpp).

## Why this still does not explain every crash

The reviewed Helio exits are user-requested, and the newest #137 attachment is a short startup transcript without an affected draw or crash stack. Low-end black-screen exits across HONOR, Xiaomi, Samsung and OPPO still lack a common demonstrated fatal signature. An ANR, a native crash, an OS memory kill and normal return to the chooser require different corrections. Memory footprint is now a stronger lead, but declaring these all OOM would overstate the evidence.

The Adreno reports also include corrupt characters during otherwise fast rendering. That remains a shader/data/binding issue until a controlled affected-draw test says otherwise. API29-native TLS is not proposed as a graphics fix. Likewise, the #199 iPhone local-image freeze is an exception to the general Apple stability observation, not evidence that Apple and Android share one broad failure.

## Revised decision

The previous scalar-context candidate is a small, correctness-tested fallback experiment. It should not be sold as the principal answer to Android performance. Prefer the broader native-TLS A/B pair for the next private phone performance test, and collect memory/pipeline/thermal measurements alongside it. Proceed to memory-conscious pipeline prewarm only if attribution supports that next intervention.

No across-the-board FPS gain is established. Success means repeatably lower CPU cost and improved frame-time distribution in the same warmed driven scene, without an arithmetic, input, audio, lifecycle or crash regression. A neutral result should move the investigation to the next measured cost, not trigger another equivalent APK. No new support reply, source optimization, merge or package release was performed during this passive pass.
