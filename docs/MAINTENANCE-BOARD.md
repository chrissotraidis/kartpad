# Maintenance work and test board

Snapshot: 13 September 2026. Current GitHub refresh: 46 open issues. Start at the
[support-agent hub](SUPPORT-AGENTS.md). The [priority source](maintenance-priorities.json)
owns ordering, readiness, exact next actions and acceptance; this board records
support decisions and evidence. Refresh GitHub and local ownership before acting.
The [device matrix](COMPATIBILITY-MATRIX.md) preserves target-specific observations.

Reporting update, 14 September: [Android90 and Apple42 test builds](REPORTING.md#reporting-test-builds)
are published separately from stable downloads. Both trackers are accessible;
Android-specific and uncertain port issues remain KartPad intake. Physical
report-flow acceptance is pending; no gameplay issue is closed by this change.

## September 15 Android performance investigation

**Second passive pass:** [revised candidate assessment](artifacts/2026-09-15/android-second-pass-candidate.md) supersedes the initial test ordering below. Prefer a separate native-TLS versus forced-emulated-TLS private comparison on API29, with memory attribution captured alongside. Historical Helio exit metadata includes about1.59 GiB PSS/1.84 GiB RSS but no proven memory kill. No production code or APK changed in this second pass.

Current source baseline `cedb338` / Android runtime `b57c59b`; public Android code93. New #275 POCO X3 evidence joins #198's warmed CPU-side lane: shader queue zero does not restore frame rate. A private source candidate removes duplicate scalar CPU-context lookup; 448,000 ARM64 emulator differential cases pass, but emulator timing is mixed and no gameplay gain is established. No APK was built or published in this pass. The next gate is a matched owner-phone CPU/frame-time comparison after checking current package/signer and symbols; stale code84 must not be offered as an update to code93.

[Research and experiment](artifacts/2026-09-15/android-performance-research.md) · [complete recent intake](artifacts/2026-09-15/android-issue-intake.md). Replied to #275 and #137 from supplied logs, and to #199's new local-screen freeze comparison. Existing unanswered requests remain in place. Raw logs are retained locally outside Git. Runtime and parent PRs remain draft pending physical benefit; other platform runtime pins are unchanged.

## Current priorities and handoffs

Counts below are distinct non-maintainer issue authors at this snapshot, excluding
comment-only corroboration. Known duplicates #209/#210 collapse under #208. Families
overlap, so these numbers cannot be summed into total affected users. The selector
refreshes counts in its generated local context, not by automatically promoting
popular reports. Historical work and old requests remain in the
[previous board](https://github.com/chrissotraidis/kartpad/blob/2028ab3/docs/MAINTENANCE-BOARD.md);
the next actions below supersede those dated assignments.

| Priority / card | Issues / authors | Current decision and next actor |
| --- | --- | --- |
| 0 / `retro-save-loss` | #169 / 1 | `awaiting-reporter`: classify lost progress and ordinary exit versus pack replacement from the existing request. Do not deliberately lose more data. |
| 1 / `android-exits` | #143, #200, #205, #208–210, #128, #131, #207, #215, #216, #236 / 10 | `awaiting-reporter`: one matching exit classification per distinct launch/cup/race subcase. #208 is canonical for #209/#210; similar wording does not establish a common runtime defect. |
| 1 / `ios27-startup` | #196 / 1 | `awaiting-reporter`: matching iPhone17 Pro Max/iOS27 retest of [0.4.17/build39](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.17-ios.1) **failed** on 13 September: Retro crashes about two seconds after the KartPad screen; Original still fails. New per-mode crash analytics were promised but are not attached. The iPhone14 trial does not resolve this device failure; preserve data and await the new reports. |
| 2 / `warmed-performance` | #198, #167, #103, #169, #195, #204, #207, #135 / 8 | `ready-local`: private code84 is packaged and audited against public83 native payload and exact symbols; arrange compatible private delivery, then capture one warmed driven slowdown. #198 has supplied captures and agreed to the handoff; do not repeat those requests. |
| 3 / `adreno-geometry` | #102, #104, #120, #137, #166, #193, #211 / 7 | `ready-local`: recover the retained actual-draw comparison into a clean current build, compile generated shaders and retain draw identity. Affected-device dynamic/literal/dynamic testing remains required. |
| 4 / `android-online` | #206 / 1 | `awaiting-reporter`: await the existing Wi-Fi endurance request beyond four/five races. #123 is closed; that is not technical online acceptance. |

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
| [#196 failed matching-device retest](https://github.com/chrissotraidis/kartpad/issues/196#issuecomment-5651820707) | At 2026-09-13 07:00:59 UTC the reporter confirmed build39 still fails on iPhone17 Pro Max/iOS27: Retro reaches the KartPad screen then crashes about two seconds later, and Original still fails. The [maintainer response](https://github.com/chrissotraidis/kartpad/issues/196#issuecomment-5651930724) requests the promised new crash analytics labelled Original/Retro. None were attached at this update. Earlier iPhone14 acceptance and compiled-guard proof do not establish this new crash cause or resolve the report; no reinstall or data erasure is needed. |
| [#123 closed upstream](https://github.com/chrissotraidis/kartpad/issues/123) and [last maintainer response](https://github.com/chrissotraidis/kartpad/issues/123#issuecomment-5644306282) | GitHub records `CLOSED` / `COMPLETED` at 2026-09-12T07:41:52Z. The final comment separates a music workaround for menu lag from reported online-race frame drops. This is a support-state reconciliation, not a technical fix or race/results/reconnect acceptance; do not assign more #123 work unless it is reopened with new evidence. |
| [#206 cellular/Wi-Fi comparison](https://github.com/chrissotraidis/kartpad/issues/206#issuecomment-5642749400) | `awaiting-reporter`: [acknowledgement posted](https://github.com/chrissotraidis/kartpad/issues/206#issuecomment-5642834780). On Samsung SM-S921W / Android 14 / build 65, mobile data worked once while Wi-Fi reportedly works normally. This is sufficient to isolate a network-dependent subcase; it does not prove a NAT, carrier or guest-runtime cause. Await the already requested confirmation that Wi-Fi passes beyond the prior four/five-race window before claiming a stable workaround; do not repeat the acknowledgement, known build/device questions or generic log request. |
| [#211 Retro screenshot response](https://github.com/chrissotraidis/kartpad/issues/211#issuecomment-5642589742) | `needs-one-detail`: Galaxy S24 Ultra and corruption in both profiles are supplied. Current in-app build and official pack version remain requested. Do not ask the handset again or infer GPU/driver. |
| [#166 additional device request](https://github.com/chrissotraidis/kartpad/issues/166#issuecomment-5628217442) | `requested`: exact device/build/profile and available renderer lines for the added report. Existing synthetic checks do not clear the failing gameplay draw. No duplicate probe/request. |
| [#198 willingness](https://github.com/chrissotraidis/kartpad/issues/198#issuecomment-5640922655) | `preparing`: existing warmed evidence justifies a bounded function profile. Signer compatibility/data preservation and private delivery are maintainer dependencies. Do not re-ask willingness, attach the APK publicly or represent installation/testing as started. |
| [#167 completed comparison](https://github.com/chrissotraidis/kartpad/issues/167#issuecomment-5608282606) | Supplied Infinix Hot 60 Pro / Android 16 / KartPad 0.4.11 / Original details and unchanged 1x aspect comparison are sufficient to stop that settings sweep. A selected warmed profile is a different decision; don't ask for the same device/build again. |
| [#215 launch/exit reply](https://github.com/chrissotraidis/kartpad/issues/215#issuecomment-5643185926) | `awaiting-reporter`: Xiaomi 25057RN09G (shortened to 25057RN09 in the reply), Android 15/API 35, 0.4.16-android.2/build 65. Both Original and Retro repeatedly exit around the reported “about to play” step. Reply is posted; Android-home exit is now confirmed. Await the matching native/Java/OS exit classification, not the destination again. No shared runtime cause is established. |
| [#216 black-surface/exit reply](https://github.com/chrissotraidis/kartpad/issues/216#issuecomment-5643186097) | `awaiting-reporter`: Galaxy Tab A (8.4-inch, 2020), One UI 3.1, Android 11/API 30, reported 0.4.16 Android; exact build unconfirmed. Both Original and Retro show a black game surface with touch controls, then exit. Reply is posted; await only chooser-versus-Android-home destination, selected profile/import completion and one short redacted exit result. Keep separate from #215 and renderer hypotheses. |
| [#208 canonical launch report](https://github.com/chrissotraidis/kartpad/issues/208) | `requested`: chooser versus Android home, profile/import state and matching exit result; #209/#210 do not justify new requests or three engineering assignments. |

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
| Input/system UI | #119 bars, #184 mapping, #197 menu input, #202 aspect/display. Match physical/touch and chooser/gameplay paths; no renderer patch for an unclassified button/inset report. #184 has a bounded feature scope in [future features](FUTURE-FEATURES.md#android-d-pad-and-shoulder-remapping). |
| External display | #100 and #199. Match local-only, wired and AirPlay transitions/recovery separately. Existing Metal/source checks are not affected-display acceptance. |
| Apple controls/projection/multiplayer | #5, #91, #101, #127; PR [#112](https://github.com/chrissotraidis/kartpad/pull/112), integrated through #254; [#157](https://github.com/chrissotraidis/kartpad/pull/157) shipped in Mac0.4.17. Reconcile current heads, candidate ownership and exact controller/split-screen scene before another build. |
| Apple performance | #135. A10X startup is already accepted; remaining frame-rate concern needs its own affected-device comparison, separate from Android CPU/GPU hypotheses. |
| Save/rating lifecycle | #105 manual transfer is accepted; automatic two-way sync and Mii scope remain distinct. #169 lost progress must be classified separately from performance and system bars. |
| Feature/compatibility | #90 Original Wiimmfi, #91 controller/DSU, #203 disc revision/NAND/cheats. Define requested behavior, supported input and implementation boundary; do not request generic logs for missing features. |
| Governance | #92 closed after live verification of the root GPL license, identical license copy, and explicit combined-work/release-policy wording. Reopen only for a concrete remaining concern. |

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

## September 13 delivery and controls update

The Community Release signing key has been located and its certificate verified.
Earlier missing-key preflight conclusions were incorrect; private credentials
remain outside this record. This removes the signing-location dependency, not
the requirement to derive and audit each diagnostic/public candidate.

Apple0.4.17 downloads are published. Android code78 passed the owner's bounded
Retro race/touch trial; possible Retro WFC menu lag remains uncertain. Two
licenses are accepted by the owner and must not be merged/reset. FPS-size and
responsive-editor work (#238) merged in PR245 and passed physical code79 UI
checks; public Android code80 also delivers PR219 shoulder remapping. Exact
reporter controller/device acceptance remains open. See the
[controls audit](artifacts/2026-09-13/android-controls-request-audit.md).


## Recent follow-up: macOS integration and Android input

- PR #112 is integrated through PR #254, preserving contributor history. Two
  fresh-preparation failures were corrected; the full ARM64 Original/Retro
  build and isolated package/signature audit passed. Source integration is
  separate from a newly published Mac package; the current download remains
  build 39, and new Retro gameplay acceptance is still open.
- #250 is a macOS presentation/VSync request. The release source prefers Metal
  Immediate when available with FIFO fallback. The public Mac build 39 still has
  no VSync switch. PR #255 is merged: source now offers experimental startup-only
  VSync, with full native builds, local package audits and isolated native settings
  checks completed. A [bounded isolated Original startup](artifacts/2026-09-13/macos-vsync-isolated-startup.md)
  selected Immediate off and FIFO on after restart; normal data/prefs stayed
  unchanged. The FIFO run logged an audio queue-full/drop warning. No new Mac
  release is published; physical tearing, warmed pacing and audio quality remain
  open. #101 projection stretching is a separate issue.
- #197 has a [concrete shared-input investigation](ANDROID-INPUT-197.md). A held
  A from either input source can suppress fresh menu edges, but the actual
  reporter cause is unconfirmed. Use the existing touch-only request and the
  focused lifecycle/handoff controls, not another generic input questionnaire.
- #234 same-phone restore remains a save/identity boundary, not a renderer
  failure. The support guide now separates raw-save/rating import from complete
  Mii, console identity and country configuration restoration.

## Current delivery and next release gate

[Android 0.4.18/code 83](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.18-android.1) is published with APK, source, notices and checksums; all four hosted downloads were verified. Preferred Game and continuation handling are delivered. D-pad/FPS changes were already delivered in code 80. Private code 82 passed the owner's general gameplay acceptance and remains the last verified phone installation; exact Item Rain and online coverage are not inferred. See the [release evidence](artifacts/2026-09-13/android-code83-public-release.md).

The [high-impact review](artifacts/2026-09-13/high-impact-priority-review.md) recommends measured sustained performance first and Android geometry second. Apple external-display recovery is the alternative second focus. The signing key location is resolved; current diagnostic packaging and affected-device delivery are still work to complete. Do not distribute the old Debug-signed profiler as a public-app update.

#196 was reopened after a completed closure without a passing result. The matching build39 retest still failed; the reporter says new analytics are absent and the in-app report fallback has already been requested. Reissuing the same IPA is not a correction.

#203 has a tested read-only disc-header helper; region compatibility, NAND and cheats remain separate features. #105 manual transfer is accepted and Preferred Game is delivered; automatic synchronization and Mii scope remain open. #194 mismatch guidance is merged, not an automatic updater. #92 and #238 remain closed on their documented evidence.

No open pull requests remained at this review. Merged Mac VSync still needs warmed pacing/audio and tearing acceptance before a new Mac release. A new Android performance or graphics release requires a measured correction and matching gameplay checks, not another version bump.

Ownership audit: [46/46 open tickets assigned and replied to](artifacts/2026-09-13/open-ticket-ownership-audit.md). Current [code84 profiling evidence](artifacts/2026-09-13/android-profiler-preflight.md#current-diagnostic-built-after-the-review) is preparation, not a performance fix.

## Concrete source corrections after deeper review

[Local failure review](artifacts/2026-09-13/android-source-failure-review.md): Original startup now skips unrelated Retro recovery, and recovery defers to an active cross-process Retro install transaction. Real filesystem/process tests reproduce and cover both boundaries. A shared packed-vertex helper also reads only its required three bytes. These changes need a new candidate to reach users; public83 is unchanged, and no broad launch/geometry issue is closed on this evidence.

## Published Android 0.4.19 / code85

[Code85 is public](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.19-android.1), delivering the PR271 Original-startup isolation, active-install recovery protection and packed-vertex read correction. APK, corresponding source, notices and checksums were uploaded and independently downloaded/verified. See the [release receipt](artifacts/2026-09-13/android-code85-public-release.md). Earlier entries saying these changes need a new APK are superseded. No fresh physical gameplay or broad issue closure is inferred; the release posts request focused affected-path comparisons.

## 14 September intake and changed evidence

#277 was consolidated into #206 after matching the reporter, device and connection failure; its code80 evidence remains in the canonical thread. New #273/#275/#278 requests and graphics retests #102/#104/#166/#193 were answered. #250 now supplies60Hz with interpolation off. All open tickets were assigned to the owner at refresh.

Code85 failed the four new graphics comparisons. Code90 uses identical native libraries, so it is offered only where its session-log export answers a missing-evidence problem. The next renderer action is reconstruction of #193's two exact shipped pipeline recipes. #196 now has symbolized native evidence and a targeted missing-address request; the separate iOS file-backed guest-memory behavior warrants local investigation. See the [intake receipt](artifacts/2026-09-14/intake-and-next-failures.md).
