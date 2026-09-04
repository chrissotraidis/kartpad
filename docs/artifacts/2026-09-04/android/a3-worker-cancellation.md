# Android A3 install-worker cancellation

Date: 2026-09-04

Branch: `codex/android-a3-worker-cancellation`

Baseline: `c39e1645a4f7749a3de5b931a68b5e3297bad410`

## Falsifiable subgoal

Cancel the unique foreground installer through its production facade while it
is actively appending bytes. Require one worker start, WorkManager's terminal
`CANCELLED` state, a preserved nonzero partial, and no success marker.

## Result

- Extended the shell-protected debug installer activity with a cancellation
  path that starts the actual resumable worker fixture and calls
  `RetroRewindInstallWork.cancel` while bytes are being appended.
- The fixture observes the exact request by UUID through WorkManager, reports
  only after its state is terminal, verifies the stable partial without
  following links, and removes only that debug fixture after recording the
  result.
- The slow debug stream now handles thread interruption without emitting an
  application exception. Production synchronous callbacks already observe
  WorkManager's stopped state, while either cancellation or an interrupted
  network read preserves the version-scoped production partial.

## Verification

- On the final wiped API 36 / 4 KiB AVD, UUID
  `6c06261e-cb0d-4cfe-8d71-f4b03c7572b2` started once, emitted a nonzero
  checkpoint, received cancellation through the production facade, reached
  WorkManager state `CANCELLED`, and retained seven partial bytes. The harness
  rejected a success marker and any KartPad/Android fatal.
- The same final run reconfirmed exact-UUID process-death resume from a
  six-byte prefix and same-PID installer activity recreation with one worker
  start.
- Debug assemble, release Kotlin/Java compilation, API-28 lint, strict
  package/privacy audit, shell syntax/lint, and diff checks pass. Relevant A3
  host contracts, builder tests, SunPad snapshot, and repository safety pass.
  The private game-runtime Kotlin/Java configuration also compiles.
- The exact source-only debug APK is 33,843,921 bytes with SHA-256
  `b18b26c878a94b071859d389730f9e37ed7526f40739552a814e245fea7f3d6b`.

## Classification

**Pass for explicit unique-work cancellation, terminal-state observation,
partial retention, and no false success on the emulator.** This does not
provide the production user interface, exercise cancellation against the
official 1.86 GB response, or close production full-disk/network/gameplay and
physical-device rows. A2 and A3 remain open. No APK/AAB, production archive,
private data, device identifier, or raw log was published.
