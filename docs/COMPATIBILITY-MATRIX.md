# KartPad platform and device compatibility matrix

Snapshot: 14 September 2026 (Japan time). This is the canonical device-level
view of current KartPad evidence. It complements the issue-family board:
[MAINTENANCE-BOARD.md](MAINTENANCE-BOARD.md) answers “what work is next,” while
this file answers “what is known on which target.”

A row describes one device/OS/GPU/build/path combination. Do not generalize a
row to a vendor, GPU family, Android version or Apple platform. A Samsung S24
Ultra row is not evidence for an S25 Ultra, and a Pixel dashboard result is not
evidence for a Helio G85 race.

## Status vocabulary

- `verified-pass`: the named path passed its acceptance test on the named
  target.
- `reproduced-open`: the symptom is reproduced or reporter-confirmed, but the
  cause or fix is not verified.
- `partial`: one boundary passed while a required stronger boundary remains
  open (for example WFC dashboard without a race).
- `candidate-awaiting-device`: a private candidate or source correction exists;
  the affected target must test it.
- `awaiting-reporter`: the next discriminator is a reporter response or
  redacted diagnostic result.
- `unverified`: the report lacks enough evidence to claim a runtime result.
- `awaiting-device`: a specific physical comparison remains outstanding.
- `simulator-pass`: the named simulator path passed; physical acceptance remains separate.
- `not-evaluated`: no meaningful evidence has been collected for this path.

## Current matrix

| Device key | OS / build | Product path | Observed evidence | State | Issues / evidence | Next gate |
| --- | --- | --- | --- | --- | --- | --- |
| `pixel-private-session-trace` | Android; private 0.4.17-android.11-wfctrace123/code 74; pack 6.12.8 | Retro WFC dashboard → VS character/preparing-race | Physical replays disconnect with code 86420 or before the first race frame while the process stays alive. The old recv_error event classifier is invalid for attribution | `partial` | [physical result](https://github.com/chrissotraidis/kartpad/issues/123#issuecomment-5641278791); [trace correction](https://github.com/chrissotraidis/kartpad/issues/123#issuecomment-5641572501) | Owned fresh-source trace with session-entry budget; correlate the peer/deferred transition before a runtime patch or online acceptance claim |
| `samsung-sm-s921w-online` | Android14; public code80 latest comparison; GPU/pack unconfirmed | Mobile-data matchmaking versus Wi-Fi | Same reporter confirms fast connection but cannot find a room over mobile data; Wi-Fi works. Earlier four/five-race disconnect remains separate endurance evidence | `partial; awaiting-reporter` | [#206](https://github.com/chrissotraidis/kartpad/issues/206), duplicate [#277](https://github.com/chrissotraidis/kartpad/issues/277) | Continue in #206; no repeat identity/connection questions or unsupported network fix claim |
| `tecno-kj5-helio-g85` | Android API 33; public 0.4.16-android.1/code 64; reported Mali-G52 MC2, driver unknown | Original/base, 1x, 4:3, validation off | After warmup, slow sessions remain about 25–29 FPS with 94–97% main-thread occupancy and about 2.3–2.6 ms `present_total`; pipeline queue is zero. Three captures and willingness to test already supplied | `reproduced-open` | [#198](https://github.com/chrissotraidis/kartpad/issues/198) | Rebuild the stale code-73 diagnostic from current code-83 source with compatible signing and exact symbols; arrange private delivery, then one bounded warmed CPU sample. Low present time does not exclude GX CPU preparation |
| `galaxy-s24-ultra-issue193` | Android / One UI 8.5; GPU/driver unknown; public 0.4.19/code85 | Original and Retro; character selection and starting grid | Code85 still fails. Two complete DrawCheck records have finite attributes and valid PN indices; pipelines 58866e32bada1f83 and 33c5ff18d5c180e0 are present in the shipped seed database | `reproduced-open` | [#193](https://github.com/chrissotraidis/kartpad/issues/193) | Reconstruct these exact recipes and inspect dynamic matrix addressing/bindings; no repeated settings or code90 graphics test |
| `honor-yle-w09-adreno-829` | Android 16/API 36; KartPad 0.4.13-android-preview.1/build 28; Original/base report | Original/base; menus, characters, karts and race view | Reporter supplied screenshots showing corruption everywhere and Vulkan details for Adreno 829 / driver branch 512.842.36; synthetic checks do not cover the complete game draw | `reproduced-open` | [#166](https://github.com/chrissotraidis/kartpad/issues/166) | Rebuild and audit the current-source diagnostic, then on this affected target: dynamic PNMTX baseline → literal variant → dynamic baseline, with correlated draw/shader lines; do not infer a vendor-wide fix |
| `adreno-840-issue166` | Android version/device not supplied; KartPad 0.4.13-android-preview.1/build 28 | Original and Retro; visible corruption reported on both | Reporter supplied Adreno 840 / driver branch 512.842.19 and passing synthetic compute checks, while screenshots still show in-game corruption | `awaiting-reporter` | [#166](https://github.com/chrissotraidis/kartpad/issues/166) | Obtain exact device and Android version, then repeat the same controlled candidate comparison on that target |
| `galaxy-s24-ultra-issue211` | Android 16; report identifies KartPad 0.4.10-android.1/build 21; current installed build still not confirmed | Original and Retro; character rendering | Reporter identifies a Galaxy S24 Ultra (512 GB / 12 GB), confirms the characters do not load in Original and supplies a later screenshot showing the same symptom in Retro; GPU/driver and current in-app build remain unknown | `reproduced-open` | [#211](https://github.com/chrissotraidis/kartpad/issues/211); [Retro follow-up](https://github.com/chrissotraidis/kartpad/issues/211#issuecomment-5642589742) | Confirm the current in-app build/version and whether the pack is official 6.12.8, then compare against the existing S24 renderer lane without inferring a GPU or fix |
| `galaxy-s25-ultra-issue195` | Android 16/API 36; SM-S938B; GPU/driver unknown; affected report on 0.4.14-preview.1/code 63 | Retro versus/online performance | Repeatable slowdown reported at 1x/Original 4:3 with validation off; matching current-release frame/audio boundary is incomplete | `awaiting-reporter` | [#195](https://github.com/chrissotraidis/kartpad/issues/195) | Current-build Original-versus-Retro comparison with first slowdown and bounded performance lines |
| `galaxy-s25-plus-issue204` | Android 16 / One UI 8.5; GPU/driver unknown; public 0.4.16-android.2/code 65 | Original GCN Cookie Land battle | Battle fluctuates about 20–50 FPS while earlier time trials were smooth; no matched warm battle capture yet | `awaiting-reporter` | [#204](https://github.com/chrissotraidis/kartpad/issues/204) | Same warmed Cookie Land battle plus another battle under identical settings and short telemetry |
| `samsung-sm-s948b-adreno-840` | Android API 36 as reported; Adreno 840, driver unknown; public 0.4.16-android.2/code 65 | Original geometry/vertex path | Current affected-device diagnostics show the geometry defect while 14 bounded draw records are finite and in range; no shader/raster cause established | `candidate-awaiting-device` | [#137](https://github.com/chrissotraidis/kartpad/issues/137) | Rebuild current-source diagnostic with selected-draw merging disabled and actual generated-shader compilation, then affected-device dynamic/literal/dynamic comparison |
| `galaxy-z-fold-8-adreno-840` | Reported Android 17 / One UI 9; reported Adreno 840, driver unknown; public code85 | Geometry/textures | Same scene at1x/4:3, validation off still has stretched models/road corruption; reporter notes possible reduced track-icon glitches separately | `reproduced-open` | [#102](https://github.com/chrissotraidis/kartpad/issues/102) | Actual failing-draw investigation; no repeat code85 comparison or code90 graphics promise |
| `xiaomi-25057rn09g-issue215` | Xiaomi 25057RN09G; Android 15/API 35; 0.4.16-android.2/build 65; GPU/driver unknown | Original and Retro launch | Reporter confirmed black screen then Android home; video supplied. This establishes app exit, not native crash versus Java failure versus OS termination | `awaiting-reporter` | [#215](https://github.com/chrissotraidis/kartpad/issues/215#issuecomment-5648640989) | Classify one matching exit/crash result; do not repeat the already answered destination question |
| `galaxy-tab-a-2020-issue216` | Galaxy Tab A (8.4-inch, 2020); One UI 3.1; Android 11/API 30; reported 0.4.16 Android, exact build unconfirmed; GPU/driver unconfirmed | Original and Retro game launch; black surface/touch controls then exit | Reporter sees black video with touch controls before repeated exits; this does not establish a renderer fault, import completion or OS exit class | `awaiting-reporter` | [#216](https://github.com/chrissotraidis/kartpad/issues/216); [posted reply](https://github.com/chrissotraidis/kartpad/issues/216#issuecomment-5643186097) | Await the existing chooser-versus-Android-home, profile/import completion and one redacted exit result request; no reinstall/data clear/game files or shared-cause inference |
| `honor-lgn-nx3` | Android 16/API 36; public 0.4.16-android.2/code 65 | Original/Retro launch after RMCP01 ZIP install | Three duplicate reports with the same report ID say the app repeatedly kicks them out; no exit class, profile or import completion | `awaiting-reporter` | [#208](https://github.com/chrissotraidis/kartpad/issues/208), [#209](https://github.com/chrissotraidis/kartpad/issues/209), [#210](https://github.com/chrissotraidis/kartpad/issues/210) | Canonical #208 response: chooser versus Android home, selected profile, import completion and one redacted exit result |
| `samsung-a05-mali-g52` | Android version unknown; public 0.4.16-android.2/code 65; reported Mali-G52 / 4 GB RAM, driver unknown | Original and Retro menus, race entry and return | Validation off; slowdown and intermittent crashes affect both modes, worst around race entry with lag returning to menus. Reporter confirms export is available | `awaiting-reporter` | [#207](https://github.com/chrissotraidis/kartpad/issues/207#issuecomment-5645952920) | Await the already requested brief redacted crash result; build, profile and transition questions are answered. Keep sustained slowdown separate from exit classification |
| `xiaomi-2201117tg-adreno-610` | Android 16; public 0.4.16-android.2/code 65 | Game start after ISO import | Reporter says game does not start; import state, selected profile and exit class are missing | `awaiting-reporter` | [#205](https://github.com/chrissotraidis/kartpad/issues/205) | In-place Original-versus-Retro launch check and final redacted startup/exit excerpt |
| `honor-x7d-snapdragon-685` | Android 15; build pending | Game launch after import | Launch crash reported, but exact build/profile/import completion and exit evidence are missing | `awaiting-reporter` | [#143](https://github.com/chrissotraidis/kartpad/issues/143) | Exact build/profile/import state and matching exit/final console excerpt |
| `ayn-thor-max` | Android; 0.4.16 Android 2 | Display/aspect and controller paths | 3x playable; online and automatic controls reported working. Pre-title bars respond to navigation mode; persistent gameplay defect not established | `partial` | [#202](https://github.com/chrissotraidis/kartpad/issues/202), [#184](https://github.com/chrissotraidis/kartpad/issues/184) | Separate surface/inset confirmation and physical controller remap press/hold/release/persistence test |
| `moto-g200-5g` | Android; reported 0.4.16; GPU/driver unknown | In-game track selection and leaving online room; ipega controller then touch | Both touch and controller fail after controller use. Default controller mode has separate A/B mapping failure; Xbox mode was used before shared failure | `reproduced-open` | [#197](https://github.com/chrissotraidis/kartpad/issues/197#issuecomment-5649509217) | Inspect Android focus/controller handoff and release dispatch locally; existing fresh touch-only before controller comparison remains outstanding. No proven stuck-key cause or D-pad-fix acceptance |
| `infinix-hot60-pro-helio-g200` | Android 16 / XOS 16.3; KartPad 0.4.11 / Original rev0; reported Mali-G57 MC2 | Original gameplay performance | Reporter supplies 15–20 FPS gameplay and about 30 FPS menus; same performance at 1x in 4:3 and 16:9. These details already exist in the report | `awaiting-device` | [#167](https://github.com/chrissotraidis/kartpad/issues/167) | Analyze the supplied comparison; obtain a matched warmed profile only when selected. Do not ask device/build again or repeat the completed aspect sweep |
| `poco-f6-pro-snapdragon-8-gen2` | Android 15; report from 0.4.10-era build | Original/Retro performance, display and save lifecycle | Older report combines FPS drops, bars and Retro save loss; no current-build matched acceptance | `reproduced-open` | [#169](https://github.com/chrissotraidis/kartpad/issues/169) | Reclassify each symptom on a current build; do not treat it as one root cause |
| `galaxy-s25-plus-issue103` | Reported Samsung S25+ / Snapdragon Gen 4 or Elite; exact OS/build/GPU/driver unknown | Gameplay rendering and frame pacing | Reporter reports clean graphics but periodic high-40s/low-50s FPS; power-mode and resolution changes were confounded | `partial` | [#103](https://github.com/chrissotraidis/kartpad/issues/103) | Retain as a reported clean-rendering control; one matched power/settings comparison when a specific performance candidate exists |
| `retroid-pocket5-snapdragon-865` | Android version unknown; 0.4.12-android.2 and 0.4.13-android-preview.1; reported Snapdragon 865, GPU/driver unknown | Mainly Original performance, 1x, validation off | About 40–45 FPS in standard power mode versus 60 in high-performance mode with reported 52°C heat and battery drain; exact app versions/settings already supplied | `reproduced-open` | [#103](https://github.com/chrissotraidis/kartpad/issues/103#issuecomment-5590528295) | Use the completed power-profile evidence to select a CPU-cost experiment; no repeat hot-mode benchmark or settings questionnaire |
| `poco-x8-pro-cup-transition` | Android 16 / HyperOS 3.1; build pending | Original and Retro cup completion | Crash reported after final Grand Prix race before ceremony; matching exit evidence is missing | `awaiting-reporter` | [#131](https://github.com/chrissotraidis/kartpad/issues/131) | One reviewed exit/console boundary for Original and Retro |
| `iphone-17-pro-max-ios26.5-simulator` | iOS 26.5 Simulator; historical private aggregate-shard candidate | Imported Original and Retro Rewind 6.12.8 offline races | Original 50cc and Retro 200cc races plus bounded soaks survive near 60 FPS with no translated crash markers; imported WBFS hash unchanged | `simulator-pass; awaiting-device` | [#196 simulator observation](https://github.com/chrissotraidis/kartpad/issues/196#issuecomment-5640549937) | Historical only; see the failed public build-39 matching-device row below. New crash evidence must select the next source correction |
| `iphone-17-pro-max-ios-27` | iOS27.0 per new report; public build39 matched by executable UUID | Retro startup / resource report | Symbolized missing-guest-target fatal path from func_8000A3F8; numeric target absent. Disk-write report says Action none; iOS guest RAM uses file-backed shared mappings | `awaiting-reporter` | [#196](https://github.com/chrissotraidis/kartpad/issues/196) | Existing fatal target/LR text; separately investigate anonymous guest-memory aliases locally. Build42 reporting preview is not a confirmed crash fix |
| `ipad-pro-10.5-a10x` | iPadOS 17.7.6; accepted compatible build 29 | Original and Retro launch/gameplay | Earlier `LDAPRB` startup failure reporter-confirmed fixed; remaining measured performance is about 30–35 FPS Original and about 30 FPS Retro | `partial` | [#135](https://github.com/chrissotraidis/kartpad/issues/135) | Lower priority than Android performance/geometry; measured compatible-device performance comparison only after a relevant candidate exists |
| `iphone-14-pro-max-external-display` | iOS/macOS versions and adapter pending; public 0.4.16 | AirPlay/HDMI | Audio continues while KartPad freezes or is black over both paths; local-only control is not yet isolated | `awaiting-device` | [#199](https://github.com/chrissotraidis/kartpad/issues/199) | Unlock paired iPhone and run local-only → AirPlay-after-launch → HDMI-after-launch comparison |
| `galaxy-s24-ultra-issue104` | Reported Snapdragon 8 Gen 3; OS/GPU/driver unknown; build-63 comparison unchanged | Character/driver geometry | Reporter confirms corruption persisted with validation and after requested renderer-initialization update | `reproduced-open` | [#104](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5620182067) | Reuse the affected-character selected-draw experiment; no repeat validation/settings sweep |
| `oneplus-opd2514-issue120` | Android 16/API 36; code 21; GPU/driver unknown | Retro Rewind 6.12.7, stretched surfaces throughout race | Screenshot/report establishes corruption; reinstall/cache clearing already failed; no current-build response | `awaiting-reporter` | [#120](https://github.com/chrissotraidis/kartpad/issues/120) | Existing current-build same-scene check and short GPU/driver startup excerpt; do not infer GPU from model |
| `oppo-cph2669-issue236` | OPPO A40; Android 14/API 34; code 65; GPU/driver unknown | Original launch | Black screen with touch controls then Android home confirmed; duplicate #237 consolidated | `awaiting-reporter` | [#236](https://github.com/chrissotraidis/kartpad/issues/236#issuecomment-5649616748) | Matching exit history/crash signature; destination already answered, no shared renderer cause established |

## Failure families and the smallest useful experiment

The public Android baseline is **0.4.19/code 85**. Older report rows retain their
actual tested builds; release availability is not an affected-device retest.
GPU names are reported evidence, not deductions from a marketing model name.
Only #166 currently supplies driver branches in this table; unknown driver
fields are deliberate. Do not select a vendor workaround from a model name.

| Priority / family | Reports that may benefit | Minimum discriminator before a shared change | Work possible without the owner's phone |
| --- | --- | --- | --- |
| 1. Sustained frame time | #198, #167, #103, #195, #204; slowdown portion of #207/#169 | Symbolized warmed CPU sample separating guest execution, GX preparation and waits; same scene/power/thermal controls. Battle and Retro remain separate scenes | Prepare current compatible profileable APK and exact symbols; inspect sampled hot functions; retain cold compilation separately from steady state |
| 2. Missing/stretched geometry | #102, #104, #120, #137, #166, #193, #211 | Actual failing draw/shader identity and dynamic → selected literal → dynamic comparison; finite CPU matrices and passing synthetic probes are insufficient | Recover narrowly gated diagnostic, disable diagnostic draw merging, compile actual generated shaders, audit immutable APK before affected-device handoff |
| Launch/process exits | #143, #205, #208, #215, #216, #236; crash portion of #207 | Matching ApplicationExitInfo/native/Java signature, not black-screen appearance alone | Review existing exit capture/classification and known signatures; #215/#236 already confirmed Android home |
| Controller-to-touch handoff | #197 | Real release/focus dispatch and fresh touch-only control, separate from default-mode A/B mapping | Inspect Android → SDL → native input transitions and focused regression coverage |

These are **overlapping symptom families, not confirmed duplicate root causes**.
A small shared correction could help several models, but closing each report
requires its own matching scene/device evidence. Prefer one measured shared fix
over model-name special cases or bundled speculative workarounds. Sustained
Android performance is first; A10X optimization and Apple external-display
recovery remain independent, lower-priority work for this pass.

## September 15 investigation update

| Device/build scope | New evidence | State and next gate |
| --- | --- | --- |
| POCO X3 / Xiaomi M2007J20CG / API31 / Adreno618; export code90, session version unknown | Original/base at1x/4:3 records 9.81–11.29 FPS after pipeline queue empties; presentation averages about4 ms; thermal/memory context absent | CPU-side candidate awaiting matched physical comparison; [research](artifacts/2026-09-15/android-performance-research.md), [#275 reply](https://github.com/chrissotraidis/kartpad/issues/275#issuecomment-5674085700) |
| SM-S901W / Android14 / code80; profile unknown | New #278 report describes sub20 FPS in every race; existing profile/log request unanswered | Await existing discriminator; do not assume chipset or send duplicate request |
| Samsung SM-S948B / API36 / Adreno840; export code90, session version unknown | Latest #137 selected archive contains startup only, no affected draw records | Geometry remains open; this export does not establish a matrix-comparison outcome |
| iPhone14 Pro Max / iOS26.6.2 / reported0.4.16 | New #199 comparison reports frozen image with continuing audio on local screen without TV, and also AirPlay/HDMI | Reclassify as local rendering freeze with external symptoms; await requested narrow diagnostic, not another TV sweep |

Earlier rows remain historical build-specific observations; these updates do not declare them resolved. The 448,000-case emulator scalar comparison is source/correctness evidence, not a device compatibility result.

## How bots and people update the matrix

1. Use a stable `device key`; never put a serial number, account identifier or
   private path in this file.
2. Record the exact public/private build, OS/API, GPU only when the evidence
   supplies it, selected profile, settings and tested path.
3. Separate `observed evidence` from `state` and `next gate`. A reporter claim
   is not a verified pass until the corresponding acceptance step is recorded.
4. Link the GitHub issue and the dated artifact. Do not paste raw private logs,
   saves, ROMs, credentials or signing material.
5. Update the row in place when evidence changes; add a new row only when the
   device/build/path combination is materially different. Keep issue-family
   grouping in [MAINTENANCE.md](MAINTENANCE.md) and the work decision in
   [MAINTENANCE-BOARD.md](MAINTENANCE-BOARD.md).
6. Every non-pass row must have one named next gate. If the gate is external,
   set `awaiting-device` or `awaiting-reporter` and stop repeating local tests
   until new evidence arrives.

This matrix is not a compatibility promise for unlisted devices. It is an
evidence ledger used to decide which build, device and reporter action can close
the next family.

September14 follow-up: #104 reports code85 still affects only pilots at1x/4:3 while the scenery is intact; #166 reports no improvement. These negative results supersede prior requests to retry code85. Code90 is a reporting prerelease with the same native libraries as85, not another graphics or speed correction. New performance reports #275 (ambiguous Poco X3/Redmi9 model,5–10raceFPS) and #278 (SM-S901W, below20raceFPS) are acknowledged; precise missing details/session evidence are requested once. #273 has an empty-body motion-control regression report pending device/build/control-path details.
