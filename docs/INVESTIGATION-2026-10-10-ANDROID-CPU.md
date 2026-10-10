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

