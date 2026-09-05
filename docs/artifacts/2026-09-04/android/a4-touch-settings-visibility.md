# Android A4 touch-settings visibility and render parity

Date: 2026-09-04

## Scope

This follow-up closes two concrete differences between the iOS and Android
three-dot touch settings: Android now includes iOS's live render-resolution
selector, and every touch setting is visible without an undiscoverable scroll
on the accepted landscape phone frame.

## Implementation

- Touch Control Settings now includes accessible 1x, 2x, 3x, and 4x radio
  choices backed by the same persistent resolution setting and live native
  display-settings path as the Display submenu.
- The landscape dialog uses two balanced columns. Render, opacity, and all-size
  controls are on the left; controller hiding, modern C-stick direction, Move
  Controls, and Reset This Device Layout are on the right.
- Reset This Device Layout now matches the iOS scope: it resets positions,
  grouped D-pad placement, individual/global sizes, visibility, and opacity. It
  no longer changes the independent hide-on-controller or C-stick-direction
  preferences.

## Emulator evidence

- The API 36 ARM64 emulator displayed the complete two-column panel over the
  running Original profile at 2400x1080. UI Automator found all four render
  choices, both sliders, both switches, Move Controls, Reset, and Done with
  nonempty visible bounds.
- Selecting 2x changed the checked accessibility node from 1x to 2x. Selecting
  1x again restored the persisted `resolution_scale` value to `1.0`.
- The installed game data, RKSYS, and Mii database retained the exact hashes
  recorded in the accessibility checkpoint.

## Verification

- Exact local-only dual APK SHA-256:
  `0217707c7410afe19923ae868bcc058dd14d9449cf8f03b2fb4c1b60f8db931f`.
- Kotlin compilation, Android lint, strict APK/privacy audit, 49 Android/iOS
  source contracts, and whitespace checks: pass.

No APK, AAB, game data, save, Mii database, log, or screenshot was published.
