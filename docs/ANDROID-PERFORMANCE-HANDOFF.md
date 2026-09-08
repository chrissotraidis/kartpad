# Android performance and geometry investigation

Prepared from a live audit of all 20 open issues, release listings, current main,
retained candidate records and the connected phone on 9 September 2026 (Japan
time). Use this document as the prompt for one lead engineering agent. Refresh
its snapshot before acting; it does not establish a performance fix.

## Assignment

Work in `/Users/chrissotraidis/GitHub/kartpad`. Identify and validate the one or
two changes most likely to improve actual Android gameplay: sustained frame
rate/frame pacing and corrupted character geometry. Preserve working builds,
game correctness and all user data. Do not spread the investigation across
unrelated features or generate speculative optimization patches.

You own the chain from existing report and reproduction through measurement,
correction, regression checks, candidate APK and a physical test handoff. Use
the model/reasoning setting selected for this task. An optional bounded reviewer
can challenge the diagnosis and patch; do not start another fleet of independent
investigators or builds. Coordinate ownership with existing tasks before taking
over their work or the physical phone. Support replies stay with the existing
coordinator; this assignment does not authorize independent public messages.

## Read and reconcile first

- [Known issues](KNOWN-ISSUES.md): all open reports, including new evidence for
  #105 and #135. Do not repeat questions already answered.
- [Maintenance board](MAINTENANCE-BOARD.md), [workflow](MAINTENANCE.md) and local
  `build/maintenance/CURRENT.md`: current owners and candidate locations. Local
  records can lag behind GitHub; #105's offline transfer succeeded.
- [Physical CPU profile](artifacts/2026-09-08/pixel-hardware-cpu-profile.md) and
  [owner follow-up](artifacts/2026-09-08/pixel-owner-slowdown-followup.md).
- [Scalar-context review](artifacts/2026-09-09/maintenance-source-reviews.md),
  [online timing](artifacts/2026-09-09/pixel-online-log-review.md),
  [alarm correction](artifacts/2026-09-09/issue-123-alarm-reschedule-guard.md) and
  [local preview2 build](artifacts/2026-09-09/android-preview2-local-candidate.md).
- [Actual-draw evidence limits](artifacts/2026-09-09/graphics-preview28-evidence.md),
  [renderer investigation](artifacts/2026-09-08/android-renderer-investigation.md)
  and the actual attachments/replies in #102/#104/#120/#137.
- [Android build guide](../android/README.md), [installation](INSTALL_ANDROID.md)
  and [physical handoff](ANDROID-PHYSICAL-HANDOFF.md). Historical instructions
  are evidence for their named builds, not current installation commands.

Refresh all open issues and PR heads, non-draft releases, `origin/main`, active
tasks/worktrees/builds and the installed package. Compare exact source and
native-library identities. Confirm no newer relevant build already contains a
proposed correction before duplicating it. Start an isolated `codex/` worktree
from the appropriate current source; preserve the root checkout and other work.

## Version snapshot: these are different builds

| Build | Verified disposition at audit |
| --- | --- |
| Public Android `v0.4.13-android-preview.1`, code 28, source `cecd69c504f66aa0d8a40f485406618b9b616791` | Latest public Android game preview. Contains conditional scalar exception-clear work, diagnostics and offline rating restore. No verified sustained-FPS or geometry fix. |
| Local Android preview2/code29, source `fdda4c1` | Includes PR #141's alarm correction. APK SHA-256 `9e7b7a0942714c7a3c9d75397e71763dc16765b9b1ada0ed8ca3e6a57dcb81ac`. Build/lint/package and bounded emulator checks passed. Not published or physically accepted. Excludes the scalar-context experiment. |
| Connected owner Pixel 9 Pro XL, API 37 | Read-only package-manager check found `0.4.13-local.a850ada`, code25. Installed package and local preview2 both verify, but their signing certificates differ. The existing preview2 APK cannot update this installation in place as-is. |
| Scalar-context experiment `a396eda`, retained branch tip `e7cdf6a` | Reviewed source experiment, not in public preview1 or local preview2. 2704 differential cases passed. One scalar-multiply helper reuses its validated CPU context; no matched game-FPS result. |
| `v0.4.13-ios.1`, build29 | Published iPhone/iPad preview. Its higher/newer listing is not an Android update or an Android performance fix. |

No later public Android preview was listed at audit. Recheck before choosing
versions, signers or an artifact. Retain exact baseline APK/native symbols and
current state so comparisons do not depend on unsafe version downgrades.

## Priorities and evidence

### 1. Sustained CPU cost: strongest current FPS lead, impact unproven

#103 includes a Retroid Pocket 5 report of 40–45 FPS at 1x in standard power mode,
with validation already off, mainly Original. The owner's Pixel also has slow
gameplay after pipeline queues reach zero. Neither report is explained merely
by enabling validation or waiting for first-use shaders.

Historical Pixel profiles identify scalar FP exception capture/clear, emulated
TLS/current-context lookups and resource hashing. One profile attributed 67.96%
of sampled CPU work to SDLThread; a later sample had XXH3 accumulation at 5.17%
self cost, clear-helper 3.49% and capture-helper 3.15%. These are historical
on-CPU samples, not frame-time shares. The later session was thermally severe;
do not turn those numbers into an FPS prediction or add overlapping stack costs.

Refresh a symbolized profile of the exact current baseline in a warmed, actual
race. Attribute hot stacks to source and time spent executing versus waiting.
Rank the largest avoidable costs by current contribution, likely affected users,
correctness risk and ease of proving the change. Use the existing scalar-context
experiment as a ready controlled comparison, not a predetermined answer. Its
7–8% multiply microbenchmark improvement is not 7–8% more game FPS. Conditional
exception clearing already shipped: do not reimplement it as a new fix.

If context/fenv work still dominates, investigate semantically safe reuse or
reduced redundant work at proven boundaries. If hashing dominates, identify
which resources are repeatedly hashed and establish ownership/mutation rules
before changing cache invalidation. If another measured stack is larger,
follow that evidence. Do not expand a tiny helper optimization into broad CPU
rewrites without demonstrating material headroom.

### 2. Actual character draws: strongest current geometry lead

#102 and #104 reproduce corruption even at 1x/4:3. The Fold supplied a near-60-FPS
interval with corrupted graphics and zero queued pipelines; improving speed
alone will not necessarily fix geometry. #104 affects drivers in selection and
the starting grid while vehicles/tracks remain recognizable. Keep #102's road
textures, OnePlus #120, exact preview1 #137 and macOS #127 distinct unless a
shared failing mechanism is demonstrated.

Affected Adreno devices pass synthetic probes, and actual-game validation
off/on did not correct #102/#104. Do not repeat generic probes, reimports or
settings sweeps. Inspect supplied screenshots/clips and actual game data flow:
character vertex/index decoding, matrix palette selection, generated shader
layout, uniforms and buffer lifetime through queued submission. Use existing
draw samples first. They only cover bounded/direct matrix-index cases; clean
samples do not prove that finite transforms, vertex inputs or resource lifetime
are correct. If an existing capture lacks the decisive information, isolate
one failing character draw and capture/replay it locally with a precise
expected invariant. Any additional instrumentation must answer that question.

A Pixel/Mali pass is useful regression coverage but cannot certify an Adreno
fix. A renderer correction needs a failing reproduction or demonstrated
invariant violation, then corrected output and ultimately affected-Adreno
confirmation. Do not integrate a custom-driver system as a speculative fix.

### Ready comparison: online alarm correction

Before commissioning another full candidate, evaluate whether the retained
preview2 native payload can supply a safe same-device comparison for #123.
The reproduced source defect can block completion processing across a guest
reschedule; its correction has passed the targeted regression. It is not yet
the established cause of the reporter's 2.222-second freeze. The recorded
receive waits occurred outside that gap, and the supplied capture was thermally
normal. Do not conflate it with the owner's heated offline session.

Test baseline versus this correction in the same Retro online-menu path and
offline control scene. If freezing remains, capture the blocked stack and
producer/completion/wakeup boundary during the gap, rather than adding more
synthetic scheduler cases. Preserve guest wakeup, callback, timing and identity
semantics. This is a bounded ready experiment, not permission for an unlimited
networking rewrite that displaces the sustained-FPS and geometry priorities.

Cup-ending crashes #128/#131 and launch crash #143 remain important separate
reports. Promote one into this pass if new evidence identifies a common cause
or the candidate regresses it. Do not claim they are fixed by an unrelated
performance change. Leave UI redesign, DSU, Wiimmfi and Mac controller work
with their current owners.

## Measurement and correctness contract

Choose a repeatable actual-game baseline: exact source/native symbols, build,
phone, game/profile, scene, camera/input, resolution/aspect/FPS cap, validation
state, normal power profile, charging state and comparable thermal range. Use
1x/4:3/validation off as a controlled performance scenario while separately
checking the owner's retained settings. Keep cold pipeline warm-up separate
from warmed gameplay; do not erase useful caches or data to simulate a cold run.

Measure frame-time p50/p95/p99, worst gaps, stalls above 100 ms, effective FPS,
pipeline activity, main/worker execution and wait time, and thermal trend from
matching windows. Existing phase logs are not GPU execution timings. Use a
GPU-specific timing method if GPU attribution is required. Compare at least
three comparable baseline/candidate runs when practical, including sustained
warm play. Alternate order only through safe monotonically versioned builds
or a bounded reversible test mechanism; never downgrade or uninstall to run A/B.
Reduce profiler overhead for the final comparison. Define success against
baseline variability before judging the candidate. Report negative results.

Change one variable at a time; combine at most the one or two supported changes
after separate comparisons. Preserve IEEE/PPC FPSCR/NI/rounding/exception and
destination-write behavior, scheduler/context ownership, saves and identity.
No broad fast-math, forced CPU frequencies, thermal-limit changes, hidden lower
quality defaults, or removal of correctness checks to inflate FPS. Edit the
reproducible patch/source chain, not just ignored generated runtime files.

Run relevant existing semantic/differential/sanitizer tests, a regression that
fails on the defective baseline where applicable, fresh Android preparation,
native build, lint and package/signature/alignment/privacy checks. Inspect
generated source and linked code to prove the tested change reached the APK.
Check Original and available Retro startup, basic gameplay, audio, controls,
save persistence and Home/resume. For shared changes, validate affected Apple
preparation/build paths; keep Android-only experiments isolated when possible.
Do not weaken checks or claim compilation establishes gameplay stability.

## Candidate and physical installation authorization

This task authorizes preparing a local Android preview and updating the owner's
connected physical Android phone in place when a justified candidate passes
the relevant checks. A defensible hypothesis may need that physical comparison
before its gameplay benefit is known: label the candidate accordingly. Do not
wait for guaranteed improvement before performing the experiment, and do not
publish it as a proven fix. Public release is separate from this local handoff.

Recheck the intended phone and installed package before mutation. Preserve a
fresh backup of saves, ratings, identities, settings, touch layout and relevant
app state using the established private backup/export path. Keep the original
game inputs and Retro installation. Do not interrupt active play without a
checkpoint. Build or derive the hardware APK with the installed signing identity
and verify its certificate, package ID, native payload, hash and increasing
version code. A differently signed public APK is not a reason to uninstall.
If the matching identity or a safe backup path is unavailable, finish the
candidate and state the exact blocker; do not improvise destructive migration.

Use the guarded installer only after reading its current contract. Supply the
exact APK and explicit expected version name/code/SHA-256 and update flag;
historical defaults target preview3/code8. Installation must use update-in-place,
without uninstall, clear-data or downgrade. Verify installed version and
before/after state, then launch the chooser and confirm retained profiles/saves.
Do not report successful installation without observing it.

Actual game process is `dev.kartpad.android`; chooser is `:launcher`. A search
for an assumed `:game` process previously produced false inactivity claims.
Verify the actual process/session before profiling. Keep raw logs, screenshots,
game captures, identities, saves and signing material private; publish only
sanitized evidence. If device access needs a user action, finish independent
analysis/build work and ask only for that concrete action.

## Completion

Deliver the ranked bottlenecks with evidence and confidence; what was tried and
rejected; the exact one or two included changes; baseline/candidate measurements
and correctness results; source/version/hash/signer compatibility; actual device
installation status; and a short test for Christopher with a pass/fail question.
Update the existing issue/build records with the result. Distinguish local
improvement, affected-device confirmation and publication. If no safe useful
change is supported, give the strongest disproven hypotheses and the single
next discriminating experiment, rather than manufacturing a preview or saying
only that more logs are needed.
