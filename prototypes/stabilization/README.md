# Local stabilization prototype

Current integration work is in draft PR #307 on
`codex/cross-platform-stabilization-20260919`. The dated sections below retain
earlier experiment history. The latest changes add actual Aurora EFB readback
verification and a rebuilt portable Android Dawn dependency, now selected by
the draft production lock. Dependency publication and full application package
validation remain pending. See
[the EFB evidence](../../docs/artifacts/2026-09-19/efb-readback-verification.md) and
[the Dawn rebuild](../../docs/artifacts/2026-09-19/android-dawn-rebuild.md).

This is a local experiment based on KartPad `c9f425c` (the Android121 diagnostic line), not a release branch promotion. It preserves the existing checkout, diagnostic artifacts, public versions and device data. It has two independently testable parts: a full Android app candidate for classified defects, and a small GPU executable for the proposed renderer allocation refactor.

## Code126 regression correction (19 September)

Code125 failed the owner Pixel test with a native allocator abort in a background
shader compiler and noticeable stalls. The replacement under validation is
`0.4.25-stabilization.4-prototype`, code126. This section supersedes older candidate
numbers below; it does not promote a public release.

- The archived Dawn source accidentally inherited the enclosing KartPad Git HEAD
  as its internal version. Code116 embeds upstream `13abc3bc`; code125 embeds the
  unrelated KartPad `c9f425c`. Dawn includes those bytes in its device cache keys.
  `pin-dawn-version.py` now supplies an explicit content-derived version based
  on the pinned source and reviewed loader patch, so unrelated app commits do
  not invalidate compiler caches. A dependency change still gets a fresh key.
- The runtime admits at most 128 earliest-use recipes for speculative startup
  replay and one background compiler. It preserves the recipe database and
  first-use compilation. Promotion to frame-critical work wakes idle compilers;
  the shared condition variable notifies all to avoid waking only a renderer.
- `test_pipeline_startup_budget.py` executes the actual production SQLite loader,
  promotion helper and worker loop with controlled compiler jobs under ASan/UBSan.
  It checks a 3,587-recipe database, shared admission across Clear/GX, exhausted
  budget handling, unchanged saved rows, later access to omitted recipes, and
  first-use progress while background compilation is blocked.
- `test_dawn_version.py DAWN_SOURCE` checks the actual Dawn version generator
  under two unrelated parent repositories and verifies patch changes affect the
  identity. This is build/cache correctness, not physical performance proof.

The prior dependency and prepared runtime are preserved under
`build/dawn-code125-preserved-install` and
`build/stabilization-android-20260919/runtime-code125-preserved`. Existing archived
APKs, symbols and phone state backups remain intact. No cache deletion is part
of this correction. One cold cache rebuild after changing dependency identity
is expected and must pass the owner stability gate.

## Phone preparation follow-up

The revised app candidate is `0.4.25-stabilization.2-prototype`, code123. Code122 remains archived unchanged. This revision fixes Android diagnostic-setting defects: silent `AtomicFile` publication failure is detected by readback, read failures cannot falsely confirm disabling validation or returning character indexing to Normal, and activity recreation retains the game process's actual validation mode instead of applying a pending preference to its report. Existing settings are preserved; changing the setting still takes effect on the next game-process launch. Fault-injected host regressions reproduce the old persistence failure and cover the corrected behavior.

The build entry point now verifies the reviewed backported Dawn library digest before invoking Gradle. Supplying the old or an otherwise different library fails before the app build. A deliberate dependency rebuild needs its own identity review before changing that approved digest.

The GPU probe now tests both overwriting and additive drawing. The latter makes every earlier draw contribute to the final pixel, so later draws cannot hide a lost submission. All eight GPU cases pass. An intentionally faulty local probe omitting the first 256 draws passes the old overwrite checks but fails the new accumulated-pixel check as expected.

Before putting a candidate on a phone, run the **read-only** identity preflight:

```sh
python3 prototypes/stabilization/phone-preflight.py /absolute/path/to/reviewed.apk \
  --sha256 DIGEST_FROM_ITS_EVIDENCE --connected
```

It checks the reviewed APK digest, verified signer, package and forward version against the installed base APK, plus the connected phone's API and ABI. It rejects ambiguous or unauthorized devices and never installs, launches, clears or uninstalls an app. `--installed-apk /path/to/previous.apk` can substitute for `--connected` for an explicitly offline comparison; it does not establish what is on the phone. Neither mode proves free space, backup completeness, Vulkan driver support or gameplay.

The candidate still uses the local debug identity. A public-release installation requires a separately prepared candidate with the existing public signing identity; a preflight mismatch is a stop, not a reason to remove the app. The existing general hardware installer is not the prototype's preflight and has historical defaults; do not invoke it without reviewing its complete handoff.

For the first game run, preserve/export existing saves and use **Character Graphics Test: Normal** and **Renderer Validation: Off** from Getting Started, then fully close and reopen KartPad. Earlier comparison preferences survive an update and disable draw merging; the revised build intentionally does not erase them. Check that existing Original/Retro profiles and saves are visible before proceeding. Then use one known race for startup, rendering, pause/resume and return-to-chooser checks. This is a bounded first smoke test, not broad device or performance acceptance. Do not begin by repeating the older indexing comparisons.

## Changes in the app candidate

- The Android runtime contains WiiCompiled's sleep-timer reentry correction, `c2289e4ba4132aa3fb2afaadba3136bf3999b199`.
- Its Dawn library is rebuilt from the existing `13abc3bc8ea2d3c2050f9e77a12d012108ceee24` baseline with upstream `33f61fdfc90d38e208fd4496f81ecf24142228f2`: incomplete optional Vulkan debug-utils entrypoints no longer discard the hardware backend. Mandatory entrypoint errors remain errors.
- Android121's four renderer corrections are retained. The local macOS/tvOS runtime branches now carry those same narrow semantic corrections; all four platform branches carry the timer correction.
- The shared source regressions now enumerate all four runtime pins. A proposed CI workflow runs these ROM-free tests and the allocation admission test.

The APK does **not** contain the experimental allocation refactor. It does not claim to fix the remaining corrupt characters, sustained low FPS, every startup exit, or cup-completion failures. General startup failure recovery and tighter diagnostic-mode scoping also remain separate work.

The production Dawn lock is unchanged. The prototype build entry point deliberately supplies the local backported dependency. Its sidecar evidence records that dependency separately because embedded KartPad provenance explicitly covers source inputs, not complete binary/dependency identity.

## Allocation prototype and what it establishes

`batch_reservation.hpp` makes a draw/command reservation atomic across vertex, uniform, index and storage buffers. Its result is one of: accepted; submit the current batch first; too large even for an empty batch; invalid request. Rejected requests leave every offset untouched. It accounts for alignment, zero-length aligned allocations, final four-byte GPU copy padding, the 3,840-byte uniform tail and the renderer's 32-bit range representation.

The admission test runs boundary cases, interpolation-sized reservations, clear/resolve/readback demands and 100,000 deterministic randomized reservations against independent byte-budget arithmetic. AddressSanitizer and UndefinedBehaviorSanitizer are enabled.

`gpu_batch_probe.cpp` is an executable WebGPU experiment, not a model of GPU completion. It allocates three mapped staging buffers, uploads real vertex/index/uniform/storage data, submits indexed rendering, waits for mapping before reusing a slot, preserves the target with load operations across submissions, and reads back actual pixels. It also injects oversized requests before valid draws to verify rejection does not disturb subsequent output.

On the Apple M3 Max, all runs matched independently calculated pixel values, and every split result was byte-identical to the unsplit control. Each workload below now runs in both overwrite and additive modes:

| Workload | Submitted batches | Result |
|---|---:|---|
| 769 indexed draws in one batch | 1 | Pass |
| Five-draw capacities | 154 | Pass |
| Smaller storage capacity than other buffers | 385 | Pass |
| One-draw capacities, repeated staging-slot reuse | 769 | Pass |

All runs completed with zero WebGPU validation errors. This establishes that the proposed bounded allocation and ordered submission can preserve this workload's output using real GPU resources. It is not a full-game capture, an FPS benchmark or proof of Aurora's worker/interpolation integration. The same probe also compiles as an Android arm64 Vulkan executable linked against the backported Dawn library. No Android device was connected during this pass, so that executable has not been run on Android hardware.

Run the macOS probes with `bash prototypes/stabilization/run-host-probes.sh`; it expects the pinned macOS Dawn package extracted into `work/stabilization/dawn-metal`, or `KARTPAD_PROBE_DAWN_ROOT` pointing to that package. Build the Android variant using the NDK's `aarch64-linux-android28-clang++`, the backported install's include/library paths, `-static-libstdc++`, and `-llog -landroid -ldl`. The source selects Vulkan on Android and Metal on macOS; it does not fall back to a fake renderer.

## Additional integration requirements found in this pass

Admission must cover every producer of staging data. Besides FIFO/raw geometry and interpolation, the current renderer allocates uniforms for:

- `gfx::push_draw_command(clear::DrawData)` in `aurora-main/lib/gfx/common.cpp`;
- `gfx::resolve_pass`, which appends its copy-filter/resolve uniform after modifying pass state;
- `gfx::efb_ram::ensure_native_texture`, which appends a native-size blit uniform during readback preparation.

A draw-only check would leave these overflow paths. Reserving space after a helper has changed the render pass would also violate atomicity. The integration needs a small command-admission layer before each relevant mutation, not a callback hidden in `ByteBuffer::resize`.

The safe integration sequence is:

1. Describe each operation's actual allocation demand before touching staging or render-pass state. Include uncached vertex arrays, conditional interpolation copies and helper uniforms. After a flush, recompute demand because array upload caches have been invalidated.
2. On insufficient current capacity, return control to the producer before consuming the command. Submit its completed prefix at a boundary where the renderer mutex is not held across a worker-completion wait. Do not call the existing FIFO-draining EFB flush recursively from inside the decoder.
3. Preserve the FIFO cursor, raw-draw data and GX state across that boundary. Existing wait callbacks deliberately service deferred retrace/alarm/audio work while suppressing guest rescheduling and recursive Aurora work; retain that property. Do not replace them with unrestricted guest pumping.
4. Rotate mapped resources only after pending interpolation pointers are discarded or finalized as appropriate. The existing replay-unsafe path provides the conservative behavior for split frames. Keep GPU-referenced resources alive through completion.
5. Retry exactly the uncommitted operation. If it cannot fit an empty batch, return an explicit oversized result to a bounded spill/subdivision/recovery path. Repeated flushes cannot fix an intrinsically oversized operation, and silently dropping geometry is not an accepted solution.

Before connecting that layer to the game, extend the real-GPU test with Aurora's actual resolve/readback and interpolation paths, including split-versus-unsplit pixel comparisons. Then exercise the renderer worker with the same boundaries and verify lock ordering. The prototype does not yet prove those steps.

The indexed-array audit also found an existing optimization worth preserving: `ApplyAuroraArraysForDisplayList` bounds uploaded spans using observed maximum indices and packs only when stride exceeds the bridge representation. Do not replace this with whole-guest-memory uploads during the refactor.

## Reproduction and preservation

- The local branch is `codex/stabilization-prototype-20260918`, in `/Users/chrissotraidis/.codex/worktrees/kartpad-stabilization-20260918`.
- Four local runtime branches are named `codex/stabilization-<platform>-20260918`. Their commits are pinned by this prototype checkout. They have not been pushed to public platform branches.
- `build-dawn-android.sh` accepts a populated baseline source tree, the pinned source archive, host protoc and a fresh output directory. It checks the source archive hash and all 85,128 archive files in the copied source before applying the exact backport. It builds out of tree, disables dependency fetching and maps private source paths out of the binary. Existing dependency sources are not edited.
- `test_dawn_loader.py BASELINE_SOURCE PATCHED_SOURCE OUTPUT_DIRECTORY` recompiles the actual old/new loader methods with controlled procedure resolution. Fifteen cases per variant cover every missing optional procedure, normal success, missing mandatory procedures and an absent optional extension.
- `build-android-app.sh` accepts existing private translation, the prototype Dawn install, pinned minizip/mBedTLS roots and existing DiscIO JNI. It stages a fresh runtime, verifies maintained-source parity and builds both profiles. It never installs, signs with the public release key or publishes.
- The generated game graph is consumed from the existing diagnostics translation without regeneration. Its fingerprint is compared with Android121's recorded fingerprint.
- `work/` and `build/` are ignored. Private logs, source dependencies, binaries and generated game material stay out of commits. Reproduction scripts and ROM-free tests are tracked.

This candidate uses a **local Android debug certificate**, despite an optimized non-debuggable Release build. It is not an in-place update for public-release installations. Device handoff requires a compatible signer and preserved data; do not uninstall the existing app to make this APK install. No device was installed or modified during this pass.

Keep the prototype worktree and its runtime commits until its changes have been deliberately integrated or rejected. Main and existing platform release pins remain unchanged. The complete results, artifact hashes and remaining acceptance gates are recorded in the dated prototype review and local evidence sidecar.
