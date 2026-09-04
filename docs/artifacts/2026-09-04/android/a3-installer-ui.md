# Android A3 production installer UI

Date: 2026-09-04

Branch: `codex/android-a3-installer-ui`

Baseline: `b04437b`

## Falsifiable subgoal

Put the existing durable installer behind a production Android screen that
observes its persisted state, shows determinate phase/byte progress, exposes a
real cancel/retry action, survives UI-owner loss, and opens from the foreground
notification. Do not download or install the production archive.

## Result

- Added a release-owned, non-exported `RetroRewindInstallActivity`. Its
  production action enqueues the pinned unique worker; its cancel action calls
  the same production facade proven by the prior worker fault test.
- The screen observes the unique WorkManager chain independently of the
  activity lifecycle and renders waiting, capacity check, download, extraction,
  success, cancellation, and failure states. Active byte totals are shown as a
  determinate percentage, and users are told work continues off-screen.
- A foreground-notification tap now returns to this status screen through an
  immutable explicit pending intent. Android 13+ install starts are gated on
  notification permission, and Android 12+ is told to show the long-running
  foreground notification immediately rather than deferring it.
- A historical WorkManager success is not treated as proof that files are still
  usable. The screen hashes and validates the installed pinned version and
  required artifacts on a private executor before reporting ready.
- The debug manifest alone permits privileged ADB launch with
  `android.permission.DUMP`; release keeps the activity non-exported. The debug
  path uses a bounded worker and labels its completion as a fixture, never as
  installed game data.

## Verification

- On a wiped API 36 / 4 KiB AVD, worker UUID
  `cf536fba-365b-446d-ba12-51f1884156e9` entered the visible running state.
  Keyboard focus activated the real production Cancel button without using
  screen coordinates. The activity observed terminal `CANCELLED`, exposed
  Retry, rejected any worker completion marker, and restored the same cancelled
  state after an app force-stop and ordinary reopen.
- The same run granted the runtime notification permission, required an active
  KartPad notification with a content intent, and resolved that pending intent
  to the non-exported production installer activity.
- The progress and cancelled layouts were visually inspected at the emulator's
  2400×1080 landscape framebuffer. Text, progress, and the single active action
  remained readable without scrolling.
- All seven pre-existing A3 host contracts plus the new UI harness pass. Debug
  assemble, release Kotlin/Java compilation, API-28 lint, strict package/privacy
  audit, the 22-test builder suite (one expected private-payload skip), SunPad
  snapshot, repository safety, shell syntax/lint, and diff checks pass.
- The exact source-only debug APK is 33,843,921 bytes with SHA-256
  `2e0e28fab71ea96e4d17e46fea5b7699b690284736010ff441f795be509d8079`.

## Classification

**Pass for a production-owned installer observer, notification return path,
visible progress, explicit cancellation, retry presentation, and validation
before ready.** The current Android product still lacks its first-launch dual-
mode chooser, so this screen is not yet routed from normal game startup; only
active installer notifications and future in-app callers can open it in
release. Official-archive cancellation, a production-size install/fault matrix,
Retro Rewind gameplay/mode switching, and physical hardware remain open. No
APK/AAB, archive, private data, device identifier, or raw log was published.
