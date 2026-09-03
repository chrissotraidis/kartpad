# Android A2 SDL controller bridge

Date: 2026-09-03

Base checkpoint: `02543e9` (`codex/android-a2-keyboard-race`)

Targets: host contract test, `KartPad_API_36_ARM64` (API 36, 4,096-byte
pages), `KartPad_API_35_PS16K_ARM64` (API 35, 16,384-byte pages), and the
private Original ARM64 runtime link

## Falsifiable subgoal

Make controllers already discovered by Aurora's SDL layer reach Mario Kart's
Classic/KPAD input path on Android, without changing Apple input behavior or
claiming controller acceptance in the absence of attached hardware.

## Implemented contract

Aurora now exposes a narrow, SDL-free public snapshot containing standard
face buttons, shoulders, Start/Back, D-pad, left stick, and analog triggers.
KPAD maps that snapshot to the existing Classic Controller representation:

- south/east/west/north to A/B/X/Y;
- Start/Back to Plus/Minus;
- shoulders to L/R and analog triggers to ZL/ZR at 16,000;
- D-pad directions to the matching Classic directions; and
- the SDL left stick through an inclusive 8,000-unit deadzone, normalized to
  `[-1, 1]`, with SDL's downward-positive Y axis inverted.

Explicit Aurora player assignments remain authoritative. Until the native
controller settings UI exists, player one may also consume exactly one
connected, unassigned controller. The bridge refuses to guess when multiple
unassigned controllers exist and never steals a controller explicitly
assigned to another port. Controller input is mixed only when the RKG fixture
is inactive. Existing trigger/release history supplies a final neutral sample
after a secondary channel disconnect so held inputs do not remain asserted.
Sanitized transition logs contain only channel number and connected state.

The mapping is a shared header used by the production patch, a host CTest, and
the Android source-only fixture. Compile-time assertions lock Aurora's public
button bits to the KartPad contract.

## Verification

- `kartpad.android.gamepad-contract` passes the disconnected-neutral, complete
  button map, trigger threshold, axis endpoints, inversion, and inclusive
  deadzone cases.
- The source-only API 36 / 4 KiB and API 35 / 16 KiB cold-boot fixtures both
  emit `A2 SDL gamepad contract passed` while retaining their guest-memory,
  scheduler/fiber, Vulkan present, rotation, and three background/foreground
  recreation checks. The audited fixture APK SHA-256 is
  `b6309fbd054fdac7bd12f724961b03f07af98413ab30217cbcdaaa338935abbd`.
- A from-scratch prepared private source tree compiled and linked the complete
  ARM64 Original runtime. After the final transition-log hardening, the
  preparation script reproduced all three patched upstream files
  byte-for-byte and the full runtime rebuilt successfully.
- The final local-only game APK is 103,433,120 bytes with SHA-256
  `7491b416ea3640b8d7a9cb8545fffe41dc625a4d378dd4d0d4abc8293ae22d01`.
  Its stripped 83,536,152-byte `libmain.so` has SHA-256
  `15a7c1dfecd40066b5f15dc950bb4d555d4375a09a21553ff9fbf9dd8f6c3c74`.
  The strict APK audit passes.
- Debug lint, release Kotlin compilation, storage-layout contract, repository
  safety audit, `git diff --check`, and 11-hunk patch verification pass.
- Both emulators were shut down; `adb devices` was empty after testing.

No game data, translated shards, saves, controller identifiers, captures,
APK, or AAB were committed, hosted, or published.

## Classification

**Pass for the deterministic mapping contract, reproducible Aurora/KPAD
integration, both source-only emulator lanes, and the private runtime
compile/link/package boundary.** No physical or emulated SDL controller was
available, so connection, live menu navigation, gameplay, disconnect/reconnect,
rumble, and hands-on behavior remain unaccepted. A2 remains open for a complete
player race, results, save/relaunch, real controller, and physical Android
hardware.
