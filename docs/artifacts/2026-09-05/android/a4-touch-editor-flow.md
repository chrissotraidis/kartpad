# Android A4 touch layout editor flow

## Scope

This checkpoint executes the full Android touch-layout editing round trip on
both canonical emulator families. The debug/source-only fixture opens the real
Touch Control Settings dialog, activates its real Move Controls button, and
selects the rendered A control with `MotionEvent.ACTION_DOWN` and
`MotionEvent.ACTION_UP` through the production overlay.

The fixture then requires the editor bar to name A and enable its selected-size
and visibility controls. It invokes the real Hide action and requires the
persisted state and action label to change to hidden/Show, invokes Show and
requires the inverse state, sets A to 1.25x through the overlay owner, and
invokes the real Back button. It refuses to pass unless the editor closes, the
three-dot button returns, and a new Touch Control Settings dialog is showing.
Fixture preferences are reset after success.

## Emulator evidence

The visible API 36 ARM64 Pixel 6 passed:

```text
A4 touch editor fixture passed selected=A hide=shown size=1.25 back=settings
```

The visible API 36 ARM64 Pixel Tablet passed the same exact state sequence:

```text
A4 touch editor fixture passed selected=A hide=shown size=1.25 back=settings
```

The untracked final-dialog screenshots have SHA-256 values
`aa2823304f9cd7af43799acd600d0d18e41c5ba99f4482c21a8413b3fde57496`
(phone) and
`0995b9a1028924bd0bdac0073653bdb36998ea319fdb545a53f6e654b4556f32`
(tablet). They contain no private game content and were not added to Git.

## Build and audit

The complete translated Original/Retro runtime rebuilt locally. Its APK
SHA-256 is:

`8d4bf7f24fd411edfa1a957dada33dfd425de495bbf6a53e2ce9570493c66c40`

No APK/AAB or private artifact was published.

## Classification

**Pass for Move Controls entry, rendered-control selection, per-control
Hide/Show, selected-size propagation, and Back-to-settings behavior on the
canonical phone and tablet emulators.** Physical finger-drag ergonomics and
touch-only races remain physical-device gates.
