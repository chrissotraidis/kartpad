# Android A3 fresh-save initialization with networking disabled

Date: 2026-09-04

## Scope

This check targeted the previously disclosed format-valid empty-save
precondition in the Retro Rewind emulator boot evidence. The falsifiable
subgoal was to remove the redirected Retro RKSYS from an otherwise configured
install, cold-launch the production profile with online networking disabled,
and determine whether the game could create and reopen its own system-memory
state without a seeded save.

Target and build:

- standalone `KartPad_API_36_ARM64` AVD (`emulator-5554`), Android API 36,
  arm64-v8a;
- production mode chooser and Retro Rewind 6.12.5 installation already
  validated by the preceding A3 checks;
- runtime configuration retained `[network] enabled = false`;
- clean Android runtime preparation and full debug APK rebuild after the fix.

This is emulator evidence. It is not physical-device, controller, audio,
rumble, performance, or release acceptance.

## Reproduction and diagnosis

With the redirected Retro save absent, the unmodified runtime displayed
`Could not write to / read from Wii system memory.` It created
`title/00010004/524d4350/data/rksys.dat` at the expected 2,867,200-byte size,
but the file remained all zeroes.

Temporary local instrumentation narrowed the failure beyond the successful
file creation and preallocation. The translated save setup called an auxiliary
virtual-device open, which returned failure after its underlying operation
returned `-42` twice, approximately ten seconds apart. The runtime's global
`NetworkEnabled` check was rejecting every `/dev/net/*` path before device
classification. That included these local Wii system services:

- `/dev/net/kd/request`
- `/dev/net/kd/time`
- `/dev/net/ncd/manage`

Because `/dev/net/kd/request` was not claimed by the network HLE while online
networking was disabled, it fell through as an unknown NAND device and the
first-run system-memory sequence timed out. Internet socket and TLS devices
(`/dev/net/ip/top` and `/dev/net/ssl`) are a separate boundary and should
remain unavailable under the offline setting.

## Fix

`patches/wiicompiled-offline-kd-services.patch` classifies the requested
device first. It permits KD request/time and NCD management regardless of the
online-network preference, while retaining the preference gate for IP and SSL
devices. The common patch is applied by both portable runtime preparation
paths, including Android's delegated preparation path.

The diagnostic sequence after this change matched the expected KD state
machine: command `0x02` initially returned `-42`; commands `0x01`, `0x0f`, and
`0x03` ran; a second `0x02` returned `-42`; the third returned `0`. The
translated auxiliary open, allocation, probe, and final return then all
succeeded. Temporary trace statements were removed before the clean build.

The separate Android NAND-open patch removes a create-on-open fallback from
the high-level NAND open operation. That preserves Wii open semantics and was
retained as a correctness fix, but it did not by itself resolve this failure.

## Clean-build and emulator results

- Fresh prepared source: `build/a3-android-offline-kd-clean-source`.
- Full clean build completed successfully.
- Local-only debug APK SHA-256:
  `262d821e6b2b769872df50e48e16a36b8c636b528bc9c1d03a17ae37624baaa7`.
- `scripts/audit-android-package.sh` passed for that APK.
- The packaged `libmain.so` contains no `KARTPAD_SAVE_TRACE` or `TRACE rksys`
  diagnostic marker.
- From a fresh redirected Retro NAND, a cold production launch passed the
  former system-memory error and visibly reached the Retro Rewind
  `Press the A Button` title.
- The game-created RKSYS is 2,867,200 bytes with SHA-256
  `708c7a040e0cfe6cd815690e63f46d1678f17899bce0e786f7480030830f1d13`,
  exactly matching the known format-valid empty-save fixture.
- A second independent fresh-NAND run reached the same title and produced the
  same exact RKSYS hash.
- A force-stop and cold relaunch with the newly created save again reached the
  title.
- The emulator's original base and Retro saves were restored after testing.
  Their SHA-256 values remained exactly
  `708c7a040e0cfe6cd815690e63f46d1678f17899bce0e786f7480030830f1d13`
  and
  `9c6c7b52c0d1ae7c74489be53123d1943a84917f6869119ca319af5c33b58917`
  after a final clean launch.

## Controller-driven first license and cold reload

The immediate continuation tested the remaining first-run interaction on the
same clean APK and standalone emulator. Before starting the game, a temporary
Xbox-compatible `/dev/uinput` controller was registered through Android's
documented command boundary. InputReader classified `/dev/input/event12` as an
external keyboard, gamepad, and joystick with the Xbox key layout. All game
input below followed the ordinary InputReader, SDL, Aurora, Classic-controller,
and KPAD path; no application or guest state was injected.

The existing Retro save was copied to an app-private test backup, then the
exact game-created empty RKSYS above was placed at the redirected Retro path.
The production chooser launched Retro Rewind and ordinary south-button input:

1. advanced the title to four `NEW` license slots;
2. selected the first slot and confirmed creation;
3. displayed and selected the existing KartPad Mii;
4. confirmed `A new license will be created for KartPad`; and
5. reached `Your new license is ready` with the KartPad card visible.

The resulting RKSYS remained 2,867,200 bytes and changed to SHA-256
`4b83dc4a02dd351d1e594b1c9c13ecd7530e6c80520957d4c576c46c88b0972d`.
Read-only semantic validation found `RKSD0006` at the file header, `RKPD` in
license slot zero, and an exact stored/calculated core CRC-32 match
(`21a244ff`).

The app was force-stopped and started again through the production chooser as
a new process. It reached the Retro title, retained the exact license-save
hash, and ordinary controller input advanced to the license screen where slot
1 visibly displayed the KartPad Mii and name rather than `NEW`. The accepted
created-license and cold-license screenshots have SHA-256 values
`5c27520ec6b5e58b67826ff772313ca89b3d414dd05b59ec45839471f647d8cf`
and
`310517bbfdb1192eb96659fa12ebe80e5c4503c05593bf16483a5a02d41e1da0`;
the private screenshots were not added to the repository.

Finally, the test-created save was retained only in app-private test storage,
the original Retro save was restored to exact SHA-256
`9c6c7b52c0d1ae7c74489be53123d1943a84917f6869119ca319af5c33b58917`,
and a final production Retro launch reached the title.

## Classification

**Pass for fresh offline Retro system-memory creation, controller-driven first
license creation, and byte-stable cold license reload on the API 36 ARM64
emulator.** The prior seeded-empty-save precondition is no longer required for
this path. Physical hardware, physical controller behavior, audio/rumble
quality, performance, and release acceptance remain open. No APK, AAB, game
data, save, trace, or screenshot was published.
