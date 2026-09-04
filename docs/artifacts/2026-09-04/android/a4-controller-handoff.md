# Android A4 controller/touch handoff

## Falsifiable subgoal

When an Android game controller appears, clear all held touch state and hide
the touch overlay. When the last controller disappears, restore the overlay
without restoring any touch button or stick state.

This is an API 36 ARM64 emulator hotplug and state-clearing result. It is not
physical-controller discovery, physical touch feel, accessibility, controller
latency, or physical-device acceptance.

## Implementation

- `KartPadActivity` listens for Android input-device add, remove, and change
  events while resumed.
- Devices advertising either `SOURCE_GAMEPAD` or `SOURCE_JOYSTICK` participate
  in the handoff count.
- The first connected controller clears the native touch snapshot before the
  overlay becomes invisible. Removal of the last controller restores the
  overlay and publishes a neutral connected touch snapshot.
- Pause unregisters the listener and retains the existing unconditional touch
  clear. Resume registers once and immediately reconciles controllers that
  were already connected.
- The source contract covers discovery, listener lifecycle, touch clearing,
  hiding, and restoration.

## Emulator evidence

- Baseline source commit: `0d85914`; branch:
  `codex/android-a4-controller-handoff`.
- Device: standalone `KartPad_API_36_ARM64`, API 36, arm64-v8a, 4 KiB pages,
  logical landscape frame `2400x1080`.
- The 119,090,830-byte local-only APK has SHA-256
  `f777c271082b34a9896beda816ec85134cb3d7472a73d99607b311bcc10e994f`.
- Android InputReader classified the temporary device as keyboard, gamepad,
  joystick, external, and Xbox layout. The app logged controller counts
  `0 -> 1 -> 0` while the same rendered Retro Rewind process stayed active.
- With touch initially visible, controller connection hid every touch control;
  disconnect restored the complete overlay. Ignored screenshot SHA-256 values
  are `b7b3081f...fe10069`, `0a7f7fc7...71e055`, and
  `e964616b...a12e8`, respectively.
- A 1.4-second touchscreen hold first left A visibly cyan and locked. Connecting
  the controller hid the overlay; disconnect restored A green and unlocked.
  The ignored locked/hidden/restored screenshot SHA-256 values are
  `1a391263...30ea67`, `2a2a128...b62757`, and
  `bb4eaa2...fa5713`.
- The temporary virtual controller was disconnected at the end, and InputReader
  no longer listed it.
- The native touch contract, 13 Android/iOS touch-parity tests, Android lint,
  strict APK audit, repository safety audit, pinned source/input verification,
  SunPad snapshot verification, and `git diff --check` pass.

## Classification

**Pass for Android A4 emulator controller/touch handoff, including clearing a
latched A acceleration state across controller connect/disconnect.**

Still open: configurable controller-hides-touch policy, persistent touch
editing/opacity/size/hide, virtual accessibility nodes and hit maps,
multi-pointer replay, tablet layout, motion steering, physical controller and
touch behavior, and physical-device acceptance. No APK, AAB, screenshot,
private graph, save, or game data was published.
