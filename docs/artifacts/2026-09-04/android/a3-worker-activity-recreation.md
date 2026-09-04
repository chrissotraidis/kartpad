# Android A3 install-worker activity recreation

Date: 2026-09-04

Branch: `codex/android-a3-worker-recreation`

Baseline: `0ecc0290d2bb688dbffe0aede84c058c131c78e3`

## Falsifiable subgoal

Destroy and recreate an installer-owning Android activity while a foreground
Retro Rewind work request is active. Require the same application process, one
worker UUID/start, duplicate suppression when the recreated UI enqueues again,
and successful completion.

## Result

- Added a debug-source-only, non-SDL activity that models the future native
  installer UI owner. It starts a bounded foreground worker, requests its own
  recreation after one second, and re-enqueues after recreation so
  `ExistingWorkPolicy.KEEP` is exercised across the real lifecycle.
- The fixture activity is absent from release builds. Its debug manifest is
  exported only for automation and requires Android's signature/privileged
  `android.permission.DUMP`, which permits ADB shell launch but rejects
  ordinary applications.
- The process-death/resume fault also moved to this lightweight owner, isolating
  installer lifecycle from SDL game-window startup.

## Verification

- On the final wiped API 36 / 4 KiB AVD, work UUID
  `c61d6ecd-0d8b-4d22-af3e-93572eb7c133` started once at attempt 0, the
  activity requested and observed recreation in PID 4580, the recreated
  activity re-enqueued with `KEEP`, and the original UUID completed once.
- In the preceding fault within the same harness, UUID
  `c00ecc2f-c283-4c6b-be1d-983ffe552c6e` persisted six bytes, lost its
  process, restarted at attempt 1 from byte 6, and completed. This confirms the
  lightweight owner still initializes durable work after process death.
- The first experimental implementation recreated `SDLActivity` during
  native startup. Android correctly destroyed its game window and the process
  restarted; that was not accepted as UI-recreation evidence. The implementation
  was removed in favor of the installer-specific owner above.
- Debug assemble, release Kotlin/Java compilation, API-28 lint, private
  game-runtime Kotlin/Java configuration compilation, strict package/privacy
  audit, relevant A3 contract runners, the 22-test builder suite, SunPad
  snapshot, repository safety, shell syntax/lint, and diff checks pass. No ADB
  target remains.
- The exact source-only debug APK is 33,843,921 bytes with SHA-256
  `e1a06115225c52e9749349a14d6fa22fd9688dd84b084604ddc679fe31a52b84`.

## Classification

**Pass for foreground install work surviving real same-process installer
activity destruction/recreation without duplicate execution.** This does not
prove production UI observation/cancellation, the official archive install,
complete production fault injection, Retro Rewind gameplay/mode switching, or
physical hardware. A2 and A3 remain open. No APK/AAB, production archive,
private data, device identifier, or raw log was published.
