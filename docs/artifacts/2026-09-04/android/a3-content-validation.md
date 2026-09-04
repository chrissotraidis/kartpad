# Android A3 pinned content validation

Date: 2026-09-04

Branch: `codex/android-a3-content-validation`

Baseline: `ba998d46b14d870b378f85dc066d65b88ce9c905`

## Falsifiable subgoal

Generate Android's Retro Rewind release constants from the repository profile
and prevent an incomplete, wrong-version, wrong-size, wrong-hash, unsafe, or
symlinked staging tree from reaching atomic activation.

## Result

- Added a deterministic Android Java contract renderer and checked-in generated
  contract. A builder regression compares the file byte-for-byte with
  `builder/profiles/mkwii-rmcp01-rev0.json`, so a profile advance cannot leave
  Android's visible version, root, URLs, byte counts, or hashes stale.
- The generated contract includes the archive, `Code.pul`, Riivolution XML, and
  production payload pins. The payload remains a translated-build input: the
  existing builder validates its size, hash, header, declared size, and
  signature before producing the native profile. It is not an installed pack
  file and is not downloaded again by the Android app.
- Added a bounded Android installed-tree validator. It reads at most 129 bytes
  for `version.txt`, decodes strict UTF-8, compares the exact trimmed version,
  and streams required files through the platform SHA-256 implementation with a
  1 MiB heap buffer.
- Required artifact paths must satisfy the same absolute/backslash/NUL/dot/
  parent/colon rules and every parent/final node must be a real directory/file,
  not a symlink. Size is checked before hashing and again against streamed bytes
  to catch a changed file.
- Validation results contain only fixed error categories and profile-relative
  artifact names; absolute app-private paths are never returned.
- `validateAndActivate` joins this validator to the prior storage coordinator.
  Invalid staging remains in place and leaves the active install unchanged;
  only a fully valid tree reaches the atomic swap.

Source SHA-256 values:

- renderer: `3a5a846e5001cbd3adff832b0cedb7bb4bfdceb1e0b81a0e88b88b279676fdef`
- generated contract: `4c631fe8847657b7ab657ff720a5bd1ab588c0af1b74294a3b9b4d0e51f76040`
- validator: `342eae827d6fb66e3ead629ac38f62db33c7b77ec57f0a3da146ef0ee00dca3d`
- test: `4e81526ec160bcbf1f77ff2bc7cf523c6cbd0107bbc079821abc9f3e2cf19563`
- runner: `8d0f18110580038e3c713f324da09f8fbd1f6fc0a51187d7256a1285a639632f`

## Verification

- Pinned-JDK warning-as-error content matrix: pass. It covers valid staging and
  post-activation validation, invalid staging refusal, wrong/invalid/oversize
  version files, missing/short/tampered artifacts, unsafe requirements, and a
  symlinked required file.
- Generated-contract/profile byte comparison: pass.
- Complete builder suite: 21 pass plus one optional private-payload test skip.
- Public fixture debug assemble, release Java compilation, and debug lint: pass.
- Private game-runtime debug Kotlin/Java configuration compile: pass. No private
  APK was rebuilt or installed.
- The exact source-only debug APK is 33,675,275 bytes with SHA-256
  `2c6ad2c220444e61ce36826f7b90116fa29be369ba43831d44af9dc670b15e5f`.
  Its ABI, alignment, native dependencies, permissions, assets, and private-
  data/path audit passes, and the validator is present in its DEX.
- Shell syntax/lint, repository safety, and diff checks: pass.

## Classification

**Pass for profile-derived Android release constants and bounded exact installed
content validation gating atomic activation.** This does not download, inspect,
or extract the archive, nor prove process-death behavior or gameplay. A2 remains
open for physical Android acceptance. A3 remains open for acquisition,
free-space preflight, ZIP adapter/extraction, durable progress/cancellation,
fault injection across those layers, and complete emulator/physical offline
mode-switch/race/save/relaunch acceptance. No APK/AAB or private data was
published.
