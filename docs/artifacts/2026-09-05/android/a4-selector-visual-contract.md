# Android A4 selector visual contract

## Scope

This checkpoint converts the first-launch selector's phone/tablet visual review
into a repeatable raw-frame contract. It covers the selector only; touch-overlay
goldens and physical-device appearance remain separate gates.

## Harness

`scripts/test-android-selector-visual.sh` builds the source-only APK, requires
exactly one already-running emulator, locks the lane's native landscape
orientation, installs the fixture, and opens the real launch activity. A
debug-only fixture flag makes private game-data validation succeed without
including, reading, or fabricating RMCP01 content; production game-runtime builds
cannot activate that flag.

The wrapper captures UI Automator hierarchy plus Android's raw RGBA screencap.
`scripts/check-android-selector-visual.py` uses only the Python standard library
to verify:

- every iOS-equivalent selector label and the accessible KartPad mark;
- equal, separated, horizontally centered Original/Retro card columns;
- a full square mark target and aligned card content bounds;
- exact iOS-derived Original `(8, 125, 255)` and Retro `(245, 56, 99)` fills;
- the diagonal navy-to-wine background direction; and
- the exact canonical raw-frame dimensions and RGBA format.

## Results

Both visible pinned API 36 ARM64 lanes pass the same wrapper:

```text
Android selector visual contract passed: viewport=2400x1080 cards=973px blue=(8, 125, 255) pink=(245, 56, 99) gradient=(14, 17, 41)->(38, 12, 31)
Android selector visual contract passed: viewport=2560x1600 cards=742px blue=(8, 125, 255) pink=(245, 56, 99) gradient=(15, 17, 41)->(37, 12, 31)
```

The ignored phone/tablet raw frames have SHA-256 values
`95d1c5d61715a1f7249baffbe5a987b2cf54841f0b094cf01d2c51ca0c823531`
and `dc0778a840176752eb3c25e54a22f71ae46563ea8acfdd376127001412f2a270`.
The source-only APK SHA-256 is
`5c913a2d10345a5e01494d9df269f75fc168e3d61f626ef1feec6649d8c53e12`.

The complete translated dual-runtime APK then rebuilt and passed the strict
package/privacy audit at SHA-256
`2244ca5d1cf74d85d1b98279f36aa67a165e30dd3510c05612beb48a7b58da94`.
Android lint, the 74-test suite with one intentional skip, repository safety,
Python compilation, shell syntax, and whitespace checks pass.

## Classification

Pass for automated selector visual contracts on canonical emulator phone and
tablet viewports. This is stronger than screenshot inspection but is not a
claim of cross-platform pixel-identical font rasterization or physical-screen
acceptance. No APK/AAB, private content, raw frame, UI dump, or screenshot was
published.
