# Android A3 install storage and recovery

Date: 2026-09-04

Branch: `codex/android-a3-install-storage`

Baseline: `636e72e7316fadb9737d9719acc0569e99e342a8`

## Falsifiable subgoal

Give Android an app-private, same-volume Retro Rewind staging/activation/
rollback contract that restores the prior complete installation after an
injected activation failure and performs deterministic cold-start recovery.

## Result

- Added `RetroRewindInstallStorage` under the Android owner layer. All active,
  staging, and rollback directories are direct children of
  `filesDir/KartPad`, so production activation uses a same-filesystem
  `ATOMIC_MOVE` rather than copying a partially extracted tree into place.
- Install tokens are limited to 1--64 ASCII letters, digits, and hyphens; the
  activation API also requires the exact normalized staging path created for
  that token.
- Startup removes stale `RetroRewind.import-*` trees. If the active install is
  absent and exactly one real rollback directory exists, it atomically restores
  that directory. Multiple rollbacks are left untouched for explicit recovery
  rather than guessed.
- Support, installed, staging, and rollback roots must be real directories, not
  symlinks. Recursive cleanup does not follow symlinks.
- A validated staging activation first moves the old install to a unique
  rollback, then moves staging into the active name. If the second move fails,
  the old install is restored; a failed restoration is retained as a suppressed
  error and remains recoverable on the next startup.
- Game-runtime `KartPadActivity` invokes recovery before installing public
  runtime resources or loading SDL. Public fixture mode packages the owner but
  does not mutate a Retro Rewind directory.

Source SHA-256 values:

- owner: `4f70ae8a97a238c604e2fd1563cc735b7065249c01acf12fb1d251c68497b99f`
- test: `2c8e7fd513ec9033ec350a9060f99d54b75bad200657017a9cac3e6e40a6a789`
- runner: `77e7b2058cd7977cda8782a113219b02185d548ae5571d033927690e6b7ab646`

## Verification

- Pinned-JDK warning-as-error storage contract: pass. It covers stale staging
  removal, single rollback restoration, ambiguous rollback refusal, successful
  replacement, injected second-move failure with old-install restoration,
  out-of-scope staging, unsafe tokens, and support/rollback symlink refusal.
- Public fixture debug assemble: pass.
- Public debug lint plus debug/release Kotlin and Java compilation: pass.
- Private game-runtime debug Kotlin and Java configuration compilation: pass.
  This is a compile only; the private runtime APK was not rebuilt or installed.
- The exact source-only debug APK is 33,675,275 bytes with SHA-256
  `ec5eefa73266e1dd15e76a9a76369093b3a4bb538022ffe5ea116d39c6bb5699`.
  Its ABI, alignment, native dependency, permission, asset allowlist, and
  private-data/path audit passes.
- Bash syntax, shell lint, repository safety, and diff checks: pass.

## Classification

**Pass for Android app-private same-volume staging, atomic activation,
rollback, and cold-start recovery contracts.** No archive is downloaded or
extracted yet, and only a future content validator may call the activation API.
A2 remains open for physical Android acceptance. A3 remains open for Android
archive acquisition/inspection/extraction and content validation, lifecycle-
durable progress/cancellation, fault tests beyond this storage layer, and the
complete emulator/physical offline gameplay matrix. No APK/AAB or private data
was published.
