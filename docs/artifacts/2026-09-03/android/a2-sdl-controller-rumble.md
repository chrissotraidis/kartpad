# Android A2 SDL controller rumble

Date: 2026-09-03

Base checkpoint: `623b75f` (`codex/android-a2-sdl-controller`)

Targets: host command contract and the private Original ARM64 runtime link

## Falsifiable subgoal

Route Mario Kart's Android `WPADControlMotor` output to the same SDL controller
selection used by the accepted Aurora-to-Classic input bridge, without changing
Apple behavior or claiming tactile acceptance without controller hardware.

## Implemented contract

Aurora now exposes a narrow start/stop rumble call beside its SDL-free input
snapshot. It uses the same controller resolution rule as input: an explicit
port assignment wins, and player one may use exactly one unassigned controller
until the native assignment UI exists. The request fails closed when the
controller is absent, disconnected, lacks rumble support, or SDL rejects it.

Android `WPADControlMotor` command `1` starts both motors at the controller's
configured intensities; command `0` stops them with zero intensity and zero
duration. Unknown commands also stop output rather than accidentally starting
it. An active request uses SDL's maximum duration and remains active until the
guest sends Stop, the controller is removed, or Aurora shuts down. The
non-Android HLE remains the existing no-op.

## Verification

- `kartpad.android.gamepad-contract` passes Stop, Rumble, and unknown-command
  cases in addition to the existing button, trigger, stick, and deadzone
  contract.
- Both incremental patches dry-run against a clean pre-rumble prepared tree.
  A fresh complete preparation applies them and reproduces the modified Aurora
  header, Aurora implementation, and WiiCompiled `wpad.cpp` byte-for-byte.
- The full 29,065-function private Original ARM64 graph compiles and links
  through Gradle. After centralizing input/output assignment in one resolver,
  the exact final source rebuilt and relinked successfully. The local-only APK
  is 103,433,440 bytes with SHA-256
  `3044e148e320236b0b71d4cf86ff8a5b158a896c75671f215a5da8c0faf23ad0`.
  Its stripped 83,536,472-byte `libmain.so` has SHA-256
  `57856f61c5e1e162c0525b1d757eed46ccd27aaacf7a9bf287a20b78472954ad`.
- The strict APK audit passes its ABI, 16 KiB alignment, dependency, symbol,
  permission, asset allowlist, and private-data/path checks. Runtime storage,
  debug lint, release Kotlin compilation, repository safety, patch verification,
  and `git diff --check` pass.
- The broad source verifier accepted all 412 patch hunks and the WiiCompiled,
  SunPad, and WheelWizard pins, then stopped at the pre-existing ignored
  `rr-pulsar` checkout mismatch (`b566a5d` present versus `29e76d4` locked).
  This branch does not touch that checkout or its lock.

No controller was available, so actual motor capability, intensity, Stop,
disconnect, pause, and reconnect behavior remain unaccepted. No APK/AAB,
private data, translated source, RKG, save, log, or game capture was published.

## Rejected replay diagnostic

A temporary uncommitted diagnostic exposed RKG samples through the translated
retail KPAD calculator instead of replacing it. It synchronized and moved the
player, but the mismatched Luigi Circuit run reached a wall at 14.346 seconds.
A second run used the exact selectable N64 Mario Raceway staff configuration
(Baby Mario, PAL Nanobike/Bit Bike, Manual) and still diverged off course by
8.580 seconds. No forced finish was enabled. The marker, private RKG, source
experiment, app process, and emulator were removed or stopped afterward.

This falsifies the hypothesis that the earlier Android player-fixture failure
was only a character/vehicle mismatch. The experiment is not retained as a
product path and is not race-completion evidence.

## Classification

**Pass for deterministic rumble-command semantics, reproducible SDL output
integration, private compile/link/package, and package privacy.** Live rumble,
complete controller-driven race/results/save, and physical Android acceptance
remain open, so A2 remains incomplete.
