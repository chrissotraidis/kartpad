# Android A4 reporting parity checkpoint

Date: 2026-09-04

## Scope

This checkpoint replaces Android's empty diagnostic template with the same
user-guided reporting flow exposed by KartPad on iOS.

## Implementation

- Report a Problem now asks what went wrong, where/what the user was doing, and
  whether it happens every time, sometimes, once, or is unknown.
- Share Report creates a bounded plain-text report with a random short report
  ID, app revision, Android/API version, device model, selected runtime profile,
  Retro Rewind release, and the three answers.
- Report on GitHub uses `Uri.Builder` query encoding and pre-fills the bug title,
  report ID, revision, platform, runtime profile, summary, context, and
  frequency. It does not include game data, saves, credentials, controller
  input, screenshots, or local paths.

## Emulator evidence

- The API 36 ARM64 emulator displayed all three accessible fields and the GitHub,
  Cancel, and Share actions over the running Original profile at 2400x1080.
- The dialog was canceled; no chooser, browser, report, issue, or message was
  opened, created, or sent.
- Game data, RKSYS, and the Mii database retained their exact checkpoint hashes.

## Verification

- Exact local-only dual APK SHA-256:
  `539d9bf73e617c052b4439db0c017d1d5bc425288d2852a7fec6146241e78577`.
- Kotlin compilation, Android lint, strict APK/privacy audit, 49 Android/iOS
  source contracts, and whitespace checks: pass.

No APK, AAB, diagnostic report, issue, message, or private artifact was
published.
