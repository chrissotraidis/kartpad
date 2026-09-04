# Android A3 shared archive-scan contract

Date: 2026-09-04

Branch: `codex/android-a3-archive-entry-core`

Baseline: `a768ea26522be9b365a3b90e5510f0b521416106`

## Falsifiable subgoal

Move the existing Retro Rewind ZIP entry-selection and expansion-limit policy
into portable C++ consumed by the Apple installer, without changing the
official root, entry cap, expanded-byte cap, or unsupported-entry behavior.

## Result

- Added a stateful `kartpad::retro_rewind::ArchiveScan` that rejects an invalid
  path, symlink, encrypted entry, or negative uncompressed size before root
  selection.
- Safe entries outside the exact expected root are ignored without affecting
  selected totals, matching the existing Apple behavior.
- Selected entries are bounded by the caller's exact entry and expanded-byte
  limits. Addition is checked before mutation, so a malicious directory cannot
  wrap the 64-bit byte total.
- The first error is latched, preventing a caller from continuing a scan after
  a fail-closed result.
- The iOS/tvOS installer now obtains its selected entry and byte totals from the
  shared scan and uses the latter for extraction progress. Its existing error
  categories and `RetroRewind6.12.5` profile authority remain unchanged.

Source SHA-256 values:

- header: `180c46133e94f8c70836619aec0d7320541bba20baa057f20b741ac00b244a3a`
- implementation: `e6f69a8197bf9bcc9c194e9d29d0869fb5f3b5e6c4dc09523d37fa4337936792`
- test: `324b37120382526274b335247fe4d6bef312c6ff5eecf076d9fbe1bb5c736460`

## Verification

- `kartpad.retro-rewind.archive-path` and
  `kartpad.retro-rewind.archive-scan`: pass.
- The scan test covers foreign-root ignore, exact-limit acceptance, entry-limit
  rejection, expanded-size rejection, unsigned-addition overflow, symlink,
  encryption, negative size, invalid path, counters, and error latching.
- Pinned NDK 29 API-28 ARM64 warning-as-error compiles for both shared source
  files: pass; each output is an AArch64 ELF relocatable object.
- iOS Simulator SDK-targeted warning-as-error syntax compile of the updated
  Objective-C++ installer: pass with its established omitted-operand extension
  explicitly allowed.
- Fresh integrated WiiCompiled source preparation for the dual Apple product:
  pass; both shared sources appear in `PublicProducts.cmake`.
- Builder/tvOS contracts: 29 pass and one optional private-payload test skips
  because that input is not cached.
- Repository safety, SunPad snapshot, and diff checks: pass.

The full Apple link remains unavailable because the local Dawn cache mismatch
recorded in `a3-shared-archive-path.md` occurs before configuration. The
fail-closed dependency check remains unchanged.

## Classification

**Pass for shared unsupported-entry, exact-root selection, bounded-count, and
overflow-safe expanded-byte policy with an immediate Apple consumer.** This is
not an Android installer or A3 runtime result. A2 remains open for physical
Android acceptance. A3 remains open for duplicate-entry handling, byte/hash and
payload validation, Android download/storage/extraction/activation/recovery,
and the complete emulator/physical offline gameplay matrix. No APK/AAB,
archive, game data, save, device identifier, or private log was published.
