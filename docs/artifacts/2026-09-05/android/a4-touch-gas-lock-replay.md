# Android A4 touch acceleration-lock replay

## Scope

This checkpoint executes the accepted one-second touch-A acceleration lock as a
timed Android event sequence on both canonical emulator families. The
debug/source-only fixture sends a real A `MotionEvent.ACTION_DOWN` through the
production overlay, checks at 900 ms that A is held but not locked, and checks
after another 200 ms that the lock has activated.

The locked checkpoint requires the published Classic mask to remain A, the A
control to resolve to KartPad's cyan locked fill, the accessibility state to be
`Acceleration locked`, and exactly one virtual-key haptic request to have been
dispatched. Releasing the long press must leave acceleration locked with no
pointer owner; a subsequent A down/up must return the state to neutral.

The haptic counter is debug-only and wraps the same Android
`performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)` call used in the
product. It proves dispatch count, not physical vibration strength or feel.

## Emulator evidence

The visible API 36 ARM64 Pixel Tablet passed:

```text
A4 gas lock fixture passed delay=1106ms cyan=true haptics=1 release=locked tap=neutral
```

The visible API 36 ARM64 Pixel 6 passed:

```text
A4 gas lock fixture passed delay=1102ms cyan=true haptics=1 release=locked tap=neutral
```

## Build and audit

The complete translated Original/Retro runtime rebuilt locally. Its APK
SHA-256 is:

`f970b77c37030d2f0d4eb48ed770bb7309ccd866fbae18e4d7553465f510c505`

No APK/AAB or private artifact was published.

## Classification

**Pass for emulator timing, Classic publication, cyan visual state,
accessibility state, one haptic request, release-to-lock, and tap-to-unlock on
the canonical phone and tablet.** Physical haptic feel, finger ergonomics, and
touch-only races remain physical-device gates.
