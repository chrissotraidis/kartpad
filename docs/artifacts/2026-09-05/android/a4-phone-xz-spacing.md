# Android A4 phone X/Z spacing

Date: 2026-09-05

## Outcome

The untouched Android phone layout now places X slightly farther left while
keeping Z against the right safe edge. This raises the rendered X/Z
edge-to-edge gap on the canonical Pixel 6 from 32 px to 49 px. Button sizes,
the vertical relationship, and the accepted phone ordering remain unchanged.

The change is confined to the phone fallback origin. Persisted custom origins
still win, and the separate iPad-derived tablet defaults are unchanged.

## Emulator evidence

- Visible Pixel 6, 2400x1080: 14 accessibility targets, 49 px X/Z gap, equal
  237 px L/R pills, and palette checks passed.
- Visible Pixel Tablet, 2560x1600: 14 accessibility targets, the existing
  212 px X/Z gap and 560 px R trigger remained unchanged.
- The focused 29-test touch-overlay contract passed.

## Build and audit

The complete local translated runtime rebuilt at APK SHA-256
`a1b88fc4f74d860ba97d530f8defff988995d73cd7fd4245617f50f4d79096bc`.
The strict package/privacy audit, Android lint, 86-test suite with one
intentional skip, repository safety, shell syntax, and whitespace checks pass.
No package or private artifact was published.

## Classification

**Pass for the canonical emulator phone spacing correction with tablet
regression coverage.** Physical-device ergonomics and touch-only racing remain
open.
