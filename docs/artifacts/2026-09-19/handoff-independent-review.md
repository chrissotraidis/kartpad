# Independent handoff review and release decision

19 September 2026. This review treats the supplied builder handoff as research,
not as authority to change release gates or contact reporters. The requested
acknowledgment was posted to [issue 305](https://github.com/chrissotraidis/kartpad/issues/305#issuecomment-5741390645).
All subsequent investigation is developer-owned. No additional reporter tests
or logs have been requested.

## Current checkpoint — September 20

**Latest binaries:** clean `a6fca28` now produces Android code133 and Apple build57, including the ImGui correction below. Native builds, package audits, symbol matching, the normal-shutdown real GPU probe, exact source fingerprint checks and coordinated asset readback pass. See [the new candidate record](release-050-code133-build57.json) and [coordinated assets](coordinated-assets-code133-build57.json). These binaries still require their own physical/gameplay acceptance; code132/build56 runtime observations below are historical evidence.

A subsequent refresh found [#309](https://github.com/chrissotraidis/kartpad/issues/309). The real pinned ImGui backend reproduces its `0xb0` cleanup crash. All four maintained wrappers now guard partial initialization; [the verification record](imgui-partial-startup.md) describes the proof and limits. Code132/build56 below predate this correction and require replacement relinks before release.

Clean `e787794` produced Android code132 and Apple build56, integrating the
capacity, readback and Android controller fixes. The package identities and
current acceptance are in [the candidate record](release-050-code132-build56.json).
Mac build56 now passes repeated built-in ghost replay loops and a normal return
to course selection; its prior test state and normal user data remain preserved.
See [the replay record](macos-build56-replay.json). This does not establish full
player-controlled cups, online endurance or affected-Android acceptance.

A fresh issue refresh found [#308](https://github.com/chrissotraidis/kartpad/issues/308):
Red Magic 11 Pro / nubia NX809J on Android16 reports vertex explosions when
booting Original at 1x/4:3. Its reported app is **build65**, not code132, and no
manual log attachment or follow-up comment was present. It remains a separate
unreproduced hardware case; no reporter request or fix claim was sent.

The dated sections below preserve the investigation history. Their older
candidate IDs and pending-step descriptions are superseded by the linked
current records and [active goal loop](android-release-goal-loop.md).

## What was independently established

The reviewed Android command processor resolves to exactly the handoff's blob
`7c8a9ac4596286b5de132ecda9cd0fedce632989`. Its runtime `ac32b7a` predates the
existing integration candidate. The separate transcribed test kit was not
attached. Local tests instead extract production functions from the maintained
checkout, with explicitly stubbed surrounding services, and run on host ARM64
with AddressSanitizer and UndefinedBehaviorSanitizer.

| Finding | Independent result | Candidate action and remaining boundary |
| --- | --- | --- |
| R1: invalidation bypasses merge | Old source fails; candidate already dirties GX state on invalidation | Retained. Source tests pass; not matched to a handset crash. |
| R2: format switch bypasses pipeline selection | Old source fails; candidate already marks a changed format dirty | Retained and tested across all four runtime pins. |
| R3: expanded previous primitive accepts triangle merge | Reproduced in the candidate-before condition | Added explicit previous-draw expansion metadata to the merge key. Ordinary triangles remain batchable. |
| R4: merged 16-bit indices wrap | Old source fails; candidate already bounds total vertices | Retained wide arithmetic and the 65,536-vertex ceiling. Output uses triangle-list indices without primitive restart, so index 65,535 is usable. |
| R5: incomplete primitives cross draw boundaries | Reproduced in candidate-before source | Emit complete list triangles; short strips/fans emit nothing. Short line draws are consumed before upload/instance-count arithmetic. |
| R6: quad remainder references absent vertex | Reproduced in candidate-before source | Complete groups retain prior winding; a three-vertex remainder becomes one triangle; one/two vertices emit nothing. |
| R7: 16-bit quad counter wraps | Old source fails; wide counter already present in candidate | Retained wide counter; combined tests cover output count, winding and bounds, including 65,520–65,535. |
| R8: mapped staging slice aborts at capacity | Confirmed `ByteBuffer::resize` abort and the additional 3,840-byte final uniform tail | Integrated in September 20 source `2da33c5`: complete-operation admission, bounded retry, offscreen-prefix preservation, and readback generation handling. Real forced-capacity GPU comparisons pass. Oversized operations receive typed rejection; integrated code132/build56 packages now pass audits; wider physical acceptance remains pending. See [capacity validation](staging-capacity-verification.md). |

The topology test samples small counts, counts spaced by 127, and every count
from 65,520 through 65,535. It validates every emitted index in each sampled
case; it is not an exhaustive full-FIFO/GPU test. The quad remainder behavior
was checked against [Dolphin's index generator](https://github.com/dolphin-emu/dolphin/blob/master/Source/Core/VideoCommon/IndexGenerator.cpp).

## Startup, compilation and memory

The existing optional Vulkan debug-utils backport matches the signatures in
#301, #303 and the newer A9+ subcase of #216. Controlled advertised/missing
entrypoint tests pass. This does not resolve the older Tab A report by itself.
The prior code125 Pixel failure is preserved as a failed candidate: driver
compiler allocations exhausted memory. Stable Dawn identity, a 128-recipe
speculative replay budget, one background compiler, demand-work promotion and
malformed cache-row rejection are retained. The real SQLite/worker tests pass;
the compiler in that scheduling test is a controlled stand-in.

A new disposable Android emulator run reproduced a separate Dawn assertion:
SwiftShader's ExtendedDynamicState toggle was force-set twice when its extension
or feature was absent. A narrow backport of the guard present in
[current upstream source](https://github.com/google/dawn/blob/99807f37d56c1dfe375807f108fe435d7ea303b5/src/dawn/native/vulkan/PhysicalDeviceVk.cpp)
passes all eight vendor/extension/feature combinations; the original branch
asserts. The corrected dependency then starts the actual Android fixture and
passes its touch tests. The combined patch identity is
`b0fd045b0a694eb07ac3fcf0d741f8697b935856`; the Android Dawn archive SHA-256 is
`99cef2c445bb9fa9758dda2036887f29c6116629053d2b40b3107590881db43a`.
Earlier dependency installs remain intact.

All four runtimes return an explicit graphics-unavailable status rather than
asserting when no backend starts. The first useful adapter/device error survives
fallback/window cleanup and is copied before another SDL call. The runtime
shows it and exits before installing renderer/input hooks. Controlled failure,
direct-success and fallback-success tests pass. Returning from the runtime is
not yet proof of the complete chooser/retry flow on an affected phone.

For #304, the pinned Dawn already tries Compatibility limit calculation after
Core fails. Core requires 16 interstage variables and Compatibility 15; with
two reserved vec4 slots these require 72 and 68 Vulkan components. Merely
requesting Compatibility cannot accommodate 64. Upstream has an opt-in ImgTec
14-variable relaxation, but the pinned device's `ReifyDefaultLimits` raises a
lower request back to its feature-level default. A physical-device check alone
would therefore leave an inconsistent device contract. The actual Moto G54
numeric limits and representative shader execution remain unavailable; no
limit falsification or PowerVR-support claim is included.

The handoff's 148 MiB arithmetic is correct for requested destination/staging
sizes (37 + 3×37 MiB); it is not measured process residency. The map wait really
has no deadline/backoff and its spontaneous callback shares global state.
Adding an arbitrary timeout would risk accessing unavailable storage or losing
one-shot texture work. A safe next change must join lifecycle generation,
callback cancellation, pass ownership, and transactional reservation. It must
cover offscreen/suspended EFB passes and one-shot bakes before integration.

## Graphics and performance claims that remain unproved

The existing diagnostic counters inspect selected matrix elements, not decoded
vertex-array positions/normals. `draw_binding` records a CPU recipe before
pipeline readiness, encoding and submission. Those counters cannot clear the
whole vertex path. The no-improvement merging-disabled/literal-indexing result
in #193 is preserved: R1–R7 do not explain all S24 corruption.

The next S24 experiment needs a private exact-draw replay with actual vertex,
index, uniform and texture bytes, lowered shader, pipeline/readiness outcome,
submission and pixel output. A CPU reference and immutable dedicated buffers
can then distinguish decode/layout, shader lowering and resource reuse. The
Fold/whole-scene cases retain separate acceptance rows. No blanket PNMTX, SSBO,
FIFO, native TLS or floating-point workaround has been promoted.

Warmed #198/#275 captures show heavy main-thread occupancy after compilation,
but do not identify an expensive function. The inspected audio path uses SDL,
not Oboe, and drops incoming blocks when its queue budget is full. Better warmed
race frame-time tails, guest speed, audio and thermal behavior still require
matched workload measurement. Startup compilation improvements cannot be
reported as a demonstrated warmed-race FPS improvement.

## Recent settings and configuration reports

| Report | Action and acceptance |
| --- | --- |
| #305 auto-accelerate | Added persistent Android/iPhone/iPad opt-out. Disable clears the latch/timer while preserving an actual held A. Android production callback tests and real emulator MotionEvent fixture pass, including stale timer and accessibility cases. |
| #295 ghost discovery | Original import/export already shipped in code117/build49. Six available local save copies contain no ghost presence flags/records, so they cannot reproduce this report. Parser layout/CRC rules agree with the independent MKW decompilation. Fixed swallowed export-validation errors on Android/Apple; valid slots still export beside corrupt slots. JNI and save-preservation tests pass. Custom-track support and the reporter's discovery failure remain separate. |
| #297 mapping | Expanded mapping already exists. Menu tests were stale about labels and the number of controls; they are being updated against the running UI. |
| #197 held/released controller input | Existing native focus/removal controls pass. Popup-window key-up routing and changing device/source ownership remain unproved; clearing all input on resume is not justified. |
| #273 motion | The report has no reproducible sequence. No speculative motion rewrite or new reporter request. |
| #302 payload mismatch | Existing candidate already verified the new signed small WFC payload and regenerated its 4,102-function mod translation. Preserved authentication and exact size/hash checks. |
| #299 release discovery | The next release must put APK, unsigned IPA and Mac archive under one tag; verify consumer asset selection before publication. No coordinated release has been published from this candidate. |

The initial inventory contained 57 open issues. A final refresh found #306,
reporting Wii Remote + Classic Pro delay, missing D-pad and failed remapping on
Mac v0.4.22/macOS 27. The mapping/pairing UI is unchanged from that tag. Pinned
SDL explicitly decodes all four Classic D-pad bits, including MotionPlus fixups,
and KartPad exposes those mapped buttons. The experimental Wii HID backend is
opt-in; actual backend/packet timing is unknown. Next is a local investigation
of backend selection, packet-to-guest latency and mapping ownership. No reply
or unsupported fix claim was sent. The current inventory has 58 open issues.

Race/cup exits, online
endurance, unclassified launch failures, handheld insets, save/identity restores,
older Apple platforms and new service/controller features remain separate
families. Source-kernel or emulator results do not close those reports. The
prior #248 continuation correction has shipped; it is not newly fixed here.

## Integration evidence and release decision

Changes live in the existing `codex/cross-platform-stabilization-20260919`
worktree; the primary checkout's 99 pre-existing changes are preserved.
Runtime startup commits: Android `606d3bc`, iOS `959ba99`, macOS `70dc938`,
tvOS `b923726`. Topology changes precede these commits. The parent branch
includes the prior candidate work and still requires final source integration.

iOS/iPadOS build53 compiles against the physical-device SDK and passes the full
app audit. Mac build53 compiles and its package passes the audit. An isolated
Mac test copy completed over 31,000 intro/title frames, exercised native
settings, persisted a resolution change and exited with code zero. Short
automated game-key presses did not advance the title screen; race/input
acceptance is therefore not claimed. The build ran alongside compilation and
is not a performance comparison. User saves and normal application defaults
were not used for this test.

Android code128 passed the package audit but predates the later startup/ghost/
Dawn changes. Code129 is the combined local candidate. Neither local prototype
is approved for public signing/publication merely because it builds. Final
artifact hashes, embedded provenance, release certificate compatibility and
native symbol matching must be recorded after the clean-source build.

Clean source `0fe98c1` now produces audited Android APK, unsigned iOS/iPadOS
IPA and Mac ZIP candidates. Identities and acceptance states are recorded in
[`combined-candidate-build.json`](combined-candidate-build.json). Android's native
payload is byte-identical before/after the clean provenance refresh. Its release
shell installs and displays the missing-game-data chooser in the disposable
emulator; this is not full-game GPU acceptance. The unpacked Mac ZIP preserves
its internal symlinks and passes the package/signature audit. Apple symbols match
the app UUID. The local APK's certificate is not the public release certificate.

The complete Android menu/inset rerun passes. Draft
[PR #307](https://github.com/chrissotraidis/kartpad/pull/307) contains the integration,
with all four runtime commits published on matching source branches. Its shared
runtime and build-receipt checks pass. CI exposed one stale expected mod count
in the existing REL-guard test; correcting the expected 4,102 count while
retaining stale/unexpected-count rejection passes all 11 local tests and the
subsequent CI regression job. That follow-up changes only a test.

The release goal remains active. Next are staging/map lifecycle integration,
developer-owned graphics/input reproduction and matched workload validation,
followed by production dependency promotion and coordinated release preparation.
Current evidence does not justify promising zero issues, faster warmed gameplay
on affected Android hardware, or closing all graphics/compatibility reports.

## Actual Aurora EFB follow-up

The ROM-free real Metal renderer reproduced a scaled-readback vertical clamp
defect. Corrected source preserves the expected four-color GX tiles across
repeated batch splits. Independent callback controls additionally reproduced
use-after-return, expired error text, stale-lifecycle completion and shutdown
reentry failures; corrected cases pass all four pins. See
[`efb-readback-verification.md`](efb-readback-verification.md). Code130/build54
predate these corrections. Fixed-capacity admission and device acceptance are
still separate work.
