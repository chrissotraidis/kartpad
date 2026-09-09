# Maintenance work and test board

Snapshot: 9 September 2026 (Japan time). Refresh GitHub and active work before claiming a task.
This is the tracked coordination index, not a claim that all local work is merged.
See [workflow](MAINTENANCE.md), [known issues](KNOWN-ISSUES.md) and their evidence links.
Private artifact paths and task identifiers belong in the local maintenance files.
Open-issue audit: 19 open issues and PR #112 checked during the 01:14 UTC cycle on 9 September 2026.
Next manual Android investigation: [bounded handoff and test plan](ANDROID-PERFORMANCE-HANDOFF.md).

The [Android technical debt work order](TECH-DEBT.md#order-of-operations)
defines failure classification, evidence requirements and completion criteria.
Use it to select ready follow-up work without duplicating the active build owner.

## Ready work and dependencies

| Workstream | State / owner role | Next action and completion condition | Platform boundary |
| --- | --- | --- | --- |
| #143 Android game-launch crash | Awaiting targeted exit evidence | Exact build/profile, import completion and matching exit/final console; no repeat installation | Honor X7D/Android15, hardware cause unverified |
| #135 iPad launch crash | CPU correction published; raw crash instruction independently verified | [Raw crash review](artifacts/2026-09-09/issue-135-raw-crash-review.md) decodes faulting LDAPRB in build15. Build29 chooser test requested 9 September; await A10X result, no repeated log request | A10X/iPadOS; this does not validate Android CPU or graphics behavior |
| #105 rating companion restore | Published and reporter-confirmed for offline ratings/information transfer | [Success acknowledged](https://github.com/chrissotraidis/kartpad/issues/105#issuecomment-5594271981); preserve separate Mii/server-sync scope | Android; Apple parity not implemented |
| #123 online stalls | Alarm reschedule defect fixed in PR #141; local preview2/code29 passes bounded checks | Compare a matching-signer candidate against a controlled baseline in online menus; see [alarm evidence](artifacts/2026-09-09/issue-123-alarm-reschedule-guard.md). If stalls persist, capture the blocked execution/wakeup boundary. No more broad reporter logs requested | Android; source defect verified, reported freeze cause and hardware improvement unproven |
| #103 and owner Pixel sustained FPS | Historical physical profiles identify FP status/context and resource-hashing costs; current-build attribution needed | Follow [targeted handoff](ANDROID-PERFORMANCE-HANDOFF.md). Manual Android owner has exclusive performance/geometry/build/device investigation. Local Debug hash optimization has scene-bounded measured gains and owner-reported gameplay improvement; Release already uses O2. Menu/loading/countdown investigation is active; scalar remains separate. Do not equate Debug gains with a public #103 fix | Android; standard power mode and comparable thermals, separate from #123 |
| #102/#104/#120/#137 rendering | Existing preview diagnostics verified; #137 excerpts requested | [Interpret bounded matrix/draw samples](artifacts/2026-09-09/graphics-preview28-evidence.md) before selecting actual character draw/upload/shader reproduction using supplied validation results and bounded draw diagnostics; record a discriminating result | Adreno evidence; do not infer same cause on Mali or macOS |
| #128/#131 cup crash, #119 bars | Shared awards handlers present; awaiting exit classification | Use [awards/resource source findings](artifacts/2026-09-09/cup-transition-investigation.md) with matching exit/console excerpt; keep display/bar lifecycle separate | AYN Thor and Poco X8 Pro reports; #131 identifies Next before the awards ceremony, Original and Retro both confirmed by reporter; matching exit evidence pending |
| PR #112 controller/keyboard work | Contributor changes requested | Review changes after d18d3e6 for capture cancellation and physical-scancode mapping; run regression checks before new-head acceptance | macOS; owner/Retro acceptance pending |
| #127 two-player rendering | Await same-scene comparison | Compare main and PR source with equivalent settings before attribution | macOS Original; no demonstrated shared Android root cause |
| #100 external displays | Source recovery ownership defect identified; hardware cause unproven | On lost-surface recovery, audit/reuse the SDL Metal view and reattach controls; pair correction with a forced recovery test before mirroring hardware acceptance | iPhone/iPad and Android separately; wired first, then wireless |
| Report context/provenance | PR #133 merged; Android preview released | [iPhone/iPad build 29 published](releases/v0.4.13-ios.1.md); physical report/share tests remain pending | Android and iPhone/iPad; physical Apple share tests remain |
| #142 disclosure/docs | Closed by Christopher after his follow-up; documentation cleanup and FAQ restoration merged | Preserve disclosure and restored FAQ; leave broader UI review separate from runtime investigation | Repository/support |
| Other support/features | See known-issues index | Keep #101/#5/#92 and separately scoped DSU #91/Wiimmfi #90 with their existing owners and next evidence | Record platform applicability individually |

Use one owner per task and keep ready, active, awaiting review, awaiting device,
merged, and released distinct. New replies are not required to work on ready items.

## Build and test-request ledger

Update a row when a candidate is prepared, superseded, requested, tested or rejected.
Each actual candidate record must include source SHA, version, artifact SHA-256,
target machines, test evidence, request link/date, outcome and next action. Keep
local artifact locations in `build/maintenance/CURRENT.md`; never imply they are
public downloads. Link full provenance records instead of copying raw diagnostics.

| Candidate / work | Current disposition | Test request / next step |
| --- | --- | --- |
| Android public v0.4.12-android.2 / code 23 | Published diagnostic beta, not a verified graphics/cup-crash fix | Existing issue threads hold off/on results and pending crash/bar evidence. No repetitive requests |
| Android v0.4.13-android-preview.1 / code 28 | [Published unstable preview](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.13-android-preview.1), ARM64 Android 9+, at cecd69c504f66aa0d8a40f485406618b9b616791; APK SHA-256 `e70ff84fb64ce52294ac13608530bdbed3e22395e5fab7a8ef85799c22de0607`. PR #133 merged; broad physical performance acceptance pending | Medium rating source review cleared; 214 storage, 52 format and 66 Android contract checks reported passing; bundle-derived emulator Original rendering and 21 state files preserved. Final source, repeat signing, export/payload and public-signer emulator gates passed. PR #133 merged; anonymous downloads byte-match and downloaded APK/signature audit passes. [#105](https://github.com/chrissotraidis/kartpad/issues/105) confirmed successful ratings/offline information transfer on 8 September at 14:06 UTC; Mii and server-sync acceptance remain separate. Physical performance acceptance pending. Separate CPU context experiment excluded |
| Local macOS 0.4.12/build 27 at 271fdc1 | Historical candidate; later PR head adds keyboard behavior | Contributor hardware results apply to exact tested commits; resolve newer review findings before declaring a replacement ready |
| Android preview2/code29 (local candidate) | Clean fdda4c1 source, alarm guard correction; APK SHA-256 `9e7b7a0942714c7a3c9d75397e71763dc16765b9b1ada0ed8ca3e6a57dcb81ac`, 110351769 bytes; excludes unmerged scalar optimization | [Build record](artifacts/2026-09-09/android-preview2-local-candidate.md): build/lint/package/signature audits, repeat derivation and disposable-emulator chooser/seeded Original startup pass. Physical comparison and public distribution gates remain |
| iPhone/iPad 0.4.13/build 29 | [Published preview](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.13-ios.1) by the separate manual owner from `4ccda75611ca445bb02e4782b8c4a72fde5bc4f3`; IPA SHA-256 `80470292ce62fdaff28bcfd28d3983e9bb3223f890594f9e92da5bc991b5ea53`, 45,058,388 bytes | [Release evidence](artifacts/2026-09-09/ios-preview-build29.md): native build, repeat packaging, anonymous download comparison and downloaded-IPA/provenance audit pass; 152 tests with 2 skips and chooser harness pass. Exact-build physical gameplay/share, A10X and #135 reporter confirmation remain pending. Scheduled coordinator never publishes IPA |
| tvOS | No new candidate declared ready here | Track applicable shared changes and experimental device acceptance separately |

A pending request is not acceptance. When results arrive, link them and record
whether they support the fix, reject it, or require a different experiment.
Do not close a report solely because a candidate exists. Local tests, owner
acceptance, reporter confirmation and public availability are separate states.
