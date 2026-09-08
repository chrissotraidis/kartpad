# KartPad performance ledger

Historical Apple measurements: 30 August 2026. The measurement contract below
applies to new comparisons; active Android and Apple investigations are on the
[maintenance board](MAINTENANCE-BOARD.md).

G11 is not accepted. KartPad reaches real native gameplay on Apple Silicon,
but first-use shader compilation and some sustained scenes are materially
slower than the retail cadence. A visible FPS label or successful race never
substitutes for frame-time, guest-cadence, audio, memory, and soak evidence.

## Current observations

| Scenario | Observation | Classification |
|---|---|---|
| Cold exact macOS self-build title | Roughly 44 FPS while about 793 shaders were still compiling; later reached 60 FPS | Diagnostic only; uncontrolled cold sample |
| Moonview Highway first use | 1.3 FPS initially, roughly 46 FPS within 20 seconds, then roughly 46–54 FPS | Fail for G11; controlled warm rerun required |
| Normal two-player race | Captured overlay repeatedly showed 59.5–60.1 FPS | Gameplay evidence only; no frame-time distribution |
| Three-player clean-load observation | Retail 29.5–30.1 FPS mode cadence observed | Mode identification only; p99/worst open |
| Three-player lifecycle stress | Captures showed 14.8–19.8 FPS and 18 audio drops | Rejected performance/audio sample |
| Exact self-build first exercise | 43 dropped audio blocks / 16,512 bytes under compilation load | Fail signal; must be paired with exact frame/shader timeline |
| Representative audio continuity | 2:00:18 completed; 175 stale blocks / 67,200 bytes, about 0.0073% of submitted bytes | Useful bounded telemetry; not G11 soak acceptance |
| Exact `2cfb7e1` retained-cache title | Minimum effective FPS 59.001; maximum p99 17.701 ms; maximum worst 32.808 ms while the queue fell from 1,223 to 865 | Instrumentation pass only; short, non-fixture session |
| Exact `2cfb7e1` empty-cache title | Minimum effective FPS 51.958; maximum p99 83.783 ms; maximum worst 85.094 ms; 20 audio blocks / 7,680 bytes dropped | Controlled fail signal |
| Exact `2cfb7e1` immediate warm title relaunch | Minimum effective FPS 59.963; maximum p99 17.264 ms; maximum worst 25.966 ms; zero audio drops | Controlled title improvement; race/soak evidence still open |
| macOS one-vs-six priority-worker sweep | One worker ranged from 55.460–59.868 minimum effective FPS; six workers ranged from 52.000–59.974 as machine-level Metal state warmed | Confounded; one-worker default reverted |
| Three-player stationary VS, ~310 s live | Typical 29.94–30.10 effective FPS with p50 33.2–33.6 ms and p99 33.9–35.4 ms; 29 audio blocks / 11,136 bytes dropped | Native 30 Hz cadence mostly stable; audio fail and no standings |
| Interrupted exact `2282e2c` macOS attract soak | 4:10:10 sampled; RSS 257,120–1,125,792 KiB with negative post-warmup slope; 23–28 threads; 480 audio blocks / 184,320 bytes dropped across scene transitions; save unchanged | Diagnostic memory/thread pass signal; audio fail; operator-stopped and not row-38 acceptance |

## Acceptance contract

Every performance result must record:

- exact commit, app hash, hardware, OS, power state, display refresh, window
  mode, resolution scale, interpolation mode, and graphics settings;
- save/fixture identity without publishing private content;
- whether application and Metal/Dawn caches were retained, copied, or cleared;
- queued/compiled pipeline counts over time;
- guest cadence plus host-present p50, p95, p99, and worst frame interval;
- CPU profile, GPU/Metal capture, resident/peak memory, and thread count;
- audio queue checks, empty observations, drops, submitted bytes, and maximum
  depth; and
- exact start/end state, duration, clean shutdown result, and evidence paths.

Interpolated or duplicate presentation frames are reported separately from
effective motion and guest simulation cadence. Averages do not override a bad
p99 or worst frame. Any correctness, audio, save, rendering, or lifecycle
regression rejects the candidate even if its average FPS improves.

## Controlled experiment order

1. ~~Add bounded, machine-readable present telemetry with interval buckets,
   p50/p95/p99/worst, effective-motion cadence, and pipeline queue counts.~~
   Implemented and exercised at `2cfb7e1`; G11 is still open.
2. ~~Run a controlled warm-cache title/menu baseline without clearing any
   state.~~ Exact immediate warm title evidence is recorded at `2cfb7e1`.
3. ~~Copy the complete existing cache aside, clear only regenerable KartPad
   caches, and run the exact cold title/menu path once.~~ The empty-cache title
   run is recorded as a quantified failure.
4. ~~Restore the copied cache and repeat the same path to prove the comparison
   itself is reversible.~~ The original cache tree hash matched after restore.
5. Repeat the cold/warm pair on deterministic Luigi Circuit and Moonview
   Highway fixtures, pairing frame telemetry with audio telemetry.
6. Rank CPU, GPU, shader compilation, synchronization, and guest-thread stalls;
   change one variable per experiment.
7. Keep only improvements that pass the affected correctness/ghost/audio
   regressions and improve p99/worst, not merely average FPS.
8. After representative scenes pass, run launch/race stress and the required
   eight-hour macOS soak with memory/thread/leak and clean-shutdown checks.

The first automated soak attempt was intentionally retained as an interrupted
diagnostic. It exposed a fixed 120 ms queue ceiling that overflows during some
scene exits even after pipelines are warm. Counterbalance bounded queue
headroom before repeating the required eight-hour run; do not accept a larger
cap unless observed queue depth drains and latency remains bounded.

## Hypotheses from the recorded measurements

- The initial pipeline cache covers many common states but misses enough
  title- and track-specific combinations to cause visible compilation stalls.
- Compilation competes with guest and audio work under heavy first-use load.
- KartPad's application cache does not capture all relevant Metal/Dawn state:
  a counterbalanced six-worker run became as smooth as the best one-worker run
  after prior exercises. Worker count alone is not the root fix.
- Moonview Highway's sustained 46–54 FPS after the visible queue shrinks may
  include a second CPU/GPU/synchronization bottleneck; it must not be described
  as only a shader-cache problem without a profile.
- Skipping draws for unready pipelines may improve pacing while producing
  incorrect output; it remains an experimental comparison variable, not a
  release default.

## Exit conditions

G11 can pass only when mode-specific native cadence and frame pacing pass on
the exact macOS candidate across defined cold and warm scenarios, all required
stress/soak rows pass, memory and thread counts remain bounded, audio remains
accepted, shutdown is clean, and the evidence is indexed in `docs/STATUS.md`
and the PRD matrix. Mobile performance is separate G16 evidence and cannot be
inferred from Mac results.
