# Android A2 controller cold-relaunch evidence

Date: 2026-09-03

Branch: `codex/android-a2-cold-input`

Target: `KartPad_API_36_ARM64`, Android API 36, `arm64-v8a`, 4,096-byte
pages, gfxstream with host lavapipe

## Falsifiable subgoal

Keep a controller attached before process startup, cold-launch the complete
Original runtime, and prove short controller taps reach title/license/menu
without crossing JNI from a switched guest-fiber stack. Also establish that
the same controller can navigate the complete Time Trial setup into live
gameplay. Do not treat a virtual controller as physical-device acceptance.

## Result and failures found

Before the cold-launch correction, the temporary InputReader `/dev/uinput`
controller navigated title, license, Main Menu, Single Player, Time Trials,
character, vehicle, drift, course, and entered live N64 Mario Raceway. After a
force-stop and relaunch with that controller still attached, controller and
keyboard events were no longer consumed even though rendering continued.

The prior JNI guard correctly refused Java-backed SDL polling on a Wii guest
fiber, but it discarded the request. The narrow correction records a pending
poll and services it on the original scheduler stack immediately after the
host-fiber switch returns. This preserves the single authoritative Android SDL
event pump and keeps JNI work on its valid stack.

The first clean scheduler build accepted a controller tap when temporary
event logging changed timing. The exact uninstrumented build did not reliably
accept a short tap. One scheduler poll can collect both button-down and
button-up before KPAD consumes the cached level, collapsing the press. The
final correction therefore latches each event-backed button-down for one
standard-gamepad snapshot while retaining the ordinary held-button level.

## Exact-final execution

The virtual controller existed before final PID `6595` started. No temporary
button logging or diagnostic timing change was present. The process remained
live while the translated game rendered. A deliberately short 250 ms
south-button press/release advanced the intro/title path to **Select License**;
a second 250 ms tap selected the existing license and visibly reached **Main
Menu**. This proves cold-start discovery and two consecutive short edges on the
production event-cache path.

One earlier first launch of the clean scheduler build, PID `4997`, exited at a
missing translated target with caller LR `0x80526ec8`
(`MiiManager::Init+0x134`). That is the known independent intermittent Mii
callback gap, not a controller or JNI failure. A controlled retry and the exact
final latch build remained live. No CheckJNI abort was observed in the
accepted run.

## Verification

- A fresh complete runtime preparation applied the final patch stack and
  reproduced the four inspected Aurora/WiiCompiled files byte-for-byte.
- The complete ARM64 runtime built and packaged successfully.
- `kartpad.android.gamepad-contract`, repository safety, `git diff --check`,
  the SunPad overlay snapshot, and the strict APK/privacy audit pass.
- Aurora event-cache patch SHA-256:
  `3adf33c3d2499be457c28121edc3a32b872a30bf965af24375a5c24b697025df`.
- WiiCompiled scheduler-poll patch SHA-256:
  `a818e58d8ef8ce96fe8e99695f9d368b5dc674c2b5fc95d2f0f019c97cf86ee9`.
- Final local-only APK: 103,440,032 bytes, SHA-256
  `2c11450996f33a35ba3aa85dcf16c1c467bf6fd4a0943edef966557639d7a6e7`.
- Extracted stripped `libmain.so`: 83,543,064 bytes, SHA-256
  `506ce89943e2e84a3ec7c9afd5ec4571d413d720bfa153ef70987de97e03210e`.

No APK/AAB, private game data, save, NAND data, controller identifier, or
capture was published.

## Honest classification

**Pass for controller-driven setup/race entry and controller-attached cold
launch through title, license, and Main Menu on the ARM64 emulator.** A2 stays
open for a complete natural controller-driven race, results, post-race save
and relaunch, physical controller/rumble, audible-device confirmation,
performance, and physical Android hardware.
