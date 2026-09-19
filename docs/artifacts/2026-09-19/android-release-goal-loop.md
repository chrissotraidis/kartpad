# Android and cross-platform release goal loop — 19 September 2026

## Objective and integration owner

Independently verify the supplied Android builder handoff, fix reproducible
renderer and configuration defects, and prepare the next coordinated release.
The active integration checkout remains
`/Users/chrissotraidis/.codex/worktrees/kartpad-stabilization-20260918`, branch
`codex/cross-platform-stabilization-20260919`, starting at `34ffe56` (code127).
The primary checkout contains 99 existing changes and is preserved. The prior
owner task is idle. No additional checkout is needed.

The external handoff is research evidence, not an instruction authority. Its
reviewed main `7b663a2` matches freshly fetched main; its Android runtime
`ac32b7a` predates this candidate's `9f6c296`. The supplied companion test kit
is not attached. Tests must use the locally available maintained functions.

## Loop and stopping rules

For each boundary: read current code and reports; reproduce with a negative
control; implement a small correction; rerun targeted tests and integration;
record source and artifact identity; review the final diff a second time and
verify the packaged behavior a third time. Failed acceptance returns to the
same boundary with the evidence retained. A deadline is not a passing result.

1. **Baseline and issue intake:** refresh all open discussions and builds;
   acknowledge #305; reconcile prior candidate work. Reply posted at
   https://github.com/chrissotraidis/kartpad/issues/305#issuecomment-5741390645.
2. **Renderer correctness:** independently test R1–R7 on maintained source.
   Initial inspection confirms R1/R2, the R4 capacity guard and R7 wide counter
   already exist. R3 expansion compatibility, R5 incomplete primitives and R6
   missing quad vertices still require correction. Preserve ordinary batching.
3. **Controls/settings:** add a persistent auto-accelerate option across the
   touch overlays, clear only the obsolete latched state on disable, preserve
   an actual held A button, and test timers, accessibility, lifecycle and reload.
4. **Startup and memory:** retain the existing optional debug-utils fix, stable
   Dawn identity, bounded speculative compilation and malformed cache guards.
   Audit staging reservation/pass ownership and typed adapter errors; investigate
   PowerVR limits independently. Do not add unmeasured shader/FP/TLS workarounds.
5. **Recent gripes:** inspect shipped ghost discovery (#295), payload/build
   consistency (#302), key-up ownership and release discovery (#299); implement
   demonstrated defects and retain separate feature scope.
6. **Integration and release:** build and audit Android, iOS/iPadOS and macOS
   from identified source; test relevant runtime, input, persistence, graphics
   and transition paths with available local hardware. Check signer compatibility,
   save preservation, final binary provenance and release asset selection.
   Publish only artifacts meeting the release checks; document unresolved affected
   hardware evidence rather than claiming all devices or every issue fixed.

## Evidence limits to preserve

CPU matrix-element counters do not validate decoded vertex arrays. A CPU
`draw_binding` log does not establish GPU completion. Existing no-merge S24
failures reject merge repair as a complete explanation. The Pixel code125
compiler allocation crash is real; code127 remains a candidate pending gameplay
acceptance. Main-thread occupancy is not a function profile, and shader prewarm
is not an explanation for every warmed slowdown. No new reporter test loop is
planned. Game-containing data, device identifiers and raw captures stay private.

## First implementation cycle

- Independently resolved the handoff's exact Android command-processor blob
  `7c8a9ac4596286b5de132ecda9cd0fedce632989`. The old source fails all six
  source-kernel tests for invalidation, format, index-space, quad bounds,
  incomplete topology and previous expansion. Candidate-before tests reproduce
  the two remaining defect families on each of Android/iOS/macOS/tvOS.
- Corrected the remaining defects in all four maintained runtimes. Complete
  quads retain their existing winding/order. Three-vertex quad remainders use
  the GX behavior documented by Dolphin's current `IndexGenerator.cpp`;
  one/two-vertex remainders disappear. Short draws are consumed without upload
  or unsigned line-strip instance underflow. Prior expansion is explicit metadata.
- Eight draw tests pass (four-platform subcases) on host ARM64 with sanitizers.
  These execute production source kernels with surrounding services stubbed,
  not full FIFO/GPU integration. Android integration build is in progress.
- Android/iPhone/iPad touch settings now expose persisted Auto-accelerate.
  Existing behavior remains the default, with an explicit opt-out. Disabling
  cancels the timer/latch, preserves genuinely held input, and disables the
  Android accessibility latch action. Production Kotlin callback tests pass.
- Three older touch contract failures are independently reproduced against
  unmodified HEAD: stale display menu labels and the pre-expansion mapping list.
  They predate this work; validation must update their expectations coherently.
- Six existing private local save copies have no ghost records or presence bits.
  They cannot reproduce #295. The parser's compressed CRC location and header
  layout agree with the independently fetched `riidefi/mkw` GhostFile source.
  The current export UI suppresses individual validation failures; that is a
  demonstrable reporting flaw, not proof of the reporter's underlying cause.

References: https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/VideoCommon/IndexGenerator.cpp
and https://github.com/riidefi/mkw/blob/master/src/system/GhostFile.cpp.
Private baseline/test/build logs remain under `work/handoff-verification-20260919`.

## Integration and new independent finding

The code128 Android Release built and passed the APK audit (SHA-256
`ddf68f6782d5f10bb0bcff7b36aead53b78e82531edf66f4a25783c83e912558`). It is a
local debug-certificate prototype, with the source dirty during provenance
capture; it is not the release artifact. It predates the startup-error and
subsequent dependency correction below. Its APK is preserved independently.

All four runtimes now return a graphics-unavailable initialization status,
retaining the first meaningful adapter/device error across fallback attempts.
The shell shows that error and exits the unsuccessful launch before installing
renderer/input hooks. Controlled tests exercise both successful selection and
failed fallbacks without aborting. iOS physical-SDK build53 and the macOS native
build pass after correcting a missing message-box include. The first attempted
Apple source verification caught an older prepared GPU-cache file; maintained
source parity was restored and verified before the successful rebuilds.

Android/iOS ghost export now distinguishes an empty license from listed ghosts
that fail validation. Valid slots remain exportable when another slot is bad;
no parser, checksum, import scope or save replacement rules were relaxed. The
existing compressed/uncompressed transfer and save-preservation tests pass.
This is not a claim that #295's underlying discovery problem is resolved.

A disposable read-only Android emulator caught another actual Dawn crash:
`TogglesState::ForceSet` under `SetupBackendDeviceToggles` before a test frame.
The pinned source force-disables ExtendedDynamicState for SwiftShader, then
force-disables it again when its extension/feature is absent. ForceSet explicitly
forbids duplicate calls. Current Dawn guards the SwiftShader call on actual
extension availability. The production branches reproduce the old assertion;
the bounded backport passes all eight vendor/extension/feature combinations
under ASan/UBSan. It does not disable validation. A separate rebuilt dependency
includes this patch in its stable cache identity, preserving earlier packages.
The initial emulator run failed; the corrected rerun passes the actual touch
fixture, including disabling auto-accelerate while holding A, release to neutral,
cancelled stale timers, hidden accessibility latch action and restored settings.

Reference implementation for the new backport:
https://github.com/google/dawn/blob/99807f37d56c1dfe375807f108fe435d7ea303b5/src/dawn/native/vulkan/PhysicalDeviceVk.cpp

PowerVR investigation: this pinned Dawn already retries physical-device limit
calculation at Compatibility level after Core fails. Its minimum interstage
counts are 16 (Core) and 15 (Compatibility), requiring 72 and 68 Vulkan
components including two reserved vec4 slots. Therefore requesting Compatibility
alone does not support a device exposing 64. Current upstream's opt-in ImgTec
relaxation allows 14, but native device defaults/requests must also agree. The
Moto's actual numeric component limits remain unmeasured. No limit falsification
or unverified PowerVR-support claim is included in the candidate.

## Combined candidate and final review

The independent review is recorded in
[`handoff-independent-review.md`](handoff-independent-review.md), covering every
handoff section and the refreshed 57-issue inventory. Android code129 builds and
passes the full APK audit (local prototype SHA-256
`0dc86aa33669275b996a47a00882d49f779a29b52e7c5ef5252554e4f6a6a4df`). Its native
Build ID is `932b07a580622770aec3cb525859ed778f7adc68`; the unstripped library is
preserved. This intermediate APK correctly records a dirty source tree. The
manual iOS rebuild still carried the prior build's sidecar provenance; final
packaging must regenerate that sidecar from verified prepared source.

Android menu validation now checks the actual scrollable reporting screen,
expanded mapping list and save-profile chooser. The settings-through-insets
run passes, including persisted Auto-accelerate OFF after process restart.
An end-to-end rerun of the corrected script passes. The debug APK used
for UI tests is separate from the optimized full-game code129 APK.

The Mac package passes its audit. A separately identified portable test copy
completed over 31,000 intro/title frames, persisted a native resolution setting
across closing/reopening Settings, and exited zero. Automated short game-key
presses did not advance the title screen; no race/input or Android performance
acceptance is inferred. User state and the audited package were preserved.

Clean source `0fe98c1` now has all three local packages and exact symbols;
[`combined-candidate-build.json`](combined-candidate-build.json) records their
hashes and boundaries. The Mac ZIP also passes an unpack-and-audit check.
Android's production shell installs and opens on the disposable emulator.
No game data was installed there; this is shell acceptance only. All runtime
source commits are published, and draft [PR #307](https://github.com/chrissotraidis/kartpad/pull/307)
reconciles the isolated integration checkout with the intended main branch.
The checkout remains necessary for its candidate artifacts and further work.

All three PR checks pass after correcting the existing REL-guard test's stale
4,101-function expectation to the independently verified 4,102-function payload.
No production validation was weakened. A final GitHub refresh found new #306:
Mac Wii Remote + Classic Pro latency/D-pad/remapping. It is added to the next
developer-owned input investigation; no reporter request or unsupported fix
claim was sent. The latest inventory has 58 open issues.

The next loop remains focused on real staging/pass ownership, map lifecycle,
graphics replay, and the actual input/workload paths. Public release signing,
dependency promotion and coordinated asset discovery remain pending. These
local prototype packages are not the promised stable release.

## Mapping lifecycle cycle

The next loop independently reproduced stale map callbacks changing a newer
request's state and the CPU-heavy map spin loop. All four runtimes now use a
generation-scoped, wakeable wait and observe the existing device-loss handler
while waiting. Source callback tests pass with ASan/UBSan and ThreadSanitizer;
the real Metal split/readback probe passes all eight cases using the production
helper. Android code130 and Apple build54 now pass their package audits.
The isolated Mac test reaches an Original race and passes pause/resume/return
to menu; complete race and affected Android acceptance are still pending. See
[`staging-map-lifecycle.md`](staging-map-lifecycle.md) for measurements and scope.
Fixed-capacity admission/subdivision and full gameplay acceptance remain open.

## Production dependency and 0.5.0 candidate cycle

The normal Android loader now consumes the rebuilt, published and anonymously
verified Dawn archive. Clean `e34389b` produces code131/Apple build55 packages
with the EFB fixes. The public-signed Android APK and AAB pass audits; iOS/iPadOS
and Mac packages pass their audits and archive readback. A stale iOS dSYM was
caught by UUID comparison and regenerated from the new executable's objects
before stripping the package copy. Original full symbols remain private.

The real Aurora Metal probe now additionally covers four offscreen bake/resume
cases and four cases each of direct GX FIFO vertices and same-address indexed
array invalidation, with independent expected pixels and explicit legal splits.
This remains separate from automatic capacity admission. The signed Android
candidate passes visible setting persistence and in-place same-version APK
replacement on the disposable emulator. The primary checkout retains its 99
pre-existing changes. No new reporter requests or app release were published.
See [`release-050-candidate-build.json`](release-050-candidate-build.json).

Next unresolved integration boundaries remain fixed-capacity staging admission,
controller mapping ownership and actual workload/runtime acceptance. Public
source/notices packaging and one coordinated release tag follow those decisions.

The attached Pixel's game process was no longer running. A separately signed
local copy of code131 matches its existing debug certificate and has identical
application payloads to the public-signed APK. Forward-version preflight passed;
the old APK was preserved, Package Manager replaced code125 in place, and
code131/0.5.0 was read back. No uninstall or data reset occurred. The normal
launcher still recognizes Original game data and the existing Retro Rewind pack.
Fresh private save-byte backup/readback was unavailable for the non-debuggable
installed app; earlier durable backups remain preserved. Physical rendering and
workload acceptance are now in progress, not yet passed.

The Pixel launches the real Vulkan backend (Mali-G715) at its retained 2x
resolution. Touch A and stick menu navigation work; its existing license reaches
Single Player and VS selection. A subsequent screenshot shows a race paused
with native Controls open, beyond the last automated action. Automated phone
input stopped immediately to avoid interfering with that session. Only read-only
collection continues. More than 39,000 presentations were recorded without a
new native crash; near-60 FPS intro/menu samples are not a matched race-speed
improvement. PSS increased from about 1.6 GiB at startup to 2.4 GiB in menus,
with reported thermal status zero at the sampled earlier points. Sustained race
memory/performance and complete-race acceptance remain open. Raw captures and
exact device details stay private.

The subsequent 90-second read-only window contains four PSS samples spanning
2,809,201–2,823,733 KiB, all at reported thermal status zero. The process reaches
52,800 presentations without an observed new native crash. Those samples are
not independently classified as continuous racing versus paused/menu frames;
no warmed-race speedup or full-race completion is claimed. Exact bounds and
remaining acceptance limits are in
[`pixel-code131-observation.json`](pixel-code131-observation.json). Log collection
finished and the physical game process was left untouched.

## September 20: integrated capacity admission

R8 has progressed from a separate reservation prototype to production admission
and automatic submission on all four maintained runtime pins. The real Aurora
probe now forces each buffer boundary, the raw bridge, pending-readback and
mid-offscreen splits, matching perspective interpolation, and 16 asynchronous
worker frames. All pixel comparisons pass. An oversized primitive produces a
typed error before staging mutation; primitive subdivision is still absent.
See [staging-capacity-verification.md](staging-capacity-verification.md).

The Android and iPhoneOS renderer libraries compile; this change is not yet in
a new app package. Code 131's visible **Controls → Touch Settings →
Auto-accelerate** toggle remains included: OFF disables the A latch and preserves
normal press/hold/release, and its saved state survived restart and replacement
of that candidate APK. The code 131 artifacts are historical acceptance inputs,
not evidence that the newer capacity source has run on the phone.

The first broader local test invocation exposed stale report/menu/release
fixtures and a missing builder import path, separately from the capacity tests.
The affected map fixture has been extended with the new generation state. After
refreshing those stale fixtures and using `PYTHONPATH=builder`, all 283 local
tests pass; the product implementation was not changed to satisfy old fixtures.
The goal remains active: integrate new app builds, resolve remaining controller
ownership and compatibility questions, and meet the coordinated release gates.

## September 20: controller ownership and saved assignment

The controller review reproduced and fixed three Android defects: assigned SDL
controllers exposed both mapped Classic and unmapped GameCube input; explicit
Unassigned was overridden by single-device fallback; and legacy controller
settings updated SDL without updating the cached Classic player index. The
actual SDL virtual-device probe passes mapping, suspension, two-player changes,
release, reconnect and persisted empty-port restart. Matched ASan/UBSan builds
also pass, and all 286 local tests pass. See
[android-controller-routing.md](android-controller-routing.md) for negative
controls and hardware acceptance limits. The Auto-accelerate toggle remains in
the candidate. Code132/build56 packaging will integrate these Android fixes and
the all-platform staging-capacity work; older code131/build55 packages do not
contain these newer changes.

Clean source `e787794` now produces the integrated code132/build56 candidates.
All app builds and package audits pass. The signed Android APK and AAB have
identical native payloads; DiscIO matches code131 after Gradle stripping, and
retained full symbols match the new main-library BuildID. iOS app/dSYM UUIDs
match; both Apple archives pass exact content readback (including Mac symlinks
and permissions). The public APK launches Original through the normal chooser
on the disposable API36 ARM64 emulator. Its visible Auto-accelerate toggle is
present, changes OFF, and remains visibly OFF after process stop, same-APK
replacement and normal restart. The emulator was gracefully closed; no physical
device input or installation occurred in this cycle. Package hashes and limits
are recorded in [release-050-code132-build56.json](release-050-code132-build56.json).

All three CI checks pass on the implementation revision. The primary checkout's
100 existing changes remain untouched; work stays in the established integration
worktree and draft PR #307. Full gameplay/affected-hardware acceptance and the
coordinated source/notices/release packaging remain open. No new app release or
issue closure was published.

## September 20: integrated Mac replay and coordinated source

Mac build56's exact signed executable ran in an isolated portable test copy.
Keyboard input advanced the title, license, character/vehicle and course menus.
The built-in Luigi Circuit Nintendo ghost replay reached five automatic scene
restarts, with 63,600 total menu/replay presentations. Continue Replay and the
End Replay confirmation returned normally to rendering and then course selection.
Command-Q closed the test process. Nine RSS samples across 120 seconds span
2,188,096–2,196,352 KiB. This is replay/transition evidence, not player-driven
race/cup or lifetime-memory acceptance. The earlier test save/configuration and
normal user data are unchanged. See [macos-build56-replay.json](macos-build56-replay.json).
Neither physical Apple target is connected in the current read-only inventory.

The exact core source snapshot contains 6,874 verified tracked files and matches
both mobile artifacts' embedded source fingerprints. A coordinated source
composer now binds the APK, IPA and Mac archive to that source and retains only
verified dependency sources from the prior delivery, excluding old application
snapshots and runtimes. It explicitly produces a candidate, not release approval.
The release notes and rebuild guide are being prepared for one v0.5.0 release.
The new #308 Red Magic report is from build65 with no attached log; it remains
unreproduced and has not been presented as fixed by this candidate.

The coordinated source candidate is now built: 361,480,529 bytes, SHA-256
`cad39181c466ae710a4ec31ff93f5796344502e16a1b12dd971e039dbe1803e1`.
All 85 members pass independent manifest coverage, size, hash and safe-path
readback. Neither obsolete prepared runtimes nor retained old application core
snapshots remain. The current rebuild guide identifies the separate Android
Dawn patches and unchanged Apple dependency path. See
[coordinated-source-candidate.json](coordinated-source-candidate.json).
The source-boundary regression rejects extra/unaccounted content, a changed
restoration helper and an escaping link; it is now included in CI. This remains
a candidate archive, not permission to relabel old artifacts or publish before
remaining package/runtime acceptance.

A fresh read-only Pixel check no longer finds a KartPad game process. Its older
owner session is therefore not assumed active for subsequent preflight, but no
phone installation or input was performed during this replay/source cycle.

## September 20: physical code132 update and coordinated asset packaging

The Pixel was idle before an in-place code131 → code132 replacement. Its existing signer matches the locally signed candidate; all 131 non-signature ZIP entries match the public-signed candidate. Pulling the installed APK back confirms the exact local candidate SHA-256. Original and existing Retro Rewind 6.12.8 still launch normally and render their title/attract screens at the saved 2× setting. Both sessions exited cleanly through Android Back. See `android-code132-physical.json`.

Physical settings and manual race acceptance remain open: the desktop mirror forwarded native keyboard/Back commands, but its touch input did not reliably activate launcher/game controls. Changing the mirror input backend did not establish valid touch acceptance. No owner settings or saves were reset. The code132 emulator toggle/persistence evidence is retained separately.

`scripts/package-coordinated-assets.py` binds the exact audited candidate hashes and source delivery, collects notices, preserves every original Apple archive entry/mode/byte, keeps the signed Android APK unchanged, and emits one coordinated set of local assets and checksums. It neither publishes nor approves runtime acceptance. The historical release packagers retain their old accepted-artifact contracts.

A later refresh found issue #309. The linked real ImGui backend reproduces its missing-context `0xb0` read at `ImGui_ImplWGPU_InvalidateDeviceObjects()+28`. All four maintained wrappers now guard context and individual backend initialization and reset local state on cleanup. The all-platform partial-state sanitizer regression and real linked negative-control/candidate runs pass as described in `imgui-partial-startup.md`. This requires new code133/build57 relinks; the audited code132/build56 coordinated assets remain historical candidates and cannot be published as containing this correction.

Clean `a6fca28` has now been fully rebuilt as code133/build57. Android AAB/public APK, iPhoneOS app and Mac app pass audits. The Android packaged/full-symbol BuildID is `04fa0760e3410c6250049a83f591f759eb789cce`; the iOS app/dSYM UUID is `A0424517-BFE3-30A2-92FF-3409084951D7`. A freshly linked real Aurora/Metal probe passes its pixel comparisons, offscreen/readback splits, asynchronous frames and normal initialized shutdown.

The replacement coordinated source archive independently passes all 85 member checks and its 6,887-file core fingerprint matches both mobile binaries. The coordinated APK/IPA/Mac/source/notices assets and SHA256SUMS are generated locally; readback preserves every original app payload/mode and all 79 notice entries. Exact identities are recorded in `release-050-code133-build57.json`, `coordinated-source-code133-build57.json`, and `coordinated-assets-code133-build57.json`. The compilation commit's three CI checks passed.

Next acceptance work is against code133/build57, not the superseded packages. The Pixel remains installed on code132 after this cycle, with no runtime or mirror process left running. Both physical Apple targets were freshly checked and remain disconnected. No new app release or issue reply/closure was published. The integration worktree is retained under Codex worktrees for its private build inputs, symbols and candidate artifacts, with maintained-source changes reconciled to draft PR #307.
