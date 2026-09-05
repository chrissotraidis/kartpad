# Android A4 game-data, save, and selector parity checkpoint

Date: 2026-09-04

## Scope

This checkpoint replaces Android's disclosure-only Game Data & Saves row with
real extracted-folder import/reimport, save-preserving removal, and exact RKSYS
backup/restore actions. It also makes the production Original/Retro chooser the
recovery surface when game data is missing. ISO/WBFS extraction, a positive
multi-gigabyte folder-import emulator run, and complete A4 parity remain open.

## Implementation

- The three-dot submenu now contains Import or Reimport Game Data, Remove Stored
  Game Data, Manage Retro Rewind, Manage Saves, and Manage Miis.
- The isolated launcher validates the app-private extracted RMCP01 tree. It
  enables the side-by-side Original and Retro Rewind choices only when that data
  is ready and always exposes Manage Game Data for recovery.
- Extracted-folder import uses `ACTION_OPEN_DOCUMENT_TREE`, retains only a read
  grant, resolves DATA/GameData wrapper folders, bounds depth, entry count, and
  bytes, rejects unsafe names, verifies RMCP01 disc/revision/header plus the
  pinned `main.dol` hash, copies into same-volume private staging, and activates
  through rollback-safe directory renames. `Config.toml` retains a relative
  `GameData` path. No provider URI becomes a gameplay path.
- Removal is atomically marked from the isolated manager and applied by the
  chooser before a new SDL runtime starts. Only GameData/import/rollback paths
  are removed; NAND, saves, Miis, Retro Rewind, settings, and diagnostics are
  outside the deletion allowlist. Undo removes the marker without touching data.
- Manage Saves exports a checksum-validated exact 2,867,200-byte RKSYS through
  `ACTION_CREATE_DOCUMENT`. Restore uses `ACTION_OPEN_DOCUMENT`, checks exact
  size, `RKSD0006`, and core CRC-32, then atomically stages the save. Before SDL
  starts, KartPad backs up the current validated save and atomically installs the
  pending copy.

## Emulator evidence

- The exact APK was installed over the existing app on the standalone API 36
  ARM64 emulator. Before install, the active RKSYS was
  `708c7a040e0cfe6cd815690e63f46d1678f17899bce0e786f7480030830f1d13`,
  `main.dol` matched the pinned
  `80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05`,
  and the Mii database was `6212cbf7...`; reinstall preserved all three.
- The production chooser visibly showed enabled side-by-side Original and
  installed Retro Rewind 6.12.5 choices, Manage Game Data, and the status
  `Original and Retro Rewind 6.12.5 are ready`.
- Manage Game Data visibly reported the validated private RMCP01 installation.
  Import opened the real Android DocumentsUI folder picker. Selecting an empty
  temporary folder, granting access, and returning to KartPad produced the
  bounded missing-files rejection. The installed `main.dol` remained exact.
- The in-game submenu visibly rendered all five data/save actions over the live
  Retro title. Manage Saves recognized the active save. Export through
  DocumentsUI created an exact 2,867,200-byte file with the same `708c7a...`
  hash. Selecting that file for restore staged the same exact hash.
- Restart Now returned to the production selector. Selecting Retro applied the
  pending save before SDL, removed pending state, retained an exact `708c7a...`
  backup, and reached the Retro runtime. The created external document and test
  backup were then removed; the active save remained exact.
- Removal created the expected marker while both active GameData and RKSYS stayed
  present. Undo removed the marker and the manager again reported the validated
  installation.
- Switch Game Version returned from live Retro to the chooser; selecting
  Original logged `selected=base`, launched the base profile, and reached the
  Original attract scene. The emulator was left running Original with the full
  Game Data & Saves submenu visible.

## Verification

- Exact local-only APK SHA-256:
  `6aa904883b174940f728b672bee971a6367dc6008d7c9837eeb7cf684e043203`.
- Android Kotlin compilation, lint, and strict package/privacy audit: pass.
- Twenty-four focused Android/Apple source contracts: pass.
- Native Android touch, host Android gamepad, portable Mii database, and RKSYS
  CRC fixture contracts: pass.
- Repository safety, 464 patch hunks across 54 patches, pinned source/input
  verification, SunPad snapshot, and whitespace checks: pass.

No APK, AAB, game data, save, Mii database, log, or screenshot was published.
