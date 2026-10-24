# The WiiCompiled 0.9 graphics layer — 24 October 2026

WiiCompiled v0.9.0 (`ac99413`) replaced its vendored Aurora with
[patchzyy/aurora-wiicompiled](https://github.com/patchzyy/aurora-wiicompiled)
`dd399416`: 655 commits of upstream Aurora plus patchzyy's WiiCompiled work,
including a render worker, fixed-point indirect texturing, depth-copy fixes
and a reworked readback path. KartPad's runtimes carry about 100 platform
patches on the old Aurora, so 0.8.6 adds the new layer beside it on Android
instead of replacing it.

## How it ships

`vendor/runtimes/android` (`chrissotraidis/wiicompiled` `7e4e375`) has two
graphics layers: `aurora-main`, the classic layer and the default, and
`aurora-wiicompiled`. The same runtime source builds against either. The APK
carries `libmain.so` (classic) and `libmain_wiicompiled.so`; both keep the
shared-object name `libmain.so`, so the one game pack loads with either.
Translated code includes no Aurora header, and both libraries embed the same
pack fingerprint. `KartPadNativeRuntime` picks the library from the player's
choice (a file read fresh by the start screen and the game process), so a
process only ever loads one.

## What the new layer has

aurora-wiicompiled `dd399416` plus these KartPad changes (fork commit
`7e4e375`; `git diff` against `dd399416` shows exactly what changed):

- Android build: KartPad's SDL 3.4.4 AAR and pinned Dawn (cache callbacks as
  plain functions).
- The runtime's Aurora API: shared diagnostics header, frame-time percentiles,
  `GXSetSourceVtxDesc` (a no-op; this Aurora decodes indexed attributes
  itself), and the race-copy, pipeline-scene and prewarm entry points.
- The standard gamepad bridge behind Android controller slots, KartPad's port
  reservation (#378), and no rumble claim for controllers without a motor.
- KartPadSurface's surface mutex, the scheduler-guarded Android event pump,
  and background/foreground handling.

The classic layer now reads the v4 controller-preference file the new layer
writes, so switching keeps controller assignments.

## Not ported yet

- Adreno workarounds: CPU vertex repack, constant matrix lookup, native
  uniform buffers on Adreno 6xx/7xx, and the draw self-check (#102, #104,
  #301). Adreno phones that needed them should stay on Classic.
- Course pipeline recipes, launch prewarm and race-copy skipping. Their entry
  points do nothing, so shaders compile when first needed.
- Pipeline-cache flush before Android backgrounding, staging and EFB readback
  hardening, and draw-merge boundaries. Upstream reworked these areas; each
  needs review against the new code rather than a port.
- iPhone, iPad, Mac and Apple TV. The macOS runtime and this layer compile
  together, but iOS runs the runtime as the app executable, so choosing a layer
  there needs the runtime split into two embedded libraries. Mac can launch a
  second executable. Both are follow-up work.

## Checks

On an API 36 emulator with the host GPU, the release-signed dual APK passed
the bundle and APK audits (both runtimes: dependencies, stack, exports,
`libmain.so` name, TLS parser strings) and installed over the fresh-install
emulator. Classic and WiiCompiled each reached a Luigi Circuit race at about
60 FPS. WiiCompiled resumed its race after the app went to the background.
Switching from the in-game Display menu and from the start screen both
applied after a restart, and switching back to Classic loaded the classic
runtime again. No phone has run the new layer.
