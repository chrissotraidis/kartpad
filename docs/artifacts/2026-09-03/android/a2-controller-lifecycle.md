# Android A2 controller lifecycle evidence

Date: 2026-09-03

Base checkpoint: `396fbcc` (`codex/android-a2-sdl-rumble`)

Host: Apple Silicon macOS 26.6.2

Target: `KartPad_API_36_ARM64`, Android API 36, `arm64-v8a`, 4,096-byte
pages, gfxstream with host lavapipe

## Falsifiable subgoal

Make Android controller reads fail neutral while the app is backgrounded or
its native surface is unavailable, reject new rumble starts at the same
boundary, and stop any active rumble before the surface is released. Keep
SDL's background controller events enabled so a release that occurs while the
app is backgrounded is not lost.

## Implementation

Aurora now owns one lifecycle gate for the public standard-gamepad snapshot
and rumble APIs. The gate is derived from both Android surface readiness and
foreground state. Suspension makes every standard-gamepad snapshot neutral,
rejects rumble starts, and sends a zero-intensity stop to every open
rumble-capable pad. Stop commands remain legal while suspended.

The Android UI thread can change surface readiness while SDL processes a
controller add/remove event. A narrow mutex therefore serializes the public
snapshot/rumble/lifecycle bridge with controller add, remap, removal, and
shutdown, so suspension cannot use a gamepad pointer while removal closes it.
Other Aurora controller behavior and the Apple patch stack are unchanged.

## Failure-driven correction

The first ARM64 compile rejected the new calls because `window.cpp` included
only Aurora's private input header. Adding the explicit public
`aurora/input.hpp` include fixed that integration error.

The first live cold launch then logged only `Standard gamepads suspended`.
Android had already created the surface before Aurora initialized, and an
unconditional initialization-time suspend overwrote that authoritative state.
Initialization now derives the gate from the current surface and background
atomics. A corrected run logged `Standard gamepads resumed`; on the exact final
artifact, the first HOME action emitted a state-changing `Standard gamepads
suspended` marker, proving the bridge had been active before backgrounding.

One corrected process ended without an Android fatal record roughly eighteen
seconds after its first resume. A fresh process then retained the same PID
through four consecutive HOME / surface-destroy / foreground cycles and
reported exactly four suspend/resume pairs. The earlier silent exit is kept as
an unexplained, non-reproduced event; it is not attributed to this change and
is not counted as passing evidence.

## Verification

- The host `kartpad.android.gamepad-contract` test passes.
- The lifecycle patch dry-runs cleanly on the exact pre-change rumble source.
- A fresh complete Android runtime preparation applies the lifecycle patch;
  its modified Aurora header, input source, and window source are byte-for-byte
  identical to the tested tree.
- The complete private Original ARM64 runtime rebuilds and relinks.
- Exact final emulator process: PID `2293` retained across four cycles, four
  `Standard gamepads suspended` markers, four `Standard gamepads resumed`
  markers, and matching SDL `surfaceDestroyed` / `nativePause` /
  `surfaceCreated` / `nativeResume` transitions.
- The final run contains no Android fatal or `SIGABRT` record.
- Debug lint, release Kotlin compilation, runtime storage-layout contract,
  repository safety, patch whitespace, and strict APK audit pass.
- The broad source verifier accepts 426 hunks across 46 patches plus the
  WiiCompiled, SunPad, and WheelWizard pins, then stops at the pre-existing
  ignored `rr-pulsar` checkout/lock mismatch.
- Lifecycle patch SHA-256:
  `949aca693d660e966d0c3a8a6c10956e0f0aef0cc4488b8e10c6b96f01eee3a0`.
- Final local-only APK: 103,434,720 bytes, SHA-256
  `2c9c62b88277f34b27b481e254a25dd37936144d5c78a7db10eedb36c75e7145`.
- Extracted stripped `libmain.so`: 83,537,752 bytes, SHA-256
  `cf6b61932ef465c12135095ccfeb058c490fa2886f502d116c5dbeb9b87e0f24`.

No APK/AAB, private game data, save, controller identifier, or capture was
published.

## Honest classification

**Pass for lifecycle-gated controller input/rumble implementation, exact patch
reproduction, ARM64 compile/link, and an emulator execution trace through four
surface-loss cycles.** No controller was attached, so this does not prove a
real pad becomes neutral, a physical rumble motor stops, controller
disconnect/reconnect behavior, a complete race, or physical Android hardware.
A2 remains open.
