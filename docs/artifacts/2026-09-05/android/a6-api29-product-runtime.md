# Android A6 API 29 product-runtime compatibility

Date: 2026-09-05

Branch: `codex/android-a4-touch-settings`

Baseline commit: `9faffce`
Classification: **Pass on the official Android 10 ARM64 emulator; physical
hardware remains open.**

## Subgoal

Determine whether the complete dual-game release runtime can execute on the
oldest official ARM64 emulator image with a usable Vulkan inventory, correct
any product-owned compatibility defect, and repeat the exact release-bundle
gate on the modern pinned tablet lane.

## Baseline and diagnosis

- Target: disposable API 29 `google_apis` ARM64 AVD, 4,096-byte kernel pages,
  host GPU, official system-image revision 13.
- The image exposed a real Vulkan adapter, unlike the empty API 28 inventory.
- The existing preview retained its process but remained on an almost entirely
  black frame. Native stacks localized the stall to concurrent Dawn pipeline
  creation and submission inside the Android 10 Goldfish Vulkan handle map.
- Disabling both pipeline and frame workers avoided that wait but moved all
  pipeline work onto SDL's approximately 1 MiB thread and produced a native
  `StackOverflowError`. That broad serialization was rejected.

## Correction

`aurora-android-api29-serialized-vulkan.patch` disables only Aurora's priority
pipeline-worker pool on API 29 and lower. Asynchronous frame submission and
presentation remain enabled. API 30 and newer retain the normal worker pool.
The patch is part of fresh Android runtime preparation and has a source
contract preventing accidental frame-worker serialization.

## Runtime evidence

The corrected debug runtime remained alive and produced diverse 2400x1080
frames at 15, 30, and 60 seconds. Its private console confirmed Vulkan,
asynchronous frame submission, asynchronous presentation, completed 1,214-
pipeline prewarm, and later telemetry near 60 FPS. It contained none of the
bounded fatal signatures. Raw logs and frames were kept ignored and deleted.

Two independent scoped clean release builds produced the identical unsigned
AAB:

- version code: `7`
- version name: `0.4.0-android-preview.2`
- AAB SHA-256:
  `d03f1791989142e109f2a3101a3bca629e80d3b8b1fdde54269b17b21d554f4a`

Pinned bundletool derived the retained local, nondebuggable universal APK:

- size: 90,477,735 bytes
- APK SHA-256:
  `cfb32065650a15e9d3ddab9aa2705ea62e9930626445c7e568e1ef29b8e53420`
- ignored path:
  `.android-bootstrap/hardware-preview/KartPad-0.4.0-android-preview.2-v7-arm64.apk`

On API 29, both the universal APK and the exact four-part device split passed:
one stable process, production selector, initialized SDL surface/audio,
diverse frames, consistent split signer, exact native bytes, preserved durable
state, and restored debug package. The same exact AAB then passed the complete
universal/split gate on the pinned API 36 Pixel Tablet, proving the conditional
compatibility path did not regress modern Android.

The guarded phone installer rejected the emulator before mutation. No APK/AAB
was published and no private artifact entered Git. The disposable AVD,
restricted 2.7 GB product transfer, raw diagnostics, and reproducibility copy
were deleted. API 28 remains provisional because its official emulator image
has no usable Vulkan adapter. Vendor Vulkan, physical touch/audio/haptics,
controller behavior, thermals, lifecycle soak, signing, and publication remain
physical or explicitly authorized gates.
