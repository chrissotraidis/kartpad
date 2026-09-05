# Android A6 physical Vulkan and storage preflight

Date: 2026-09-05

## Falsifiable subgoal

Reject an unsuitable Android phone before package mutation when it lacks a
declared Vulkan implementation or enough free space for the complete hardware
preview workflow.

## Changes

- The read-only physical-device gate now requires both
  `android.hardware.vulkan.version` and `android.hardware.vulkan.level` from
  Android's package-manager feature declarations. Driver JSON remains useful
  diagnostic inventory but is no longer the only Vulkan signal.
- The one-command hardware-preview installer raises its session floor from
  4 GiB to 6 GiB free under `/data`, covering more of the Original-data, Retro
  content, private install, and staging overlap. An override may raise but not
  lower that floor.
- The fake-ADB contract adds an explicit no-Vulkan rejection while retaining a
  supported case where driver JSON is unavailable but Android declares Vulkan.

## Results

- `scripts/test-android-physical-device-preflight.sh`: pass, 13 cases with ADB
  serial redaction
- installer/preflight contract unit tests: pass
- changed shell lint, syntax, and whitespace: pass
- live safety run with exact audited APK
  `898a03bed41a95af41537f626ffee6928b609aec397bde7643cdc48c136517d7`:
  the sole API 36 emulator was rejected as non-physical before install; the
  installed APK hash remained exactly unchanged and the selector stayed active

## Classification

**Pass for fail-closed Vulkan/storage intake and live emulator rejection, not
physical Android acceptance.** No physical phone was connected, no package or
app data was mutated by the negative run, and no APK/AAB was published.
