# KartPad support-agent hub

Start here when responding to a player, choosing engineering work or requesting
a build test. The objective is stable gameplay and supported online play across
Android, iPhone, iPad and macOS. Track Original and Retro Rewind separately.
Every request must advance a specific decision toward an affected-player result.

**From 5 October** the [current goal loop](CURRENT-LOOP.md) sets the work
order. No hourly coordinator is running; `maintenance-priorities.json` is the
1 October queue and isn't updated. Current player-facing state is in
[STATUS.md](STATUS.md) and [KNOWN-ISSUES.md](KNOWN-ISSUES.md).

## Read these records

| Record | What it owns |
| --- | --- |
| [Living priorities](maintenance-priorities.json) | Ordered work, issue membership, readiness, next action, acceptance and external dependency. The coordinator updates this in the loop. |
| [Maintenance board](MAINTENANCE-BOARD.md) | Human-readable current decisions, evidence, request disposition and accepted subscopes. |
| [Device matrix](COMPATIBILITY-MATRIX.md) | Exact device/OS/GPU/build/profile/path observations and next gates. Unknown stays unknown. |
| [Player support guide](SUPPORT.md) | Player-facing instructions, report/export paths and data precautions. Check the exact build before giving UI instructions. |
| [Maintenance contract](MAINTENANCE.md) | Issue families, states, engineering and release acceptance. |
| [Coordinator runbook](MAINTENANCE-AUTOMATION.md) | Model routing, workers, process ownership and atomic reply receipts. |

The JSON owns ordering; do not maintain another editable priority list. A normal
selection prints every card and updates the ignored local
`build/maintenance/coordinator/PRIORITIES.md`. Read that full context after intake,
a useful result, priority edits or compaction. Dated audits explain earlier
evidence; they do not replace current issue comments or assign recurring work.

## Work each wake

The hourly heartbeat resumes the same coordinator task and its goal. Keep its
model set to secondary Luna Medium and verify the execution route at wakeup;
do not start another coordinator or discard an unfinished goal.

1. Check the existing coordinator claim, workers, worktrees and actual processes.
   Retain live owners. Read the hub and current priorities, then run the selector:

   ```sh
   python3 -B scripts/maintenance-loop.py --max-iterations 1 \
     --state-file build/maintenance/coordinator/loop-state.json
   ```

   All worktrees use the coordinator's shared absolute state paths from the
   scheduled prompt; the relative example assumes that checkout. `--preview`
   refreshes without writing state. Normal selection never executes product tests.
2. Fetch current open issues and comments, including edited older content.
   Delegate fresh intake while continuing owned engineering. No new evidence
   means no intake worker and no repeat support request.
3. Reconcile intake into the existing family, device row and request. Update
   priority only when the evidence changes the decision. Keep unrelated symptoms
   in one report as separate subcases.
4. Complete the selected action: discriminate a hypothesis, correct a demonstrated
   defect, finish a compatible candidate handoff or verify the affected path.
5. Record the result and reload priorities. Continue useful steps within this
   wake. If blocked, name the actual owner/action and advance ready work. If all
   cards are blocked, check existing board work once; do not invent another probe.
6. Persist reviewed queue changes as described below. Notify the owner only for
   a meaningful result, failure or concrete required action. A waiting queue is
   not product completion.

Coordination uses secondary Luna Medium. One separate intake worker may use
secondary Luna Medium, or secondary Sol Medium when Luna is not callable. One
secondary Astra Medium worker may investigate a bounded difficult engineering
question. The coordinator reviews/posts replies and alone edits priority/state
records. No primary Astra, nested delegation, duplicate investigation or parallel
heavy build/device session. If the requested intake model is unavailable, the
coordinator handles intake directly. See the runbook for execution-route checks.

## Respond to what the player actually supplied

Read the entire relevant conversation before replying. First state the useful
new observation and its implication. Answer the question directly; feature
requests usually need desired behavior and control mapping, not logs. Use the
player's language when possible and keep the response short.

Record device/model, OS, GPU/driver **only if supplied**, exact app build, profile
and pack version, settings, failure milestone, evidence and requested outcome.
The milestones are chooser, import, offline gameplay, renderer, online login,
lobby, race, results, reconnect, display and input. A report ID is a correlation
key, not an uploaded log. A chipset name is not a proven driver defect.

Before requesting anything, check the last request and everything supplied since
it. Use one canonical thread for actual duplicates (#209/#210 currently belong
under #208). Do not close duplicates automatically or collapse reports with
different devices, transitions or failure signatures into a single cause.

The selector fingerprints reporter content, including edits to old comments.
After reviewing a revision, record its real reply URL or documented disposition:

```sh
python3 -B scripts/maintenance-loop.py \
  --state-file build/maintenance/coordinator/loop-state.json \
  --review-issue NUMBER --review-revision DISPLAYED_REVISION \
  --review-evidence ACTUAL_REPLY_URL_OR_DISPOSITION_PATH
```

Use the runbook's stable action receipt before posting. An uncertain post stays
pending until GitHub proves what happened. A maintainer comment timestamp does
not acknowledge every older question. Willingness, gratitude and silence are not
test results. Record willingness once; do not keep asking for it.

## Is the evidence sufficient?

Evidence is sufficient when it can support the **next decision**, not when every
possible field has been collected. Record `sufficient for <decision>`, or
`missing <one discriminator> because it decides <A versus B>` in the board/request
disposition. Use existing logs and recordings first. Do not demand a full template
again because one field is missing.

| Report path | Smallest useful evidence | Decision / when to stop collecting |
| --- | --- | --- |
| Chooser/import | Build, selected profile, source format, last completed step and exact error | Distinguish picker/import/pack rejection from a native game exit. A known validation rejection can be investigated without a crash log. Never request game files. |
| Android unexpected exit | Matching `process-exits.json` entry and short final session excerpt, with build/profile and the last transition | Classify native crash, OS termination, ANR or return to chooser before choosing a patch. A manual close can create an exit entry; absent records do not disprove an exit. |
| Apple crash | Exact build/OS/device, exception and symbolicated crashing frames or bounded crash excerpt | Match the source **and emitted packaged binary** to the failing instruction. Simulator evidence does not satisfy a physical-device gate. |
| Online | App/pack version, login/lobby/race/results boundary, disconnect code and a short matching session interval | Distinguish import/version/profile issues, service reachability and guest/session failures. Dashboard presence is not a race result. A trace with exhausted budget or wrong event classifier is insufficient for attribution. |
| Geometry | Same failing scene, character/vehicle, settings and screenshot plus available renderer/driver lines | Visible corruption is valid even with no validation errors. Request draw/shader detail only when a bounded hypothesis requires it. A clean synthetic probe does not clear the actual draw. |
| Performance | Same warmed course/scene, settings, frame-time/FPS/audio interval and available CPU/present/pipeline data | Choose CPU guest work, render preparation, synchronization, GPU/presentation or power hypotheses. Low GPU utilization alone proves none. Once a warmed trace is available, analyze it instead of repeating aspect/resolution sweeps. |
| Input/display | Controller/touch path, exact menu or gameplay action, screen/adapter, transition and recovery behavior | Distinguish mapping, held/released state, inset/surface, projection and external-output paths. Wired and AirPlay are separate tests. |
| Save/rating | Profile, lost category, ordinary exit versus replacement boundary, versions and existing backup status | Separate save data, rating companion and online identity. Do not reproduce by deliberately losing more progress or request the save/NAND publicly. |

For Android, Share Report is a bounded summary; runtime history is in the reviewed
private diagnostic export. Use the [support guide](SUPPORT.md#collect-a-useful-report)
for exact collection steps. Request only the relevant redacted excerpt, not the
whole ZIP. Missing metrics are unavailable, not zero. If current logging cannot
answer a specific hypothesis, add one bounded opt-in event or capture with an
explicit expected signal, verify it is present in the packaged build, then disable
it for normal acceptance/performance testing. More logging is not itself a fix.

## Send a concrete build-test handoff

Prepare the test before asking the player to perform it. A candidate is ready to
hand over only when all of these are known:

- Issue/subcase and decision; exact baseline and changed hypothesis.
- Immutable source/configuration and candidate version/build, hash and matching
  native symbols where needed; package audit and intended logging mode.
- Named compatible device/tester, signer compatibility and approved delivery.
  Android Debug and public Release signers are not interchangeable. Never suggest
  uninstalling to solve a signer mismatch.
- One short numbered sequence with profile/pack/settings/scene, a time bound,
  expected result and relevant negative/control comparison. Ask for a baseline
  only when the existing one is insufficient or materially changed.
- The smallest return: pass/still fails/unavailable, exact candidate used, reached
  milestone and a screenshot or bounded excerpt only when it changes the decision.
- Data preservation, stop conditions and a safe recovery path. Do not silently
  change a reporter's saves, settings, identity or device ownership.

Keep a request row in the board keyed by **issue/subcase + candidate + purpose**:

| Field | Record |
| --- | --- |
| State / owner | `preparing`, `requested`, `returned`, `needs-one-detail`, `unavailable`, `superseded` or `accepted`; name the next actor |
| Test identity | Exact build/hash, profile/pack, device/OS, hypothesis and sequence |
| Request | Actual comment URL or private handoff reference; never a secret link/token |
| Returned evidence | Matching build and milestone, pass/failure, relevant excerpt reference |
| Disposition | Whether evidence answers the question, interpretation limits and one next action |

These are **request states**, distinct from engineering and release state. A sent
request means `requested`, not “testing.” Only say a test started when the tester
or an owned process confirms it. A returned result on a different build is useful
but does not accept the intended candidate. `Unavailable` names the missing route,
device or time; park it without repeated nudges. A new candidate explicitly
supersedes the previous request rather than adding another unexplained download.

Example reply: “This confirms the failure occurs after matching, before the race.
The existing log is enough to classify the boundary. We need a compatible private
candidate before the next test; no reinstall or additional log is needed now.”

## Prioritize and accept honestly

Prioritize actionable data loss and launch/crash failures, then supported online
session reliability, real-game geometry and measured performance. Compare severity,
independent affected targets, reproducibility, confidence and closure feasibility.
Explain changes in the JSON's priority reason/evidence. Counts exclude maintainer
and bot issue authors, collapse known duplicates and are not total affected users.
Review comment-only corroborators separately; never sum overlapping families.

Original Wiimmfi is unimplemented. Retro version compatibility, service access,
login, race and endurance are separate gates. For each platform/profile, online
acceptance needs login, matching, race, results, repeat and reconnect on the exact
artifact. Endurance must exceed a reported failure window, such as #206's four or
five races. Do not extrapolate Android, Mac or Simulator results to iPhone/iPad.

| Term | Required meaning |
| --- | --- |
| Source corrected | A demonstrated defect has a reviewed narrow correction and relevant regression evidence. Device acceptance may remain open. |
| Fixed / verified fix | The original affected boundary passes the specified gate with source/artifact identity and required device/reporter evidence. State the verified scope. |
| Accepted | The named tester or release operator reviewed and passed the explicit test card on the exact target/artifact. Say whether acceptance is simulator, physical, reporter or release level. |
| Released | The authorized artifact passed release gates and was actually published; record the release URL/hash. Merging this manual or a patch is not releasing an app. |
| Not reproducible | A documented attempt did not reproduce under the stated build/device/profile/settings/sequence. It does not invalidate the report or close another target's failure. |

No build, host contract, simulator launch, dashboard, thank-you or documentation
change establishes a gameplay fix. No automatic issue closure or IPA/APK/feed
publication belongs to the scheduled support loop. Keep release preparation
reviewable for the authorized manual release task.

## Keep the hub and queue current

The coordinator maintains this system in the loop. After meaningful evidence:

1. Update the existing priority card's action/state/dependency and reason when
   ordering changes. Add a card for a genuinely new actionable family; retain
   accepted subscopes instead of reopening them with a broader report.
2. Update the board's decision/request and affected matrix row together. Link
   the real evidence; use dated artifacts only for new useful findings.
3. Separate public summaries from private receipts, device traces and candidate
   storage. No game data, saves, raw archives, credentials, signing material,
   personal identifiers or private delivery URLs enter GitHub.
4. Carry only reviewed documentation/process changes into a small branch from
   fresh `main`. Validate JSON/checkpoint links and run the focused maintenance
   checks. Review the exact staged diff, push a PR and merge when checks pass.
   Preserve unrelated dirty work; don't bundle runtime candidates into this PR.
5. Record the merged revision in the local handoff and reload the merged public
   records without resetting local receipt/state files. Skip commits for unchanged
   wakes. This makes the maintained repo, rather than one agent's memory, durable.

After two unproductive experiments or two hourly wake windows at an unchanged
gate, choose a better discriminator or name the remaining dependency. Rewriting
the manual, replaying unchanged tests or asking the same person again is not the
next action unless new evidence justifies it.
