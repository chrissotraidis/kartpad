# Pixel regression correction: code126

Code125 failed owner acceptance. Code126 contains a focused correction for the
identified cache-version mistake and unsafe speculative compilation policy.
It has passed source/host/package checks and connected-phone signing preflight.
It has not yet passed a physical game test. Installation is waiting for the
owner to finish the running game session so unsaved race progress is not lost.

## Located defect and contributing behavior

The local Dawn rebuild used an archive located inside the KartPad checkout.
Dawn's version generator calls `git rev-parse HEAD` from its source directory
when no version file is provided. Git walked to the enclosing KartPad repository
and returned `c9f425c0cfae478d8037c3366b15752a0f7fa11e`, which is the KartPad
build121 handoff commit, not the pinned Dawn revision.

The preserved code116 native library contains the expected upstream version
bytes `13abc3bc8ea2d3c2050f9e77a12d012108ceee24`; code125 instead contains the
unrelated parent-repository version bytes. Both binary checks found three
occurrences of their respective identity and none of the other identity.
Dawn's `DeviceBase` includes `kDawnVersion` in every device cache key. Thus this
packaging mistake invalidated compatibility with the old compiled cache, and
unrelated future app commits could change that identity again.

The existing runtime replayed all 3,587 saved pipeline recipes at startup,
using the full compiler worker pool. This policy predates code125 but made a
cold dependency cache expensive: unused historical pipelines were rebuilt and
retained, while first-use work competed with speculative jobs. The owner's
exact crash was a failed allocation in a background Tint shader compiler.
This connects the identified cache regression to a specific vulnerable path;
it does not reconstruct peak memory at the crash or prove every reported pause
has the same cause.

## Correction

1. The archive build explicitly supplies a stable dependency version, derived
   from the verified Dawn base revision and reviewed loader-patch contents.
   The identity is `b5b118dd9afbc485fd7e8f58d067dd0127998e4a`. A dependency change
   gets a new identity; app commits and checkout location do not. This avoids
   falsely reusing upstream cache entries for a modified dependency.
2. Startup admits at most 128 earliest-use recipes across Clear and GX, and
   allows one speculative compiler at a time. Saved database rows are retained.
   Omitted recipes still compile on demand. This bounds speculative work and
   retained unused pipelines; it is not a global lifetime memory bound.
3. Promoting a cached pipeline to frame-critical work now wakes idle compilers.
   New-work notifications wake all waiters because the condition variable is
   shared with renderer waits: waking just a renderer can leave available
   compilers asleep. A concurrency test exercises this exact production helper.

The runtime change is in common C++ renderer code, on the maintained Android
branch. Apple runtime pins/build52 are unchanged pending Android verification.
The candidate does not contain a broad renderer rewrite or scalar-FP/TLS changes.

## Validation

- The production SQLite loader, promotion helper and worker loop execute in a
  host probe with controlled compile jobs under AddressSanitizer and UBSan.
  A 3,587-recipe database admits 128 entries across Clear/GX without deleting
  rows; exhausted-budget handling leaves the query reusable and later access
  to remaining recipes succeeds. An on-demand promotion completes while the
  speculative job remains blocked. Test passes.
- The actual Dawn version generator is exercised beneath two different parent
  Git repositories. Explicit identity remains identical, is idempotent, differs
  from each parent's HEAD, and changes when dependency patch contents change.
- Android API29's existing serialized Vulkan policy contract passes.
- Dawn Release rebuild and final Android Release build pass. The final app
  build includes the wakeup correction; an earlier intermediate build did not
  and was not installed or archived as the final candidate.
- Maintained-source parity, APK audit, packaged stable identity and matching
  connected-phone signer/forward-version checks pass. No phone data changed
  during these checks.

## Exact retained candidate

| Item | Value |
| --- | --- |
| APK | `build/stabilization-20260919/artifacts/KartPad-0.4.25-stabilization.4-code126-local-debug-signer.apk` |
| Version | `0.4.25-stabilization.4-prototype`, code126 |
| APK SHA-256 | `559b2b6c9fcb8f12ece6989cf93011d2edc3a9397bd90b6ec25a926f6a109f0f` |
| Native BuildID | `b70d61e0e99b7dd26347b72a83a979bb21f98ff4` |
| Matching symbols | `build/stabilization-20260919/artifacts/libmain-code126.symbols` |
| Embedded app source | `dcbe6a613fecf9eec9a815a20fe104205e3825bd`, clean at capture |
| Maintained Android runtime | `956d811e363ab51089197849998557f098c3e159` |
| Dawn library SHA-256 | `43f30a51139b7860b33e4c1a65e593ebf55be5e8c4329cfc0a27f8eb2980b0bf` |

The local debug certificate matches installed code125. Both APKs are optimized,
non-debuggable and profileable. Prior code116/123/124/125 artifacts are retained.
Code125's prepared runtime is preserved with its original fingerprint under
`build/stabilization-android-20260919/runtime-code125-preserved`; its original
Dawn package is preserved under `build/dawn-code125-preserved-install` with
unchanged library hash `2552416c021482ac44981b9aeed791396cf45c80b4dbd517145fc91944739923`.

## Remaining physical test and separate warmed issue

Install in place after the owner finishes the current session. Preserve saves,
game data, settings and cache rows. Observe the unavoidable first cold run with
the corrected dependency identity, then a warm relaunch using the same mode,
resolution and scene. Compare speculative queue size, memory, frame tails,
rendering, race completion and save/relaunch behavior. Do not replace the
old failure with a claim based only on launcher success or average FPS.

The continued code125 session later produced approximately 41 FPS samples with
zero queued pipelines. Android reported thermal status 2 and active CPU/GPU
cooling controls. A contemporaneous screenshot showed the notification shade,
so this is not a controlled racing benchmark. Record thermal state when
comparing candidates; compilation is not an adequate explanation for every
warmed slowdown.

A ten-second profileable-app CPU capture succeeded with 1,566 samples and no
userspace sample loss (78 kernel samples were lost). Exact code125 symbolization
identifies scalar floating-point flag handling, emulated TLS/context access and
display-list processing among hot paths. The four largest sampled scalar-flag
sites total 6.22% of aggregate cycles, and `__emutls_get_address` has a 4.47%
aggregate share. These are optimization leads for the captured state, not an
old/new regression result or permission to weaken floating-point correctness.
The direct-PID profiler attempt was denied; the supported profileable-app route
succeeded without changing device security settings.

Raw captures, profile data and thermal/device identifiers remain private. No
GitHub reporter was sent another build or asked for another log. The working
correction remains on `codex/cross-platform-stabilization-20260919`, with the
runtime on `codex/pipeline-startup-budget-20260919`; the dirty primary checkout
is preserved and documentation is reconciled there.

The subsequent [11:20 monitoring finding](pixel-code125-memory-crash.md#monitoring-follow-up-1120-background-launcher-exit)
records Android reclaiming the background launcher for low memory while the
game continued. This reinforces the need to measure sustained memory use after
compilation drains; the speculative-startup cap is not a lifetime memory bound.
