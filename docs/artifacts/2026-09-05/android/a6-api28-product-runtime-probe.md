# Android A6 API 28 product-runtime probe

Date: 2026-09-05

Classification: **Blocked by the official API 28 ARM64 emulator image's unusable
Vulkan implementation; this is not an API 28 product-runtime pass and is not a
physical-device failure.** The retained hardware preview remains ready for a
Vulkan-capable ARM64 physical phone.

## Scope

A disposable Pixel 7 AVD used the official Android 9 / API 28
`google_apis;arm64-v8a` image. The known debug package and a restricted product
fixture were staged without saves, logs, shared preferences, or unrelated app
state. Every one of the 4,185 intended files matched its source content before
the release run.

The legacy image lacks `getconf`, so Android page-size probes now fall back to
`KernelPageSize` in `/proc/self/smaps`. It also cannot directly execute the
shell `test` builtin through `run-as`; the bundle runner now invokes that check
through `sh -c`. A failed `pidof` is normalized so the runner emits its bounded
"no stable process" diagnostic instead of exiting silently.

## Observed boundary

Both the AVD's default graphics setting and an explicit host-GPU restart
reported Vulkan hardware features, but `cmd gpu vkjson` returned an empty
inventory. During product startup:

- the production selector loaded and enabled Original;
- installed ARM64 `libmain.so` entered `SDL_main`;
- SDL created its surface and opened low-latency audio;
- Android's Vulkan loader then lacked required instance procedures;
- Dawn returned `VK_ERROR_INCOMPATIBLE_DRIVER` and found no supported adapter;
- Aurora selected its non-rendering null adapter and intentionally raised the
  fatal renderer dialog; and
- the process exited before the sustained-runtime gate.

This result does not show an Android 9 framework or ABI incompatibility. It
shows that this particular official emulator image cannot satisfy KartPad's
required Vulkan renderer. The declaration of API 28 support therefore remains
provisional until a Vulkan-capable physical API 28 device is tested; newer
Vulkan-capable physical phones can enter the existing preview handoff now.

## Cleanup

The debug version 5 package and selector were restored before shutdown. The
temporary API 28 AVD, restricted 2.7 GB transfer, checksum manifests, trace,
and private runtime log were deleted. The persistent API 36 Pixel Tablet was
restarted visibly and ends on the two-game selector. No APK, AAB, private game
content, log, screenshot, device identifier, or signing material was
published.
