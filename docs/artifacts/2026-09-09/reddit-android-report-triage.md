# Android Reddit report triage — 9 September 2026

Source: owner-supplied text export of the r/decomps post **“KartPad
(wiicompiled) — first Android community release · chrissotraidis/kartpad”**
by TypeZaxter. The export has relative timestamps, no post/comment permalinks,
no exact APK versions and no attached logs. Its “Comment Image” placeholders
are not screenshots we inspected. Handles below identify comments within that
export; they do not establish identities across Reddit and GitHub.

Compared with the live GitHub issue list and relevant issue comments on
9 September, plus checkout `ca36e2b`. These are reported symptoms and product
leads, not reproduced defects or verified shared causes. Another Android build
is currently being tested by the owner. None of these comments establishes a
result for that build. The [local preview 2 record](android-preview2-local-candidate.md)
documents a candidate separately; the owner did not identify the active test
build in this request. No builds, installs, releases or public replies were
performed for this triage.

## Report mapping

| Report in the supplied export | Existing work / interpretation | Smallest useful next evidence or action |
| --- | --- | --- |
| Bubbly-Thanks-8076: Poco X6 Pro / reported Dimensity 8300U; about 40 FPS, repeat play falls to about 20 with slow motion; restart sometimes helps. 1–3x feels similar, 4x costs more. | Performance symptom overlaps [#103](https://github.com/chrissotraidis/kartpad/issues/103). Repeat-session degradation is a useful distinct trigger. Neither MediaTek nor thermal throttling is established as the cause. | Exact build/profile, what “play again” means, same course cold/repeat, power mode and elapsed time; use an existing matching performance/health interval if available. Similar resolution performance alone does not identify a CPU bottleneck. |
| jakeburns99: Poco X6 Pro 12/512; menus 60 FPS, races 25–30, sections 15–21, no graphical glitches reported. | Second comment on this device family supports investigating scene-dependent performance under #103, separately from repeat-session degradation. | Course/section, Original versus Retro, build and settings. Preserve the clean-graphics observation as a comparison; do not combine the two Poco accounts into one measured session. |
| Cammie_Crossing: Retroid Pocket 5 / Snapdragon 865 with active cooling; Retro below 60 FPS and Dolphin faster at twice the resolution. | Strong device/symptom overlap with the [Retroid report in #103](https://github.com/chrissotraidis/kartpad/issues/103#issuecomment-5589429674). GitHub later confirms .2 and preview 1, validation off, mainly **Original**; Reddit explicitly names **Retro**. Reporter identity is unconfirmed. | Keep the profiles separate. Existing GitHub reporter was already told no repeat benchmark is needed. Await a targeted candidate comparison; active cooling and comparative impressions do not establish equal temperature/power or performance parity. |
| Feeling-Key5883: Spanish comment says Dolphin runs better than this native port on reported “MTK G100 Ultimate.” | Qualitative performance comparison related to #103, without enough context to group by GPU or diagnose. | Device model, exact build and game/profile before requesting profiling. The later GameCube Mario Party optimization question supplies no additional KartPad measurement. |
| PattF: Fold 8 graphics are messed up. | Strong symptom/device overlap with [#102](https://github.com/chrissotraidis/kartpad/issues/102); related renderer reports [#104](https://github.com/chrissotraidis/kartpad/issues/104), [#120](https://github.com/chrissotraidis/kartpad/issues/120), [#137](https://github.com/chrissotraidis/kartpad/issues/137) do not establish a common mechanism. | Exact build and one matching scene image; use existing actual-game renderer investigation. Do not repeat synthetic probes or imports already completed by GitHub reporters. |
| Chriscautillo: “not working” on reported “8 elite gen 5 on fold 8”; PattF replies “same boat.” | Unclassified failure. Could overlap #102, but this is not evidence of a crash. [#143](https://github.com/chrissotraidis/kartpad/issues/143) is a separate launch-crash report on different hardware. | Identify the last working screen and whether import rejects, graphics corrupt, game freezes, or Android closes the app. Preserve reported hardware wording until a technical report confirms it. Request exit metadata only for an actual unexpected exit. |
| TypeZaxter: AYN Thor works well but fullscreen is missing. | Likely overlap with system-bar issue [#119](https://github.com/chrissotraidis/kartpad/issues/119), also reported on Thor in [#128](https://github.com/chrissotraidis/kartpad/issues/128). If this means aspect bars, [#101](https://github.com/chrissotraidis/kartpad/issues/101) is a different path. | Distinguish Android status/navigation bars from expected 4:3/16:9 letterboxing; record display and launch/resume behavior. Build 23 has local immersive-mode checks, but Thor acceptance remains open. |
| WayApprehensive6494: Thor runs well; wants triggers/stick clicks remappable for wheelies/tricks instead of D-pad. | Confirmed **source-level feature limitation**: current Android mapping exposes only A/B/X/Y/Z to A/B/X/Y/left shoulder. [macOS PR #112](https://github.com/chrissotraidis/kartpad/pull/112) is related design work, not Android implementation or acceptance. | Record in tech debt. Confirm desired physical button → action; preserve defaults, analog behavior, player assignment and release edges if expanded. No crash logs needed. |
| 420MacMan: Retro folder is not recognized; sees only ISO/folder selection and cannot find the suggested in-app download. | Setup/discoverability lead, no exact matching open issue found. Current source already has an official-pack downloader; failure to reach it is not proof it is absent. | Exact build, selected mode, whether base data was validated, and error/screen text. Explain the owned base-disc prerequisite separately from the official Retro pack; distinguish wrong folder, missing base data and incompatible pack. |
| Dank_boredom: tried both suggested inputs, later reports success after ISO-conversion guidance, then asks whether Retro uses the same process. Ambitious_Stock_4211 also reports success after repeated setup guidance; Terminator996 reports Snapdragon 778g+ working. | Disc-format/region and base-versus-mod confusion; no confirmed importer regression. Closed Apple picker [#1](https://github.com/chrissotraidis/kartpad/issues/1) is historical UX context, not the same Android defect. Deduplicate the repeated conversion reply. | Explain owned PAL RMCP01 revision 0 ISO/WBFS versus unsupported direct RVZ input and separate official Retro installation. Success does not reveal which earlier check failed. Do not reproduce game-download links from the comments. |
| Terminator996: changing render resolution freezes the game; pausing/unpausing reportedly recovers it. | New settings-transition reproduction lead; no exact matching issue found. Keep separate from online-menu stalls in [#123](https://github.com/chrissotraidis/kartpad/issues/123). | Build/device/profile, old → new scale, scene and exact pause control used; whether audio, native menu and FPS continue. Inspect settings application, renderer resource transition and lifecycle state. Pause/resume is a reporter workaround, not a verified fix. |
| TypeZaxter: wording “fullscreen is fps uncapped.” | Ambiguous request concerning an FPS cap/uncapping, not evidence that game speed or frame limiting is broken. | Clarify whether they want a higher cap, observe uncapped rendering, or mean something else. Any future option needs game-speed/audio/physics validation; do not infer the request from punctuation. |

## Questions and positive reports

- Switch-port and Nvidia Shield questions are demand/compatibility questions,
  not failed runs. No Shield acceptance or Switch delivery commitment follows.
- A PC-server compatibility question receives a community “yes” for Retro
  Rewind. Treat it as a question to answer using the supported Retro WFC flow,
  matching content and existing platform acceptance boundaries; it is not a
  captured successful Android online session and does not imply Wiimmfi support.
- Thor users, a Snapdragon 778g+ user and SimpleDrawer26 (unspecified device,
  reportedly smooth at 4x/16:9) provide positive comparisons. None provides a
  sustained benchmark, build identity or all-mode acceptance. Keep these beside
  failures so a vendor-wide incompatibility is not inferred.
- The maintainer's comment anticipates a preview improving frame stability.
  It is an announcement, not the result of the Android test now in progress.

## Comparison examples for future reviews

These examples use the evidence reviewed for this dated triage and the linked
repository records. They illustrate coverage, not a maintained compatibility
list. Update the existing issue/board when new test results arrive; do not infer
that the active Android build matches any row below.

| Source / device | Build and profile known here | What the report supports | What remains unresolved |
| --- | --- | --- | --- |
| Reddit TypeZaxter / AYN Thor | Build/profile unknown | Positive play claim; fullscreen complaint | Race/cup duration and fullscreen meaning; no general pass |
| GitHub #128 / AYN Thor | Build 23 per known-issue record; Retro | Reaches end of cup; reports crash and persistent system bars | Exact exit evidence and affected bars; separate from Reddit identity |
| GitHub #102 / Fold | Actual validation comparison on build 23; Original and Retro corruption reported in separate runs | Game presents near 60 FPS in supplied interval, corruption unchanged | Actual failing draw; speed does not establish correct graphics |
| Reddit Bubbly-Thanks-8076 / Poco X6 Pro | Build/profile unknown | Reported repeat-play decline from about 40 to 20 FPS | Exact repeat sequence, scene, settings and thermal/power context |
| Reddit jakeburns99 / Poco X6 Pro | Build/profile unknown | Reported 60 FPS menus, 25–30 racing, lower in sections; clean graphics | Scene/build/context; do not merge with the other Poco session |
| GitHub #103 Retroid contributor / Pocket 5 | .2 and preview 1, mainly Original, validation off | Reported standard-profile slowdown and higher-power 60 FPS | Sustained improvement on a targeted candidate; no repeat hot benchmark needed |
| Reddit Cammie_Crossing / Pocket 5 | Build unknown; Retro | Reported sub-60 performance with active cooling | Build/settings and comparable session; not the same known profile as the GitHub result |
| GitHub #143 / Honor X7D | Build/profile not yet supplied in reviewed record | Reported exit after import and Launch | Import completion, matching exit and console evidence |
| Reddit SimpleDrawer26 / unspecified device | Build/profile unknown; 4x/16:9 reported | Qualitative smooth-play claim | Device, duration and completed milestone; cannot certify 4x generally |

## Follow-up boundary

The [Android community section in technical debt](../../TECH-DEBT.md#android-community-reports-and-flow-gaps)
records the actionable work and acceptance criteria. Existing
[known issues](../../KNOWN-ISSUES.md) remain the live hardware-evidence register.
Use current GitHub evidence before asking an existing reporter to repeat work.
For a new report, first obtain build, profile, visible failure and trigger;
request only a short matching, reviewed diagnostic excerpt when it can answer
the remaining question. Missing logs do not block documenting a confusing flow
or the confirmed remapping limitation. No raw private archive, game data, save
or account identifier is needed for this aggregation.
