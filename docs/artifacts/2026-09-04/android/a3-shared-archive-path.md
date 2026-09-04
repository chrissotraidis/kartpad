# Android A3 shared archive-path contract

Date: 2026-09-04

Branch: `codex/android-a3-archive-path-core`

Baseline: `ef791deb04c4653f282ac0f2d28e17332b95f4cf`

## Falsifiable subgoal

Move the existing Retro Rewind ZIP member-path policy out of the Apple-only
installer into portable C++ that the Apple products consume immediately, and
reject the same unsafe byte-level inputs in a host contract test. This is
independent source-only A3 preparation while A2 remains blocked on physical
Android hardware; it is not A3 installation or gameplay acceptance.

## Result

- Added `kartpad::retro_rewind::ValidateArchiveMemberPath`, which treats entry
  names as opaque bytes and rejects empty names, absolute paths, backslashes,
  embedded NULs, empty components, `.` and `..`, and colons/drive prefixes.
- Exactly one trailing slash is retained as a directory marker. Repeated
  separators, including a double trailing slash, remain invalid.
- The iOS/tvOS installer now passes minizip's explicit `filename_size`, so an
  embedded NUL cannot be hidden by C-string or `NSString` truncation.
- Existing iOS, tvOS, Retro-only, and dual product targets compile the shared
  `.cpp` through their current mobile source lists. Android can consume the
  same API when its installer wrapper is added.

Source SHA-256 values:

- header: `a4555c677dd04ced3fd91466ffef24a7a463951658e51dba873d1ecb5ed421cf`
- implementation: `fc2985fb2d56a92ef589472df07cbcae6352db1504d2e5f154f526c90a9e52aa`
- test: `927fb46e929afe4304ca93af0ae7fab616e945c69b288c9f39875ec4bd35e52c`

## Verification

- `kartpad.retro-rewind.archive-path`: pass, including valid nested,
  directory, and UTF-8 paths plus every prohibited path class.
- Pinned NDK 29 API-28 ARM64 compile with the repository warning-as-error
  policy: pass; output is an AArch64 ELF relocatable object.
- iOS Simulator SDK-targeted Objective-C++ syntax compile of
  `KartPadRetroRewindInstaller.mm` with warnings as errors: pass (with the
  file's established Objective-C omitted-operand extension explicitly allowed).
- Fresh integrated WiiCompiled source preparation for the dual Apple product:
  pass; all patches apply and `PublicProducts.cmake` contains the shared
  source.
- `tests.test_kartpad_builder` and `tests.test_tvos_contract`: 29 pass, one
  pre-existing private-payload test skipped because that payload is not
  cached.
- `git diff --check`: pass.

A full dual iOS Simulator link was attempted but stopped before configuration:
the local cached Dawn archive hashes to
`c9272faca14a307e4545ea83cb66ab2f65e87fa33a0a687bf5c702666271bc03`,
not the script's required
`feb5c4e07da90c47d2f279bf83c43bc67db01dac1138cb9af8ea9b5b50c67fbf`.
The integrity check was preserved; the mismatched cache was neither trusted nor
modified. The direct SDK compile and fresh patch preparation cover this slice,
but do not upgrade the full link to passing evidence.

## Classification

**Pass for the portable archive-member path contract and its immediate Apple
consumer; inconclusive for a full Apple link due to the unrelated fail-closed
Dawn cache mismatch.** A2 remains the lowest incomplete goal. A3 remains open
for Android download/storage ownership, all remaining shared install rules,
fault recovery, emulator and physical-device installation, mode switching,
offline race/results/save/relaunch, and fallback rejection. No APK/AAB, Retro
Rewind archive, game data, save, identifier, or private log was published.
