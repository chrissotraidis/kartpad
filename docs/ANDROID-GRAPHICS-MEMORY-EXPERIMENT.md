# Private Android graphics memory experiment

Enable with `-PkartpadGraphicsMemoryExperiment=true` on a full-runtime Android build. The default is off. Open **Display → Graphics Memory…** in the running game. Refresh reports Dawn's live texture/buffer estimates and allocator use/reservation. **Release Unused** asks the pinned Dawn library to reclaim unused GPU allocations. It preserves game data and settings, may cause a brief hitch, and can report that GPU work is still pending. It is a diagnostic control, not a general FPS fix.

JNI queues requests; the game thread services them at the next coarse KartPadPerf telemetry interval, where device lifetime is stable. The dialog remains responsive and removes its polling callback on dismissal. No background trim loop, dependency update, shader policy, or guest-code change is introduced. `KartPadMemory` records numeric byte counts and the action/pending flag; no user/game content is logged.

## Pixel 9 Pro XL hardware evidence, 2026-09-15

API 37, Tensor G4; same signer, data-preserving in-place updates. Release-mode, shell-profileable ARM64 builds. Retro Rewind 6.12.8, 150cc Boo Cinema bundled ghost replay, original 4:3 and 1× resolution.

A prior TLS-only A/B/A comparison did not show a useful gain: emulated/native/emulated averaged 59.73/59.87/59.85 FPS and 78.59/78.16/78.34% main-thread occupancy. Mean five-second-window p99 values were 24.13/24.20/24.48 ms. This experiment therefore keeps emulated TLS. Runs were sequential with some temperature drift, and do not establish statistical significance or older-device behavior.

Graphics accounting showed approximately 300 MiB during title-screen prewarming and much higher residency during the race. In a separate settings sequence, resolution change plus replay restart lowered graphics residency by about 1 GiB; returning to 1× retained the lower level. That observation does not establish that higher resolution uses less memory or isolate resize from restart.

In the new probe build, the explicit release request returned pending work. After that work settled, Dawn allocator reservation fell from 1285.1 to 909.1 MiB, while allocator use remained 622.2 MiB. Android Graphics fell from 1,498,640 to 1,102,792 KiB, and total PSS from 2,034,879 to 1,628,116 KiB. These are one-session observations, not a universal memory/crash fix. The fresh probe run already had lower residency before release, so the larger earlier difference cannot be credited to this code.

Validation: release build/lint and package audit; exact APK/symbol identity, compatible signer, non-debuggable/profileable and 16 KiB alignment checks; actual hardware title/race readout, release and refresh UI. Existing resolution and aspect settings applied live and persisted across updates. Raw captures, screenshots, private APKs, backups and symbols remain local.

The tested native-TLS build also replaced emulated lookup activity with Android's dynamic TLS resolver, so changing TLS models alone did not remove all context lookup cost. Separately, the base Mario Kart Wii path reached title but did not advance with touch A in the first baseline; Retro accepted the same input. Base gameplay, physical audio quality, low-end-device acceptance and reporter crashes remain unverified.

## Next decision

Measure whether reclaimed reservation grows back across the same replay, course transitions and long sessions. If a repeatable safe boundary emerges, test reclamation at that boundary or in response to Android memory-pressure callbacks. Do not enable periodic trimming during racing solely from this experiment. Compare live allocation use against reserved heap and Android Graphics/PSS rather than treating any one counter as complete attribution.

References: [Dawn native memory operations](https://dawn.googlesource.com/dawn/+/refs/heads/main/src/dawn/native/DawnNative.cpp) and [Android game memory monitoring](https://developer.android.com/games/optimize/memory-monitoring). API declarations were verified in the exact pinned Dawn package; no dependency upgrade was needed.
