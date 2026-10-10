# Android performance bench

Tools from the 10 October #339 investigation. Read the
[performance handoff](../../docs/ANDROID-PERFORMANCE-HANDOFF.md) first for what
the numbers mean and the bench's limits. Run everything from the repository root.
Outputs go to `build/perf/` (ignored).

## Prerequisites

- **An Android build environment:** `scripts/build-android-app.sh` must work
  (`.android-bootstrap`, dependency cache, Dolphin disc-I/O JNI).
- **A private self-build translation** at
  `private/self-build/retro-rewind/translation` (or set `KP_TRANSLATION`).
  Never commit it.
- **An arm64 phone AVD with root,** 2400×1080 landscape. The default is
  `KartPad_API_36_ARM64` (Android 16, Google APIs); set `KP_AVD` for another.
  KartPad must be installed with game data imported and a license on the save.
  The menu taps in `bench.sh` assume this screen size.
- **Signing:** the perf app is debug-signed. The first install over another
  signer needs the game data moved aside and back as root; see the
  investigation.

## Scripts

| Script | What it does |
|---|---|
| `build-variant.sh NAME` | Builds an optimized, profileable, debug-signed `0.8.0-perf` app that loads a pushed game pack, plus a game pack for the current runtime working tree, into `build/perf/v-NAME`. Keeps the unstripped `libmain` for profiling |
| `deploy.sh NAME` | Installs `v-NAME` over the current install (data kept) and pushes its pack and fingerprint |
| `bench.sh LABEL SECONDS` | Starts the app, drives it into Grand Prix race 1 (Luigi Circuit, player idle), waits 55 s, then reports game-thread user and kernel CPU per frame |
| `ab.sh OUT A B ROUNDS` | Alternates A and B, cold-booting the emulator before every run, and records the emulator's host memory |
| `ui.py` | Taps, buttons, window dumps and screenshots over adb (`KP_SERIAL`) |
| `agg.py`, `topfuncs.py`, `insnkind.py`, `lines.py`, `kernelcallers.py` | simpleperf analysis: buckets, top translated functions, sampled instruction kinds, source lines inside a function, user callers of kernel time |
| `add-flat-locals.py` | Inserts the flat-memory locals into a translation copy (for `patches/android-runtime-flat-memory-locals.patch`) |
| `pgo_dump.cpp` | PGO only: writes the instrumented pack's counters from a timer thread |

To make a base variant without rebuilding, copy a known app and pack into
`build/perf/v-base` (`app.apk`, `libkartpad_game.so`, `fingerprint`).

## Profiling a running race

```sh
adb shell simpleperf record -t <game tid> -e cpu-clock -f 1000 --duration 15 -g -o /data/local/tmp/perf.data
adb pull /data/local/tmp/perf.data build/perf/x.data
python3 tools/android-perf/agg.py build/perf/x.data <symfs> <game tid>
```

The game thread is the thread that logs `KartPadPerf`. The symfs needs:

- the unstripped pack at `data/data/dev.kartpad.android/files/gamepack/libkartpad_game.so`;
- a zip at the installed `base.apk` path containing `lib/arm64-v8a/libmain.so`
  (unstripped).

## Patches

These are experiments, not adopted (results in the handoff):

| Patch | What it changes |
|---|---|
| `android-runtime-explicit-fp-context.patch` | The FP adapters take the generated function's `ctx` (with `noinline` adapters) |
| `semantics-normal-fp-fast-path.patch` | Exact fast path for normal FP results |
| `android-runtime-flat-memory-locals.patch` | Flat-memory base and check flag read once per function |

