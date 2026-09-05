# Android A4 Mii management checkpoint

Date: 2026-09-04

## Scope

This accepts Mii database listing, standard-file import, removal, restart-time
application, backup, and last-Mii protection on the standalone API 36 ARM64
emulator. It does not add a Wii Menu/Mii Channel or claim complete A4 parity.

## Implementation

- Manage Miis reads either the pending or live app-private RFL database and uses
  KartPad's shared portable parser to list slot, name, and creator.
- Import uses Android's system document picker and reads at most 75 bytes so only
  exact 74-byte Mii files reach native validation. Duplicate creation IDs, empty
  files, invalid metadata, and full databases fail closed.
- Removal is selected by named record and staged through the shared portable
  mutator. The shared invariant always retains at least one valid Mii.
- The active RFL database is not edited while Mario Kart is running. Updated
  bytes are atomically staged, independently checked for exact size, RNOD header,
  and CRC-16 at the next launch, backed up, and atomically installed before SDL
  starts. Errors shown to the user do not expose app-private paths.
- Create a Mii accurately explains KartPad's iOS-equivalent boundary: KartPad
  does not ship the Wii Menu or Mii Channel; a compatible exported `.mii` can be
  imported instead.

## Emulator evidence

- The live manager initially rendered one available Mii and accessible Import,
  Remove, Create, and Done actions.
- A locally generated non-personal Mii named `Android` was selected through
  DocumentsUI. The app staged a 779,968-byte database at SHA-256
  `04bc43603071564b5e0022ecd0216d3210b94e30e18a19621bef98df553842c8`.
- Restart Now returned to the production Original/Retro selector. Selecting
  installed Retro Rewind applied the pending database before SDL, removed the
  pending file, retained a byte-identical backup of the original, and the live
  manager listed both `KartPad` and `Android`.
- Removing `Android` staged the exact original database SHA-256
  `6212cbf744e28d8e0687c9e8a7d8b22343ef37291b8dc5c031f04f1c45e5b3b7`.
  A second restart applied it and retained a byte-identical backup of the
  two-Mii database. An attempted removal of the remaining KartPad Mii displayed
  the shared last-Mii rejection.
- The synthetic document and two test-created backups were removed. The active
  database retained the exact original hash, no pending database remains, and
  the exact clean build's manager again lists one Mii without a fatal signal.

## Verification

- Exact clean local APK SHA-256:
  `24dbe0768dc07fa3d3cf8a27c7fcd163bff5cd53615dce5cddfc51207b580545`.
- Strict Android package/privacy audit and Android lint: pass.
- Twenty-four Android/Apple source contracts: pass.
- Portable Mii database and Android gamepad contracts: pass.
- Native Android touch contract, repository safety, 464 patch hunks, pinned
  source/input verification, unchanged SunPad overlay snapshot, and
  `git diff --check`: pass.

No APK, AAB, game data, save, Mii database, log, or screenshot was published.
