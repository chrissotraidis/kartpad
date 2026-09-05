# Android A4 controller player setup

## Scope

This checkpoint closes the emulator/UI portion of one-to-four-player controller
assignment. It does not claim physical multi-controller behavior, Bluetooth or
USB reconnect identity across vendor devices, rumble, or physical-device
acceptance.

## Change

- Added **Controller Player Setup…** to the consolidated Controls submenu ahead
  of button mapping and touch settings.
- Exposed a bounded, instance-sorted snapshot of connected SDL controllers from
  Aurora through a narrow JNI bridge.
- Added explicit Player 1--4 assignment, safe replacement of an occupied slot,
  movement that clears the controller's previous slot, and explicit clearing.
- Reused Aurora's existing `controller_ports.dat` identity persistence so an
  assignment follows a controller when it reconnects. A lone unassigned
  controller retains the documented automatic Player 1 fallback.
- Added a source-only two-controller JNI fixture and debug entry point so the
  real Android dialog can be tested without private game content or pretending
  that an emulator has physical Bluetooth hardware.

## Emulator proof

The source-only fixture was installed on the visibly running pinned API 36
ARM64 Pixel Tablet emulator at 2560x1600. UI Automator observed:

- initial state: Player 1 = `KartPad Virtual One`; Players 2--4 empty;
- assigning `KartPad Virtual Two` to Player 2 produced distinct Player 1 and
  Player 2 assignments;
- assigning Player 1's controller to occupied Player 2 cleared Player 1 and
  replaced Player 2 without duplicating either controller;
- choosing **No controller** then cleared Player 2.

Every Player 1--4 row and the Done action had a distinct accessible label and
bounded hit rectangle. The source-only APK SHA-256 is
`2dba74a0f0b63d2c2fac9dd5dd8db179bf7339cd0123dad2b0c0da6173b74ab7`.
Sanitized local screenshots remain untracked at `/private/tmp`; the initial,
two-player, moved, and cleared captures have SHA-256 values
`96048084df77ba2ba14c17e76d04a132a25d68bd87c4bbc29baf8048eb7e1a60`,
`d9cd1af1bcb623fe0f1adb262046c82e2882b50841f9d066a0169703ba32b19b`,
`dbac9691c1fcc8687f9e2caa1334247b4225d16341012e7830bf8d1971fe70ac`,
and `8e2e6490b268a6a09c981aa8f2a7f0ca3491a43cdf3ac92d22cdc16ca7dfeaf9`.

## Reproduction and package checks

A fresh disposable dual-runtime preparation applied the new Aurora patch and
contained all four public controller-slot functions. The complete translated
dual runtime then compiled and linked the production JNI implementation. Its
local-only APK SHA-256 is
`b41b7b3b33a9c3eec2e8a66d0a9d11e8f96d71a4be6d05e727a57fc83ca5a14c`.

The 74-test Python suite passes with one intentional skip. The focused A4
contract has 17 passing tests. Android lint, the strict APK/privacy audit,
repository safety, whitespace, and fresh patch reproduction all pass.

## Classification

Pass for persistent Player 1--4 setup semantics, accessible Android UI, and
production-runtime compilation on the emulator. Physical controllers remain
the authority for reconnect identity, concurrent input, handoff, and rumble.
No APK/AAB, private data, save, raw log, UI dump, or screenshot was published.
