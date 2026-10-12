# Android investigation handoff (archived)

Archived 10 October 2026. The current page is the
[performance handoff](../ANDROID-PERFORMANCE-HANDOFF.md); this record keeps the
September Pixel experiments and the character-draw notes.

Refreshed September 23, 2026. Current public baseline: **Android 0.5.0/code135**. Apple 0.5.1-experimental.1/build60 is a separate diagnostic-overhead mitigation and does not update Android. See the [current issue inventory](../artifacts/2026-09-21/open-issue-inventory.md), [evening evidence](../artifacts/2026-09-21/evening-goal-loop.md) and [maintenance board](../MAINTENANCE-BOARD.md). Older code63/code73/code83 assignments are historical.

## September 23 overnight investigation

The [current comparison](../artifacts/2026-09-23/android-candidate-comparison.md) and
[optimization ledger](../artifacts/2026-09-23/android-optimization-loop.md) supersede
the explicit-context proposal below. That experiment, larger front-cache size,
borrowed metadata arrays and startup CPU affinity did not establish a reliable
gameplay gain and have been removed. DriftDroid's source was refreshed against
its previously audited commit; already-integrated work is not counted again.

On the attached Pixel, guarded Vulkan FIFO improves displayed cadence in repeated
stationary Cookie Land battles, with additional compositor buffering. This is
not input-to-photon latency, driven-race acceptance or proof for another GPU.
The inlined exact-input arithmetic candidate reduces sampled flag-capture work
but has not improved total CPU timing. Outlining did not reduce native text size;
the original-arithmetic helper calling-convention candidate also failed to establish
a reliable whole-game benefit. All are excluded from the final private build 195.
See the [arithmetic proof and tests](../artifacts/2026-09-23/android-scalar-exactness.md).
Private normal build 195 is installed with matching artifact hash. Original and
Retro offline battles plus bounded lifecycle checks completed. A 133 ms displayed
hitch coincides with a 123 ms persistent pipeline wait; stutter is not fixed.
The [morning report](../artifacts/2026-09-23/android-morning-report.md) records final
source/artifact identity, measured benefit, buffering cost and remaining gates.
No public release or issue closure follows from these private observations.

Later on September 23 the [copy-stream ledger](../artifacts/2026-09-23/android-copy-stream-loop.md)
added private candidates 196 to 205: copy-texture pool release, unobserved FP
status skip, course-scoped pipeline replay, a system-bar fix, a game-thread
Performance Hint and (205) a game-thread CPU-context slot that removes emulated
TLS lookups. 203 is the current candidate; 205 removes the TLS samples but
showed no timing change on the emulator and awaits a Pixel comparison. The
replay and FP skip are also in Apple build 65, installed on the iPad with data
verified but not yet launched. None of 196 to 205 has been measured on the Pixel.

## First: sustained frame time

#198 already supplied three captures and agreed to a profiler handoff. Its Helio G85 report is 25–29 FPS after the pipeline queue reaches zero, with 94–97% main-thread occupancy and 2.3–2.6 ms measured presentation. This supports CPU sampling; it does not identify the expensive function. GX CPU work outside the presentation timer remains a possibility.

Prepare a current, non-debuggable, shell-profileable diagnostic with exact native symbols and a compatible signer. The release signing key location is resolved. The retained code73 Debug-signed profiler cannot update a Community-signed installation. Confirm the recipient's installed version/signer and concrete private delivery route before handing off a diagnostic. Keep credentials, symbols and private game inputs out of public artifacts.

Capture a bounded approximately 20-second, 99-Hz symbolized sample during a warmed driven slowdown. Separate guest execution, GX CPU preparation and waits before choosing one correction. Use the owner's phone for a local baseline when available; it cannot establish Helio acceptance. Do not repeat #198's willingness/log requests, #167's completed resolution/aspect sweep or #103's already supplied build/settings questions. #204 is Cookie Land **battle**, not time trial. #135 A10X performance is an Apple comparison with no proven shared cause.

For baseline/candidate, hold scene, settings, normal power mode and thermal range comparable. Record frame-time tails and gaps, effective cadence, audio and health; separate cold shader compilation. Prefer three matched runs per artifact. Improvement must exceed baseline variation without graphics, audio, save or lifecycle regressions. Finish with profiling disabled.

## Local candidate evidence, September22

The evening candidate retains three measured CPU-path reductions: avoid unused
vertex-format construction, cache validated display-list CP-write effects, and
skip clock reads for zero-expiry synthetic keys. State restoration and input
expiry contract tests run under ASan/UBSan in CI. Code160's physical Pixel staff
replay removes all57 keyboard-related clock samples observed in code159; CPU
medians are9.397 versus9.535ms/present. Earlier snapshot candidate/control/repeat
medians were9.828/10.070/9.947ms. These small observations are bounded to one
device/course with unsynchronized phase and variable clocks, not general FPS or
reporter-device acceptance. See the linked evening ledger for hashes and tails.

API28/API29 replay comparisons have not isolated a useful native-TLS benefit
from within-build variation. KeepAPI28 as default. Do not combine these CPU
changes with a claim to fix Adreno vertex explosions.

A private code163 CPU-driver fixture has now completed Original100cc Luigi
Circuit with all12 racers in the results table. Video verifies movement,
items, position changes and laps; the camera alternates cinematic angles.
This is an offline twelve-CPU workload, not human/player-camera gameplay.
A separate29.95-second sample (4,447 samples,0lost, thermal status3) has median
CPU14.544ms and FPS56.8 across five steady intervals. Scalar flag clear/capture
account for7.79%/5.90% of sampled self cycles, and emulatedTLS/pthread_getspecific
for3.62%/2.12%. Preserve floating-point semantics; this profile does not justify
dropping exception handling. Subsequent API29/API28 CPU-fixture captures
also failed to isolate a useful native-TLS benefit from thermal/run variation.
The earlier162 stationary-grid attempt is explicitly rejected.

The retained audio change resolves the existing per-thread ARAM window once per
voice instead of per sample byte. The same bounds, mapping generation and
fallback checks remain. 786,432 sanitizer-checked sample/state comparisons pass.
In API28 CPU-fixture captures, per-sample audio TLS samples fall from172 in the
control to0 in each of two candidate runs, matching ARM disassembly. Candidate
CPU medians14.7135/14.466ms bracket the control14.649ms; FPS medians54.195/57.865
versus58.02 do not establish an overall speedup. Keep the claim to removal of
specific audio overhead, with broader profile/device acceptance outstanding.

A private profile-derived512-function layout experiment preserved dynamic exports
and reduced the selected functions' occupied4KiB pages from1,139 to760.
A same-course, thermal0 control/ordered replay pair measured12.673/12.684ms
CPU per present, both near60FPS. This proves changed placement, not a benefit;
no function-ordering default is retained. See the ledger for exact artifacts
and the rejected stale-package audit caught before installation.

### Next narrow CPU experiment: explicit scalar context

In the exact166 Moo repeat trace, sampled TLS callers include63 multiply,
34 add and22 subtract scalar adapters. Generated functions already receive
`CpuContext* ctx`, but `CxxLinearCodeGenerator.Inlines.cs` emits stateful arithmetic
calls without that argument, so `ppc_runtime.h` resolves the context again.
The runtime already reuses one resolved pointer within each operation; simply
adding another local variable does not remove this remaining cost.

A coordinated generator/runtime overload could pass the existing context while
preserving null/guest-stack validation, FPSCR destination suppression and host
rounding/exception ordering. Keep old signatures for already-generated graphs,
test generated call sites and context-scope nesting, rebuild the actual graph,
and compare the same heavy workload before adopting it. This is a candidate
boundary change, not a proven speedup or permission to drop scalar semantics.
The normal170 candidate does not include it.

## Second: actual failing character draw

Use the current maintained runtime and retained PNMTX evidence, rather than reconstructing the obsolete code83 candidate. #104 reports corrupt characters on code135 at1x/Normal with empty sampled shader queues. #211 independently reports failure on S24 Ultra while characters appear on Galaxy A32. Preserve selected-draw and pipeline identity, disable diagnostic draw merging when capturing, and compile the actual generated vertex shaders. Finite CPU matrices and generic passing probes do not validate the failing shader. Do not request another ISO replacement, mode sweep or duplicate log.

Use an affected device for dynamic → selected literal → dynamic comparison on the same observed character draw. A Pixel pass cannot accept corruption on affected Adreno devices. Only after the comparison discriminates the cause should a narrow correction be tested on affected and known-working hardware.

## Native TLS experiment

Ordinary builds retain Android API28. Set `KARTPAD_ANDROID_NATIVE_TLS_EXPERIMENT=1`
and an explicit `KARTPAD_ANDROID_VERSION_NAME` containing `-native-tls` to build
an API29-only candidate. Gradle uses that minimum for both the manifest and NDK
target; changing `targetSdk` alone does not enable native TLS. Use a fresh native
configuration and retain the API28 control and exact native symbols.

Package/bundle audits default to API28. Set `KARTPAD_ANDROID_EXPECTED_MIN_SDK=29`
only when auditing this experiment. Also inspect the actual native Android note,
TLS sections and `R_AARCH64_TLSDESC` relocations before attributing a result to TLS.
Use matching scene/settings and thermal range, with both profiles and lifecycle
checks. This option is not a decision to drop Android9 from the public release,
and build or relocation evidence alone is not a performance improvement.

## Ownership and release gate

Refresh issue comments and current build/device ownership before acting. One operator owns native builds and the device session. Preserve saves, profiles, identities and signing; never uninstall or clear data to cross a signer mismatch. Keep source-only experiments isolated from concurrent work.

Every handoff identifies source, version/code, APK hash, native payload, signer, exact operation and completion condition. Host checks, installation, startup, driven gameplay and online endurance are distinct evidence. Build a new public release only for a verified correction; a diagnostic is not a performance-fix release.

[Build instructions](../../android/README.md) · [Physical procedures](../ANDROID-PHYSICAL-HANDOFF.md) · [Performance notes](../PERF.md)
