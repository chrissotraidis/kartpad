# Android A2 debug input and retail replay evidence

Date: 2026-09-03

Base checkpoint: `3bbbc16` (`codex/android-a2-save-relaunch`)

Target: `KartPad_API_36_ARM64`, Android API 36, `arm64-v8a`, 4,096-byte
pages, gfxstream with host lavapipe

## Falsifiable subgoal

Make the existing native RKG player-input diagnostic reachable from an Android
debug game build without packaging private input, then determine whether its
countdown-synchronized stream can naturally finish a matching Time Trial.

## App-private debug boundary

`KartPadActivity` now considers exactly
`files/KartPad/Diagnostics/TestInput.rkg`, and only when both the game runtime
and `BuildConfig.DEBUG` are true. The file must be a regular file between
`0x90` bytes and 1 MiB with the `RKGD` magic. A valid file enables the existing
`_V2` input, autostart, metadata, and precise-menu-pulse variables before SDL
loads. A missing or invalid file clears all four variables. The log reports
only that the diagnostic is enabled; it does not print the private path or
payload.

The ignored staff input was copied into the app sandbox after APK installation
and matched its source SHA-256
`30c4ec21c2c8324c6180ef3e806df10a36ce14b1c641494acfb40fef911d5ed2`
at 2,016 bytes. The repository's content-free inspector reports course ID 8,
89.670 seconds, 2,194 input bytes, 59/1,030/4 sequences, and equal
5,615-frame streams. No RKG bytes, game data, save, or screenshot is committed
or packaged.

An initial `adb exec-out` stdin copy delivered the file but did not terminate
at EOF. The transport was interrupted and replaced with a bounded
`/data/local/tmp` copy, an app-sandbox copy, SHA-256 verification, and deletion
of the exact temporary-device file.

## Player-fixture result

The exact debug build reported `Debug app-private RKG input enabled`. Its
metadata path selected Mario, Standard Kart M, automatic drift, Mushroom Cup,
and Luigi Circuit. Autostart moved the kart after the countdown, proving the
Android bridge reached the native player fixture.

The stream did not remain synchronized with live player physics. At guest time
10.881 seconds the kart was against the outer wall; at 34.236 seconds it
remained there on lap 1/3. This reproduces the already documented native
fixture limitation rather than completing a race. No forced-finish variable
was enabled. The ignored final capture is
`.android-bootstrap/a2-rkg-diverged-final.png`, SHA-256
`57cba22e4ffb71a969d3c1cb9de7556a40e4bfd3e1c3a68e27f70d005ad9a71b`.

Classification: **Pass for the private debug bridge; fail for natural
player-fixture race completion.** This is diagnostic keyboard/RKG evidence,
not controller evidence.

## Clean retail replay observation

The diagnostic file was renamed to an app-private disabled backup and the app
was cold-launched. PID `8784` emitted no diagnostic-enabled marker. Precise
keyboard pulses selected Time Trials, Luigi Circuit, and the on-disc Nintendo
staff **Watch Replay** path. The retail replay then rendered continuously for
more than twelve wall-clock minutes at roughly 9--13 FPS under the unchanged
PID, with byte-distinct progress captures and zero `SIGABRT`, ImGui assertion,
`WithinFrameScope`, or Java fatal-exception matches.

The observation included a finish-line crossing, but Watch Replay exposes no
player lap HUD, results, or save and remained in replay presentation afterward.
It is therefore useful long-course renderer evidence but is **inconclusive as
a player race/results/save proof**. Representative ignored captures are:

- live replay:
  `.android-bootstrap/a2-replay-progress1.png`, SHA-256
  `9320ca7f613a65aab5b15ebf6a19291a279ad5f8f53952e59cf6fd954f26fb4b`
- later replay progress:
  `.android-bootstrap/a2-replay-progress6.png`, SHA-256
  `3418bdf1d1b927f5b0f1c1f1f2fa4b0919ac1147880ccd3cd88bfc960119a4ab`
- finish-line observation:
  `.android-bootstrap/a2-replay-finish.png`, SHA-256
  `a25889c407a87a84e3a6088f2c008eef94f330c2aaa0a39e44e02e19f5407a49`

## Build result and remaining gate

The full private Original debug APK, game-runtime release Kotlin compile, and
source-only debug Kotlin compile passed. `lintDebug` and the strict APK audit
also passed.
The APK is 103,429,984 bytes with SHA-256
`c6b0eae50624f1e5466b679558a643e41cf8d721b3f3d5d4179303c3a038884e`.
Its stripped 83,533,016-byte `libmain.so` remains SHA-256
`71486d448c0765e916b95c3ca703d1276152357a912ad0d2fd49c673cc98b44a`.
No APK or AAB was hosted or published.

A2 remains open for a complete player race, results, post-race save/relaunch,
a real controller, and physical Android hardware. The replay does not satisfy
any of those rows.
