# Maintenance work and test board

Snapshot: 9 September 2026 (Japan time). Refresh GitHub and active work before claiming a task.
This is the tracked coordination index, not a claim that all local work is merged.
See [workflow](MAINTENANCE.md), [known issues](KNOWN-ISSUES.md) and their evidence links.
Private artifact paths and task identifiers belong in the local maintenance files.

## Ready work and dependencies

| Workstream | State / owner role | Next action and completion condition | Platform boundary |
| --- | --- | --- | --- |
| #143 Android game-launch crash | Awaiting targeted exit evidence | Exact build/profile, import completion and matching exit/final console; no repeat installation | Honor X7D/Android15, hardware cause unverified |
| #135 iPad launch crash | M2-targeted initializer instruction verified; baseline CPU correction independently reviewed | Manual PR146 merged CPU correction; owner completes exact merged-source rebuild/audit; raw PC/binary UUID still needed to attribute reporter crash | A10X/iPadOS report; declared minOS alone is not device acceptance |
| #105 rating companion restore | Medium source review cleared; PR #133 merged; Android preview published | Await the [offline real-save test](https://github.com/chrissotraidis/kartpad/issues/105#issuecomment-5586204311) requested 8 September; compare matching licenses/ratings before any online test | Android implementation; real-save acceptance pending, Apple parity not implemented |
| #123 online stalls and Pixel performance | Definitive gap confirmed; recorded receive waits outside it; actual HLE probe passes bounded cases; no runtime fix established | [Online timing review](artifacts/2026-09-09/pixel-online-log-review.md) distinguishes sample windows; replacement log establishes2222ms gap, validation ON and thermal0. [Actual HLE probe](artifacts/2026-09-09/issue-123-hle-sleep-probe.md) passes six cases plus negative control; actual alarm-callback probe reproduced rescheduling under the active pump guard; Android-only correction independently reviewed in PR #141; local exact-source Android preview2/code29 built and bounded emulator startup passed; next owner/device comparison, reporter cause unproven. No more reporter input requested. Separately, [Independent Medium source review cleared](artifacts/2026-09-09/maintenance-source-reviews.md) Android-only scalar multiply context reuse (a396eda); next gate is a matched game benchmark; keep separate from online-menu stalls. Owner reports 2704 physical semantic cases and host sanitizers; 66 Android contracts and fresh preparation differing only in the tested header pass; prototype multiply-only timing is not game FPS | Android; no proven freeze fix or FPS improvement percentage |
| #102/#104/#120/#137 rendering | Existing preview diagnostics verified; #137 excerpts requested | [Interpret bounded matrix/draw samples](artifacts/2026-09-09/graphics-preview28-evidence.md) before selecting actual character draw/upload/shader reproduction using supplied validation results and bounded draw diagnostics; record a discriminating result | Adreno evidence; do not infer same cause on Mali or macOS |
| #128/#131 cup crash, #119 bars | Shared awards handlers present; awaiting exit classification | Use [awards/resource source findings](artifacts/2026-09-09/cup-transition-investigation.md) with matching exit/console excerpt; keep display/bar lifecycle separate | AYN Thor and Poco X8 Pro reports; #131 identifies Next before the awards ceremony, Original and Retro both confirmed by reporter; matching exit evidence pending |
| PR #112 controller/keyboard work | Contributor changes requested | Review changes after d18d3e6 for capture cancellation and physical-scancode mapping; run regression checks before new-head acceptance | macOS; owner/Retro acceptance pending |
| #127 two-player rendering | Await same-scene comparison | Compare main and PR source with equivalent settings before attribution | macOS Original; no demonstrated shared Android root cause |
| #100 external displays | Source recovery ownership defect identified; hardware cause unproven | On lost-surface recovery, audit/reuse the SDL Metal view and reattach controls; pair correction with a forced recovery test before mirroring hardware acceptance | iPhone/iPad and Android separately; wired first, then wireless |
| Report context/provenance | PR #133 merged; Android preview released | Manual owner task builds applicable iPhone/iPad changes; record exact artifact and separate acceptance | Android and iPhone/iPad; physical Apple share tests remain |
| Other support/features | See known-issues index | Address new evidence for #103/#101/#5/#92; scope DSU #91 and Wiimmfi #90 separately | Record macOS/iOS/iPadOS/Android/tvOS applicability individually |

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
| Android v0.4.13-android-preview.1 / code 28 | [Published unstable preview](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.13-android-preview.1), ARM64 Android 9+, at cecd69c504f66aa0d8a40f485406618b9b616791; APK SHA-256 `e70ff84fb64ce52294ac13608530bdbed3e22395e5fab7a8ef85799c22de0607`. PR #133 merged; physical acceptance pending | Medium rating source review cleared; 214 storage, 52 format and 66 Android contract checks reported passing; bundle-derived emulator Original rendering and 21 state files preserved. Final source, repeat signing, export/payload and public-signer emulator gates passed. PR #133 merged; anonymous downloads byte-match and downloaded APK/signature audit passes. [#105 offline rating test requested 8 September](https://github.com/chrissotraidis/kartpad/issues/105#issuecomment-5586204311); reporter outcome pending. Physical performance acceptance pending. Separate CPU context experiment excluded |
| Local macOS 0.4.12/build 27 at 271fdc1 | Historical candidate; later PR head adds keyboard behavior | Contributor hardware results apply to exact tested commits; resolve newer review findings before declaring a replacement ready |
| Android preview2/code29 (local candidate) | Clean fdda4c1 source, alarm guard correction; APK SHA-256 `9e7b7a0942714c7a3c9d75397e71763dc16765b9b1ada0ed8ca3e6a57dcb81ac`, 110351769 bytes; excludes unmerged scalar optimization | [Build record](artifacts/2026-09-09/android-preview2-local-candidate.md): build/lint/package/signature audits, repeat derivation and disposable-emulator chooser/seeded Original startup pass. Physical comparison and public distribution gates remain |
| iPhone/iPad 0.4.13/build 29 (intended) | [Manual Apple release PR #146](https://github.com/chrissotraidis/kartpad/pull/146) owns build, merge, publication and README; merged at 4ccda75; corrected pre-merge build audited, final merged-source rebuild owned by manual task | Manual owner reports 152 tests pass (2 skips), fresh native build passes, all eight generated targets and six compiled targets use generic/-rcpc, zero RCpc instructions in decoded final executable and checked Dawn/DiscIO libraries. Final merged-source provenance/public artifact handoff pending; no physical acceptance; scheduled coordinator never publishes IPA |
| tvOS | No new candidate declared ready here | Track applicable shared changes and experimental device acceptance separately |

A pending request is not acceptance. When results arrive, link them and record
whether they support the fix, reject it, or require a different experiment.
Do not close a report solely because a candidate exists. Local tests, owner
acceptance, reporter confirmation and public availability are separate states.
