# Android A1 rotation and repeated Vulkan surface lifecycle

## Classification

**Pass for deterministic flipped-landscape handling and three consecutive
background/foreground surface replacements on both pinned ARM64 emulator
lanes.** SDL observes the physical sensor transition, Dawn reconfigures and
presents through the retained Android surface, and then releases/replaces the
surface after each actual Android teardown.

This is bounded source-only emulator evidence. It is not physical-OEM
lifecycle, foldable/multi-window, long-session, gameplay, or performance
evidence. A1 remains open for the ELF AArch64 scheduler/register stress gate.

## Ownership model

- Android `surfaceChanged`: retain the existing `WGPUSurface`, configure it for
  the current pixel size, acquire, clear, and present.
- Android background/foreground: allow `onStop` and `surfaceDestroyed` to
  finish, release the Dawn surface after foreground, acquire SDL's replacement
  `ANativeWindow`, create a replacement `WGPUSurface`, and present.
- Final shutdown: release the retained surface before the shared Dawn device.

The distinction matters. A rejected intermediate implementation attempted to
create a brand-new Dawn surface from a `SurfaceView` that Android had changed
in place during 180-degree rotation; Dawn correctly rejected that transition-
era surface at capability lookup. Retaining the owning surface across
`surfaceChanged` and replacing it only across true destruction is stable.

## Commands and exact results

```sh
./scripts/run-android-fixture.sh KartPad_API_36_ARM64
./scripts/run-android-fixture.sh KartPad_API_35_PS16K_ARM64
```

| Lane | API | Page size | Rotation | Replacement cycles | Result |
| --- | ---: | ---: | --- | ---: | --- |
| `KartPad_API_36_ARM64` | 36 | 4,096 | SDL `1 → 2`, present | 3/3 | pass |
| `KartPad_API_35_PS16K_ARM64` | 35 | 16,384 | SDL `1 → 2`, present | 3/3 | pass |

Each was a wiped cold boot. The runner pins an absolute emulator acceleration
vector rather than relying on relative emulator orientation state. It requires
surface presentation generations 1 through 5: initial, flipped orientation,
and three foreground replacements. It also fails if any `KartPadFixture` error
line exists after all positive markers.

The combined run retains the exact GPU readback and guest-memory checks. The
exact local debug APK is 33,545,363 bytes with SHA-256
`f2efa7efd850d41fe5bb4b19e0d2d448ade8ee3a4f82f58397c63665cdfe2e70`.
It passes the inherited Android package, ELF, 16 KiB alignment, symbol,
permission, and privacy audit. No APK/AAB was hosted or published.

## Next gate

Implement the Android ELF AArch64 cooperative scheduler fixture and prove
start/yield/sleep/wake/join/cancel plus callee-saved general/SIMD register
preservation under a long bounded stress run on both page-size lanes.
