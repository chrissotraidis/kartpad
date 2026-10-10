# Android game-thread CPU investigation, 10 October 2026

Part of #339. Source: KartPad 0.8.0 (`c0056a6f`), Android runtime `21da321`,
Original game, private game pack from the 0.8.0 translation.

## Bench

- Android 16 arm64 emulator (4 vCPU, Apple M3 Max host), an optimized,
  profileable, debug-signed `0.8.0-perf` app that loads a pushed game pack.
- Scene: Grand Prix race 1, Luigi Circuit, 12 racers, player idle. The script
  starts the app, drives the menus, waits 55 s and measures 40–60 s of racing.
- Metric: game-thread CPU time divided by frames presented
  (`/proc/<pid>/task/<tid>/stat`, `KartPadPerf` fps). Build and deploy happen
  between runs, never during one; base and candidate alternate.
- **Do not use emulator FPS.** Two emulator threads spend 77% and 30% of a core
  in `goldfish_pipe` (the host graphics transport) and cap the race near
  40 FPS. Phones have no such thread. Earlier "no FPS change" emulator results
  for CPU-only changes were measuring that cap.

## Where the game thread goes

simpleperf, 1 kHz cpu-clock, call graphs, with unstripped pack and runtime:

| Share | What |
|---:|---|
| 40% | Translated game code (`func_8…`) |
| 21% | GX/graphics on the game thread: `aurora::gx::fifo::process`, `GX__CallDisplayList`, `handle_bp`, vertex format/descriptor setup, texture lookup, uniform build, `HleFifoWrite` |
| 11–14% | Scalar FP semantics (`EvaluatePpcScalarBinary`, `FinishScalarFp`, `Ppc…StateInline`) |
| 10% | Emulated TLS (`__emutls_get_address`, `pthread_getspecific`, `CurrentCpuContext`), mostly from the FP adapters |
| 6.5% | Indirect-call dispatch (`TryDispatchRawCpuTarget`, `InvokeIndirectCpu`, `FindRawByAddressPtrMiss`) |
| 6% | Kernel (partly the emulator transport) |

The shares match the earlier Pixel profiles, so the emulator is a fair stand-in
for where CPU time goes, but not for frame rate.

## Experiments (rejected; patches kept privately)

| Candidate | Profile effect | Game-thread ms/frame (alternating runs) | Result |
|---|---|---|---|
| Pass the generated function's `ctx` to the FP adapters instead of TLS (macro over the adapters; state-free leaf functions keep TLS) | TLS 10.4% → 2.5% of samples | base 8.78 / 8.98 / 10.14, candidate 9.12 / 9.01 / 9.29 | No measurable gain |
| + exact fast path for normal FP results (no exception, normal result) inlined at every site | — | base 9.68 / 9.15, candidate 10.49 / 10.16 | Slower: pack `.text` +12% (116.4 → 130.1 MB) |
| Same, adapters out of line | `.text` +1% | base 9.52 / 10.63 / 10.00 / 9.67, candidate 10.34 / 9.84 / 9.75 / 8.87 | No measurable gain |

Correctness checks that passed:

- A check build that aborts when `ctx` differs from the thread's current context ran from the title through 44 s of the race.
- 64 million old/new FP results compared bit for bit, with host status tracking both on and off. A planted error was caught.

Run-to-run spread on this bench is about ±0.6 ms (±6%), so it cannot resolve
changes below roughly 5%. The FP/TLS overhead is real in the profile, but removing
it did not produce a measurable whole-frame gain, consistent with the
September 23 Pixel results. Further FP/TLS micro-work is not the next priority.

## Next levers, by size

1. **Graphics preparation off the game thread (about 21%).** GX FIFO parsing and
   WebGPU command building run synchronously on the game thread. A consumer
   thread for the FIFO, as in Dolphin's dual-core mode, could move most of it to
   another core. The open question is which GX calls must stay synchronous
   (draw sync, EFB/texture copies the CPU reads, peeks).
2. **Indirect-dispatch misses (about 6.5%).** `FindRawByAddressPtrMiss` is
   visible in a steady race; a miss cache or a static table for hot targets
   should be cheap to measure.
3. **Translated code (40%).** Translator code quality, with patchzyy.

Each needs a lower-noise gate than whole-frame CPU on this emulator: more
rounds, or per-component sample counts per frame on the same build pair.


## Second round, same day

### Bench corrections

- **The emulator degrades over a session.** After about 5 hours and many app
  restarts, qemu held 30 GB of host memory and took more than 12 host cores.
  Races fell to 30 FPS and game-thread time doubled. The A/B script now
  cold-boots the emulator before every run and records qemu's resident size.
- **User and kernel time are now reported separately.** Kernel time on the game
  thread (mostly futex wakeups and the emulator transport) is about 0.7–0.8 ms
  per frame.
- **Run-to-run spread stays about ±0.4 ms (±5%) on cold boots.** The window is
  time-based, so it covers slightly different race segments. On this bench a
  change needs roughly a 10% effect to be resolved.
- **The emulator runs on M3 Max cores**, which hide dependent-load and
  branch costs that phone cores, especially in-order little cores, do not.
  Changes that remove instructions can therefore look smaller here than on
  phones.

### Where translated code spends its time

The sampled instructions inside `func_8…` code break down as:

| Share | Instructions |
|---:|---|
| 43% | Immediate-offset loads/stores (context, globals, structs) |
| 12% | Stack loads/stores |
| 7% | Register-offset (guest RAM) accesses |
| 11% | `ldrb` alone |
| 10% | `sub` |

The profile is flat: 887 functions, with the top 40 adding up to 10%.

On Android (and iOS), every flat guest access first reloads the
`g_requiresCheckedAccess` byte and the `gFlatGuestBase` pointer. Each needs an
`adrp`+`ldr` of the GOT entry, then the value, then a compare and branch. Guest
stores are byte copies that may alias any global, so the compiler cannot keep
either value in a register. Desktop builds use a compile-time base and pay none
of this.

### Flat-memory locals (not adopted yet)

`KARTPAD_FLAT_FUNCTION_LOCALS` reads both globals once into locals at function
entry (29,065 functions), and the `Flat*` helpers use them through macros. Code
without the locals falls back to the globals. Semantics are unchanged: both
values are fixed before translated code runs.

- **Code size:** pack `.text` fell from 116.4 MB to 109.0 MB (−6.4%).
- **Timing:** game-thread user time was 8.63 ms (base) against 8.50 ms (flat),
  a −1.4% difference over 8 cold-boot pairs, inside the ±0.4 ms spread.
- **Patches:** `build/perf/flat-locals-*` (local).
- **Status:** a candidate for a phone A/B. Do not ship it on emulator evidence.

### Smaller items found

| Item | Game-thread share | Where |
|---|---:|---|
| Vertex-layout hash recompute | ≈1.7% | `gx_dl.cpp` `HashScanLayoutState`, 650 multiplies whenever the dirty flag is set |
| Display-list scan cache misses in `unordered_map::find` | ≈1% | front-cache misses |
| Audio worker wake per AX frame | 1.9% | `notify_one` in `DispatchCommandList` (worth keeping off-thread) |
| Binder call from the performance hint | 0.6% | — |


### PGO experiment (pipeline works; not yet measured)

- **Instrumented pack:** `-fprofile-generate` must go in through
  `CMAKE_CXX_FLAGS` and `CMAKE_SHARED_LINKER_FLAGS`. The Android toolchain
  ignores `CXXFLAGS`/`LDFLAGS`. The 11 `retro_mod` shards ran over 45 minutes
  under instrumentation (normally under 30 s each), so they are compiled
  without it.
- **Collection:** the dump thread (`build/perf/pgo/pgo_dump.cpp`) resets the
  counters 75 s after load and writes 90 s later. One Luigi Circuit race gave a
  30 MB profile covering 38,570 functions.
- **Profile-use pack:** `.text` 126.8 MB, against 116.4 MB for base.
- **A/B:** invalid. Other jobs on the same Mac (BlueWake PGO and a SunPad perf
  loop) pushed the load average to 184 and the emulator to 10–20 FPS. Repeat
  on a quiet machine, and check a second track before trusting a
  single-track profile.

