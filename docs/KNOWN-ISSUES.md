# KartPad known issues

## Community reports reviewed 9 September 2026 (Japan time)

See the [support guide](SUPPORT.md) for workarounds and the exact diagnostic
steps. Open reports are not treated as verified root causes.
The [maintenance workflow](MAINTENANCE.md) defines how evidence advances into
reviewed fixes, platform tests and accepted builds.

| Issue | Current boundary / next evidence |
| --- | --- |
| [#137](https://github.com/chrissotraidis/kartpad/issues/137) preview1 vertex explosion | Galaxy S26 Ultra/SM-S948B, Android16, exact published cecd69c source fingerprints, Original/base and Retro not installed. Reported 4x/16:9 with validation active; settings changes did not resolve stretching. GPU/driver and actual-draw excerpts are not yet supplied. Keep related reports linked without asserting a shared cause or repeating broad settings/import tests. |
| [#143](https://github.com/chrissotraidis/kartpad/issues/143) Android game-launch crash | Honor X7D/Snapdragon685/Android15, after import and Launch. Exact build/profile/import completion and matching exit/final console excerpt requested; no renderer/CPU cause inferred from device name. Video was not accessible to the review tool. No reinstall or full archive requested. |
| [#135](https://github.com/chrissotraidis/kartpad/issues/135) iPad opening crash | iPad Pro 10.5/A10X, reported iOS 17.7.6. Binary inspection found an unsupported M2-targeted instruction in the named initializer; the supplied AI-written crash summary does not establish that it caused the reporter failure. The generic ARM64 correction is [published in iPhone/iPad 0.4.13 build 29](releases/v0.4.13-ios.1.md), with build/ISA/package audits passing. Exact-build physical A10X acceptance and a matching original crash PC/UUID remain pending. No established jailbreak/GPU cause or reporter-confirmed fix. |
| [#128](https://github.com/chrissotraidis/kartpad/issues/128), [#131](https://github.com/chrissotraidis/kartpad/issues/131) end-of-cup crash | AYN Thor Retro report and Poco X8 Pro/Android 16/HyperOS 3.1 report. #131 identifies tapping Next after the final Grand Prix race, before the ceremony, at fullscreen/3x/60 FPS; reporter now confirms Original and Retro are both affected (also mentions online). Matching reviewed exit/error excerpts are requested. Similar timing does not establish a shared cause or all-device impact. No repeat cup runs, reinstall or data clearing requested. |
| [#127](https://github.com/chrissotraidis/kartpad/issues/127) macOS two-player character offsets | Contributor reports M5 MacBook Air / macOS 27 beta / Original at PR #112 head 271fdc1, 4x, 120 FPS, borderless/notch extension. Controller input works; characters appear outside karts. Same-scene main comparison is pending; neither PR regression nor shared Android cause is established. |
| [#105](https://github.com/chrissotraidis/kartpad/issues/105) save location/transfer | The [Android 0.4.12-android.1 testing APK](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.12-android.1) adds profile-aware raw-save transfer. Reporter restored the license but saw a missing Mii and online rating 5000. Earlier raw-save transfer omitted Retro's separate `RRRating.pul` and the Mii database; login also synchronizes ratings. [Android preview 1](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.13-android-preview.1) now adds checked, matched offline rating restore; #105 has received a concrete offline test request. Mii transfer and real-save acceptance remain pending. Reporter confirmed WiiCompiled 0.2.31, Retro 6.12.7, an existing companion file in the shared Dolphin NAND, matching friend codes and a completed race without rating synchronization. Complete migration is not accepted; companion transfer needs backups and profile matching. |
| [#102](https://github.com/chrissotraidis/kartpad/issues/102), [#104](https://github.com/chrissotraidis/kartpad/issues/104) Android geometry/textures | Fold #102 supplied Vulkan/Adreno 840 driver 512.842.19 logs confirming 1x/4:3, both screen states, Retro Rewind 6.12.7. A [synthetic renderer probe](../tools/renderer-probe/README.md) tests packed decoding and uniform layouts; Mac Metal and physical Pixel Vulkan baselines pass. Adreno 840 (512.842.19) and Adreno 750 (512.762.39 / 512.762.41) all pass the compute checks; the reporter confirms matching Original corruption and no logged GPU errors. The expanded [0.2.0 diagnostic](https://github.com/chrissotraidis/kartpad/releases/tag/renderer-probe-v0.2.0) now tests synthetic indexed draws, textures and queued updates; the #104 reporter also passes all eight compute/draw checks on Adreno 750 / 512.762.41. Adreno 840 draw results remain open. #104 confirmed corruption at 1x/4:3 affecting drivers only, with vehicles/tracks correct; no more repeat logs are requested from that reporter. Character transforms and generated shaders need a failing-draw reproduction; #102’s road-texture symptom remains separate. Build-23 actual-game validation on/off is now complete on the Fold: unchanged corruption, no crash, and the supplied interval presents near 60 FPS with no queued pipelines. No repeat comparison is requested. The #104 reporter also confirms unchanged driver corruption with actual-game validation enabled; no repeat import/validation comparison requested. No verified renderer correction. |
| [#123](https://github.com/chrissotraidis/kartpad/issues/123) Pixel online-menu freezes | Pixel 8 Pro / Android 17 API 37 / Mali-G715. The reporter now confirms online-menu freezes at 1x Native / Original 4:3 with Renderer Validation off. Audio stalls and catches up while the native three-dot menu stays responsive; offline play/races work. This supersedes the earlier archive setting mismatch. Reporter replaced the earlier excerpt with a definitive console log and matching health samples: build28/API37/Retro,1x/4:3, validation ON, thermal status0 and battery30.4–31.1C. This capture is separate from the earlier validation-off result. It includes a reported 2222.337ms presentation gap and completed network-call records; synchronized source/timing review is active, no cause assigned yet. See the [timing review](artifacts/2026-09-09/pixel-online-log-review.md). Investigation targets synchronous guest/network waits; neither a network nor renderer root cause is established. |
| [#103](https://github.com/chrissotraidis/kartpad/issues/103) Android frame drops | Original reporter improved behavior after changing Game Booster+ mode and resolution; controlled comparison remains pending. A separate Retroid Pocket5/Snapdragon865 reporter reports40–45FPS at1x/standard profile versus60FPS with higher heat/power in high-performance mode, and Dolphin60FPS at standard. Reporter confirms Android .2 and preview1 with validation OFF, mainly Original (Retro installed separately). No repeat settings/benchmark requested; exact OS remains unspecified. No parity, thermal comparison or settings fix verified. |
| [#101](https://github.com/chrissotraidis/kartpad/issues/101) Fill Screen distortion | 16:9/4:3 fallback; paired scene screenshots and technical report requested. Shared projection correction needs reproduction and cross-platform checks. |
| [#100](https://github.com/chrissotraidis/kartpad/issues/100) external video black with audio | Device/output chain, local-screen behavior and connection-order comparison requested. Mirroring and a dedicated external game view need separate acceptance. Apple and Android external output are accepted priorities; see the [implementation/test plan](EXTERNAL-DISPLAYS.md). |
| [#94](https://github.com/chrissotraidis/kartpad/issues/94) console serial | Resolved: client correction is distributed on every platform. On 8 September the upstream reporter confirmed bad CSNums were removed from server history and no KartPad remediation remains; affected users should update and re-login from the same IP used for the affected license. Unavailable original IP or persistent login failure needs service-admin help, not identity resets. |
| [#91](https://github.com/chrissotraidis/kartpad/issues/91) DSU phone controller | Open experimental feature; tester identified Apple TV 4K 3rd gen and DSUController 3.0.8. Exact tvOS and phone layout requested. No DSU build yet. |
| [#90](https://github.com/chrissotraidis/kartpad/issues/90) Wiimmfi | Open compatibility feature, no release commitment. Requires matching executable integration and private identity/authentication handling, not just a MAC/host field. |
| [#5](https://github.com/chrissotraidis/kartpad/issues/5) Mii/Wii Remote | Shipped cursor/Mii work; reporter directed to current ready-made Mac download for remaining experimental Wii Remote/Nunchuk hardware results. |
| [#92](https://github.com/chrissotraidis/kartpad/issues/92) licensing clarity | Correction already merged in #93; remains open for upstream author's review. No new unanswered follow-up at review time. |

Latest renderer evidence: #104's video shows character corruption in both
vehicle selection and the starting grid, before driving. #102's second device,
Galaxy Tab S7 FE / Adreno 619, also passes all eight synthetic checks. Its
Android 14 / 0.4.10 build logs confirm Retro at 1× / Fill Screen. The latest
session ends after roughly 9 FPS with no captured termination reason; the sole
fatal report is an earlier missing-DVD-root startup, followed by successful
game loads. The tablet reporter subsequently completed a race at 4:3 after
also moving the app from microSD to internal storage. Both changed, so neither
is established as the cause; keep that working setup. These are separate
observations, not one established GPU bug.

[#120](https://github.com/chrissotraidis/kartpad/issues/120) adds a OnePlus
OPD2514 / Android 16 / build 21 / Retro 6.12.7 report with large stretched
surfaces obscuring the race. Reinstalling and clearing caches did not help.
The exact GPU/driver is not inferred from the device name.

The [Android 0.4.12-android.2 diagnostic beta](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.12-android.2)
adds opt-in validation/bounds protection for the actual game renderer and
bounded OS exit history. It also fixes the Android system bars remaining visible
during play ([#119](https://github.com/chrissotraidis/kartpad/issues/119)); local
release-emulator checks cover launch, menu return, Home/resume and transient
edge swipes. The AYN Thor reporter in #128 says system bars still remain visible on build 23; display, affected bars and launch/resume behavior are requested. Device-wide resolution is not established. Normal mode keeps the
previous renderer toggles.
Local host/emulator checks pass; affected Adreno testing and a failing game
draw remain open. This is an Android diagnostic, not a macOS/iPadOS fix.

## macOS contribution under local review

[#112](https://github.com/chrissotraidis/kartpad/pull/112) proposes controller
assignment/profiles, trigger bindings, native settings and menu integration.
The revised contributor head `271fdc1` includes the trigger correction and
a narrower controller layout. The full dual runtime rebuilds and audits, the
200-case trigger/profile checks pass, and the right-hand controls fit in the
actual native window. A local Apple Silicon candidate (0.4.12/build 27) is
available. It is **not approved**: physical controller/race acceptance remains open. A portable contributor guide
is prepared on the maintainer review branch. See the [local review record](artifacts/2026-09-08/macos-pr112-review.md)
for exact source and acceptance limits.

Next work prioritizes physical acceptance of the corrected controller candidate
and collecting real-save acceptance for the published Android rating companion
importer. #105 has supplied source/profile evidence and received a concrete
offline test request; no further preliminary log request is needed. Ratings are loaded into memory and separately
synchronized by network code, so live file replacement is not an accepted sync
workflow. Android character rendering needs an actual
failing draw reproduction; synthetic passes are insufficient. Performance and
external-display reports still need their requested comparisons. DSU and
Wiimmfi remain independent feature work, not bugs blocked solely on logs.

Profile-aware save management, reusable network-controller input, and any
shared projection/service fixes need platform-specific UI and acceptance work.
An Android picker or a tvOS prototype does not establish parity across hosts.

## Latest macOS PR source boundary

The contributor confirms the physical controller results were obtained on
`271fdc1`, on Original only. Later cleanup and keyboard-panel commits advance
PR #112 to `d18d3e6`; the old local candidate does not include them. Review and
focused tests must use the new source before claiming that acceptance transfers.
Owner and Retro acceptance remain open.
