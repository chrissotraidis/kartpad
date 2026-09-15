# Android stability and performance investigation

The [second passive pass](android-second-pass-candidate.md) revises the proposed next test: native TLS before the small context-reuse candidate, and stronger memory attribution from existing Helio exit records. This document retains the first-pass results.

The strongest actionable performance evidence points to CPU-side game and render preparation, not an absence of parallel execution. A newly supplied POCO X3 log records roughly 10–11 FPS with no shader pipelines queued; an independent Helio G85 archive records roughly 25–29 FPS with 94–97% main-thread occupancy after prewarm. Presentation API timings in those intervals are much shorter than frame intervals. Neither observation proves that the GPU is idle, identifies a particular guest function, or rules out memory stalls. Together they justify prioritizing a measured CPU investigation over another resolution sweep or blanket shader-worker increase.[^1][^2]

A narrow candidate now reuses the already validated CPU context across each scalar floating-point evaluation and commit. Android ARM64 baseline disassembly contains two context lookup calls in the representative single-add adapter; the candidate contains one. Both use the same arithmetic evaluators and exception rules. The emulator differential passes 448,000 cases. Alternating emulator microbenchmarks are mixed, so there is **no established gameplay speedup**, and no APK has been released by this investigation.

This assessment was refreshed against GitHub on September 15, 2026. The engineering baseline is KartPad `cedb338`, with Android runtime submodule `b57c59b89a059e0f7f93b18f86cc44d58f8e9adb`. Current public Android is 0.4.22/code93. The primary checkout contains substantial unrelated work; the investigation uses a separate worktree. Historical code64, code83 and reporting-code90 evidence is identified below rather than presented as testing code93.[^3]

## Priorities

The living ordering remains in `docs/maintenance-priorities.json`. These are the decisions supported by this investigation, not a second ongoing queue.

| Order | Work | Reason and next decision |
| --- | --- | --- |
| Urgent when actionable | Data loss and repeatable launch exits | Keep the already corrected Retro pack-save path separate from ordinary-exit save complaints. An exact native-crash, ANR or low-memory-exit signature takes precedence over tuning. Several low-end reports lack that discriminator; do not guess a common OOM cause. |
| First active engineering | Sustained Android CPU-side slowdown | POCO X3 and Helio G85 provide actual post-prewarm evidence. Test the scalar-context candidate and obtain a matched CPU profile. Preserve all guest arithmetic semantics. |
| Next independent renderer experiment | Missing/stretched character geometry | Adreno 750/829/840 reports include real corruption, including fast-running scenes. Use the existing affected-shader/index comparison; clean synthetic draws do not validate those real draws. |
| Separate reliability lane | Retro online transitions and cup exits | Login, room matching, a completed race and repeated reconnects are different gates. Mobile-data failures with working Wi-Fi and offline cup exits do not establish the same cause as low FPS. |
| Lower priority for this pass | Additional Apple features and broad tuning switches | Apple remains generally usable by owner observation, but the new local-screen iPhone freeze is a real exception. Affected Apple failures retain their own triage. |

## Recent issue and log findings

### POCO X3: new evidence, sufficient for a CPU investigation

Issue #275 initially names two different models and reports build83, 10–25 FPS in menus and 5–10 FPS in gameplay. The reporter subsequently confirms POCO X3 and attaches a diagnostic text. The export identifies Xiaomi M2007J20CG, API31 and reporting build90. The selected session's runtime header says version unknown; **export-time code90 is not proof of the selected session's compiled runtime**. The session is Original/base, Vulkan/Adreno618, resolution1x and original aspect. Both profiles are affected according to the report, but this log proves only the selected base session.[^1]

| Present counter | Reported FPS | Queued pipelines | Created pipelines | Adjacent CPU occupancy |
| --- | ---: | ---: | ---: | ---: |
| 300 | 34.94 | 1114 | 243 | Unavailable |
| 600 | 6.35 | 684 | 673 | 57.1% |
| 900 | 11.29 | 0 | 1357 | 73.9% |
| 1200 | 9.81 | 0 | 1394 | 86.9% |
| 1500 | 39.66 | 0 | 1397 | 89.4% |
| 1800 | 41.75 | 0 | 1397 | 20.6% |

Prewarm takes 53.3 seconds for 1,353 pipelines. It plausibly contributes to startup contention, but cannot explain every later slow interval. At the 900-present checkpoint, presentation total averages 4.389 ms and worker overlap encoding averages 10.628 ms wall/7.178 ms CPU. These phase averages and the CPU-occupancy interval have different sampling windows from the reported FPS. They must not be subtracted from one another to manufacture an unexplained time budget. There are also spikes; averages do not dismiss them.

Later faster intervals are not a before/after optimization result. There are no explicit scene or pause markers, and no matched thermal or resident-memory sample in this exported text. The correct next step is CPU sampling of a known slow scene, not asking again for model, settings or another general log. A response with these findings was posted.[^4]

### Helio G85: independent warmed CPU-side evidence

The latest supplied #198 archive contains several sessions, health history and user-requested exit records. The reporter had already performed the requested menu/submenu/race sequence and confirmed charging and battery saver were off. The analyzed long session has zero queued pipelines and 1,259–1,260 created pipelines while repeated samples record 25.00–28.83 FPS and approximately 94–97% main-thread occupancy. Representative presentation totals are approximately 2.3–2.6 ms. Earlier archive analysis recorded an ANR signal, but that does not establish the cause of the later slow run.[^2]

The report already contains three captures and willingness to use a private profiler. Asking for the same capture or consent again does not advance it. The previously prepared code84 profiler is older than current public code93 and must not be sent as an update to an installation of code93. Verify the recipient's actual package version, signer and native-symbol match before any eventual private delivery. No private delivery was performed in this pass.

### Older and flagship devices do not share one proven failure

| Reports | Supplied distinction | Interpretation |
| --- | --- | --- |
| #167 | Helio G200, 15–20 FPS; same result at 1x across aspect choices; reporter compares favorably with Dolphin | Evidence that the current port has room to improve; the Dolphin comparison is not a controlled profile of this runtime. |
| #103 | S25+ fluctuating FPS without graphics corruption; separate Retroid Pocket5 corroboration | Keep reporter/device rows distinct. Low GPU percentage alone is not an execution-time measurement. |
| #169 | POCO F6 Pro combines slowdown, display layout and Retro save loss | Three subcases. A pack-replacement save correction does not resolve FPS or ordinary-exit complaints. |
| #195 | S25 Ultra Retro VS/online drops at 1x and validation off | CPU-opponent and network paths need separate comparisons. |
| #204 | S25+ Cookie Land battle stutters while prior time trials run well | Scene/workload dependence; compare another battle, not a nonexistent Cookie Land time trial. |
| #207 | Samsung A05/Mali G52: slow matches plus intermittent exits | Performance and crash classification remain separate. No provided OOM signature. |
| #278 | SM-S901W, Android14/API34; below20 FPS in races | Profile/settings are not yet supplied. Existing request remains sufficient; no duplicate reply. |
| #143/#205/#208/#215/#216/#235/#236 | Launch exits across HONOR, Xiaomi, Samsung and OPPO | Keep exact device, version and transition. Black screen plus touch controls does not uniquely identify GPU, memory or native arithmetic failure. |

All linked issue bodies and recent discussion were included in intake. Canonical #208 consolidates its known reposts; those duplicates are not counted as independent devices. The accompanying intake ledger records the reviewed issue set.[^5]

### Graphics and Apple follow-ups

The newest #137 ZIP is only 4,968 bytes and contains a short selected base startup transcript. It identifies Adreno840 and normal validation mode but contains no affected draw-comparison/performance records. Its export-time version is code90; its runtime header remains unknown. It cannot accept or reject a particular matrix-index comparison. The reply acknowledges the report, records this limitation and avoids repeating broad settings sweeps.[^6]

The latest #102, #104 and #166 comments already received maintainer replies recording that code85 did not fix their corruption. #193 is closed in current GitHub state; closure by itself is not evidence that every related Adreno report is fixed. Sustained FPS and geometry stay separate even where they affect the same phone.

The new #199 response says the iPhone14 Pro Max/iOS26.6.2 image freezes with no TV attached, then also with AirPlay and HDMI, while audio continues. This invalidates an external-output-only attribution. A Spanish reply explains the existing diagnostic export and requests only the relevant local-screen failure interval. The independent Apple issue remains open.[^7]

## Fundamental causes and competing hypotheses

### Serial guest work and host bookkeeping

Ahead-of-time translation does not automatically outperform an emulator's mature optimizing runtime. KartPad still implements guest register state, exceptions, floating-point status, memory semantics, function dispatch and graphics command processing. The critical path can remain serial even when graphics and audio run elsewhere. A large generated graph can also stress instruction caches; no current-device instruction-cache counters were supplied, so that remains a hypothesis.

Historical physical Pixel profiling identifies exception bookkeeping, emulated TLS and context lookup as real on-CPU costs. Later source already includes conditional exception clearing and skips redundant NI-mode application. Those optimizations must not be proposed again as new work. The remaining double lookup in scalar adapters is present in current source and emitted Android API28 code, making it a bounded next experiment rather than a guess based only on GPU brand.[^8]

The scalar evaluator is synchronous and has no guest-fiber yield or callback. Holding the validated context pointer only through that evaluation avoids one repeated lookup without introducing a process-global context, changing thread-local ownership or bypassing the initial invalid-context/stack check. It is not a proposal to share a guest CPU among parallel workers.

### Parallelization and startup contention

The POCO log explicitly enables six shader-compilation workers, asynchronous frame submission, asynchronous presentation and an audio mix worker. The runtime chooses compilation workers from logical processor count. On heterogeneous mobile CPUs, logical count is not equivalent to available high-performance capacity. More background compilation can compete with active game work and increase transient memory or thermal load. Nevertheless, zero-queue slowdown disproves compilation as the complete explanation here.

A future startup experiment should compare bounded background concurrency with the same cold cache and first-race sequence, measuring time-to-play, stall percentiles and peak memory. Do not clear the user's cache or alter CPU affinity to create an undocumented comparison. Android's guidance favors examining actual thread placement and workload; fixed affinity also removes scheduler flexibility under thermal changes.[^9]

### Memory: material unknown, not a demonstrated leak

Guest memory initialization reserves virtual address space with `PROT_NONE` and maps shared backing sections into guest aliases. Android uses `ASharedMemory_create`; cached/uncached aliases share backing. A large virtual mapping is therefore not equivalent to consuming that many gigabytes of physical RAM. The runtime's reported 128 MB MEM2 configuration must not be reduced blindly: Original and Retro requirements and guest address contracts need to remain valid.[^10]

No reviewed POCO excerpt contains process PSS/RSS, heap growth, major-fault counts or an LMK classification. The 4GB-device crash reports make memory important to measure, but do not prove OOM. Android explicitly distinguishes memory accounting and low-memory termination from other crashes.[^11]

The next physical capture should collect app-specific `dumpsys meminfo` before launch, after warmup and after repeated races, alongside the matching exit record if the process dies. Look for growing resident/dirty/native/graphics categories, reclaim pressure and repeated-course retention. Use `smaps_rollup` only if permissions permit, and never weaken device security for it. If memory grows, isolate texture/pipeline caches, imported resources and native allocations by stage before changing budgets. No generic pool rewrite or aggressive cache eviction is justified yet.

### GPU and thermal limits

`present_total` measures CPU/API work, not GPU shader execution. Queue submission can be cheap while GPU work remains expensive, and CPU producer work can dominate before presentation begins. A GPU trace or permitted counters can resolve that distinction. Geometry bugs require the actual shader, binding and failing input, not merely a clean generic draw helper.

Existing private health logging samples thermal and power state, but the newer single-session exports intentionally omit that journal. The POCO attachment consequently cannot establish cool operation. Previous Pixel slowdown at thermal status1 supports investigating power behavior but does not explain low-end reports by itself. Compare charging state and the same warmed workload; leave governor, game mode and thermal policy unchanged. Add logging only for a specific missing discriminator, using the existing bounded journal or an operator capture rather than per-instruction output.[^12]

## Experiment and validation

The Android runtime candidate changes only `runtime/include/ppc_runtime.h`. Fourteen scalar adapters obtain one `CpuContext*`, pass its FPSCR into the unchanged evaluator and pass the same pointer into commit. The original two-argument commit helper remains available. Other platform runtime gitlinks remain unchanged.

The reusable `scripts/test-android-scalar-context.py` compiles the actual baseline header and candidate header as distinct symbols, preventing linker coalescing from making a false comparison. It uses NDK29/API28, O2, no fast math, disabled FP contraction and the existing Android scalar exception helpers. Without `--serial`, it only builds; running requires an explicit ADB target.

The ARM64/API36 emulator run covers 448,000 old/new cases across fourteen operations and four host rounding modes, with special values, random bit patterns, randomized FPSCR, suppressed writes, host exception flags, nested context restoration and two concurrently running host threads. All pass. No game files, saves, app package or system settings were changed. The test runs as a standalone executable under `/data/local/tmp`.

Six alternating-order single-add microbenchmark pairs in the final retained run range from 15.798–16.164 ns baseline and 15.331–16.101 ns candidate. Some pairs favor the candidate; others do not. These small emulator timings do not establish an optimization benefit. They are an explicit reason to withhold an APK and performance claim until device measurement, despite the reduced call count.

## Phone comparison and next loop

1. Verify the actual installed version, signer, current profile and retained state when the owner attaches the phone. The old code84 receipt is historical. No uninstall, downgrade or clearing is part of this experiment.
2. Prepare matched profileable baseline and candidate packages with exact native symbols, identical build flags and identical renderer settings. This header change affects generated-code compilation; merely repackaging an old native library would not include it. Verify the emitted candidate call path.
3. Warm Original/base on a fixed course at1x/4:3 with validation off. Let the owner drive the same segment, recording scene boundaries. Capture a short approximately20-second/99Hz CPU sample plus frame/phase, thermal/power and memory evidence. Keep Retro as a separate follow-up.
4. Compare baseline–candidate–baseline with comparable thermal conditions. Judge median/tail frame time, stalls and audio continuity, not peak FPS. Check arithmetic regression and crashes alongside timing.
5. If benefit is repeatable without regression, retain the change and complete package/device acceptance. If neutral or slower, do not promote it; use the profile to choose the next largest guest/GX cost. Do not keep compiling equivalent APKs at an unchanged gate.

No physical device was attached during this investigation. A full game APK was not built or installed; the deliverable is a source candidate, executable differential test, reviewed logs, triage responses and a concrete device gate. Current code93 remains the public baseline. This is progress toward performance acceptance, not completion of Android stabilization.

## Sources

[^1]: [Issue #275 and POCO attachment](https://github.com/chrissotraidis/kartpad/issues/275#issuecomment-5663784234), reporter, September14,2026. Attachment read locally; only aggregate timing facts reproduced.
[^2]: [Issue #198 latest split capture](https://github.com/chrissotraidis/kartpad/issues/198#issuecomment-5639411647), reporter, September11,2026; [existing interpretation](https://github.com/chrissotraidis/kartpad/issues/198#issuecomment-5639757736). Archive independently re-read in this pass.
[^3]: [Current status at baseline](https://github.com/chrissotraidis/kartpad/blob/cedb338/docs/STATUS.md), KartPad, September15,2026.
[^4]: [POCO analysis reply](https://github.com/chrissotraidis/kartpad/issues/275#issuecomment-5674085700), September15,2026.
[^5]: [Issue intake ledger](android-issue-intake.md), current GitHub issue bodies and recent comments, accessed September15,2026. Each row links its original thread.
[^6]: [Adreno840 attachment](https://github.com/chrissotraidis/kartpad/issues/137#issuecomment-5658636061) and [review reply](https://github.com/chrissotraidis/kartpad/issues/137#issuecomment-5674085864).
[^7]: [iPhone local-screen comparison](https://github.com/chrissotraidis/kartpad/issues/199#issuecomment-5658622675) and [Spanish reply](https://github.com/chrissotraidis/kartpad/issues/199#issuecomment-5674088922).
[^8]: [Physical Pixel CPU evidence](https://github.com/chrissotraidis/kartpad/blob/cedb338/docs/artifacts/2026-09-08/pixel-hardware-cpu-profile.md); [baseline scalar adapters](https://github.com/chrissotraidis/wiicompiled/blob/b57c59b89a059e0f7f93b18f86cc44d58f8e9adb/runtime/include/ppc_runtime.h).
[^9]: Android Developers, [CPU/GPU optimization](https://developer.android.com/games/optimize/optimization-tips) and [thread scheduling](https://developer.android.com/agi/sys-trace/threads-scheduling), accessed September15,2026; [runtime worker policy](https://github.com/chrissotraidis/wiicompiled/blob/b57c59b89a059e0f7f93b18f86cc44d58f8e9adb/aurora-main/lib/gfx/pipeline_cache.cpp).
[^10]: [Android shared guest-memory implementation](https://github.com/chrissotraidis/wiicompiled/blob/b57c59b89a059e0f7f93b18f86cc44d58f8e9adb/runtime/src/apple/guest_flat_memory_apple.cpp) and [region configuration](https://github.com/chrissotraidis/wiicompiled/blob/b57c59b89a059e0f7f93b18f86cc44d58f8e9adb/runtime/src/memory.cpp).
[^11]: Android Developers, [memory management](https://developer.android.com/games/optimize/memory-overview) and [low-memory killers](https://developer.android.com/games/optimize/vitals/lmk), accessed September15,2026.
[^12]: Android Developers, [thermal API](https://developer.android.com/games/optimize/adpf/thermal); KartPad [bounded health implementation](https://github.com/chrissotraidis/kartpad/blob/cedb338/android/app/src/main/java/dev/kartpad/android/KartPadRuntimeHealth.kt) and [diagnostic export boundaries](https://github.com/chrissotraidis/kartpad/blob/cedb338/docs/SUPPORT.md#collect-a-useful-report).

## Reproducing the source comparison

Runtime candidate commit: `535924a`, [draft runtime PR #1](https://github.com/chrissotraidis/wiicompiled/pull/1). Export the baseline header from Android runtime commit `b57c59b89a059e0f7f93b18f86cc44d58f8e9adb` to a private temporary file, then run:

```sh
python3 scripts/test-android-scalar-context.py \
  --baseline-header /private/path/baseline-ppc_runtime.h \
  --serial EXPLICIT_ADB_TARGET
```

The runtime checkout needs the locked `sse2neon.h` dependency from `dependencies.lock.json` at `runtime/third_party/sse2neon/sse2neon.h`; its verified SHA-256 is `44b9fa3dec3a52ea473246e04b9f692a4e5b0ed654299eef7fe7ec3049e223e0`. The script defaults to the local macOS SDK/NDK29 installation and can use `ANDROID_SDK_ROOT`. It does not install KartPad, change system settings or access saves.

Maintenance validation: 65 tests pass. The optional compatibility-matrix test filename is absent from this checkout; its discovery ran zero tests and is not claimed as validation. Changed Markdown relative links and JSON are checked separately.
