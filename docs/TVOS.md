# KartPad native tvOS implementation

## Current status

The current package is the [0.4.11 experimental IPA](releases/v0.4.11-tvos.1.md),
with the console-serial correction and generic ARM64/RCpc compiler hardening.
Exact-build physical and online acceptance remain open.

The [0.4.1 storage hotfix](artifacts/2026-09-04/tvos-v0.4.1-storage-acceptance.md)
was accepted by an Apple TV 4K (3rd generation) tester: both modes launched,
config/save changes survived normal relaunch, and backup succeeded. This is
historical evidence for that device and build. It does not establish current
A12 compatibility, purge recovery or sustained performance.

This implementation starts from KartPad `main`, the project's pinned upstream
sources, and Apple/SDL platform contracts. External pull requests remain useful
feasibility evidence, but the shipped implementation and acceptance gates are
maintainer-owned.

## Platform scope

- Apple TV hardware running tvOS 17 or later.
- Original Mario Kart Wii and Retro Rewind 6.12.7 through the existing
  `KartPadDual` ahead-of-time translated product.
- Offline play first. Retro WFC remains a separate network-acceptance gate.
- One to four Extended Gamepad controllers. The Siri Remote can operate native
  setup UI but is not a supported racing controller.
- User-provided, validated PAL `RMCP01` revision-0 extracted game data.
- The official pinned Retro Rewind full pack, downloaded and hash-verified by
  KartPad. Neither game data nor the Retro Rewind pack is bundled.

## Architecture

The tvOS target shares KartPad's translated base/Retro Rewind graph, Aurora,
Dawn/Metal renderer, Classic Controller adapter, four-player GameController
assignment, release profile, and Retro Rewind archive verifier. It has a small
tvOS-specific UIKit host for focus-driven setup and deliberately excludes the
iPhone/iPad document picker, touch overlay, motion steering, and Files app
workflow.

The host refuses to begin gameplay until all of these are true:

1. A complete RMCP01 extracted tree is present and its disc header and
   `sys/main.dol` match the pinned profile.
2. The selected Original or Retro Rewind product exists in the linked dual
   graph.
3. Retro Rewind content matches the pinned version, sizes, and SHA-256 hashes
   when that mode is selected.
4. At least one Extended Gamepad is connected.

## Storage and recovery contract

tvOS may purge large local data. KartPad therefore separates state by whether
it can be reconstructed:

| Data | Location | Recovery |
| --- | --- | --- |
| Extracted RMCP01 data | `Library/Caches/KartPad/GameData` | Restage from the user's Mac |
| Retro Rewind pack | `Library/Caches/KartPad/RetroRewind` | Download and verify again |
| Config, NAND, saves, runtime logs | `Library/Caches/KartPad` | Back up to the user's Mac before and after testing |
| Controller diagnostics | `Library/Caches/SunPad/Logs` | Collect separately with the diagnostics script |

[Apple documents](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppleTV_PG/)
tvOS local files outside the small preferences allowance as purgeable. The
developer build therefore keeps every writable filesystem path under Caches and
includes a Mac-side backup command. Testers must assume config, saves, game
data, and logs can disappear under storage pressure and must back up before
replacing or deleting the app. A later broadly supported release needs a tested
durable sync/restore design, such as an appropriately entitled CloudKit
container, before it can promise durable saves.

## Building a candidate

Requirements:

- ARM64 Mac with an installed stable Xcode that includes the tvOS SDK.
- KartPad's pinned reference checkouts and private dual-profile translation.
- User-owned extracted RMCP01 data. Keep it outside Git and the app bundle.

Build the pinned Dawn package once:

```sh
./scripts/build-dawn-tvos.sh appletvos
```

Prepare a fresh patched runtime and build the unsigned dual-mode app:

```sh
./scripts/prepare-tvos-game-runtime.sh
./scripts/build-tvos-game-app.sh
```

The expected output is
`build/tvos-game-app-xcode/Release-appletvos/KartPad.app`. The build script runs
the tvOS audit automatically. Signing and installation remain local developer
actions; the unsigned app contains translated code but no disc image, extracted
assets, Retro Rewind pack, saves, provisioning profile, or signing identity.

After installing the signed app, stage the user's extracted DATA directory:

```sh
./scripts/stage-tvos-game-data.sh /absolute/path/to/DATA "Living Room"
```

Launch KartPad, choose Retro Rewind, and allow KartPad to download and verify
the pinned official pack. Never stage Nintendo or Retro Rewind data into the
repository or distributable app bundle.

Back up saves and configuration before replacing or deleting the app:

```sh
./scripts/backup-tvos-state.sh "Living Room" /absolute/path/to/new-backup
```

The default bundle identifier is `dev.kartpad.tv`. If a tester signs the app
with a different identifier, use that same identifier for the build and every
device operation in the shell session:

```sh
export KARTPAD_TVOS_BUNDLE_IDENTIFIER=com.example.kartpad.tv
```

This keeps game-data staging, backups, and diagnostic collection pointed at
the signed app's actual container.

Collect path-redacted runtime and controller logs after a failure. This does
not copy game data or saves, but the tester should still review the output
before sharing it:

```sh
./scripts/collect-tvos-diagnostics.sh "Living Room" /absolute/path/to/new-diagnostics
```

## Physical acceptance matrix

Record the Apple TV model, tvOS version, Xcode/SDK, controller models, source
commit, binary SHA-256, and whether the run used Original or Retro Rewind.

- [x] Clean unsigned `KartPadDual` build passes `audit-tvos-app.sh`.
- [x] The exact public `v0.4.1` IPA installs in place after local re-signing and
  opens on a physical Apple TV.
- [ ] Missing data shows setup instructions rather than crashing or exiting.
- [x] Valid RMCP01 data loads from Caches and survives ordinary relaunch on the
  exact public `v0.4.1` IPA.
- [ ] Original mode reaches a complete race with correct video and audio.
- [ ] Retro Rewind downloads, verifies, installs, and reaches a complete race.
- [ ] Original/Retro mode switching works across clean relaunches.
- [ ] Controller-required UI works with no controller, pairing, disconnect, and
  reconnect; Siri Remote input never leaks into racing controls.
- [ ] Two-, three-, and four-controller slot assignment is stable.
- [ ] A save survives normal exit, relaunch, sleep/wake, and forced termination.
  The normal-exit/relaunch substep passes on `v0.4.1`; sleep/wake and forced
  termination remain open.
- [ ] `backup-tvos-state.sh` captures the save and a restore rehearsal recovers
  it before any tester is asked to risk meaningful progress. Capture passes on
  `v0.4.1`; restore remains open.
- [ ] Purging reconstructible content produces a recovery screen; restaging
  game data and redownloading Retro Rewind do not overwrite saves.
- [ ] A full cup and at least a 30-minute soak record frame pacing, audio,
  memory pressure, temperature, and controller behavior.
- [x] The original three-layer tvOS app icon and Top Shelf artwork compile into
  `Assets.car` and pass structural inspection.
- [ ] The compiled icon is visually checked on a physical Apple TV Home Screen.
- [ ] The exact tester artifact contains no private data, derived branding,
  signing material, local paths, or unsupported public claims.

## External hardware bring-up

The maintainer does not currently have physical Apple TV hardware, so an
outside cohort performs physical acceptance. The first report confirms both
modes can reach smooth playable gameplay with audio, 3D rendering, menus, and
wireless gamepad input. It also exposed error 513 on Application Support; the
reporter's cache-root workaround succeeded and is the basis of `v0.4.1`.
The reporter subsequently re-signed and installed the exact public `v0.4.1`
IPA in place. Config writes produced no error 513, Original and Retro Rewind
both launched, NAND/save and settings changes survived normal termination and
relaunch, and `backup-tvos-state.sh` captured the cache-root state. This closes
the storage defect in Issue #17. Sleep/wake, forced termination, restore,
multi-controller, purge recovery, sustained performance, and the exact 0.4.4
artifact remain open. This is still a hardware bring-up build, not a supported
release. The acceptance record is in
[`docs/artifacts/2026-09-04/tvos-v0.4.1-storage-acceptance.md`](artifacts/2026-09-04/tvos-v0.4.1-storage-acceptance.md).

Before sending it, package and audit one exact candidate. Testers must have a
paired Apple TV, a Mac with Xcode, an Extended Gamepad, their own supported game
data, and either their own signing setup or a registered-device build supplied
by the maintainer. Apple documents
[running on a paired tvOS device](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
and [registered-device distribution](https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices).
Start with testers who accept that launch may fail and who have no valuable
KartPad save in the app container.

Give every tester the executable SHA-256 and the physical matrix above. Require
the Apple TV model, tvOS version, controller model, signing/install method,
selected mode, failure stage, and collected diagnostics for every result. The first
priority is missing-data UI, staging, launch, controller input, and one Original
race. Only then ask that same tester to download Retro Rewind and exercise save,
relaunch, sleep/wake, and backup. Expand distribution only after at least one
tester completes both modes. Keep issues open until the reported hardware path
has been retested.

The concise tester-facing procedure is
[`docs/TVOS-TESTING.md`](TVOS-TESTING.md).

The first unsigned device build passed on 2026-09-03 with Xcode 26.6 and the
tvOS 26.5 SDK at a tvOS 17.0 deployment target. See
[`docs/artifacts/2026-09-03/tvos-first-native-build.md`](artifacts/2026-09-03/tvos-first-native-build.md).
