# Android A2 virtual-controller hotplug evidence

Date: 2026-09-03

Base checkpoint: `f47ab98` (`codex/android-a2-cold-input`)

Host: Apple Silicon macOS 26.6.2

Target: `KartPad_API_36_ARM64`, Android API 36, `arm64-v8a`, 4,096-byte
pages, gfxstream with host lavapipe

## Falsifiable subgoal

Exercise Android's real InputReader-to-SDL gamepad discovery path with a
hotpluggable controller, prove button and analog input reach Mario Kart's
Classic/KPAD channel, and retain the same process across disconnect,
reconnect, background, and foreground. Treat emulator evidence as diagnostic;
do not upgrade it to physical-controller acceptance.

## Failure and root cause

The emulator shell can create a temporary `/dev/uinput` Xbox-compatible
gamepad. Android classified it as a keyboard, gamepad, and joystick and SDL
opened it. On the first south-button event, pre-fix PID `4204` aborted under
ART CheckJNI while `SDL_GamepadConnected` forced `SDL_UpdateJoysticks`, which
called Java `InputDevice.getDevice` from WiiCompiled's switched guest-fiber
stack. ART reported an invalid JNI transition-frame reference.

The first correction made KPAD reads consume event-backed cached buttons and
axes and queued rumble for the SDL event path. That allowed one hotplug,
button navigation, analog navigation, and unplug. A second hotplug then
reproduced the same abort in `aurora::window::poll_events`, reached from
`AdvanceDueRetraces` on a non-scheduler guest fiber. This separated the two
unsafe paths: both direct state queries and SDL event pumping could cross the
JNI boundary from a substituted stack.

The final correction:

- makes the game-facing standard-controller snapshot a pure mutex-protected
  cache read with no SDL or JNI calls;
- updates that cache from SDL button and axis events;
- queues KPAD rumble changes and flushes them during safe event polling;
- exposes whether WiiCompiled is executing on its original scheduler fiber;
- polls Android SDL events only on that fiber; and
- disables Aurora's opportunistic Android event pump, because the guarded
  poll path is the single authoritative pump.

Other platforms retain their existing event-pump behavior. No Java check was
disabled and no controller event was fabricated inside the application.

## Exact-final emulator result

Final PID `5007` survived all of the following in one run:

1. virtual controller connect;
2. south-button press/release reaching the Classic/KPAD channel as core
   `0x00000800` and Classic `0x00000010`;
3. disconnect;
4. reconnect of the same virtual controller;
5. repeated south-button navigation;
6. HOME/background with the process retained;
7. a HOT foreground resume with the same PID;
8. post-resume controller input; and
9. final disconnect.

In the preceding exact-code run, repeated controller presses advanced from
the title to the Main Menu and holding the left X axis moved the visible
selection from Single Player to License Settings. The final log recorded
connect, input samples, lifecycle suspension, disconnect, resume, reconnect,
post-resume input, and final disconnect. Final logcat contained no CheckJNI
abort, Java fatal exception, or native fatal signal.

The controller has no physical motor, so queued rumble output remains compile
and contract evidence only. Physical Bluetooth/USB identity, latency, motor
behavior, OEM lifecycle, and device Vulkan performance remain untested.

## Adjacent corrections

The earlier keyboard "cold relaunch input did not advance" observation was a
cadence false alarm. On the unchanged fresh PID `4204`, five normally spaced
Enter presses advanced title, license selection, and Main Menu while logging
the expected core and Classic triggers. A later controller-attached cold
relaunch was a separate real failure: safe guest-fiber polls were deferred but
not serviced reliably, and a batched down/up pair could collapse before KPAD
read it. That follow-up is corrected and evidenced separately in
`a2-controller-cold-relaunch.md`.

The completed `05:17.517` feedback race's `Ghost data could not be saved`
message is consistent with the already documented native macOS result for a
slow unguided run whose ghost recorder overflowed. The Android controller work
does not convert that inference into post-race save proof; A2's natural
results/save/relaunch row remains open.

## Verification

- A fresh complete Android runtime preparation applies both new patches and
  reproduces the seven tested Aurora/WiiCompiled files byte-for-byte.
- The complete private ARM64 runtime compiles, links, and packages.
- `kartpad.android.gamepad-contract`, runtime storage layout, repository
  safety, `git diff --check`, debug lint, release Kotlin compilation, and the
  strict APK/privacy audit pass.
- The SunPad overlay snapshot remains byte-identical at
  `e43f0ea6b797e5110787171957c9dc3c6213269c`.
- The broad source verifier accepts 444 hunks across 48 patches and the
  WiiCompiled, SunPad, and WheelWizard pins, then stops at the pre-existing
  ignored `rr-pulsar` checkout/lock mismatch.
- Aurora event-cache patch SHA-256:
  `9a93ba14e23efbb64ced86aa6f8655d96b1c4c2e1120721957f586de6b03e178`.
- WiiCompiled fiber-poll patch SHA-256:
  `2de5d2b66d24a0f84d8ff20b6db0eeeaac9c00cf7ffb8fd06ebd79b58732010b`.
- Final local-only APK: 103,437,088 bytes, SHA-256
  `44cbeed7bdca40541bdee71b944ffce17ee63fba10c05dca9777f0fe04f6a715`.
- Extracted stripped `libmain.so`: 83,540,120 bytes, SHA-256
  `67449ea532d61a17580f941b38ba74f52a2ea3cacf9d331a49bcf3143b69294a`.

No APK/AAB, private game data, save, NAND data, controller identifier, or
capture was published.

## Honest classification

**Pass for emulator controller discovery, button input, analog input,
disconnect/reconnect, hot background/foreground, JNI-safe event ownership,
exact patch reproduction, and ARM64 packaging.** This is a virtual controller,
not physical Android hardware. A2 remains open for a natural complete
controller-driven race, results and post-race save/relaunch, physical
controller/rumble, audible-device confirmation, and physical Android hardware.
