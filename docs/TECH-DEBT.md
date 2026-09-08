# Technical debt

This file records useful engineering directions that have not fully cleared
KartPad's acceptance gates. An entry is not a release promise or evidence that a
feature works on untested hardware. External pull requests listed here are source
material only; any follow-up is maintainer-owned and its completed and remaining
gates are stated explicitly below.

## tvOS A12 compiler baseline

Status: defensive compiler hardening implemented; physical A12 compatibility
unverified.

The tvOS WiiCompiled targets should use a generic AArch64 CPU baseline and
explicitly disable RCpc instruction selection. `-mcpu=generic` alone is not
sufficient with the tested Apple Clang toolchain: it can still emit RCpc loads
that fault on the A12 Apple TV. Physical iOS also uses a generic/RCpc-disabled
baseline in
[0.4.13 build 29](releases/v0.4.13-ios.1.md); macOS and Simulator tuning are
separate. A10X iPad acceptance remains pending.

Completed integration evidence:

- the generated tvOS Xcode project contains `-mcpu=generic` and
  `-Xclang -target-feature -Xclang -rcpc` for every WiiCompiled runtime target;
- the final tvOS executable contains no unsupported RCpc load instructions;
- the complete unsigned tvOS build and app audit pass; and
- the complete iOS Simulator build and app audit pass without changing its CPU
  tuning.

An A12 compatibility claim still requires the exact resulting app to boot, reach
the title screen, produce audio, and complete a race on an A12 Apple TV. Until
such evidence is available, the change is described only as compiler hardening.

Source: pull request [#31](https://github.com/chrissotraidis/kartpad/pull/31)
and its physical-device follow-up. The submitted pull-request head did not
include the RCpc fix.

## tvOS settings and aspect presentation

Status: aspect-state consistency implemented; presentation choices remain deferred.

A Settings bundle could eventually expose presentation preferences, and the
aspect-ratio behavior should be made explicit. Those are separate decisions from
the first-run controller and launch-mode flow. The current controller-required
screen and mode chooser remain part of the tvOS safety and acceptance contract;
they must not disappear as a side effect of adding preferences.

The mobile settings bridge now reports the selected aspect mode through the
guest `SCGetAspectRatio` result. This removes a deterministic state mismatch
without adding new tvOS settings UI or changing the accepted launch flow.

The Issue #17 Apple TV 4K (3rd generation) report also found the fixed 1.0x
render scale visibly soft on a large display and reported that 2.0x or 2.5x
remained at 60 FPS while the device thermal state was nominal. Treat that as a
single-device optimization lead, not a new default or sustained-performance
claim. Any default change belongs with the deferred tvOS settings work and must
be benchmarked across supported Apple TV hardware and thermal states first.

Acceptance requires all of the following:

- controller-required messaging and input gating remain intact;
- preference defaults, relaunch behavior, and migration are deterministic;
- 4:3, 16:9, and fill presentation are verified in menus and gameplay without
  clipping or stretching regressions;
- the runtime's reported aspect ratio agrees with the selected presentation; and
- iPhone and iPad presentation behavior remains unchanged.

Source: pull request [#32](https://github.com/chrissotraidis/kartpad/pull/32).

## tvOS controller rumble

Status: hardware experiment required.

Core Haptics may provide controller rumble on supported tvOS controllers, but
the engine lifecycle has to be treated as recoverable state. Cached player state
must not suppress a restart after the engine resets, stops, the controller
disconnects, or the system sleeps.

Acceptance requires all of the following:

- reset and stopped handlers reconcile the engine and cached active-player state;
- unsupported controllers and haptic localities fail safely;
- start, update, stop, disconnect, reconnect, interruption, and sleep/wake paths
  are exercised;
- the emulation path remains non-blocking; and
- physical controllers confirm observable output for representative game events.

Source: pull request [#33](https://github.com/chrissotraidis/kartpad/pull/33).

## Dolby Pro Logic II to multichannel LPCM

Status: audio experiment required.

Decoded multichannel output may be useful when tvOS exposes a compatible route,
but it must preserve the existing stereo path and cannot be accepted from channel
plumbing alone. The exact app must demonstrate meaningful rear-channel content
and correct channel ordering on physical output hardware.

Acceptance requires all of the following:

- stereo remains the deterministic fallback for unsupported or changing routes;
- the physical run uses the exact submitted source and compiler baseline;
- front and rear channel mapping is verified with non-zero, audible content;
- route changes, pause/resume, underruns, latency, and a sustained soak pass; and
- documentation avoids center or LFE claims unless those channels are actually
  decoded and verified.

Source: pull request [#35](https://github.com/chrissotraidis/kartpad/pull/35).

## Integration order

1. Retain the statically verified A12 compiler hardening and keep physical
   compatibility explicitly unclaimed unless exact-artifact evidence arrives.
2. Treat aspect semantics as a focused change that preserves controller safety.
3. Evaluate haptics and multichannel audio as independent hardware experiments.
4. Rebase each experiment independently and resolve its runtime-host conflicts
   before combining any accepted work.
