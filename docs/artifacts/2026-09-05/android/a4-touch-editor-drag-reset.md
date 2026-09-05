# Android A4 touch editor drag and reset

## Scope

This checkpoint strengthens the prior editor round trip with the two remaining
state-changing paths. After selecting rendered A, the source-only fixture sends
real `ACTION_DOWN`, `ACTION_MOVE`, and `ACTION_UP` events. It moves A four
percent of the safe width left and five percent of the safe height up, then
requires the rendered center and normalized persisted origin to match within a
bounded tolerance.

After exercising Hide/Show, selected sizing, and Back, the fixture invokes the
real Reset This Device Layout button and the real positive action in the reset
confirmation. It passes only after the queued Android dialog callback removes
A's custom origin and 1.25x size and leaves A shown at its default.

## Emulator evidence

The visible API 36 ARM64 Pixel 6 and Pixel Tablet both passed:

```text
A4 touch editor fixture passed selected=A dragged=A hide=shown size=1.25 back=settings reset=defaults
```

The first Pixel 6 attempt checked reset state synchronously after
`Button.performClick()`. It observed the pre-reset origin and size because
Android queues the `DialogInterface` callback. The final fixture verifies on
the next main-loop turn, after that real callback runs; both device families
then passed. This was a fixture-ordering correction, not a product reset
workaround.

## Build and audit

The complete translated Original/Retro runtime rebuilt locally. Its APK
SHA-256 is:

`8cc43a1f0ab1889caaeee4010322e48295bc5b599f36658d52d9e2b12c6cab33`

No APK/AAB or private artifact was published.

## Classification

**Pass for real editor drag persistence and confirmed per-device layout reset
on the canonical phone and tablet emulators.** Physical finger ergonomics and
touch-only races remain physical-device gates.
