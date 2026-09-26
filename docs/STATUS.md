# KartPad status

**September 26 release checkpoint:** [KartPad 0.5.1](https://github.com/chrissotraidis/kartpad/releases/tag/v0.5.1) is the latest stable release, with Android code 229 and iPhone/iPad/Mac build 85, all built cleanly from de3a99c. All six downloads were re-downloaded anonymously and match their checksums; the APK carries the 0.5.0 release signer. The owner accepted gameplay on private iPad build 84 (the iPad stutter regression is resolved) and Pixel code 227 (offline play, with Retro online joining). [Release notes](releases/v0.5.1.md) · [Final package record](artifacts/2026-09-26/release-051-final.md).

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
