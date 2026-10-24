# Profile-guided Android game pack for 0.8.6 — 24 October 2026

**Result:** a game pack compiled with a profile recorded from Original and
Retro Rewind races used less game-thread CPU than the identical pack without
it in every one of four alternating emulator pairs, on a course the profile
never saw. 0.8.6's Android release pack is built this way. These are emulator
CPU measurements, not a phone FPS promise (#339).

## What changed

`scripts/build-game-pack.sh` accepts `KARTPAD_GAME_PACK_PGO`, Android only and
off by default:

- `generate` builds an instrumented pack. `tools/android-perf/pgo_dump.cpp`
  resets the counters 75 s after load and rewrites the cumulative profile every
  30 s, so one session can cover several races. Retro Rewind's `retro_mod`
  shards stay uninstrumented (instrumenting them took over 45 minutes each).
- `use=PROFILE` adds `-fprofile-instr-use` to the release flags the script
  already sets (`-O3 -DNDEBUG -g0`), leaving the NDK toolchain's own flags alone.

PadMint player builds do not set it, so iPhone, iPad and Mac builds are
unchanged. The profile is derived from running the game and stays private
(`private/pgo/`), like the pack.

## Recording

Same translation as 0.8.5 (Retro Rewind 6.13.4), perf app `0.8.5-perf`
(pack fingerprint `54f11dc1…`), Android 16 ARM64 emulator on an M3 Max with
`-gpu host`. Three touch-driven sessions, holding accelerate in a 12-racer
Grand Prix: Original Luigi Circuit, Retro Rewind Wii Luigi Circuit, and a longer
Original Luigi Circuit session. `llvm-profdata merge` from NDK 29 produced a
10.4 MB profile covering 851,167 blocks.

The profile-guided pack is **116.9 MB** stripped against **133.8 MB** for the
same translation without it: the compiler shrinks code the profile shows is
cold. (The October experiment grew `.text` 9%; that build used a single-race
profile.)

## Measurement

`tools/android-perf/ab.sh` with the new `KP_BENCH_COURSE=mario` route: Mario
Circuit, 50cc Flower Cup race 1, 12 racers, idle player. Mario Circuit was not
in any recording session. Every run cold-boots the emulator, deploys the same
app with one of the two packs, waits 55 s into the race and samples game-thread
CPU for 60 s. Screenshots confirm the course in all eight runs.

| Pair | Base ms/frame (FPS) | PGO ms/frame (FPS) | Change | Host |
| ---: | ---: | ---: | ---: | --- |
| 1 | 13.19 (48.1) | 9.43 (59.4) | −29% | Two other projects compiling (16 + 8 jobs) |
| 2 | 10.20 (58.8) | 6.89 (59.5) | −32% | Busy, load falling |
| 3 | 7.97 (60.0) | 6.71 (60.0) | −16% | Quiet |
| 4 | 7.65 (59.9) | 7.10 (60.0) | −7% | Quiet |

Only pairs 3 and 4 are clean: together they show **about 12% less game-thread
CPU** (7.81 → 6.91 ms). The busy pairs point the same way but are not a fair
size estimate. Two earlier attempts were stopped and are kept in the private
record: one reached Luigi Circuit instead of Mario Circuit because the cup
screen loaded late (fixed with longer waits), and one stopped when `adb root`
failed on the busy host (`ab.sh` now retries).

## Limits

- Emulator on desktop cores. A phone whose game thread is the limit should turn
  the saving into frame rate, but no phone was measured.
- One unprofiled course, idle player. Traffic can bump the kart and change the
  camera between runs.
- The profile must be re-recorded when the translation, translator or compiler
  changes; a stale profile builds but optimizes less.
