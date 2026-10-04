# KartPad status

## Current status: 4 October 2026

**Latest release: [KartPad 0.7.10](https://github.com/chrissotraidis/kartpad/releases/tag/v0.7.10) (build 253).**
Downloads are ready to play again: the Android APK, the iPhone/iPad IPA and the
Mac app include the game code, and players add their own game data the first
time. PadMint stays an option for building your own copy.

| Platform | How players get it | State |
| --- | --- | --- |
| Android | Ready-to-play APK from Releases | Main platform; most open reports |
| iPhone / iPad | Ready-to-play IPA from Releases, signed by the player's sideloading tool | Stable on tested devices |
| Apple Silicon Mac | Ready-to-play ZIP from Releases, or `scripts/self-build-macos.sh` | Experimental |
| Apple TV | Experimental source build | Experimental |

### 0.7.9 and 0.7.10

| Version | What changed | Checked |
| --- | --- | --- |
| 0.7.9 | Ready-to-play downloads (#403); hourly update check (#397) | Android 16 emulators (update and fresh install), iOS Simulator, Mac race |
| 0.7.10 | Startup checks every game file and names missing ones (#370); fatal errors show a message instead of a black screen on iPhone/iPad; Automatic uses the full repack on Snapdragon 8xx (#316); PowerVR logs whether shaders exceed the GPU's inter-stage limit (#304); the ⋯ button hides with a controller (#402) | Emulator (data check, missing file, ⋯ hiding); iPad Pro (fatal message, normal launch) |

### What remains

- **Android 3D drawing on some GPUs.**
  - Adreno 8xx: 0.7.10 makes the full repack the default. It needs confirmation from the OnePlus 15 reporter (#316).
  - Adreno 6xx/7xx (#104, #301): the in-app character test options are the only route; nothing new in 0.7.10.
  - PowerVR (#304): 0.7.10 logs `KartPad inter-stage over limit` if shaders pass more values than the GPU's limit (14 on the Moto G54). One report from a PowerVR phone confirms or rules out that cause before any fix.
- **Startup:**
  - iPad black screen (#370): explained as an incomplete game data copy; 0.7.10 now says so.
  - Moto G75 (#332): no diagnostic yet.
  - iPhone 16 flicker while a game opens (#390): the reporter's video shows the game drawing only one frame in nine while the safety screen fades. It doesn't happen on the iPad Pro; the cause is not found yet.
- **Online over mobile data (#405):** finding a room fails on carrier NAT; Wi-Fi or a VPN works. KartPad can't fix this without a relay server.
- **Controllers:**
  - ipega (#378): fix in 0.7.8, awaiting the reporter.
  - Single Joy-Con on iPhone (#324): its presses don't arrive.
  - Mac: Wii Remote with Classic Controller Pro (#306) and two-player rendering (#127).
- **Game flow and data:**
  - Crash after the last race of a cup (#131): doesn't happen on 0.7.10 in automated full cups on the emulator, through both endings and at 3x ([record](artifacts/2026-10-04/android/131-cup-ceremony-harness.md)). Needs a retest by an affected player.
  - Ayn Thor screen area (#202).
  - Restoring Mii, identity and rating from a backup (#234).
- **Performance (#339, patchzyy's focused pass).**
  - Runtime: September profiling on the Pixel 9 Pro XL ([ledger](artifacts/2026-09-23/android-copy-stream-loop.md)) led to candidate 203 (skip unobserved FP status capture, game-thread Performance Hint). It cut game-thread CPU per frame in a 12-player Cookie Land battle from 14.70–14.79 ms to 12.65 ms and shipped in 0.5.1. Candidate 205 (a game-thread context slot) was measured and rejected.
  - Compile: the breakdown and the `-g0` change (compile CPU 2,232 s to 1,404 s) shipped in 0.7.5.
  - Still to do: a baseline on the current build, the incremental-rebuild measurement, and the next candidate (the translator passing the CPU context to float helpers instead of looking it up, which needs a game pack rebuild).
- **WiiCompiled.**
  - Main is built on upstream `8346376`, 20 commits behind upstream `main`.
  - Draft #384 moves to `9d182f8`. It changes the pack interface, so it ships as **0.8.0** with the speed work.
  - Nothing has been contributed upstream yet. The first candidate is the controller assignment fix, which upstream's `input.cpp` shares.

### Next versions

- **0.7.10** (released 4 October): the fixes above. Waiting on reporter confirmation for #316, #370 and #402, and a PowerVR log for #304.
- **0.8.0** (pack interface change): WiiCompiled sync (#384) plus the first runtime speed work from #339.

## Earlier checkpoints

**29 September 2026:** prebuilt downloads have been retired and all earlier
releases are no longer available. KartPad publishes source only; users build
their own app with the [Personal IPA Builder](BUILDER.md) (iPhone/iPad on an
Apple Silicon Mac today; Mac and Android targets in progress). The checkpoint
below is kept as a record of the last published version.

**September 26 release checkpoint:** KartPad 0.5.1 (retired) is the latest stable release, with Android code 229 and iPhone/iPad/Mac build 85, all built cleanly from de3a99c. All six downloads were re-downloaded anonymously and match their checksums; the APK carries the 0.5.0 release signer. The owner accepted gameplay on private iPad build 84 (the iPad stutter regression is resolved) and Pixel code 227 (offline play, with Retro online joining). [Release notes](releases/v0.5.1.md) · [Final package record](artifacts/2026-09-26/release-051-final.md).

[Coordinator runbook and implementation plan](MAINTENANCE-AUTOMATION.md) ·
[Canonical active queue](MAINTENANCE-BOARD.md).

Updated: 26 September 2026. This page summarizes acceptance, not a full test log.
Use the [maintenance board](MAINTENANCE-BOARD.md) for candidate ownership and
next actions, and [known issues](KNOWN-ISSUES.md) for current reports.

## Historical reporting prereleases — 14 September 2026

[Android code90](releases/v0.4.20-android-reporting.1.md) and
[iPhone/iPad build42](releases/v0.4.20-ios-reporting.1.md) are optional reporting
test builds. Build/package checks passed; physical reporting-flow acceptance is
pending. These older test builds are retained for historical comparison. Current stable downloads are below.

## Published packages

| Platform | Package | Acceptance boundary |
| --- | --- | --- |
| Android | [0.5.1, code 229](releases/v0.5.1.md) | Owner accepted offline play and Retro online joining on private code 227 (same fixes). Update in place over 0.5.0 verified on an emulator (2,044 game files preserved). The Adreno character fix is opt-in and unconfirmed on affected phones. |
| iPhone / iPad | [0.5.1, build 85](releases/v0.5.1.md) | Owner accepted gameplay on private build 84; the exact build 85 is installed in place on the owner's iPad with saves preserved. A brief cup-select slowdown remains. |
| Apple Silicon Mac | [0.5.1, build 85](releases/v0.5.1.md) | App/ZIP audited; launch and about two minutes of play in a host smoke check. Broad gameplay and controller acceptance remain separate. |
| Apple TV experimental | [0.4.11, build 9](releases/v0.4.11-tvos.1.md) | Published identity-fix and compiler-hardened package; exact-build hardware acceptance remains open |

[Download and install](../README.md#downloads). All listed packages include the
issue #94 console-serial correction. Updating does not clear old server-side
identity history or bans. Older affected packages should stay offline.

The September 10 releases include the [joint source delivery](artifacts/2026-09-10/android-source-delivery.md)
and [verified download ledger](artifacts/2026-09-10/platform-release-verification.md).
Historical local candidates are retained in their dated records.

## Earlier device acceptance

The owner accepted the source-migration candidates for loading, running and
starting games on iPad and Android, and explicitly chose not to require a
completed race as another release gate. iPad new-license Retro WFC login worked;
the old license's 22005 serial mismatch reproduced on both builds. This does not
claim a complete online race/reconnect sequence. See the
[migration validation ledger](source-maintenance/VALIDATION.md).

### Earlier device evidence

The owner accepted the bounded iPhone 14 trial of **0.4.17/build 39** on
13 September. Saves, identity and configuration were preserved during the
in-place upgrade. The unsigned IPA delivers that executable with the original compilation
manifest retained. This does not close the iPhone 17 Pro Max/iOS 27 report. See the [candidate handoff](artifacts/2026-09-13/platform-candidate-handoff.md).

The owner also considers iPad and Mac good to release. That is owner acceptance;
this pass's recorded physical Apple trial was on iPhone 14. Android code 78
passed the owner's random Retro single-player race and touch-settings trial.
Code 79 adds FPS text sizing and a responsive touch editor; Large persistence
and D-pad Hide/Show passed physical Pixel UI checks. Save and identity file
hashes were unchanged during that trial; only the new FPS preference changed
among touch settings. Two Android licenses are being preserved as requested;
their presence does not prove that an update created an identity. Possible
Retro WFC menu slowdown remains under investigation. See the
[controls and acceptance audit](artifacts/2026-09-13/android-controls-request-audit.md).

## Established results and remaining limits

- **Android:** the owner accepted Original Grand Prix with Kishi and automatic
  touch hiding, and reported Retro WFC login, worldwide matchmaking and live
  racing. These apply to the tested runtime, not every later preview. Graphics
  corruption, online-menu stalls, cup crashes and warm slowdown remain open.
- **iPhone/iPad:** the owner accepted build 32 on the M2 iPad after controller
  gameplay, reporting/menu and chooser checks. Build 33 publishes those app
  changes with updated version metadata. All 32 protected save/settings files
  were preserved across the build-32 update. The A10X reporter confirms build-29
  startup and Original/Retro loading; their lower FPS remains a separate issue.
  Touch gameplay, custom remapping, external displays and complete production
  online behavior are not newly accepted by these results.
- **Mac:** the original correctness and offline test program includes all 32
  retail tracks, race/save cycles, two-player results and representative audio
  continuity. New two-player rendering reports and controller changes need
  their own regression evidence; see the maintenance board.
- **tvOS:** the reporter accepted the 0.4.1 storage repair on Apple TV 4K
  (3rd generation). That [specific result](artifacts/2026-09-04/tvos-v0.4.1-storage-acceptance.md)
  does not establish A12 compatibility, purge recovery or current-build performance.
- **Online:** isolated WFC race/results tests and Android owner reports have
  different scopes. Complete distributed-build results/reconnect, Original
  private-server gameplay and native room hosting remain open. See [ONLINE.md](ONLINE.md).
- **Performance and peripherals:** sustained frame pacing, long soaks, full
  three/four-player coverage, motion/audio refinements and external displays
  remain incomplete. See [performance](PERF.md), [controllers](MULTIPLAYER.md)
  and [external displays](EXTERNAL-DISPLAYS.md).

## Evidence and requirements

- [Release notes](releases/) and [dated artifacts](artifacts/) record exact
  source revisions, checksums, procedures and observed outcomes.
- [Product requirements](PRD.md) retain the engineering acceptance matrix.
  A historical checked row does not accept a later package automatically.
- [Release checklist](RELEASE-CHECKLIST.md) applies to new candidates.
- [Historical status ledger](archive/status-through-2026-09-07.md),
  [journal](archive/JOURNAL.md) and [iterations](iterations/) preserve earlier
  results. Their machine state and next steps are not current work assignments.
