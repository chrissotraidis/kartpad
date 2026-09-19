# Maintenance work and test board

Scoped intake update: 19 September 2026; 56 open issues. The older family and release snapshots below retain their dates. Start at the
[support-agent hub](SUPPORT-AGENTS.md). The [priority source](maintenance-priorities.json)
owns ordering, readiness, exact next actions and acceptance; this board records
support decisions and evidence. Refresh GitHub and local ownership before acting.
The [device matrix](COMPATIBILITY-MATRIX.md) preserves target-specific observations.

## 19 September intake decisions

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
| 0 / `retro-save-loss` | #169 / 1 | `source-corrected-awaiting-reporter`: Android pack activation now preserves both Retro WFC save branches; see [source finding and fixture](artifacts/2026-09-12/issue169-retro-save-preservation.md) and the [public update](https://github.com/chrissotraidis/kartpad/issues/169#issuecomment-5644596717). The original build-21 report still needs its exact exit-versus-pack-replacement boundary and current-candidate data-preserving acceptance. Do not deliberately lose more data. |
| 1 / `android-exits` | #143, #200, #205, #208, #235–236, #128, #131, #207, #215, #216 / 11 open cases | `awaiting-reporter`: one matching exit classification per distinct launch/cup/race subcase. Closed #209/#210/#224–232 remain historical duplicates under #208; #236 is canonical for closed #237. #235 and #236 remain separate Honor X7c and OPPO CPH2669 device subcases. Similar wording does not establish a common runtime defect. |
| 1 / `ios27-startup` | #196 / 1 | `released-awaiting-device`: public [v0.4.17-ios.1](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.17-ios.1) is the corrected unsigned IPA, SHA-256 `d322484192dde92139ed8aac66c9abd7764b91f97895840995ef17f0ff49f9ff`. Anonymous audit and owner iPhone 14 / iOS 26.6.2 in-place data preservation passed. The matching iPhone 17 Pro Max/iOS 27 Original+Retro launch/race/relaunch gate remains open; see [platform handoff](artifacts/2026-09-13/platform-candidate-handoff.md). |
| 2 / `android-online` | #206 / 1 | `awaiting-reporter`: await #206's already requested Wi-Fi endurance confirmation beyond the prior four/five-race window. #123 is closed upstream and remains historical evidence only; closure is not technical online acceptance. |
| 3 / `adreno-geometry` | #102, #104, #120, #137, #166, #193, #211 / 7 | `awaiting-owner`: release operator and affected-device tester establish compatible signing/delivery for the retained dynamic/literal/dynamic character-draw comparison. Closed #233 is preserved as an SM-S928B/Retro subcase under #211, not a separate active case. The host has no release keystore; see [Android signing preflight](artifacts/2026-09-12/android-release-signing-preflight.md). No GPU-wide cause or correction is established. |
| 4 / `warmed-performance` | #198, #167, #103, #169, #195, #204, #207, #135 / 8 | `awaiting-owner`: #198 tester is willing. The prepared profiler needs compatible signing or an approved data-preserving route **and** private delivery before capture. The host has only a debug keystore; see [Android signing preflight](artifacts/2026-09-12/android-release-signing-preflight.md). Retained Debug-signed APK is not a public-app in-place upgrade. |

## Release-candidate sequence

The current delivery order is: (1) revalidate and hand off the clean #196
iOS candidate for compatible signing and matching iPhone 17 Pro Max/iOS 27
acceptance; (2) prepare merged PR #219 for a signer-compatible Thor/Odin test;
(3) prepare merged PR #157 for the same-scene two-player Mac comparison. See
the [reconciliation artifact](artifacts/2026-09-13/release-candidate-reconciliation.md).
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
| [#196 published build audit](https://github.com/chrissotraidis/kartpad/issues/196#issuecomment-5642179928), [corrected simulator runtime](artifacts/2026-09-12/issue196-simulator-candidate-runtime.md) and [build-integrity correction](artifacts/2026-09-12/issue196-rel-report-build-integrity.md) | Public v0.4.16-ios.2/build 36 still contains the reported aggregate-shard load. The new clean `0.4.16/build38.96.2` candidate now passes the isolated simulator lifecycle for Original and Retro 6.12.8 with data preserved and no translated crash markers. Regenerate a signed candidate; matching iOS 27 hardware acceptance remains unperformed. |
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
| [Closed duplicate cleanup](../build/maintenance/reviews/2026-09-13-issue-cleanup.md) | `reconciled`: #209/#210/#224–232 are closed under #208; #237 is closed under #236; #233 is closed under #211. Originals retain the evidence and remain the only active memberships. |

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
