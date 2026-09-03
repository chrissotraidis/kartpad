# Android A1 Vulkan readback, present, and foreground recreation

## Classification

**Pass for the first A1 renderer slice on both pinned ARM64 emulator lanes.**
The source-only fixture creates one Dawn Vulkan device, clears a 4×4
`RGBA8Unorm` texture, copies it to a 256-byte-row mapped buffer, and verifies
all 16 pixels as `20-80-e0-ff`. It separately creates a WebGPU surface from
SDL's Android `ANativeWindow`, clears and presents the current surface texture,
goes HOME, observes the SDL background boundary, resumes after teardown has
settled, and successfully creates and presents through the replacement surface.

This does not prove visual color through screenshot comparison, translated
Aurora rendering, rotation, repeated surface stress, guest memory, fibers,
physical-device Vulkan correctness, gameplay, or performance. A1 remains in
progress.

## Command and result

```sh
./scripts/run-android-fixture.sh KartPad_API_36_ARM64
./scripts/run-android-fixture.sh KartPad_API_35_PS16K_ARM64
```

| Lane | API | Page size | GPU readback | Surface lifecycle |
| --- | ---: | ---: | --- | --- |
| `KartPad_API_36_ARM64` | 36 | 4,096 | 16/16 pixels exact | initial present and post-HOME present pass |
| `KartPad_API_35_PS16K_ARM64` | 35 | 16,384 | 16/16 pixels exact | initial present and post-HOME present pass |

Both use the emulator's gfxstream path with host lavapipe and guest Vulkan
`ranchu`. The exact local debug APK is 33,537,851 bytes with SHA-256
`151397d104723415d4db9663f4a4566f3d769d42708d600ec417ea5525fa846f`.
It passes the inherited A0 package, ELF, alignment, symbol, permission, and
privacy audit. No APK/AAB was hosted or published.

## Failure signatures resolved

- The first surface implementation created a second Dawn device from the same
  native adapter; that returned null after the readback device had completed.
  Readback and presentation now share one device, matching the product's
  intended ownership model.
- SDL's Android window path maps the `RESIZABLE` flag to a new requested
  orientation. Removing that desktop-oriented flag keeps the manifest and SDL
  at sensor landscape and eliminates a first-activity recreation race.
- Relaunching immediately when the background marker was queued could overlap
  Android's `onStop`/surface teardown and destroy the activity. The runner now
  waits for teardown to settle before requesting foreground; both cold-boot
  lanes then pass the replacement-surface presentation.

## Next gate

Add explicit orientation/surface-generation observation and bounded repeated
recreation stress. Then implement page-size-aware Android guest-memory alias
and protection fixtures and the ELF AArch64 scheduler/register stress fixture.
