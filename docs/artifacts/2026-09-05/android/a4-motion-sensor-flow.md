# Android A4 motion sensor flow

Date: 2026-09-05

## Outcome

A repeatable source-only emulator flow now exercises motion steering through
Android's real `SensorManager` registration and sensor callback path. The
fixture enables motion steering at 1x sensitivity, establishes a neutral
gravity baseline, and changes the emulator's accelerometer vector through the
documented emulator sensor command.

For each canonical layout it proves two independent processes:

- standard direction converts the injected tilt into positive steering; and
- the persisted Invert Direction setting converts the identical tilt into
  negative steering.

The callback is delivered to the production `KartPadMotionSteering` owner and
then to the normal overlay steering merge. The debug hook only logs the final
value and is unavailable when `GAME_RUNTIME=true`. The script restores the
emulator's original acceleration vector on every exit.

## Emulator evidence

Visible API 36 ARM64 Pixel 6 and Pixel Tablet runs both emitted:

```text
A4 motion sensor mode=standard direction=positive passed
A4 motion sensor mode=inverted direction=negative passed
Android motion sensor flow passed: lane=<lane> standard=positive inverted=negative
```

Both runs required `KartPadMotion` to report `started registered=true` before
injecting the tilt.

## Build and audit

The complete translated runtime rebuilt at APK SHA-256
`79eb1ac8da137b63e9060ae08f688a63bade1fb19777a25d85330bf6d1ef0750`.
The strict package/privacy audit, Android lint, 89-test suite with one
intentional skip, repository safety, shell syntax, and whitespace checks pass.
No package or private artifact was published.

## Classification

**Pass for canonical emulator Android sensor registration and standard/inverted
steering direction.** Physical-device steering feel, calibration ergonomics,
sensor noise, latency, and a motion-assisted race remain physical acceptance
gates.
