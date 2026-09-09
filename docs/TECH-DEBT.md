# Technical debt

This file records useful engineering directions that have not fully cleared
KartPad's acceptance gates. An entry is not a release promise or evidence that a
feature works on untested hardware. External pull requests listed here are source
material only; any follow-up is maintainer-owned and its completed and remaining
gates are stated explicitly below.

## Current priorities across platforms

Reviewed 9 September 2026 against [known issues](KNOWN-ISSUES.md), the
[maintenance board](MAINTENANCE-BOARD.md) and their dated evidence. This document
records engineering gaps and what would demonstrate progress; the board owns
assignments and candidate status. The [Android investigation handoff](ANDROID-PERFORMANCE-HANDOFF.md)
contains the current ranked experiments and installed/candidate build distinctions. Open reports are not automatically one shared
bug. The tvOS experiments below remain useful, but are not the whole debt queue.

### Android stability and performance

Android is the main current stability priority. Public preview 1/code 28 adds
rating restore and diagnostics, with offline rating transfer now reporter-confirmed.
It is **not** a verified graphics, freeze or crash fix. Preview 2/code 29 is a local candidate, not a published download.

| Work / reports | Established evidence and remaining gap | Next discriminating check / acceptance |
| --- | --- | --- |
| Character/geometry corruption: [#102](https://github.com/chrissotraidis/kartpad/issues/102), [#104](https://github.com/chrissotraidis/kartpad/issues/104), [#120](https://github.com/chrissotraidis/kartpad/issues/120), [#137](https://github.com/chrissotraidis/kartpad/issues/137) | Multiple Adreno devices pass synthetic renderer probes while actual characters remain corrupted. Validation on/off has not resolved reported corruption; road textures may be a separate symptom. No verified rendering correction. | Reproduce a failing game draw and trace its transform/upload/shader inputs; verify a correction on affected hardware and a non-affected GPU. Avoid repeating already-completed synthetic or settings tests. [Draw evidence](artifacts/2026-09-09/graphics-preview28-evidence.md). |
| Online-menu stalls: [#123](https://github.com/chrissotraidis/kartpad/issues/123) | A matched build-28 log shows a 2.222-second presentation gap with thermal status 0. Recorded receive waits lie outside that gap. A separate actual-HLE probe reproduced alarm rescheduling under a recursive pump guard; its Android correction is merged, but reporter causality is unproven. | Compare the exact corrected candidate on the affected gameplay path; correlate guest progress, callbacks and presentation. Require real freeze/audio behavior to improve before calling it a fix. [Timing review](artifacts/2026-09-09/pixel-online-log-review.md), [local candidate](artifacts/2026-09-09/android-preview2-local-candidate.md). |
| Slowdown, frame pacing and heat: [#103](https://github.com/chrissotraidis/kartpad/issues/103) | Performance varies with device power mode, scene, compilation and heat. An independently reviewed scalar-context optimization remains separate from released builds; a synthetic multiply improvement is not a game FPS gain. | Matched cold/warm runs at the same resolution, track and power mode, measuring frame-time tails, audio and thermal state. Benchmark the optimization in-game before integration or performance claims. [Review boundary](artifacts/2026-09-09/maintenance-source-reviews.md), [performance guide](PERF.md). |
| End-of-cup crashes: [#128](https://github.com/chrissotraidis/kartpad/issues/128), [#131](https://github.com/chrissotraidis/kartpad/issues/131) | Reported after Next at the final race, before awards, with Original and Retro both reported affected. Shared awards/resource paths are identified; the matching termination cause is not. | Use the requested exit/console evidence to classify the failure, then exercise the affected awards transition. Do not infer a Retro-only bug or require destructive reimports. [Investigation](artifacts/2026-09-09/cup-transition-investigation.md). |
| Game-launch crash: [#143](https://github.com/chrissotraidis/kartpad/issues/143) | Honor X7D / Snapdragon 685 report after import and Launch. Exact build/profile and matching termination evidence are still needed. | Separate importer completion from native launch and identify the failing boundary before choosing a CPU/GPU correction. Do not infer incompatibility from the chipset name alone. |
| System bars and aspect: [#119](https://github.com/chrissotraidis/kartpad/issues/119), [#101](https://github.com/chrissotraidis/kartpad/issues/101) | System-bar handling has shipped changes but reporter/device confirmation remains separate. Fill Screen distortion needs its own projection/presentation reproduction. | Verify focus, chooser/game transitions and system UI on the affected device; compare the same scene in 4:3, 16:9 and Fill. Keep UI lifecycle separate from character corruption. |
| Save/rating/Mii migration: [#105](https://github.com/chrissotraidis/kartpad/issues/105) | Preview 1 implements reviewed, backed-up, matched offline rating restore; the reporter confirmed successful offline transfer on 8 September. Raw save export does not carry the Mii database, and file copying is not online rating synchronization. | Preserve that confirmed result rather than repeating the completed test request. Design Mii transfer, server-sync tests and Apple UI parity independently, preserving unrelated identities and licenses. [Support workflow](SUPPORT.md). |

### Apple and shared runtime gaps

- **Older-device launch (#135):** iPhone/iPad 0.4.13 build 29 ships the reviewed
  generic ARM64/RCpc-disabled correction. The final binary and initializer were
  audited. The reporter has now supplied original crash text for **0.4.0/build 15**;
  correlate it with that exact old binary, rather than the inspected 0.4.11.
  Do not request the same report again. Build 29 physical A10X launch remains
  pending. This is
  distinct from the tvOS A12 gate below. [Build evidence](artifacts/2026-09-09/ios-preview-build29.md).
- **External displays (#100):** source review found that surface recovery can
  replace the SDL Metal view and detach its controls. A real mirroring trigger
  is not established. Correct ownership with a forced-recovery regression,
  then test wired/wireless connect, disconnect and resume on each platform.
  [Source evidence](artifacts/2026-09-09/external-display-surface-ownership.md),
  [display plan](EXTERNAL-DISPLAYS.md).
- **Mac input and two-player rendering:** PR #112 still needs capture-cancel
  and physical-scancode corrections plus hardware acceptance. #127's character
  offsets need a same-scene main/PR comparison; controller success does not
  establish rendering correctness. [Current boundaries](KNOWN-ISSUES.md).
- **Diagnostics:** richer context/provenance is published on Android preview 1
  and iPhone/iPad build 29. Physical report export/share still needs acceptance
  on the exact Apple package. Use existing targeted logs first; bounded samples
  can miss a failing draw or an indefinitely blocked call. More logging without
  a discriminating experiment is not itself a stability fix.
- **Retro version compatibility and online behavior:** keep compiled profiles,
  installed content and service compatibility distinct. Apple pre-launch and
  Android install-time update checks are not identical. Future version rollout
  needs mismatch/recovery tests, plus exact-build race/results/reconnect checks;
  changing a pack or server field cannot add new executable compatibility.
  [Upstream updates](UPSTREAM_UPDATES.md), [online limits](ONLINE.md).
- **Long-session and peripheral acceptance:** sustained frame pacing/audio,
  motion steering, reconnect and complete three/four-player results remain
  per-platform gates. DSU (#91) and Wiimmfi (#90) are separate feature work,
  not already-supported paths. [Acceptance](PHYSICAL-ACCEPTANCE.md),
  [future features](FUTURE-FEATURES.md).

## Android device report register

GitHub issue bodies and replies reviewed on **9 September 2026, 01:57 UTC**.
These rows preserve the reported device/build combinations and their outcomes;
they are not a certified compatibility list. Build numbers below belong to the
reported sessions, not necessarily the current download or the owner's active
Android work. Source links identify the relevant issue or follow-up. Existing
[known issues](KNOWN-ISSUES.md) retain detailed investigation history, and the
[maintenance board](MAINTENANCE-BOARD.md) retains work ownership.

### Graphics, startup and completion failures by device

| Device and reported software | Tested build/profile | Reported failure and useful positive evidence | Remaining work for this device |
| --- | --- | --- | --- |
| **Galaxy Z Fold 8 / SM-F971U**; Android 17 / One UI 9; Vulkan Adreno 840, driver **512.842.19** in supplied startup excerpt | 0.4.10-android.1/code 21, Retro 6.12.7; Original also reported corrupted. Later actual-game validation comparison on code 23 | Stretched characters and road-texture problems persist folded/unfolded and at 1x/4:3. Code 23 ran without crashing during the supplied interval, near 60 FPS, but corruption was unchanged with validation. [Device/log details](https://github.com/chrissotraidis/kartpad/issues/102#issuecomment-5576923553), [code-23 result](https://github.com/chrissotraidis/kartpad/issues/102#issuecomment-5581255824). | Reproduce an actual failing character draw; retain road textures as a potentially separate defect. Retest the affected screen state and both profiles when a relevant correction exists. Do not repeat completed reimports or validation comparisons. |
| **Galaxy S24 Ultra**; Android 16 / One UI 8.5; Snapdragon 8 Gen 3; probe reports Adreno 750, **512.762.41** | 0.4.10-android.1, Original; later validation-on result does not restate exact APK | Racer models remain corrupted at 1x/4:3; reporter says vehicles and track look correct. Synthetic compute/draw checks passed, reimport did not help, and actual-game validation did not remove corruption. [Device/settings](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5576571212), [driver/probe](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5578298862), [scene distinction](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5578549139), [validation result](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5586910901). | Character transform/animation/shader reproduction is the next lead. Here “drivers glitch” means the **racers**, not proof of a GPU-driver bug. Preserve correct karts/tracks as a regression comparison. |
| **Galaxy Tab S7 FE 5G / SM-T738U**; Android 14 / One UI 6.1; probe Adreno 619, **512.502.0** | 0.4.10-android.1; Retro; initially native resolution / Fill Screen | Initially reported an exit before the first match. All eight synthetic checks passed. Later completed an entire race at 4:3 after also moving the app from microSD to internal storage. [Device/probe](https://github.com/chrissotraidis/kartpad/issues/102#issuecomment-5578598186), [OS/settings](https://github.com/chrissotraidis/kartpad/issues/102#issuecomment-5578959929), [successful race](https://github.com/chrissotraidis/kartpad/issues/102#issuecomment-5579111251). | Preserve that working setup. Two variables changed, so neither storage nor aspect is an established cause or universal fix. Original, repeat sessions and cup completion remain unspecified; do not make the reporter undo success merely to reproduce the old failure. |
| **OnePlus OPD2514**; Android 16/API 36; GPU/driver unknown | 0.4.10-android.1/code 21, Retro 6.12.7 | Reports incorrect textures throughout play; reinstall/cache clearing did not help. Existing image review records stretched surfaces obscuring the race. [Report](https://github.com/chrissotraidis/kartpad/issues/120). | Obtain actual renderer identity and failing scene evidence already requested. Keep the model identifier as supplied; do not guess chipset or attach another OnePlus device's driver. No confirmed working configuration. |
| **Galaxy S26 Ultra / SM-S948B**; Android 16/API 36; GPU/driver absent from technical report | 0.4.13-android-preview.1/code 28; Original/base; Retro not installed; source cecd69c | Reports stretched geometry every launch at 4x/16:9 and 60 FPS with validation on. Settings changes reportedly did not resolve it. [Report and technical context](https://github.com/chrissotraidis/kartpad/issues/137). | Match requested GPU/driver and actual-draw evidence to this build. A supported Retro version printed in the report does not mean Retro was installed or running. No broad settings retry or shared-driver diagnosis is justified. |
| **Honor X7D**; Snapdragon 685; Android 15; reported 8 GB RAM; GPU/driver unknown | “Latest prerelease”; exact version/code and profile unknown | Reporter opens app, adds game file, presses Launch, then app crashes every time. [Report](https://github.com/chrissotraidis/kartpad/issues/143). | Confirm importer completion, exact build and matching exit/last console evidence. RAM capacity alone does not diagnose memory pressure, and the chipset name does not prove incompatibility. No successful gameplay milestone established. |
| **AYN Thor**; OS/GPU/driver not supplied in issue | 0.4.12-android.2/code 23; Retro | Reaches the end of a cup, then reportedly crashes; system bars/fullscreen remain problematic. Original impact was speculation in this report. [#128](https://github.com/chrissotraidis/kartpad/issues/128). Separate owner-supplied comments identify the top time/battery bar and request D-pad/shoulder/trigger/stick-click remapping. | Classify cup exit using the existing request; separately verify immersive-mode lifecycle and selected aspect on the affected display. Do not transfer another device's Original result to this Thor. Use the [Thor follow-up](artifacts/2026-09-09/reddit-android-report-triage.md#additional-ayn-thor-report--9-september-2026) for controls and missing attribution. |
| **Poco X8 Pro**; Android 16 / HyperOS 3.1; GPU/driver unknown | Report says “0.4.12 build 2”; exact Android version code unresolved; Original and Retro subsequently confirmed | Grand Prix at fullscreen/3x reportedly stays at 60 FPS until Next after the final race closes the game before the ceremony. Reporter also mentions online, without a separate online reproduction. [Initial report](https://github.com/chrissotraidis/kartpad/issues/131), [profile follow-up](https://github.com/chrissotraidis/kartpad/issues/131#issuecomment-5587364209). | Match the exit to the awards transition and establish the exact APK. Do not silently translate “build 2” into code 23 or claim all devices/modes fail. Passing race performance does not close the transition crash. |

### Performance and online behavior by device

| Device and reported software | Tested build/profile | Reported failure and useful positive evidence | Remaining work for this device |
| --- | --- | --- | --- |
| **Galaxy S25+**; reported Snapdragon Gen 4/Elite; exact OS/GPU driver unknown | Exact APK/profile unknown; initially 1x | Reports clean graphics for about 20 minutes but repeated high-40s/low-50s FPS dips. Changing Game Booster+ from battery saver to performance **and** resolution to 4x reportedly produced 55–60 FPS. [Report](https://github.com/chrissotraidis/kartpad/issues/103), [follow-up](https://github.com/chrissotraidis/kartpad/issues/103#issuecomment-5574390735). | Preserve clean rendering as a comparison to Fold/S24. Two settings changed: higher resolution is not a demonstrated fix. Exact build/driver and the already requested controlled comparison remain missing. |
| **Retroid Pocket 5**; Snapdragon 865; OS/GPU driver unknown | 0.4.12-android.2 and 0.4.13-android-preview.1; mainly Original; validation off | Standard power profile/1x reportedly stutters at 40–45 FPS; high-performance mode reaches 60 with greater heat/battery use. Dolphin comparison is reporter evidence, not a controlled benchmark. [Performance report](https://github.com/chrissotraidis/kartpad/issues/103#issuecomment-5589429674), [build/profile confirmation](https://github.com/chrissotraidis/kartpad/issues/103#issuecomment-5590528295). | Await a candidate with a specific measured reason to improve this path; no repeated hotter-profile or Dolphin benchmark needed now. Keep the separate Reddit **Retro** report distinct; installed Retro content does not change which runtime an Original session used. |
| **Pixel 8 Pro**; Android 17/API 37; Vulkan/Mali-G715 in reviewed log; driver version not recorded here | Initial code 23, Retro 6.12.7; definitive later log code 28, 1x/4:3, validation **on** | Offline play, spectating and one online race reportedly worked; online menus freeze with audio catch-up and disconnects while the native menu responds. Earlier validation-off failure is a separate observation. Later matched log records a 2.222-second gap at thermal status 0. [Report](https://github.com/chrissotraidis/kartpad/issues/123), [definitive log/context](https://github.com/chrissotraidis/kartpad/issues/123#issuecomment-5589711600), [timing analysis](artifacts/2026-09-09/pixel-online-log-review.md). | Correlate guest progress and presentation through the failing online transition on the targeted candidate. Recorded receive waits outside the gap do not diagnose it. A successful race does not validate between-race menus; no repeat generic logs requested. |
| **Poco X6 Pro**; one Reddit commenter reports Dimensity 8300U; OS/GPU driver unknown | APK/profile unknown in supplied Reddit export | Separate comments describe repeat-play decline from about 40 to 20 FPS, and 60 FPS menus versus 25–30 racing with 15–21 FPS sections and no graphical glitches. [Attributed Reddit evidence](artifacts/2026-09-09/reddit-android-report-triage.md). | Establish exact build/profile and repeat/scene trigger before a device-specific comparison. This is not the Poco X8 Pro cup-crash report. Do not infer a shared MediaTek failure or combine two comments into one measured session. |

### Device identity and driver claims

- Separate the **reported marketing name**, OS/firmware, logged GPU/driver,
  APK identity and runtime profile. Keep contradictory or missing fields visible
  until resolved; never fill them using another device with a similar name.
- Adreno 750 **512.762.39** probe results also appear in
  [#102](https://github.com/chrissotraidis/kartpad/issues/102#issuecomment-5578283020).
  That comment does not identify the handset. Do not attach it to the S24 Ultra
  row, whose own probe reports **512.762.41**, or count it as an identified model.
- No reviewed report establishes a GPU-driver root cause. A driver version is
  a comparison key, not a diagnosis. Passing synthetic probes does not clear the
  actual game; clean output on another Samsung device does not clear all Adreno
  devices either.
- The S24 reporter asked about Turnip. The
  [existing response](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5581427321)
  records that KartPad has no custom-driver loading option. Keep a possible
  alternate-driver experiment separate from available installation advice;
  downloading a driver ZIP is not a working KartPad workaround.
- **#101 is an iPhone 15 Pro Max Fill Screen report**, and **#100 begins with
  iPhone/iPad external video loss**. They provide related design/investigation
  context, not additional Android failure counts. The device-free “all devices”
  claim in #119 also does not establish all-device coverage.

### Use this evidence to improve installation and device acceptance

The goal is a reliable path for each affected device, not a phone-name blacklist
or a collection of unverified “best settings.” Before a device-specific fix or
recommendation is accepted:

1. **Identify the install route.** Record fresh install versus in-place update,
   exact APK/code and required platform capabilities. Preserve the supported
   same-signer/forward-update path; a signing conflict is separate from a
   runtime crash. No new package-install defect was established by this review.
2. **Verify first-run prerequisites.** Separate file selection, identity
   validation, available destination storage, successful extraction and official
   Retro installation. Keep the existing [checked-import behavior](artifacts/2026-09-08/android-import-storage-errors.md).
   A rejected format should produce an actionable error without replacing valid
   game data. The Reddit “cannot load” comments do not establish a broken APK.
3. **Exercise the affected path.** Reach the chooser/title and race, then the
   specific failing action: character scene, final-cup Next, online selection,
   resolution change or Thor menu/resume. Include the real input/display route.
   A launch-only check cannot mark a device playable without qualification.
4. **Keep success and failure on the same record.** For repeat-play performance,
   record duration, frame-time stalls and thermal/power context. For cups, verify
   results/progress. For online, distinguish login, race and return-to-menu.
   Do not require unrelated tests from every reporter; select what validates
   the correction and its relevant regressions.
5. **Publish only the verified scope.** Update this row and the linked issue
   with the exact accepted build, tested scenario and remaining limitations.
   If a setting helps one device, record what changed and whether it was tested
   independently. Confirm safe update and retained saves/settings where affected.
   Runtime owners continue to use the existing candidate ledger; this register
   does not commission another build or phone session.

### Additional flow gaps found in GitHub replies

- **Finding the right diagnostic session (#104):** the reporter encountered
  several `base_.../console.log` folders and did not know why exit metadata sat
  outside `Logs`. This is concrete support-flow evidence for the session-summary
  work below. Use recognizable session time/build/profile and symptom-specific
  file guidance; accept reports in the user's language. Do not make them collect
  every folder. [Reporter question](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5580450816).
- **Mii database transfer (#105):** the latest
  [follow-up](https://github.com/chrissotraidis/kartpad/issues/105#issuecomment-5594344231)
  proposes importing Dolphin's `Wii/shared2/menu/FaceLib/RFL_DB.dat`. Existing
  Android Mii storage uses that database layout and the app has an individual
  Mii import UI; whole-database PC migration is not thereby accepted. Specify
  validation, merge versus replacement, duplicate/conflict behavior, retained
  local Miis and license links, backup and restart behavior before implementation.
  This does not reopen the [confirmed offline rating transfer](https://github.com/chrissotraidis/kartpad/issues/105#issuecomment-5586429782).
- **Automatic save/rating synchronization (#105):** the same follow-up suggests
  a user-accessible folder and newest-file copying through Syncthing. Treat it
  as a proposal, not proof that modification time resolves conflicts or that
  ratings have no server behavior. Design stopped-game import/export of matched
  save/rating data, conflict detection, stale in-memory handling and recovery
  before any automatic sync. Mii transfer and server synchronization remain
  separate acceptance cases; never overwrite live app-private files as advice.
- **Preferred launch mode (#105):** an earlier
  [request](https://github.com/chrissotraidis/kartpad/issues/105#issuecomment-5576572576)
  asks to start Original or Retro automatically. Deferred convenience work:
  preserve prerequisite/version checks, actionable failures, recovery to the
  chooser and a way to change preference; do not bypass setup to hide confusion.

## Android community reports and flow gaps

Status: triaged on 9 September 2026; runtime symptoms remain reporter claims
unless independently supported below. See the
[Reddit report mapping](artifacts/2026-09-09/reddit-android-report-triage.md)
for source attribution, exact observations, GitHub links and missing evidence.
The owner reports ongoing Android build work; its current build/test stage is
not verified here. These unversioned Reddit reports neither validate nor reject
that candidate. Retain the existing
[known-issue evidence](KNOWN-ISSUES.md) and avoid duplicate issue filings.

### Order of operations

The largest recurring problem areas are getting into the game, rendering it
correctly, and keeping gameplay smooth. This is an impact-based work order,
not a measured ranking by affected user count: the supplied comments do not
identify enough builds, sessions or unique devices to calculate failure rates.
Crashes during a cup also matter even when individual races work.

Keep the [maintenance board](MAINTENANCE-BOARD.md) as the work-owner and candidate
ledger. This section defines how to choose and finish work; it does not assign
another Android builder or supersede the active owner's test. Consult its latest
handoff for the build's exact identity, included changes and observed results
before requesting another comparison. The
[Android investigation handoff](ANDROID-PERFORMANCE-HANDOFF.md) owns the ranked
runtime experiments; the order below guides community triage and does not
reassign that work. A completed build alone changes none of the issue acceptance
states.

| Order | Work and reason | Next bounded action | Completion condition |
| --- | --- | --- | --- |
| 1. Classify and reuse evidence | “Does not work” cannot select an engineering fix. Do this for new reports while existing investigations continue. | Identify the last successful step using the table below; link an existing issue and record exact build/profile when available. Mark missing details unknown. | Each actionable report has a failure category, evidence link and one next question or experiment. Vague reports remain unclassified, not counted as confirmed crashes. |
| 2. Remove setup and session blockers | Import/launch failures (#143 and Reddit setup reports), plus cup-ending crashes (#128/#131), prevent starting or completing play. | Correct the confirmed import wording in a focused future change; classify startup exits; use the existing awards/resource investigation for the cup transition. Treat these as separate fixes. | An affected setup reaches valid game data and gameplay; the failing cup transition reaches the ceremony/menu with expected progress retained. One successful race does not close a cup crash. |
| 3. Fix broken graphics | #102/#104/#120/#137 can make a running game unusable. Existing diagnostics already narrow the work. | Review captured game-draw evidence, then isolate a failing character transform, upload or shader path. Compare the same scene with a known-good rendering result. | The affected device renders the failing scene correctly on the identified candidate; relevant Original/Retro and unaffected-device regression checks pass. Synthetic probes alone are insufficient. |
| 4. Stabilize gameplay and transitions | #103 slowdowns, #123 online stalls and the Reddit resolution-change freeze interrupt different parts of play. | First interpret the active build's targeted results. Measure sustained/repeat gameplay separately from online-menu waits and live resolution changes; select one supported hypothesis per experiment. | Matched gameplay improves without an unacknowledged power/heat cost; online and resolution transitions each pass their own formerly failing sequence. A higher average FPS cannot close a freeze. |
| 5. Finish presentation and control gaps | System bars #119, aspect distortion #101 and trigger/stick-click mapping affect usability. External output #100 and save migration #105 retain separate plans. | Take small ready fixes without disturbing higher-priority investigations. Confirm the exact affected route/controller; preserve the now-confirmed offline rating transfer in #105; investigate Mii and server synchronization separately. | Affected-device behavior and persistence/lifecycle checks pass; save, Mii and rating transfer boundaries remain explicit. Do not call partial transfer complete migration. |

This order is not a rule to wait idle on a missing log. Continue the highest
impact ready, unowned investigation when another needs device evidence. Promote
any newly confirmed data loss, broad startup regression or reproducible hard
freeze ahead of tuning and convenience work. Save-transfer mismatches do not
currently establish data loss. Feature requests such as DSU, Wiimmfi, a Switch
port or higher FPS caps do not block these fixes. Apple-only reports retain
their own owners and acceptance; Android results cannot close #135 or #127.

### Turn “it does not load” into an identifiable failure

Ask for the last screen that worked and what happened next before asking for
logs. The following categories describe observations, not proposed causes.

| Last successful step / symptom | Classify as | Useful next evidence |
| --- | --- | --- |
| Android refuses to install/update the APK | Package installation | Exact installer error, APK version, Android version and whether this is an update. Check package requirements, signer/version conflict and space without uninstalling. The Reddit export does not establish a package-installer defect. |
| APK installs, but no KartPad chooser appears | App startup | Exact build and any available matching OS exit reason; an in-app export is unavailable if the chooser never opens. Absence of an exit record is inconclusive. |
| Chooser opens, but a file/folder cannot be selected or import rejects it | Input selection/import | Picker versus validation failure, input format, reported region/revision, exact error and whether previous valid data still works. Do not request the image itself. |
| Base data works, but Retro setup is missing or rejects content | Retro setup | Selected mode, base-data readiness, pack version and visible installer/error state. Distinguish downloading the pack from importing the base game. |
| Import finishes, Launch is pressed, then app exits | Game startup crash | Matching build/profile, last session console lines and OS exit record when available; #143 is this reported path. |
| Launch gives black/frozen video while app or audio continues | Game startup/render stall | Whether native menu, audio and frame presentation continue; last completed startup step and bounded renderer/runtime context. Do not automatically call it a crash. |
| Game runs with stretched characters or wrong textures | Rendering corruption | Exact scene, character/vehicle, build, profile, GPU/driver and screenshot. Reuse #102/#104 evidence rather than rerunning completed import/validation checks. |
| Game slows during a race or on repeat play | Performance | Course/section, cold versus repeat session, elapsed play time, settings, power mode and matching timing/thermal samples. |
| Game stops only after Next, an online action or a settings change | Transition failure | Exact action and before/after state; distinguish cup crash, online stall and resolution freeze. Preserve separate reproductions even on the same device. |

Storage capacity, RAM pressure and thermal/power limits are different questions.
Do not infer any of them from the phone model, low FPS or a generic launch
failure. Existing [import storage checks](artifacts/2026-09-08/android-import-storage-errors.md)
already reject insufficient space and failed extraction while retaining previous
data in local validation. Preserve those checks and verify which APK a report
used before proposing them again. Android exit diagnostics can report a
`low_memory` reason where the OS supplies it; battery/thermal samples do not
measure RAM or GPU memory exhaustion. Add resource measurements only when they
can distinguish a concrete suspected failure.

### Reporting debt: join the right evidence, then add only what is missing

Status: useful diagnostics exist; a simpler failure-oriented reporting flow
needs design and acceptance. This documentation does not implement it.

Current Android source already exports version/profile/settings context,
session console logs, performance/health samples and bounded OS exit history.
The issue template already asks for build, device, steps and performance
settings. The gap is making these usable for the specific failed session:

- `report-context.json` describes export time. It must not relabel old logs as
  the new build after an update. Chooser context may not know the active runtime
  validation state; a saved next-launch setting is not evidence of the previous
  session's active setting. See
  [`KartPadDiagnosticExport.kt`](../android/app/src/main/java/dev/kartpad/android/KartPadDiagnosticExport.kt).
- Define a compact local session summary tied to the build/profile at session
  start, with monotonic timing and the last completed startup/transition step.
  First audit existing markers; fill demonstrated gaps instead of adding a
  second independent log system. An unfinished step is a lead, not proof it
  caused termination; manual stops and normal exits must remain distinguishable.
- Let a future chooser report flow select the failed session, show its last
  known step and guide the user to a bounded, reviewable excerpt. Explain that
  opening GitHub does not attach the report. Retain a local-only export and
  the fallback for failures before the chooser opens; no automatic uploading.
- Capture transitions such as scale changes or entering online menus only if
  missing timing prevents a specific decision. Log old/new state and completion
  with bounded retention; avoid per-frame disk writes and verbose normal-play
  tracing. Gate expensive renderer diagnostics behind explicit investigation.

Acceptance: reproduce a classified startup failure and a recoverable stall in
appropriate controlled tests; the report identifies the correct session/build,
last step and available evidence without needing the whole private archive.
Check export after an update, manual stop, missing OS history and failure before
runtime initialization. Missing data stays unknown, no private paths/accounts
are exposed in the share summary, and diagnostic overhead is measured on the
affected path. Better reporting is complete when it enables a troubleshooting
decision, not when it emits more lines.

### Record what “works” actually means

Use one evidence entry per source, device, exact build, profile and test scenario
in the dated investigation record linked from the existing issue. Record:

- source/comment and review date; device/OS and GPU/driver where supplied;
- app version/code and source/artifact identity when known; Original or Retro
  and content version; scene/mode, settings, controller and display path;
- furthest observed milestone: chooser, validated import, title, completed race,
  completed cup, repeat session, or online race/results; duration when known;
- outcome and evidence level: reporter claim, inspected logs/image, locally
  reproduced, or affected-device confirmation; next action/dependency.

Store missing fields as unknown. A versionless “works great” stays a positive
claim with unspecified coverage; it is not a compatibility pass. Record failure
and successful milestones together: a Thor can complete races yet crash at cup
results; a Fold can present near 60 FPS yet corrupt characters. Keep Retroid
Original and Retro observations separate. Do not infer that matching handles or
devices across sites represent the same person, or count repeated advice as
additional devices. The [dated comparison examples](artifacts/2026-09-09/reddit-android-report-triage.md#comparison-examples-for-future-reviews)
show how existing reports fit this approach.

### Finish each investigation with a decision

1. Name one question and reuse existing evidence. Choose a reproduction and
   the observation that would support or reject the hypothesis.
2. Change one relevant variable where practical. For performance, match build,
   scene, profile, resolution, power mode and starting thermal condition; report
   any unmatched conditions. Retain frame-time/stall evidence, not only FPS.
3. Record supported, rejected or unresolved, with the next action. If a test
   passes while the actual game still fails, narrow the reproduction instead
   of requesting the same test again. If blocked, identify the exact missing
   input and continue other ready work.
4. For a correction, distinguish implemented, reviewed, merged, packaged,
   locally tested, affected-device accepted and released in the existing board.
   Ask for a targeted retest only when a candidate addresses that report or a
   new comparison will discriminate between remaining explanations.
5. Close only the demonstrated scope. Verify the formerly failing action and
   the relevant regression path; link the exact candidate and result. Keep
   other profiles/devices or transition failures open where evidence is absent.

### Performance, graphics and fullscreen follow-through

Poco X6 Pro repeat-session/track-dependent slowdown and the Retroid Pocket 5
comparison belong with [#103](https://github.com/chrissotraidis/kartpad/issues/103),
while retaining device, profile and cold/repeat distinctions. Fold corruption
overlaps [#102](https://github.com/chrissotraidis/kartpad/issues/102); vague
“not working” reports still need a failure stage. Thor fullscreen likely relates
to [#119](https://github.com/chrissotraidis/kartpad/issues/119), but system bars
and aspect-ratio letterboxing must be distinguished first.

An [additional owner-supplied Thor comment](artifacts/2026-09-09/reddit-android-report-triage.md#additional-ayn-thor-report--9-september-2026)
explicitly identifies the **top time/battery status bar** remaining visible,
alongside the game not filling the screen. Record the status-bar symptom under
#119/#128. Keep unused screen area separate until the selected aspect mode,
display and screenshot distinguish expected letterboxing, system-inset sizing
and a Fill Screen defect. No bottom-bar symptom or candidate-build result was
supplied. Do not count this as a new unique affected device without attribution.

Thor presentation acceptance: the top status bar hides during normal gameplay
and hides again after menu/resume or a transient edge swipe; controls remain
accessible. At the chosen aspect mode, the game uses the intended content area
without unintended crop/stretch. Verify 4:3, 16:9 and Fill Screen separately on
the reported display; expected letterboxing is not itself a defect.

Acceptance needs the exact tested APK and a targeted affected-device result:
same-scene cold/repeat performance with power/thermal context, an actual failing
game draw for graphics work, or launch/menu/resume system-bar behavior for
fullscreen. Existing synthetic renderer passes, emulator checks, another
device's success and CPU microbenchmarks do not close these reports. Reuse
already supplied evidence; the Retroid GitHub reporter needs no repeat hot
profile or Dolphin benchmark now. No vendor-wide diagnosis is established.

### Disc import and Retro Rewind setup clarity

Status: reported confusion plus a source-confirmed messaging inconsistency;
no reproduced import failure.

The current chooser routes through base-data setup before Retro installation.
[`RetroRewindInstallActivity.kt`](../android/app/src/main/java/dev/kartpad/android/RetroRewindInstallActivity.kt)
already offers **Download official pack**. The fallback status in
[`KartPadGameDataActivity.kt`](../android/app/src/main/java/dev/kartpad/android/KartPadGameDataActivity.kt)
asks only for an extracted RMCP01 DATA folder even though the screen also
supports disc-image import. A reporter seeing only input choices may be at
this prerequisite; their exact build/screen is still unknown.

Follow-up: make the base-disc → official Retro-pack sequence visible before
selection, use consistent ISO/WBFS-or-DATA-folder wording, state the owned PAL
RMCP01 revision 0 requirement, and distinguish unsupported format, wrong
region/revision, wrong folder, missing base data and incompatible pack errors.
Explain that an RVZ must first be converted from the user's own supported dump
to a supported input and that Retro installation is a separate step.

Acceptance: a fresh user can reach the official downloader after valid base
import; rejected inputs explain the next action; cancel/retry, unavailable file
providers and incomplete installs preserve existing valid data. Verify the
reported route on its exact build before calling it fixed. Keep identity and
pack checks intact; no game-download sourcing or validation bypass is needed.

### Trigger and stick-click remapping for tricks/wheelies

Status: confirmed Android feature gap, not blocked on logs.

[`KartPadControllerMapping.kt`](../android/app/src/main/java/dev/kartpad/android/KartPadControllerMapping.kt)
only maps A/B/X/Y/Z to A/B/X/Y/left shoulder. A Thor user specifically wants
tricks/wheelies accessible from triggers or stick clicks. Evaluate a focused
extension after confirming the desired bindings; macOS PR #112 does not supply
Android acceptance.

The additional Thor comment requests **D-pad and shoulder-button remapping**.
Add D-pad directions and shoulder inputs to the proposed scope, alongside the
earlier trigger/stick-click request. Left shoulder already participates in the
limited mapping; right shoulder and D-pad need separate consideration. Confirm
which physical input should produce which action rather than assuming this
comment requests the same wheelie/trick assignment as the earlier reporter.

Acceptance: physical Thor or affected controller confirms the requested action,
including press/hold/release, without breaking analog trigger behavior,
existing defaults, saved mappings, player assignment or touch handoff. Check
menu dismissal, disconnect/reconnect and reset for stuck or duplicate inputs.
For D-pad support, include diagonal and simultaneous direction/button input,
menu navigation, conflict handling and restoring defaults; distinguish digital
shoulders from analog triggers when verifying press and release behavior.

### Freeze after changing render resolution

Status: new unverified reproduction lead; no exact matching GitHub issue found.

One commenter reports freezes following resolution changes and recovery after
pause/unpause. Track separately from online-menu issue #123. The current
`showResolutionSettings` path in
[`KartPadActivity.kt`](../android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt)
persists the scale and immediately calls `applyDisplaySettings`; inspect that
transition and the renderer/lifecycle response once the build, scene, scale
change and pause action are known. This is a source entry point, not a diagnosis.

Acceptance: the previously failing scale change completes during the affected
scene with frames/audio/input continuing, correct persisted scale after restart,
and no recovery pause required. Check Original and Retro independently. Capture
a bounded matching interval if reproduced; do not conflate a recoverable freeze
with a process crash or ship a speculative automatic pause workaround.

The export's FPS-uncapping wording remains ambiguous. Clarify the requested
behavior before adding a frame-rate feature or acceptance commitment.

## Deferred tvOS work

The following compiler, presentation, haptics and audio work retains its own
source and physical-device acceptance boundaries.

### tvOS A12 compiler baseline

Status: defensive compiler hardening implemented; physical A12 compatibility
unverified.

The tvOS WiiCompiled targets should use a generic AArch64 CPU baseline and
explicitly disable RCpc instruction selection. `-mcpu=generic` alone is not
sufficient with the tested Apple Clang toolchain: it can still emit RCpc loads
that fault on the A12 Apple TV. Physical iOS also uses a generic/RCpc-disabled
baseline in
[0.4.13 build 29](releases/v0.4.13-ios.1.md); macOS and Simulator tuning are
separate. A10X iPad acceptance remains pending.

Completed integration evidence:

- the generated tvOS Xcode project contains `-mcpu=generic` and
  `-Xclang -target-feature -Xclang -rcpc` for every WiiCompiled runtime target;
- the final tvOS executable contains no unsupported RCpc load instructions;
- the complete unsigned tvOS build and app audit pass; and
- the complete iOS Simulator build and app audit pass without changing its CPU
  tuning.

An A12 compatibility claim still requires the exact resulting app to boot, reach
the title screen, produce audio, and complete a race on an A12 Apple TV. Until
such evidence is available, the change is described only as compiler hardening.

Source: pull request [#31](https://github.com/chrissotraidis/kartpad/pull/31)
and its physical-device follow-up. The submitted pull-request head did not
include the RCpc fix.

### tvOS settings and aspect presentation

Status: aspect-state consistency implemented; presentation choices remain deferred.

A Settings bundle could eventually expose presentation preferences, and the
aspect-ratio behavior should be made explicit. Those are separate decisions from
the first-run controller and launch-mode flow. The current controller-required
screen and mode chooser remain part of the tvOS safety and acceptance contract;
they must not disappear as a side effect of adding preferences.

The mobile settings bridge now reports the selected aspect mode through the
guest `SCGetAspectRatio` result. This removes a deterministic state mismatch
without adding new tvOS settings UI or changing the accepted launch flow.

The Issue #17 Apple TV 4K (3rd generation) report also found the fixed 1.0x
render scale visibly soft on a large display and reported that 2.0x or 2.5x
remained at 60 FPS while the device thermal state was nominal. Treat that as a
single-device optimization lead, not a new default or sustained-performance
claim. Any default change belongs with the deferred tvOS settings work and must
be benchmarked across supported Apple TV hardware and thermal states first.

Acceptance requires all of the following:

- controller-required messaging and input gating remain intact;
- preference defaults, relaunch behavior, and migration are deterministic;
- 4:3, 16:9, and fill presentation are verified in menus and gameplay without
  clipping or stretching regressions;
- the runtime's reported aspect ratio agrees with the selected presentation; and
- iPhone and iPad presentation behavior remains unchanged.

Source: pull request [#32](https://github.com/chrissotraidis/kartpad/pull/32).

### tvOS controller rumble

Status: hardware experiment required.

Core Haptics may provide controller rumble on supported tvOS controllers, but
the engine lifecycle has to be treated as recoverable state. Cached player state
must not suppress a restart after the engine resets, stops, the controller
disconnects, or the system sleeps.

Acceptance requires all of the following:

- reset and stopped handlers reconcile the engine and cached active-player state;
- unsupported controllers and haptic localities fail safely;
- start, update, stop, disconnect, reconnect, interruption, and sleep/wake paths
  are exercised;
- the emulation path remains non-blocking; and
- physical controllers confirm observable output for representative game events.

Source: pull request [#33](https://github.com/chrissotraidis/kartpad/pull/33).

### Dolby Pro Logic II to multichannel LPCM

Status: audio experiment required.

Decoded multichannel output may be useful when tvOS exposes a compatible route,
but it must preserve the existing stereo path and cannot be accepted from channel
plumbing alone. The exact app must demonstrate meaningful rear-channel content
and correct channel ordering on physical output hardware.

Acceptance requires all of the following:

- stereo remains the deterministic fallback for unsupported or changing routes;
- the physical run uses the exact submitted source and compiler baseline;
- front and rear channel mapping is verified with non-zero, audible content;
- route changes, pause/resume, underruns, latency, and a sustained soak pass; and
- documentation avoids center or LFE claims unless those channels are actually
  decoded and verified.

Source: pull request [#35](https://github.com/chrissotraidis/kartpad/pull/35).

### tvOS experiment integration order

1. Retain the statically verified A12 compiler hardening and keep physical
   compatibility explicitly unclaimed unless exact-artifact evidence arrives.
2. Treat aspect semantics as a focused change that preserves controller safety.
3. Evaluate haptics and multichannel audio as independent hardware experiments.
4. Rebase each experiment independently and resolve its runtime-host conflicts
   before combining any accepted work.
