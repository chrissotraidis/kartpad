# KartPad status

Updated: 9 September 2026. This page summarizes acceptance, not a full test log.
Use the [maintenance board](MAINTENANCE-BOARD.md) for candidate ownership and
next actions, and [known issues](KNOWN-ISSUES.md) for current reports.

## Published packages

| Platform | Package | Acceptance boundary |
| --- | --- | --- |
| Android | [0.4.10-android.1, code 21](releases/v0.4.10-android.1.md) | Promotes the Pixel 9 Pro XL / Razer Kishi runtime with the console-serial correction; broader hardware and sustained performance remain open |
| Android testing | [0.4.13 preview 1, code 28](releases/v0.4.13-android-preview.1.md) | Rating companion transfer and diagnostics; #105 confirms offline ratings/information transfer. Broad physical performance, Mii migration and server-sync acceptance remain open |
| iPhone / iPad preview | [0.4.13, build 29](releases/v0.4.13-ios.1.md) | Generic ARM64 baseline, chooser artwork and diagnostics; exact-build physical acceptance and reported older-device crash confirmation pending |
| Apple Silicon Mac | [0.4.11, build 26](releases/v0.4.11-macos.1.md) | Published native identity-fix rebuild; title-screen/normal-close smoke preserved installed state |
| Apple TV experimental | [0.4.11, build 9](releases/v0.4.11-tvos.1.md) | Published identity-fix and compiler-hardened package; exact-build hardware acceptance remains open |

[Download and install](../README.md#downloads). All listed packages include the
issue #94 console-serial correction. Updating does not clear old server-side
identity history or bans. Older affected packages should stay offline.

Local Android preview 2/code 29 is **not a public download**. Its source,
checksums and bounded emulator result are in the
[candidate record](artifacts/2026-09-09/android-preview2-local-candidate.md).

## Established results and remaining limits

- **Android:** the owner accepted Original Grand Prix with Kishi and automatic
  touch hiding, and reported Retro WFC login, worldwide matchmaking and live
  racing. These apply to the tested runtime, not every later preview. Graphics
  corruption, online-menu stalls, cup crashes and warm slowdown remain open.
- **iPhone/iPad:** earlier builds reached physical races, imported owned game
  data and preserved saves. iPad build 25's Retro launch/menu/layout checks
  remain [historical acceptance](iterations/ipad-identity-build25.md), not
  proof for build 29 or complete production-online races.
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
