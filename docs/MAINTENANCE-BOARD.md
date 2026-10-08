# Bug-fix priorities and maintenance board

## Current priorities: 8 October 2026

**Primary goal: improve Android race performance across hardware, with evidence
that the improvement reaches players.** A demonstrated new data-loss or launch
regression preempts this order. Otherwise, protect sustained CPU/stutter work
from being displaced by more small features or repeated diagnostic runs.

[Complete GitHub review and intake counts](GITHUB-REVIEW-2026-10-07.md) ·
[Executable priority queue](maintenance-priorities.json) ·
[Current execution checkpoint](CURRENT-LOOP.md).

The JSON owns ordering, readiness and next actions; this board explains that same
order and its measurement gates. The public baseline is 0.7.14/build 258.
Draft #416 at product-code commit `e6bb7da7` is a candidate, not a speed release.
There are 27 open issues and five open PRs, four of which overlap in #416.
[8 October intake and build experiment](INVESTIGATION-2026-10-08.md): #437 icon
customization is newly accepted and assigned; no new replies on existing bugs.
Three compiler probes put 82–92% of their time in the back end. Warm incremental
builds work; a metadata-only edit takes two steps, not a full rebuild. No speed
improvement or issue resolution is claimed from these measurements.
New issue intake has not demonstrably slowed: 17, 14, then 19 in the last three
complete weeks. Closure/consolidation must not be counted as repaired defects.

### Work order and the next useful result

| Rank / queue card | Problem and reason | Next bounded result / acceptance |
| --- | --- | --- |
| 1 `warmed-performance` | #339: slow races across low/mid/high-end Android; twelve earlier reports are consolidated here, with #200 now playable but still slow. Largest repeated user impact. | Reconcile retained profiles and exact artifacts, then rank guest/FP/dispatch, GX preparation, waits, shader work and presentation by measured cost. Produce one bounded candidate with an explicit maximum removable cost. Physical same-scene performance acceptance is required later; emulator time is not Android speed proof. |
| 2 `build-throughput` | #339: slow builds make every hard experiment expensive. Patchy's second target deserves its own measurements. | No-op and metadata-source incremental checks now pass. Three shard profiles are 82–92% back-end time. Choose one common-shard code-generation/partition candidate; compare representative compile time/code size/semantics, then full clean and incremental builds. Retain diagnostic symbols and reject stale reuse. |
| 3 `adreno-geometry` | #104/#301: affected phones still draw characters incorrectly; #431 has no attached draw evidence yet. | Use retained actual failing draws to distinguish vertex input layout from matrix lookup/upload. Verify the actual generated shader, not a generic probe. A changed/empty image is not a passing image. Affected plus known-working hardware ultimately required. |
| 4 `android-powervr-capability` | #304: distinct PowerVR evidence; earlier capability repair does not establish correct character rendering. | Reconcile the 0.7.14 three-copy result against exact draw state. First prove what was drawn and whether any copy is correct; no automatic global workaround or repeat phone-crash capture. |
| 5 `storage-recovery` | #234-adjacent recovery defects were reproduced and fixed in #416, but full identity migration is still missing. | Synthetic process-death checkpoints and launcher access after failed import. Existing progress, backup and request survive, retry succeeds, and failure does not trap the user. Do not relabel this as full NAND/Mii/country migration. |
| 6 `apple-startup-flicker` | #390: repeatable startup flicker on two Apple devices; video/log already sufficient. | Correlate drawable/present/fade boundaries with game/FPS disappearance while touch remains. One failing-before/passing-after presentation experiment; physical matching-device acceptance remains separate. |
| 7 `controller-and-insets` | #378/#306/#202: input routing and usable screen area; distinct platform paths. | Trace raw event, player assignment, mapping and release separately; reproduce inset transitions separately. Existing ipega fix needs actual hardware confirmation, not another virtual-pad pass. |
| 8 `candidate-delivery` | #411/#430/#377/#127: complete existing sound/shake/updater and renderer acceptance without starting more features. | Final rebuilt #416 Android package; matching packs and signed fresh/update paths; audible iOS Sound and physical shake; exact Mac split-screen regression. Component PRs are not independent release obligations. |
| 8 `app-icon-choice` | #437: Chris accepted icon customization for the next build. | Inspect current platform assets and selection/reset support, then define the smallest supported flow. Check launcher identity, relaunch and update behavior before shipping; arbitrary image support is not established. |
| 9 `released-path-confirmation`, `android-launch-classification`, `single-joycon`, `android-online` | #131/#370/#380, #332, #324, #405: specific affected-device/evidence gates or network constraints. | Preserve existing asks and workarounds. No fresh patch from silence. Wi-Fi/VPN success narrows the network path but does not prove carrier NAT details. Move up only when a discriminating local experiment or new failure evidence appears. |
| 10 `retro-ghost-transfer`, `save-identity-migration`, `larger-feature-requests` | #295, #234/#203, #90/#91/#100/#203/#300: substantial new capability or unaccepted feature scope. | Keep independent contracts for Retro replay, complete migration, Wiimmfi, DSU, display output, other disc regions, cheats and older OS support. Defer expansion while Android performance and current candidate correctness are active. |

### Android performance: define the gain before spending compute

[Patchy's request](https://github.com/chrissotraidis/kartpad/issues/339) sets an
approximate **10% reduction in CPU frame time on weaker systems**, with average
and worst-case frame times, not simply a higher FPS counter. This is a goal,
not a gain already established by #416 or a universal device guarantee.

The [context-cost correction](https://github.com/chrissotraidis/kartpad/issues/339#issuecomment-6007676791)
changes candidate selection: ~17% was all sampled FP-helper work; ~3% was
context/TLS work in the cited profile. Even eliminating that entire 3% would
remove only 3% of total time in that workload; the subset reachable by passing
`CpuContext*` is smaller and may add register pressure. It cannot alone meet
the 10% target. Sampled proportions are a hypothesis budget, not a portable
performance forecast. Do not change rounding or FPSCR semantics for speed.

For any such candidate, check NaN/sNaN, signed zero, subnormals, all guest rounding
modes, destination suppression, FPSCR flags/exceptions, nested/reentrant context
lifetime and context switches. Compare emitted ARM64 loads/calls, spills and
code size. A removed lookup proves removed work, not faster gameplay. Earlier
context, affinity, cache-size and function-ordering experiments without gains
are retained in the [Android history](ANDROID-PERFORMANCE-HANDOFF.md); do not
repeat them without a changed hypothesis or workload.

Use a small benchmark matrix with fixed scenes and separate outcomes:

| Workload | Why | Required record |
| --- | --- | --- |
| Warm Original Luigi Circuit, 12 racers, fixed replay/CPU fixture | Guest CPU and GX preparation under race load | Game-thread CPU/frame, average and p50/p95/p99/worst intervals, guest cadence, native profile, audio drops, memory, thermal state |
| Warm Cookie Land battle, fixed character/camera and load | Existing #204-style stutter evidence | Same metrics plus counts above 25/40 ms, pipeline queues and blocking waits |
| Cold versus warm first race, Original and Retro separately | Separate pipeline-compilation stalls from sustained slowdown | Time to playable race, first-lap tails, later-lap tails, shader demand/waits, audio and memory |
| Later physical low-end and representative working Android | Confirm benefit outside the owner's fast device | Same exact app/pack/settings and matched baseline/candidate; affected GPU correctness remains its own gate |

Use at least three counterbalanced matched pairs for a physical acceptance
comparison; fix cache policy, scene, resolution, power/refresh settings, profiler
mode and a comparable thermal range. Report all pairs and baseline variation.
A candidate proceeds only if CPU improvement exceeds measured variation and
p95/p99/worst, audio, rendering, saves and lifecycle show no material regression.
If noise obscures the target, improve the fixture or park the claim. Do not
average away a stutter regression. Finish acceptance with profiling disabled.
The historic Pixel stationary-battle improvement is scene-specific; it does not
close the weaker-device race reports. No physical device is used by this pass.

### Build time: make experimentation cheaper

Patchy's separate goal is **roughly 40% shorter final compilation** on the same
machine. Also report full pack-build wall time, so moving work into translation
cannot masquerade as a total improvement.

[The 0.7.5 measurement](https://github.com/chrissotraidis/kartpad/issues/339#issuecomment-5966957229)
reported compile CPU 2,232 → 1,404 seconds (-37%) and wall time 396 → 271 seconds
(-32%, eight jobs on a busy host) after omitting debug information from stripped
Android packs. That is already-shipped work, not a new 0.8.0 gain or proof of the
full 40% target. Keep a symbolized diagnostic route; don't blanket-strip debugging
capability to improve a benchmark.

[The upstream-sync comparison](https://github.com/chrissotraidis/kartpad/issues/339#issuecomment-5990733427)
reported total 175 → 181 seconds, translation 39 → 46, compile wall 131 → 130.
This provides no demonstrated build speedup and lacks a repeated, separately
isolated shard-generation/incremental comparison. Use the current pinned
baseline and candidate for the next experiment, with fresh output directories
and fixed toolchain/jobs/host load/cache policy. Never erase a player's build or
private source inputs just to obtain a clean sample.

The [8 October measurements](INVESTIGATION-2026-10-08.md) complete the initial
no-op/small-change probes and find back-end-heavy compiler samples. For the next
candidate, inspect retained Ninja logs and the dependency graph: identify critical-path
shards, wall versus CPU time, peak memory and unexpected regeneration. Then run
one controlled no-op and one predefined small-change build before changing shard
size, flags or parallelism. Check generated file hashes/mtimes and whether
unchanged output is rewritten; this is an experiment, not an established bug.
Use the measurements to choose one change. Preserve pack fingerprints and exact
code/data dependencies, compare clean and incremental medians/spread, and reject
an optimization that skips a required rebuild or makes updates worse.

### Focus loop and resource limits

Default investigation allocation for the next block of work: about **50% Android
CPU/stutter, 25% build throughput, 15% affected graphics, 10% safety/delivery**.
These are planning weights, not a schedule or a quota on fixing critical bugs.
When hardware is unavailable, spend the performance share on profiles, codegen,
equivalence and cheap candidate rejection; move unavailable timing acceptance to
its explicit gate. The initial build-throughput measurement is now complete; use its compiler
pass reports to choose the next common-shard candidate on this host. Do not use repeated emulator timing runs to claim
a small phone speedup.

One primary question and one heavy build at a time. Before consuming significant
compute, write: affected workload, exact artifact, competing explanations,
maximum plausible gain, smallest discriminating test and stop condition. Use
roughly 10 minutes to select evidence, 40 to investigate/measure and 10 to review
and record; a genuinely running build may outlast that block with a checkpoint.
After two non-informative experiments, change the discriminator or record the
missing prerequisite. Do not fill the time with passing tests or more status prose.

Every change gets three different checks: source/lifecycle review, a meaningful
behavior/equivalence regression, and the relevant package/platform/measurement
check. Record a red/green comparison when a bug can be reproduced. Each result
must update the JSON card and this board together with exact source/artifact,
measurement, limits and the next decision. No new automation or model-routing
change is implied by this plan.

Judge progress by measured CPU/frame and tail reduction, build seconds saved,
confirmed playable/rendering outcomes, accepted recovery paths, and complete
release gates. PR count, log volume, successful builds and closed-issue counts
are supporting activity, not the objective.

## Historical maintenance snapshots

The sections below preserve dated evidence. Their old priority numbers, open
counts, versions and next actions are superseded by the current section and JSON.


## 5 October work snapshot

The [current goal loop](CURRENT-LOOP.md) sets the order of work for 0.7.11 and
0.8.0. [STATUS.md](STATUS.md) and [KNOWN-ISSUES.md](KNOWN-ISSUES.md) are kept
current with each release. Everything below on this board is a dated snapshot:
useful evidence, not current next actions.

## 1 October focused execution

The [67-issue review](FOCUSED-REVIEW-2026-10-01.md) and
[active goal loop](FOCUSED-LOOP-2026-10-01.md) supersede the next actions in the
dated snapshots below. Baseline is main `978a9f1c`, published KartPad 0.7.3 and
PadMint 0.2.8. Engineering is progressing locally; no generic reporter retest
or diagnostic request is needed for this pass.

- #347 was closed as completed: its interface fingerprint shipped in 0.7.0
  with recorded race/cache/mismatch gates. A compatible pack still needs the
  existing app-state check.
- #196's reporter confirms both modes now launch; retain Retro warmup and online
  searching separately from the original startup crash. #235's Honor X7c reaches
  races; #235 was closed, with remaining performance tracked in #313.
- #216's Tab A9+ reporter confirms both Original and Retro launch. Missing bodies,
  lag and the older Tab A report remain separate. #102's Fold reporter confirms
  the manual all-draw workaround; this does not prove every Automatic selection.
- #327's latest iPhone16 result is launch-only flicker, with other gameplay working.
  #370 stays open with a live but black M2 iPad surface after the safety screen.
- #304's previous PowerVR candidate was absent from 0.7.3 and raised a 14-variable
  device back to 16. The [corrected dependency and actual empty APK](artifacts/2026-10-01/powervr-device-limits.md)
  pass native limit/shader and content/state checks. The release-style empty app
  plays a race segment on an owned emulator. The hosted archive and normal
  consumer with an empty Dawn cache pass exact hash checks; handset acceptance
  remains open.
- RVZ extraction is verified locally against the matching ISO: all 2,043 file
  hashes match; wrong region/revision are rejected. This is extraction/folder
  evidence, not new picker, race or all-platform player-build acceptance.

Scoped intake update: 22 September 2026; 63 open issues. The older family and release snapshots below retain their dates. Start at the
[support-agent hub](SUPPORT-AGENTS.md). The [priority source](maintenance-priorities.json)
owns ordering, readiness, exact next actions and acceptance; this board records
support decisions and evidence. Refresh GitHub and local ownership before acting.
The [device matrix](COMPATIBILITY-MATRIX.md) preserves target-specific observations.

## 23 September Android optimization loop

[Private candidate comparisons](artifacts/2026-09-23/android-candidate-comparison.md)
now include repeated stationary Cookie Land battles and a matching Mailbox/FIFO
reversal. Displayed cadence and guest CPU are measured separately. The supplied
Reddit reports are classified in the [loop ledger](artifacts/2026-09-23/android-optimization-loop.md),
including sustained slowdown, resolution-change freeze and input/handheld requests.
None is closed from this Pixel-only evidence. CPU-affinity and cache-size
experiments without reliable gains are removed, as are unproven scalar fast paths
and helper calling-convention changes. Private build 195 retains guarded FIFO and
bounded diagnostics. Exact-artifact Original/Retro offline and bounded lifecycle
checks completed; significant pipeline-related hitches remain. The
[morning report](artifacts/2026-09-23/android-morning-report.md) records the
installed artifact and acceptance limits. No new public build was published.

## 21 September evening loop

[All 63 open issues](artifacts/2026-09-21/open-issue-inventory.md) have a new
issue-specific reply with a retained URL. No issues were automatically closed.
[The active evening goal](artifacts/2026-09-21/evening-goal-loop.md) continues
engineering after intake rather than waiting for another generic log collection.

- Build60 has reported A10X/iPad improvements (#135/#310), with remaining stalls
  and #310 online-transition crash. #196 supplied a build60 missing-guest-target
  stack; diagnostic-off is not its fix.
- Honor X7c #235 now reaches races in the same reporter's #313; 15 FPS performance
  remains. #295 Original export works; Retro transfer is the remaining feature.
- Android RVZ descriptor import passes the full Pixel system-picker import: all
  2,043 extracted file hashes match, and both saves/five preferences are unchanged.
  Normal private code167 subsequently launches Original and Retro, with a short
  Original acceleration/pause/quit check. Not yet published; other providers/devices
  and full player-driven acceptance remain separate.
- A link-only control reproduces released code135 BuildID. Function-only local
  binding removes 10,873 internal jump slots while preserving dynamic exports
  and API28. This is artifact evidence, not an FPS improvement yet.

- #216 A9+ now installs code135 after a fresh download and loads Original;
  missing character bodies and lag remain. Retro is untested, and the older Tab A
  is a separate unresolved case. #316's screenshot confirms displaced geometry.
- [PR315](https://github.com/chrissotraidis/kartpad/pull/315) retains local binding,
  background cache persistence, snapshot/CP-summary and inactive-key reductions,
  and one ARAM TLS lookup per voice. Targeted work removal is verified; whole-frame
  gains remain within run variation. API29 TLS stays opt-in, API28 is default.

## 20 September post-release priorities

[Current issue and enhancement audit](artifacts/2026-09-20/post-release-issues-and-enhancements.md)
supersedes the dated pre-release build/distribution instructions below.
v0.5.0 is public. The new S24/code135 result in #104 still fails character
rendering; #198 reports waiting, not improved performance. #302's pin correction
is shipped and its release follow-up was missed.

Explicit smaller follow-ups: Android shake-to-trick parity (Apple has it),
Retro ghost transfer (#295; Original export is now reporter-confirmed), and separate Mac Classic/Android ipega input
paths. Auto-accelerate, shared D-pad/trigger mappings, the L1 item preset and
combined release assets are already implemented. Larger NAND/identity, USA,
cheat, DSU, external-display and older-OS requests remain explicitly scoped in
the audit rather than hidden inside broad threads. No new binary is produced by
this review and no reporter acceptance is inferred from source checks.

## Historical: 19 September intake decisions

The [latest evidence review](artifacts/2026-09-19/recent-issues-and-build-evidence.md) and [37-thread inventory](artifacts/2026-09-19/github-review-inventory.md) supersede older generic waiting states for the specific subcases below. Other historical rows are not newly validated. Additional build distribution is on hold; no new reporter capture is needed for these three decisions.

| Priority / card | Evidence and next owner action |
|---|---|
| 1 / `android-vulkan-loader` | #303 adds a Redmi Note 11/code119 missing-debug-utils failure to #301 and the newer Tab A9+ #216 subcase. Internal backport exists in code123/124; affected-driver acceptance is open. Engineering owns internal validation and graceful failure handling. [Reply](https://github.com/chrissotraidis/kartpad/issues/303#issuecomment-5737578364). |
| 1 / `android-powervr-capability` | #304 Moto G54/code121 rejects the PowerVR inter-stage shader limit, then aborts. Exact symbols match. Current candidates do not fix it. Engineering owns review of the upstream instance toggle, honest device/pipeline limits and shader requirements, plus graceful rejection. [Reply](https://github.com/chrissotraidis/kartpad/issues/304#issuecomment-5737578636). |
| 2 / `retro-wfc-payload-pin` | #302 reproduces a 28,992-byte signed payload against a 28,968-byte pin. Engineering owns executable/translation review and clean self-build before pin promotion. [Reply](https://github.com/chrissotraidis/kartpad/issues/302#issuecomment-5737579079). |

#275's new thanks/waiting reply is recorded without another prompt. Existing negative geometry results and CPU-heavy captures remain unresolved; no new device acceptance was supplied. See the dated review for every recent thread's disposition and the limits of the new upstream lead.

## Owner Android acceptance failed (19 September)

Pixel 9 Pro XL/code125 crashed with an exact-symbol native allocation failure
in a background shader compiler. The owner also reports slowdowns and a pause.
[Crash, timing, memory and regression comparison](artifacts/2026-09-19/pixel-code125-memory-crash.md)
now take precedence over further candidate distribution. Existing owner gameplay
is monitored without interruption; iOS gameplay remains untested.

[Code126 correction](artifacts/2026-09-19/pixel-regression-correction.md) is built and
audited: stable Dawn identity, bounded speculative replay and demand-work wakeups.
Owner session completion and cold/warm physical acceptance remain pending.

## Current engineering sequence (19 September)

Local cross-platform stabilization is recorded in the
[build review](artifacts/2026-09-19/cross-platform-stabilization.md).
The old assignments below are historical; this sequence supersedes their
build requests. No further reporter builds or repeat-log requests are planned.

1. Finish local package/source checks for the conservative candidate: verified
   Retro-WFC payload, shared timer/renderer corrections and Android loader fix.
   The payload repair includes a measured 4102-function profile gate.
2. Complete owner gameplay acceptance. The iPhone 14/build52 and Pixel 9 Pro XL/code125
   are installed in place; [signing, state preservation and launcher evidence](artifacts/2026-09-19/owner-phone-deployment.md)
   are recorded. Original/Retro races, relaunch and warmed performance remain open.
   These phones do not close #301/#216/#303 or any geometry report.
3. Investigate PowerVR #304 as a separate adapter/device/pipeline capability
   contract, including graceful failure. Neither code125 nor the depth lab
   claims to support this device.
4. Continue batch ownership/refactoring for #137, actual-draw reproduction for
   #102/#104/#166, and CPU attribution for #198/#275/#135. Avoid a broad rewrite
   or speculative performance claims.
5. Review upstream Kamek continuation follow-up `8e0cc968` separately; migration
   to source did not automatically import it. Preserve the current candidate
   while testing any translator change against old/new generated graphs.

## Earlier family snapshot (13 September)


Counts below are distinct non-maintainer issue authors at this snapshot, excluding
comment-only corroboration. Closed duplicates #209/#210/#224–232 collapse historically
under #208, #237 under #236, and #233 under #211. Families
overlap, so these numbers cannot be summed into total affected users. The selector
refreshes counts in its generated local context, not by automatically promoting
popular reports. Historical work and old requests remain in the
[previous board](https://github.com/chrissotraidis/kartpad/blob/2028ab3/docs/MAINTENANCE-BOARD.md);
the next actions below supersede those dated assignments.

| Priority / card | Issues / authors | Current decision and next actor |
| --- | --- | --- |
| 0 / `retro-save-loss` | #169 / 1 | `source-corrected-awaiting-reporter`: Android pack activation now preserves both Retro WFC save branches; see source finding and fixture (local record unavailable in this checkout) and the [public update](https://github.com/chrissotraidis/kartpad/issues/169#issuecomment-5644596717). The original build-21 report still needs its exact exit-versus-pack-replacement boundary and current-candidate data-preserving acceptance. Do not deliberately lose more data. |
| 1 / `android-exits` | #143, #200, #205, #208, #235–236, #128, #131, #207, #215, #216 / 11 open cases | `awaiting-reporter`: one matching exit classification per distinct launch/cup/race subcase. Closed #209/#210/#224–232 remain historical duplicates under #208; #236 is canonical for closed #237. #235 and #236 remain separate Honor X7c and OPPO CPH2669 device subcases. Similar wording does not establish a common runtime defect. |
| 1 / `ios27-startup` | #196 / 1 | `released-awaiting-device`: public v0.4.17-ios.1 (retired) is the corrected unsigned IPA, SHA-256 `d322484192dde92139ed8aac66c9abd7764b91f97895840995ef17f0ff49f9ff`. Anonymous audit and owner iPhone 14 / iOS 26.6.2 in-place data preservation passed. The matching iPhone 17 Pro Max/iOS 27 Original+Retro launch/race/relaunch gate remains open; see [platform handoff](artifacts/2026-09-13/platform-candidate-handoff.md). |
| 2 / `android-online` | #206 / 1 | `awaiting-reporter`: await #206's already requested Wi-Fi endurance confirmation beyond the prior four/five-race window. #123 is closed upstream and remains historical evidence only; closure is not technical online acceptance. |
| 3 / `adreno-geometry` | #102, #104, #120, #137, #166, #193, #211 / 7 | `awaiting-owner`: release operator and affected-device tester establish compatible signing/delivery for the retained dynamic/literal/dynamic character-draw comparison. Closed #233 is preserved as an SM-S928B/Retro subcase under #211, not a separate active case. The host has no release keystore; see Android signing preflight (local record unavailable in this checkout). No GPU-wide cause or correction is established. |
| 4 / `warmed-performance` | #198, #167, #103, #169, #195, #204, #207, #135 / 8 | `awaiting-owner`: #198 tester is willing. The prepared profiler needs compatible signing or an approved data-preserving route **and** private delivery before capture. The host has only a debug keystore; see Android signing preflight (local record unavailable in this checkout). Retained Debug-signed APK is not a public-app in-place upgrade. |

## Release-candidate sequence

The current delivery order is: (1) revalidate and hand off the clean #196
iOS candidate for compatible signing and matching iPhone 17 Pro Max/iOS 27
acceptance; (2) prepare merged PR #219 for a signer-compatible Thor/Odin test;
(3) prepare merged PR #157 for the same-scene two-player Mac comparison. See
the reconciliation artifact (local record unavailable in this checkout).
PR #112 remains a separate conflicting integration lane. The older preparation
sentence is superseded by the code80 handoff below; package publication does not
claim a verified affected-device gameplay fix.

The sequence has advanced: the iOS, macOS, and Android packages are now public,
while affected gameplay gates remain open. Android `v0.4.17-android.1` / code80
was published after code79 physical Retro race/touch acceptance and code80
anonymous/package audits. Code80 was not physically installed before the test
phone disconnected, so this is a release/package fact, not code80 device or
online/results acceptance. Exact hashes, source and boundaries are recorded in
the [platform handoff](artifacts/2026-09-13/platform-candidate-handoff.md).

## Active owned investigation

`#248` / draft `252` remains owned by the existing investigator. Fresh 622-test
coverage and generated-graph checks pass, but generated-module growth is 41.3%
and the exact `0x807EF16C` crash is still unproven. Do not merge, broadly bump
the upstream pin, or spawn a competing worker. The next decision is whether the
growth gate can be reduced or the crash can be attributed; native compilation
and actual Item Change/Item Rain acceptance remain subsequent gates.

These are checkpoints, not verified fixes. Finish available preparation before
parking work. If one of these owner actions becomes locally executable, update
that card to `ready-local`; an owner label alone is not a permanent external block.
If all remain blocked, choose genuinely ready known work below and add a bounded
card rather than repeating passing tests or an unanswered request.

## Evidence and outstanding requests

Use the [hub's request fields](SUPPORT-AGENTS.md#send-a-concrete-build-test-handoff)
when creating/updating a handoff. A request is not evidence that a test started.

| Request / evidence | Disposition and next gate |
| --- | --- |
| [#196 published build audit](https://github.com/chrissotraidis/kartpad/issues/196#issuecomment-5642179928), corrected simulator runtime (local record unavailable in this checkout) and [build-integrity correction](artifacts/2026-09-12/issue196-rel-report-build-integrity.md) | Public v0.4.16-ios.2/build 36 still contains the reported aggregate-shard load. The new clean `0.4.16/build38.96.2` candidate now passes the isolated simulator lifecycle for Original and Retro 6.12.8 with data preserved and no translated crash markers. Regenerate a signed candidate; matching iOS 27 hardware acceptance remains unperformed. |
| [#123 closed upstream](https://github.com/chrissotraidis/kartpad/issues/123) and [last maintainer response](https://github.com/chrissotraidis/kartpad/issues/123#issuecomment-5644306282) | GitHub records `CLOSED` / `COMPLETED` at 2026-09-12T07:41:52Z. The final comment separates a music workaround for menu lag from reported online-race frame drops. This is a support-state reconciliation, not a technical fix or race/results/reconnect acceptance; do not assign more #123 work unless it is reopened with new evidence. |
| [#206 cellular/Wi-Fi comparison](https://github.com/chrissotraidis/kartpad/issues/206#issuecomment-5642749400) | `awaiting-reporter`: [acknowledgement posted](https://github.com/chrissotraidis/kartpad/issues/206#issuecomment-5642834780). On Samsung SM-S921W / Android 14 / build 65, mobile data worked once while Wi-Fi reportedly works normally. This is sufficient to isolate a network-dependent subcase; it does not prove a NAT, carrier or guest-runtime cause. Keep it separate from #123. Await the already requested confirmation that Wi-Fi passes beyond the prior four/five-race window before claiming a stable workaround; do not repeat the acknowledgement, known build/device questions or generic log request. |
| [#211 / closed #233 renderer evidence](https://github.com/chrissotraidis/kartpad/issues/211#issuecomment-5649620538) | `needs-one-detail`: Galaxy S24 family character corruption remains in the renderer lane. Closed #233 is retained as the SM-S928B/build-65/Retro subcase under #211; do not count it separately or infer a GPU-wide cause. |
| [#166 additional device request](https://github.com/chrissotraidis/kartpad/issues/166#issuecomment-5628217442) | `requested`: exact device/build/profile and available renderer lines for the added report. Existing synthetic checks do not clear the failing gameplay draw. No duplicate probe/request. |
| [#198 willingness](https://github.com/chrissotraidis/kartpad/issues/198#issuecomment-5640922655) | `preparing`: existing warmed evidence justifies a bounded function profile. Signer compatibility/data preservation and private delivery are maintainer dependencies. Do not re-ask willingness, attach the APK publicly or represent installation/testing as started. |
| [#167 completed comparison](https://github.com/chrissotraidis/kartpad/issues/167#issuecomment-5608282606) | Supplied Infinix Hot 60 Pro / Android 16 / KartPad 0.4.11 / Original details and unchanged 1x aspect comparison are sufficient to stop that settings sweep. A selected warmed profile is a different decision; don't ask for the same device/build again. |
| [#215 launch/exit evidence](https://github.com/chrissotraidis/kartpad/issues/215#issuecomment-5648868060) | `awaiting-reporter`: Xiaomi 25057RN09G / Android 15/API 35 / build 65 now has the Android-home boundary for both Original and Retro. Await one short redacted exit result if available; no reinstall, data clear, ROM or save is requested. |
| [#216 black-surface/exit reply](https://github.com/chrissotraidis/kartpad/issues/216#issuecomment-5643186097) | `awaiting-reporter`: Galaxy Tab A (8.4-inch, 2020), One UI 3.1, Android 11/API 30, reported 0.4.16 Android; exact build unconfirmed. Both Original and Retro show a black game surface with touch controls, then exit. Reply is posted; await only chooser-versus-Android-home destination, selected profile/import completion and one short redacted exit result. Keep separate from #215 and renderer hypotheses. |
| [#208 canonical launch report](https://github.com/chrissotraidis/kartpad/issues/208) | `requested`: chooser versus Android home, profile/import state and matching exit result. Closed #209/#210 and #224–232 remain linked historical reposts and do not justify new requests or separate engineering assignments. |
| [#234 save/identity transfer](https://github.com/chrissotraidis/kartpad/issues/234#issuecomment-5647599209) | `awaiting-reporter`: Galaxy S25 Ultra / build 65 reports missing Mii/name/rating and a changed console identity after restoration from a Wheel Witch save backup on the same phone. Classified as a same-device backup-restoration subcase under save/rating lifecycle. No private save or serial is requested. |
| [#235 Honor X7c launch evidence](https://github.com/chrissotraidis/kartpad/issues/235#issuecomment-5649459291) | `awaiting-reporter`: Honor X7c / Original 1.0 WBFS reaches a black screen with interactive controls, then returns to Android home after about 3–5 seconds. This is now a classified native launch/render exit boundary, separate from other devices; no WBFS, reinstall or data clear is needed. |
| [#236 OPPO A40 launch evidence](https://github.com/chrissotraidis/kartpad/issues/236#issuecomment-5648868168) | `awaiting-reporter`: OPPO CPH2669 / Android 14 / build 65 confirms a repeatable Original/base black screen followed by Android home, with corroborating #237 now closed as a duplicate. Await one matching redacted exit result if available; no reinstall or data clear. |
| [#215 Android-home confirmation](https://github.com/chrissotraidis/kartpad/issues/215#issuecomment-5648868060) | `awaiting-reporter`: Xiaomi 25057RN09G / Android 15 / build 65 now has the decisive return boundary: Android home after the black screen for both Original and Retro. This is actionable native/OS-exit evidence; no release is promised before reproduction and compatible-device testing. |
| [#236 Android-home confirmation](https://github.com/chrissotraidis/kartpad/issues/236#issuecomment-5648868168) | `awaiting-reporter`: OPPO CPH2669 / Android 14 / build 65 now has the decisive return boundary: Android home after the Original black screen. This remains a separate device case. |
| Closed duplicate cleanup (local record unavailable in this checkout) | `reconciled`: #209/#210/#224–232 are closed under #208; #237 is closed under #236; #233 is closed under #211. Originals retain the evidence and remain the only active memberships. |

For #215/#216, use the existing requests; do not ask for another reinstall, data
clear, ROM or save. The reports establish repeated symptoms, not a classified
OS exit or a common runtime defect.

Private artifact identities, symbols and handoff process references remain in the
ignored local maintenance checkpoint. Before delivering or installing, recheck the
actual retained file, source, signer and authorization; old prose is not provenance.

## Other issue families

These reports remain tracked even when outside the six leading work cards. Read
current comments and the linked source scope before promoting one into active work.

| Family | Reports / bounded next decision |
| --- | --- |
| Retro installation/version | #192 download/import and #194 updater design. Verify current app/official pack and last completed step; separate executable compatibility from a request for automatic updates. |
| Input/system UI | #119 bars, #184 mapping, #197 controller/touch handoff, #202 aspect/display. #197 now has in-game menu and ipega/touch evidence; next is a fresh touch-only offline menu after close/relaunch, then controller reconnect. Match physical/touch and chooser/gameplay paths; no renderer patch for an unclassified button/inset report. #184 has a bounded feature scope in [future features](FUTURE-FEATURES.md#android-d-pad-and-shoulder-remapping). |
| D-pad support question | [#238 corrected answer](https://github.com/chrissotraidis/kartpad/issues/238#issuecomment-5649620435) asks how to enable Android D-pad. The release-source path is **Move controls → select the dim D-pad → Show → Back/Done**; no engineering defect or diagnostic request is established. |
| External display | #100 and #199. Match local-only, wired and AirPlay transitions/recovery separately. Existing Metal/source checks are not affected-display acceptance. |
| Apple controls/projection/multiplayer | #5, #91, #101, #127; PR #157 is merged and needs a clean Mac candidate/same-scene two-player comparison. PR #112 remains open/conflicting and requires a separate bounded integration/test; do not block #157 on it. |
| Apple performance | #135. A10X startup is already accepted; remaining frame-rate concern needs its own affected-device comparison, separate from Android CPU/GPU hypotheses. |
| Save/rating lifecycle | #105 manual transfer is accepted; automatic two-way sync and Mii scope remain distinct. #169 lost progress must be classified separately from performance and system bars. |
| Feature/compatibility | #90 Original Wiimmfi, #91 controller/DSU, #203 disc revision/NAND/cheats. Define requested behavior, supported input and implementation boundary; do not request generic logs for missing features. |
| Governance | #92 remains an upstream review dependency; do not create recurring runtime work from it. |

## Preserve accepted subscopes

- [#188](https://github.com/chrissotraidis/kartpad/issues/188#issuecomment-5633416311)
  is closed after reporter-confirmed Mii import on v0.4.16-android.1 / AYN Thor in
  Original and Retro. It is not waiting for another initial import request.
- [#135](https://github.com/chrissotraidis/kartpad/issues/135#issuecomment-5599088464)
  confirms the A10X startup correction; roughly 30–35 FPS remains a separate concern.
- [#105](https://github.com/chrissotraidis/kartpad/issues/105#issuecomment-5597997983)
  confirms manual save/rating transfer. Automatic synchronization is not implemented.

For every update, distinguish source corrected, candidate, host/simulator,
physical/reporter acceptance and release. Commit reviewed public queue changes
in the maintenance loop; no status-page edit establishes that a build is stable.
