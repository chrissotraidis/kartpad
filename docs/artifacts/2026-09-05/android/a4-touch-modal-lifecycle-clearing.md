# Android A4 touch modal and lifecycle clearing

## Scope

This checkpoint converts Android's modal/lifecycle held-input clearing from a
source-only assertion into real `MotionEvent` replay through the production
Activity and overlay owners. The fixture entry points are accepted only by a
debug non-game-runtime build.

## Method

`KartPadOverlayView.runDebugHoldAForModalFixture()` sends a touchscreen
`ACTION_DOWN` at the laid-out A-button center. It refuses to arm unless the
normal publisher reports Classic A (`0x10`) and exactly one pointer owner.

Two independent tests then use normal application paths:

- modal: `showKartPadMenu()` opens the real three-dot hierarchy, whose first
  action clears touch state;
- lifecycle: the test sends Android `KEYCODE_HOME`; the first normal
  `onPause`/focus-loss callback clears touch state.

Both tests require the final published mask to be neutral, the pointer-owner
table to be empty, and acceleration lock to be off.

## Emulator evidence

The visible API 36 ARM64 Pixel Tablet passed the modal route:

```text
A4 modal clear fixture passed held=0x10 owners=1 neutral=0x0 owners=0
```

The visible API 36 ARM64 Pixel 6 passed both the modal route and the Home
lifecycle route:

```text
A4 modal clear fixture passed held=0x10 owners=1 neutral=0x0 owners=0
A4 lifecycle clear fixture armed held=0x10 owners=1
A4 lifecycle clear fixture passed reason=pause neutral=0x0 owners=0
```

## Build and audit

The complete translated Original/Retro runtime rebuilt locally. Its APK
SHA-256 is:

`760b440accaaf430b13f3346cae39632411cb53a678b288c12694059152b43b3`

Android lint, the 79-test Python suite with one intentional skip, strict
package/privacy audit, repository safety, shell syntax, and whitespace checks
pass. No APK/AAB or private artifact was published.

## Classification

**Pass for real held-touch clearing when the menu opens on phone/tablet and
when the phone Activity loses foreground.** OEM-specific lifecycle behavior and
physical touch remain physical-device acceptance rows.
