# Android A3 shared archive duplicate rejection

Date: 2026-09-04

Branch: `codex/android-a3-archive-duplicate-core`

Baseline: `f45332fc8f9961a08cace8db8a9d4a62549c6937`

## Falsifiable subgoal

Reject duplicate entries under the selected Retro Rewind root during the
portable directory scan, before extraction mutates staging storage, while
retaining the existing rule that entries outside the selected root are ignored.

## Result

- `ArchiveScan` now keys selected entries by their validated path components.
  A trailing directory marker is not part of the key, so `content` and
  `content/` collide rather than aliasing one output path.
- Duplicate rejection occurs before selected counters mutate and latches the
  scan in a failed state.
- Repeated safe entries outside the expected root remain ignored and do not
  consume selected-entry or expanded-byte limits.
- The Apple wrapper maps the portable duplicate result to its established
  duplicate-file error and retains the extraction-time filesystem existence
  check as defense in depth.

Updated scan SHA-256 values:

- header: `b140604c4ceaf60b4cf6262095957347b50316423c77bfdf4501b2dfad01da48`
- implementation: `33fb4fd78adf7d1fd9f4190bb19bffa9f671fe97264f1086d6f212e144d9188a`
- test: `8e7f7b130f9bfaf86a590df693502f094cb4e80aa99cf010dec6690d05c64c1d`

## Verification

- `kartpad.retro-rewind.archive-path` and
  `kartpad.retro-rewind.archive-scan`: pass.
- The scan matrix proves file/directory spelling aliases collide, duplicate
  failure leaves totals unchanged, and foreign-root duplicates remain ignored.
- Pinned NDK 29 API-28 ARM64 warning-as-error compile: pass.
- iOS Simulator SDK-targeted warning-as-error installer syntax compile: pass
  with the file's established omitted-operand extension explicitly allowed.
- Builder/tvOS contracts, repository safety, SunPad snapshot, and diff checks:
  pass.

The full Apple link remains unavailable at the fail-closed local Dawn cache
hash mismatch recorded by the first shared A3 slice; no dependency pin or
integrity check was changed.

## Classification

**Pass for pre-extraction duplicate rejection in the shared scan and its Apple
consumer.** This does not prove an Android installer or A3 gameplay. A2 remains
open for physical Android acceptance. A3 remains open for byte/hash and payload
validation, Android download/storage/extraction/activation/recovery, failure
injection, and the complete emulator/physical offline gameplay matrix. No
APK/AAB, archive, game data, save, identifier, or private log was published.
