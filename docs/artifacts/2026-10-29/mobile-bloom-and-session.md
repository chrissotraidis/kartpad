# Mobile bloom and same-process diagnostics: 29 October 2026

The later [integrated Android record](integrated-android.md) supersedes this
earlier incremental build for integration and longer-session claims. The
measurements below remain a historical receipt of the earlier candidate.

## Scope

The Android bloom setting (#535) was exercised in real Original Mario Kart Wii
races on a dedicated ARM64 Android emulator. This goes beyond the earlier source
compilation and synthetic setting tests. It does not establish physical Android,
iPhone, iPad or Apple TV acceptance.

The private test APK is `0.8.6-bloom-test` (build 270), SHA-256
`1754ac0e937da09cfeafe1702297140be0980dcb62f3a25ebf5fd1094b810b7a`.
It reuses the 27 October resolution candidate's compiled native objects and
matching game pack. The current JNI settings bridge was compiled and both
Classic and WiiCompiled libraries were relinked; the current Android Kotlin UI
was rebuilt. Unchanged native dependencies, including SDL, came from that
candidate. Native CMake and normal provenance generation were skipped for this
incremental diagnostic build. It is not a release artifact or a clean source
build check.

Its Android runtime baseline is
`4be10fabb9d978cf908819d4f0516d10c78cdd30`. The subsequent matrix-selector
runtime updates in this branch were **not** in the gameplay-tested APK. Final
integrated Android and Apple gameplay validation remains open. The earlier iOS
ARM64 overlay compilation used the then-pinned
`b6a0c0b9a15b34b8b9486e8e174ec9145c55dd16` headers; this was a compile check,
not Apple gameplay.

## Bloom checks

The emulator was an isolated copy of a previous task's test AVD, on serial
`emulator-5580`, using the host GPU on an Apple M3 Max. Original game data was
already imported in that copy. Existing user installations and the original AVD
were not modified. The scene checks used 1× rendering and original 4:3 aspect.

- Display → Disable Bloom saved mask `16`, updated the switch immediately, and
  survived a full app/emulator restart.
- Classic loaded Luigi Circuit with bloom disabled. Turning the setting off
  saved mask `0`; quitting and re-entering the course through the game menus
  restored the visible glow/haze without restarting the app process.
- Making only the copied emulator's config file read-only produced “Could Not
  Save Setting.” The saved mask stayed `16` and the switch remained on after
  reopening Display. The file's original `0600` permissions were restored.
- The live menu exposed a clipped description. It was shortened to “Removes
  bright-area glow. Applies at the next scene.” The complete text fits in two
  lines in the actual landscape menu.
- WiiCompiled 0.9 (Beta) loaded Luigi Circuit, retained the existing bloom
  preference, and successfully toggled the setting. `/proc` mappings confirmed
  that `libmain_wiicompiled.so` was loaded; this was not a silent Classic fallback.
  With the same beta PID (`5099`), the setting saved mask `16`, the race was
  reloaded successfully with bloom disabled, and a five-second touch-A hold
  moved the kart down the track and through the first item boxes.

The setting persistence, real write-error handling, menu lifecycle, and actual
race scene transitions are covered on this emulator. Fresh import, complete
driven laps, other devices, and Apple gameplay remain outside this check.

## Bounded same-process check for #510

Four 60-second windows used Classic, Original Mario Kart Wii, 50cc Grand Prix,
Mario, Standard Kart and automatic drift. The kart stayed at the start line
while AI racers continued. Resolution, aspect ratio and bloom stayed fixed
(1×, original 4:3, bloom enabled). PID `3572` and its process start ticks were
unchanged across every window and course transition. No app restart or log
clearing occurred. Earlier bloom checks had already visited Luigi in that
process, so these are warm diagnostic windows, not a cold-launch baseline.

The readiness screenshots show the race active after the countdown. Repeated
Luigi was at 5.864 seconds, Mario at 25.047 seconds and returned Luigi at 24.895
seconds before launching their captures. The first Luigi race had already been
active longer. This is four bounded samples with one repeated Luigi load and
one other-course visit, not the proposed eight-repeat stress protocol.

Other agents paused compilation and GPU tests for the sequence. Initial host
load averages were `3.02 / 6.90 / 7.61`; the emulator was the dominant CPU user
at about 200%. Sampling PSS may itself affect timing. The collector discards
the first periodic CPU record, which may overlap the prior interval, and keeps
screenshots plus numeric metrics without preserving raw logcat.

| Window | PSS start → end (MiB) | Median game-thread CPU/present (ms) | Median frame p95 (ms) | Display-list entries start → end | Copy pool (MiB) |
| --- | ---: | ---: | ---: | ---: | ---: |
| Luigi initial | 583.76 → 578.76 | 7.255 | 18.30 | 13,362 → 13,648 | 5.4 |
| Luigi repeat | 579.77 → 579.24 | 6.526 | 17.18 | 6,883 → 7,510 | 5.4 |
| Mario control | 624.05 → 627.20 | 6.290 | 17.15 | 13,750 → 14,140 | 5.4 |
| Luigi return | 626.23 → 625.09 | 6.189 | 17.15 | 6,860 → 7,382 | 5.7 |

Each window contains seven PSS samples, twelve frame metric samples and eleven
CPU samples. Pipeline counts were stable within each Luigi window; Mario added
two during its window. Display-list entry counts reset across course loads.

This short run did not reproduce the reported slowdown. Approximately 46 MiB
remained allocated after visiting Mario and returning to Luigi; that alone does
not establish a leak. There was no steadily rising PSS within the Luigi windows.
The lower later CPU medians are not a claimed speedup. The result does not settle
long-session accumulation, phone thermals, other game modes or the reporter's
specific device.

## Retained evidence and remaining gates

Private APK, native relink/package recipes, provenance notes, and the structured
live-test record remain in the ignored `private/triage-20261029/bloom/` folder.
The task-owned emulator was shut down after the checks. The copied AVD is
retained there for follow-up. Race/menu screenshots remain in
ignored `build/perf/ui/`; the four JSON windows and before/after screenshots are
in ignored `build/perf/sustain/20261029-*`. Game images, saves and native payloads
are not committed or published.

Relevant earlier checks also passed: helper compile/run against both pinned
Android/iOS runtime headers, config write/reload/failure tests, Android Kotlin
compilation, Android arm64 JNI object compilation, iOS arm64 overlay object
compilation, menu contract checks and iOS menu lifecycle tests. The short Android
description edit was compiled into the live candidate.

Before release, use the final integrated source/runtime pins for the repository's
APK/IPA audits, fresh import/update gameplay gates, the required PadMint player
checks, and physical-device acceptance. No release or version bump was made by
this validation.
