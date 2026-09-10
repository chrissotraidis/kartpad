# KartPad status

[Coordinator runbook and implementation plan](MAINTENANCE-AUTOMATION.md) ·
[Canonical active queue](MAINTENANCE-BOARD.md).

Updated: 10 September 2026. This page summarizes acceptance, not a full test log.
Use the [maintenance board](MAINTENANCE-BOARD.md) for candidate ownership and
next actions, and [known issues](KNOWN-ISSUES.md) for current reports.

## Published packages

| Platform | Package | Acceptance boundary |
| --- | --- | --- |
| Android | [0.4.16, code 64](releases/v0.4.16-android.1.md) | Retro Rewind 6.12.8 compatibility rebuild; package evidence is complete, while physical-device, GPU, cup, online and sustained-FPS acceptance remain separately bounded |
| iPhone / iPad | [0.4.16, build 35](releases/v0.4.16-ios.1.md) | Full translated ARM64 rebuild for Retro Rewind 6.12.8; package and focused app checks passed; no new full-game physical or performance acceptance claimed |
| Apple Silicon Mac | [0.4.16, build 35](releases/v0.4.16-macos.1.md) | Full translated native rebuild for Retro Rewind 6.12.8; package and native helper checks passed; tearing and external-display reports remain open |
| Apple TV experimental | [0.4.11, build 9](releases/v0.4.11-tvos.1.md) | Published identity-fix and compiler-hardened package; exact-build hardware acceptance remains open |

[Download and install](../README.md#downloads). All listed packages include the
issue #94 console-serial correction. Updating does not clear old server-side
identity history or bans. Older affected packages should stay offline.

The September 10 releases include the [joint source delivery](artifacts/2026-09-10/android-source-delivery.md)
and [verified download ledger](artifacts/2026-09-10/platform-release-verification.md).
Historical local candidates are retained in their dated records.

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
