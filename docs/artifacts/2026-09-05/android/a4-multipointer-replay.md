# Android A4 multi-pointer replay

## Scope

This checkpoint closes the automated four-finger gameplay-combination replay
required by the A4 emulator gate. It does not claim physical touch ergonomics,
digitizer behavior, or a complete touch-only race.

## Fixture

The source-only activity can now opt into a production-gated replay that builds
real Android `MotionEvent` objects and sends them through
`KartPadOverlayView.onTouchEvent`. The replay uses four stable pointer IDs at
the actual laid-out left-stick, A, R, and Z controls:

1. pointer 0 steers right at 0.75 analog deflection;
2. pointer 1 presses A while steering remains held;
3. pointers 2 and 3 add R (drift/hop) and Z (item) independently;
4. A, Z, and R lift in turn while steering remains at 0.75; and
5. the stick pointer lifts last and returns both axes to neutral.

After each event, the fixture checks the exact Classic button mask and analog
state supplied to the normal native touch bridge. It requires the stick to
remain active through the three independent button releases, the pointer-owner
table to be empty at completion, and both axes to return to zero. The delayed
A-lock generation is invalidated before it can fire. The fixture invocation
requires both a debug build and `GAME_RUNTIME=false`; private production
runtime startup cannot activate it.

`scripts/test-android-touch-multipointer.sh` builds and installs the source-only
APK, enforces the one-device rule and lane-native landscape rotation, launches
the replay, and accepts only this marker:

```text
A4 multi-pointer fixture passed steer=0.75 all=0x214 afterA=0x204 afterZ=0x200 steerOnly=0x0 neutral=0x0
```

## Results

The same wrapper passed on visibly running wiped API 36 ARM64 Pixel 6 and Pixel
Tablet emulators. This proves simultaneous steering, acceleration, drift, and
item input; independent release ownership; retained analog steering; and a
neutral final release on both canonical geometries.

The complete translated dual-runtime APK then rebuilt and passed the strict
package/privacy audit at SHA-256
`205abbb668872500975e734ca52f3132fb18122e80905c35211883f01b4c5967`.
Android lint, the 86-test suite with one intentional skip, repository safety,
shell syntax, Python compilation, and whitespace checks pass.

## Classification

Pass for automated four-pointer gameplay ownership, analog retention, and
published-mask transitions on the canonical emulator phone/tablet lanes.
Physical digitizer behavior, A-lock feel, haptic feel, and touch-only racing
remain physical acceptance gates. No APK/AAB, private data, raw log, UI dump,
or screenshot was published.
