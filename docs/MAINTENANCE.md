# Evidence-driven maintenance

The maintenance coordinator advances support reports toward verified fixes and
testable builds. Reply counts, new diagnostics, commits and elapsed hours alone
are not success measures. A run should reduce a specific uncertainty, complete
a useful implementation/test step, or identify the exact dependency that stops it.

## Coordinator and engineering roles

Astra Light owns triage, prioritization, public replies, work tracking and
coordination. Substantive debugging, implementation, code review, regression
testing and candidate build/validation are assigned to bounded Astra Medium
workers. Routine documentation and metadata updates can stay with the coordinator.
Use at most two temporary workers concurrently; reuse existing work owners and
collect their results. Workers do not spawn further workers or publish releases.
If Medium is unavailable, record the capacity blocker and continue useful light
triage; do not silently substitute Light for deep engineering or claim it finished.

The coordinator checks the evidence before integration and owns public communication.
A worker saying “done” is a review handoff, not automatic merge/release acceptance.

## Records and ownership

- [Maintenance board](MAINTENANCE-BOARD.md): canonical public work queue and
  build/test-request ledger. Keep current rows updated; link evidence for history.
- [Known issues](KNOWN-ISSUES.md): public issue/theme index, confirmed evidence,
  current limits and next evidence. Link source comments and investigation records.
- [Investigation records](artifacts/): dated reproduction, experiment, review and
  build results. Keep facts, hypotheses and untested claims distinct. Correct
  superseded conclusions explicitly instead of leaving contradictory summaries.
- [Documentation index](README.md): current guides and explicitly historical archives.
  Keep README ordering intact and put release details in versioned notes.
  Update STATUS/HANDOFF summaries in place; do not append full histories.
- [Support guide](SUPPORT.md): reporter-facing reproduction and diagnostic steps.
- [External displays](EXTERNAL-DISPLAYS.md) and [future features](FUTURE-FEATURES.md):
  accepted display work and separately scoped proposals.
- Local `build/maintenance/CURRENT.md`: compact active work board with one owner,
  source/branch, state, next action and completion condition per workstream.
  Local `build/maintenance/HANDOFF.md`: retained historical context and paths.
  Both are ignored supplements for machine-specific ownership/artifact paths.
  They do not replace the tracked maintenance board or public technical records.

Never commit raw private logs, saves, identities, credentials or game assets.
Summarize reviewed evidence publicly; retain private artifact references locally.
Do not duplicate a task, worktree, device session or build already owned elsewhere.
Recheck apparently stale claims against actual task/process state before reassigning.

## Each work cycle

1. Refresh issues, replies, PR commits/reviews/checks and existing work ownership.
   Reply where useful; do not repeat unanswered requests or demand information
   already supplied. New timestamps alone do not mean new actionable evidence.
2. Classify each change as new evidence, question, regression, feature proposal,
   completed implementation, or acceptance result. Update the corresponding
   issue/theme record. Correlate symptoms across devices without asserting a
   common cause until evidence supports it.
3. Review completed handoffs before starting more implementation. Integrate safe,
   validated changes through a reviewable PR; record any blocker and its owner.
   Do not keep stacking unreviewed local candidates indefinitely.
4. Select the highest-value unclaimed ready task, even if GitHub is quiet.
   Prefer data-loss/crash regressions, evidence-backed fixes and reproducible
   failures over speculative features. Scope one achievable unit: reproduce a
   failing operation, test a hypothesis, repair a confirmed bug, validate an
   integration, or prepare/audit a justified candidate. Coordinate isolated work
   before delegation. Avoid changing too many variables at once.
5. Validate the result and update the public technical record when warranted.
   Update the compact current board in place. Record what changed, evidence,
   source revision, affected platforms, next action, and owner/dependency.
6. Finish with one outcome: implemented/reviewed, hypothesis resolved, candidate
   ready for a named test, or blocked on a specific input. If blocked, look for
   other ready work before stopping. Do not manufacture commits or repeated
   status messages to satisfy a per-run quota.

## Experiments and diagnostics

Before an experiment, state the question, predicted distinguishing observations,
reproduction scene and comparison controls (build, device, settings, temperature,
profile). Record the result and whether it supports, rejects or leaves the
hypothesis unresolved. A log without an error can still show a defect.

Before adding instrumentation, specify which decision its output will enable,
how it will be exercised, and how overhead/private data are bounded. Use existing
samples first. Do not add another diagnostic layer merely because physical
acceptance is unavailable. Synthetic/emulator success is not hardware acceptance.

When a case stalls across runs, review the approach: smaller reproduction,
different discriminating test, independent review, or one precise missing input.
Do not rerun the same test or repeatedly nudge a reporter without a reason.

## Platforms and build completion

For a shared runtime change, explicitly record Android, macOS, iPhone/iPad and
tvOS impact as applicable, unaffected, or not yet evaluated. Each affected
platform needs its own build/test evidence; a passed Android test does not
establish Apple parity. Prioritize by evidence and impact rather than rotating
platforms mechanically or silently allowing one platform to disappear.

Track separate states: implemented, reviewed, merged, packaged, locally tested,
owner/device accepted, reporter confirmed, released. A local source fix is not a
publicly available fix. A candidate needs a concrete test purpose and exact
source/artifact identity, platform requirements, acceptance limits and test steps.
Batch compatible reviewed work where useful; do not build a new package on every
hourly check. The scheduled coordinator and its workers MUST NEVER upload or
publish an IPA, including a prerelease, release asset or distribution-feed update.
They may build and audit an IPA locally and ask Christopher to test it. Any later
IPA publication requires a separate explicitly authorized manual release task;
passing owner tests does not authorize the scheduled job to publish it.

When a candidate is ready, record its exact commit, version, hash, platform/device
requirements, included changes, completed tests and remaining risks in the board.
Ask the owner to test a local build with exact steps and a clear pass/fail question.
For community testing, use an available, verified artifact appropriate for the
reporter's device; do not link an inaccessible local path or announce an unbuilt
version. Record the issue/comment, requested comparison, request date, response
and next action. Never claim a build is “good” merely because it compiled.
Android/macOS test distribution may follow the existing authorized release
workflow after appropriate validation. The IPA prohibition remains absolute for
scheduled work. Do not create automated reminder spam for pending test requests.

## Progress accounting

The local current board should stay short; replace stale rows instead of appending
the entire history. Link dated evidence for detail. Quiet runs may record the
review cursor and unchanged dependencies without notifying the owner. Meaningful
updates should say what moved forward or what concrete owner action is needed.
After sustained work, summarize resolved issues, reviewed/merged changes, candidate
acceptance and remaining blockers—not just the number of replies or builds.
