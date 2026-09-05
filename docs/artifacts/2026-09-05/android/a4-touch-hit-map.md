# Android A4 touch hit map

Date: 2026-09-05

## Outcome

A new source-only emulator fixture verifies the gameplay overlay hit regions
separately from its raw-frame appearance. It runs against the real laid-out
`KartPadOverlayView` and requires:

- the center of every one of the 14 visible controls to resolve to that exact
  control;
- a near-edge point inside every circle, stick, or shoulder pill to resolve to
  that exact control; and
- a real `ACTION_DOWN` in empty gameplay space to return unconsumed while
  leaving the pointer-owner table and published Classic button state empty.

The fixture is available only in a debug source build with
`GAME_RUNTIME=false`; the translated runtime cannot activate it.

## Emulator evidence

Visible API 36 ARM64 Pixel 6 and Pixel Tablet runs both emitted:

```text
A4 hit-map fixture passed centers=14 edges=14 outside=passed
```

This includes the compact phone face-button cluster and the separate
iPad-derived tablet geometry.

## Build and audit

The complete translated runtime rebuilt at APK SHA-256
`7edb51da87682525093db9cedcd80d1eab795572371443d4aa4a8f857f16ac6e`.
The strict package/privacy audit, Android lint, 87-test suite with one
intentional skip, repository safety, shell syntax, and whitespace checks pass.
No package or private artifact was published.

## Classification

**Pass for canonical emulator center/edge hit mapping and empty-space
pass-through.** Physical digitizer edge behavior, palm rejection, latency, and
touch-only racing remain physical acceptance gates.
