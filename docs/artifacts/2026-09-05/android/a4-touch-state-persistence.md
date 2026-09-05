# Android A4 touch state persistence

## Scope

This checkpoint proves that Android's per-control position, size, and
visibility settings survive a real process boundary and are applied to the
rendered/accessibility layout on both canonical device families.

The fixture is available only when `BuildConfig.DEBUG` is true and the private
game runtime is absent. It first resets the disposable fixture preferences,
then writes A at normalized center `(0.55, 0.55)`, A size `1.25`, and B hidden
through the same `KartPadTouchSettings` API used by the layout editor. The test
waits for asynchronous preferences persistence, force-stops the process, and
launches a new verification process.

The verifier refuses to pass unless the new overlay independently reloads the
three values, lays out A within two pixels of the safe-frame-derived center,
and omits B from its virtual accessibility children. It resets the fixture
preferences after success.

## Emulator evidence

The visible API 36 ARM64 Pixel 6 passed:

```text
A4 touch persistence fixture seeded a=0.55,0.55 size=1.25 b=hidden
A4 touch persistence fixture passed a_center=1378,588 a_size=1.25 b=hidden
```

The visible API 36 ARM64 Pixel Tablet passed:

```text
A4 touch persistence fixture seeded a=0.55,0.55 size=1.25 b=hidden
A4 touch persistence fixture passed a_center=1408,866 a_size=1.25 b=hidden
```

## Build and audit

The complete translated Original/Retro runtime rebuilt locally. Its APK
SHA-256 is:

`254b2614f7ae17d24a1547563b77f543bafd996f0f7030a7d3cad3266d70df61`

Android lint, the 80-test Python suite with one intentional skip, strict
package/privacy audit, repository safety, shell syntax, and whitespace checks
pass. No APK/AAB or private artifact was published.

## Classification

**Pass for process-persistent per-control position, size, and Hide/Show state
on the canonical phone and tablet emulators.** Update-in-place persistence and
physical-device touch remain separate gates.
