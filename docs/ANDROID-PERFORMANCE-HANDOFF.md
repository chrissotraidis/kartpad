# Android performance: where we stand

Updated 31 October 2026. **Start here** for #339 and slow-phone reports. Evidence
behind every number is in the
[10 October investigation](artifacts/2026-10-10/android-cpu-investigation.md).
The September Pixel experiments are in the
[archived handoff](archive/android-performance-handoff-2026-09-23.md).

## 31 October: the Android beta engine ran on one core

The WiiCompiled 0.9 graphics layer (Android **Graphics Engine → WiiCompiled 0.9
(Beta)**) pins the game thread, the GX FIFO thread and its render worker to the
cores that share the highest-level cache with the core the game thread starts
on. It reads that from `/sys/devices/system/cpu/cpuN/cache`. The owner's Pixel
9 Pro XL (Tensor G4, Android 17) lists only each core's L1 there, so all three
threads were pinned to one core: `Cpus_allowed_list: 4`, with about 21.7 million
involuntary switches on the game thread and 21.2 million voluntary ones on the
FIFO thread. Which core it is depends on where the game thread starts, so a
launch can land on a little core.

Timing builds of the 29 October integrated source, same phone, Luigi Circuit
Grand Prix race, player idle, 4× render resolution, thermal status 0–1:

| Beta build | Race FPS | Game-thread CPU per frame |
| --- | --- | --- |
| Pinned (0.8.6 behavior) | 19–22 | 20–23 ms |
| Unpinned ([wiicompiled#16](https://github.com/chrissotraidis/wiicompiled/pull/16)) | 48–60, mostly mid-50s | 13–14 ms |

The pinned build stayed near 20 FPS at 2× too, and the GPU clock sat at
337–580 MHz of 940 MHz, so it wasn't GPU-bound. The display handoff didn't
throttle it either: frame-slot, staging, acquire and present waits all stayed
under 1 ms. Menus held 60 FPS either way. An earlier "phone warms up"
explanation was wrong; the drop came about a minute into a race on a cool
phone. Classic doesn't use this pinning; on the same phone and scene it ran
about 41 FPS.

Unpinned, the beta still ran 45–55 FPS in the owner's play. The next cause was
the performance hint ([wiicompiled#17](https://github.com/chrissotraidis/wiicompiled/pull/17)).
It reported only the game thread's CPU time, about 13 ms. The real frame took
18–20 ms, because the game thread also waits on the FIFO and render threads. The
governor therefore kept the mid cores around 1.1–1.8 GHz of 2.6. The hint now
reports each frame's wall-clock work, minus VI pacing sleeps, and includes the
`Aurora …` helper threads. Same phone, Luigi Circuit at 3×: the beta went from
48–58 FPS (median 52.3) to 59–60 (median 59.9), with the mid cores at about
2.0 GHz. Classic stayed at 60 with slightly higher clocks; its helper threads
are named `SDLThread` and aren't in the session.

Not checked: Snapdragon, MediaTek or Exynos phones, the beta at 4× after the
hint fix, or battery and heat over a long session with the higher clocks.

## 29 October: sustained slowdown on Galaxy S10 Lite (#510)

**Release preparation, not acceptance.** The reporter's
[three 0.8.6 logs](https://github.com/chrissotraidis/kartpad/issues/510#issuecomment-6399035109)
cover one Original runtime session across Banana, Flower and Star Cups.
**30 FPS Races** and **Simpler Computer Karts** are both logged off. The
[follow-up](https://github.com/chrissotraidis/kartpad/issues/510#issuecomment-6488481275)
explains that updating does not enable them and keeps the sustained slowdown
open.

At the three export endpoints, same-process PSS is approximately **992 MiB,
1,385 MiB and 2,063 MiB**. The retained frame windows are mostly around 60 FPS
in the first two logs; the third has a median sampled rate of about 42 FPS.
These are capped trailing windows, not whole-cup benchmarks. Android reports
only no or light thermal throttling, with none at the final endpoint. Different
courses, accumulated caches and time spent playing are confounded; this does
not prove a leak or rule out device power management.

A source review of Classic Aurora at the 0.8.6 Android runtime pin `b2a5de4`
found that `pipeline_cache.cpp` retains compiled pipelines until renderer
shutdown; changing scenes resets recording without evicting those objects.
The logs' compiled-pipeline count grows from 1,015 to 1,368 to 1,823 at the
export endpoints. **Pipeline retention is a candidate, not a diagnosed cause.**
The display-list cache has entry/command-payload bounds, and texture-object
metadata and bind-group caches retire idle entries. This does **not** bound all
GPU texture lifetime: the source review at the integrated `6e3ce40` pin found a
2,048-slot texture identity memo and a 256-slot source front cache that retain
strong texture references. A stale identity binding can keep a texture alive
after its object metadata is pruned; the source-cache eviction also waits until
that handle has no other owners. The identity memo releases on replacement or
shutdown, rather than every course load. This is documented fixed-capacity
retention, not a demonstrated leak. Framebuffer-copy telemetry covers only those
copy resources, so a small copy pool cannot exclude other texture retention.
No cache policy was changed on this evidence. The next memory attribution
should count retained static textures/bytes as well as compiled pipelines.

Next test, with fixed Classic engine, character, vehicle and settings:

1. Warm Luigi Circuit and record a 60-second baseline. Re-enter the same course
   eight times through the game menus, keeping the same runtime process alive;
   sample the same point on each visit and confirm the course with screenshots.
2. In a separate session, visit several different courses, return to Luigi
   Circuit, and repeat the identical sample. Then restart KartPad, retain its
   disk caches, and sample Luigi Circuit once more.
3. Compare same-process PSS, CPU per present, FPS, thermal status, compiled and
   queued pipelines, display-list entries and copy-resource metrics. Growth on
   identical revisits points beyond ordinary new-course caching; growth mainly
   with new pipelines warrants investigating their retention. Compare Luigi
   with Luigi before attributing a slower later course to accumulated state.

`tools/android-perf/bench.sh` force-stops KartPad before every run,
and `ab.sh` cold-boots the emulator between trials. Use the new
[`capture-window.py`](../tools/android-perf/capture-window.py) on an already
running game for this test. It preserves the process and logs, verifies both
PID and process start time, records PSS plus new numeric frame/cache/CPU
telemetry, and retains before/after screenshots without overwriting old ones.
Emulator host graphics memory is a separate known confounder, so
any emulator finding still needs a reproducing physical-device comparison.

The first short check is preserved in the [earlier record](artifacts/2026-10-29/mobile-bloom-and-session.md#bounded-same-process-check-for-510). The subsequent full integrated candidate now completes the longer local comparison:

- Nine Luigi visits in one process over **26 minutes**: PSS ended at 342.4 MiB initially, then 362–365 MiB across the last five visits. Pipelines grew from 473 to 499. The display-list cache cycled within its 16,384-entry / 8 MiB logical command-payload thresholds; those thresholds exclude allocator and fixed-record overhead.
- A separate process sampled Luigi → Mario Circuit → Peach Beach → Sherbet Land → Luigi over about **17 minutes**. End-of-window PSS was **323.4 → 371.4 → 519.3 → 557.3 → 556.4 MiB**; compiled pipelines were **502 → 555 → 690 → 735 → 735**. The copy pool stayed between 5.4 and 5.9 MiB.
- Restarting, keeping disk caches and settings, returned Luigi to **322.7 MiB**, with 504 pipelines and a 5.4 MiB copy pool. This reproduces about **233 MiB of process-lifetime retention** after different courses, without a continuing rise over the last repeated-Luigi visits.

This does not isolate a leak, a particular cache owner, or the phone slowdown. Pipeline count and memory move together while texture/allocator state also changes. The GP opponent roster/RNG was not fixed. Each window follows short actual acceleration and stationary warm sampling, not a completed race or cup. Other local work contended for the host, so timing/FPS fields are retained only as raw evidence and are excluded from performance conclusions. The owner has no affected phone available and requested continued local validation. The next useful test is memory attribution across pipeline/shader and retained texture ownership, rather than a blind eviction policy or another settings sweep.

[Full artifact, protocol, memory tables and limitations](artifacts/2026-10-29/integrated-android.md).

## 24 October: PGO ships in 0.8.6's Android pack

The Android release pack is now profile-guided (`KARTPAD_GAME_PACK_PGO` in
`scripts/build-game-pack.sh`). The profile covers Original and Retro Rewind
races. On unprofiled Mario Circuit, every PGO run used less game-thread CPU
than its alternating baseline; the two quiet-host pairs show about **12% less**
(7.81 → 6.91 ms/frame), and the pack is 13% smaller. Emulator only; no phone was
measured. PadMint player builds are unchanged until a profile may be published
for them. [Record and limits](artifacts/2026-10-24/pgo-release.md).

Next candidate from #504's Odin 3 log (fast Snapdragon 8 Elite, median 16.7 ms
but p95 20–31 ms with no shader queue): the game thread's Performance Hint
session targets the whole 16.67 ms frame and reports only that thread's CPU
time, so a power-saving governor may lower clocks until the work nearly fills
the frame. A tighter target or adding the frame worker to the session needs a
phone that shows the hitches; it is not testable on the emulator.

## Release context

- Public: **0.8.6** (build 268, 25 October), tagged at `8cd1a68c`. Android PGO,
  the vertex-repack reduction, 30 FPS Races and Simpler Computer Karts have
  shipped. None establishes a fix for #510’s sustained slowdown.
- Historical 0.8.1 restored the 0.7.15 Automatic path for Adreno 6xx/7xx after
  0.8.0 hid characters on some previously working devices. Adreno 8xx keeps its
  earlier all-draw repack policy. The 0.8.0/0.8.1 binaries contain no general
  CPU optimization from this page.

## New regression evidence (#470, 14 October)

The Honor MTN-NX3 report identifies Adreno 810, Android API 36. The first
attached runtime is 0.7.15/260, the next 0.8.1/263, both Retro Rewind at 1×
with automatic all-draw repack. The 0.8.1 export's session-directory prefix
says `base`, but the console's activated/translated profile and same-PID
health records say Retro Rewind; do not infer the profile from the directory.

- 0.7.15 includes a 23.99 FPS sample with main-thread occupancy 94.2% and
  32.487 ms CPU per present over its reporting interval; same-session thermal
  status is 1 (light).
- 0.8.1 includes an 18.34 FPS sample with main-thread occupancy 93.8% and
  39.248 ms CPU per present over its reporting interval; nearby same-session
  health reports thermal status 3 (severe). Other low samples begin at
  thermal status 1 or 2, so heat alone is not an established cause.
- `pipelines_queued=0` in these samples. FPS and CPU telemetry cover different
  window lengths; do not derive one from the other or treat whole-session
  medians as race benchmarks.
- Old version-65 thermal history in the exports is not this session. Match
  health by PID and time. This is also a different case from #465, whose
  reporter found 1× avoided their heat-related slowdown at 4×.

The player reports time trials stay stable, offline bots improve somewhat on
0.8.1, and online worsens. Those mode boundaries are not explicitly labelled in
the exported trace, and there is no log from the earlier well-performing build.
The cause of the regression is open. Reuse the supplied evidence; no further
settings sweep or log request now. Prioritize equivalent warmed CPU work and
inspect all-draw repack cost without disabling the known graphics correction
on Adreno 8xx. Source/history alone is not a measured speedup.

[Detailed triage and replies](ISSUE-TRIAGE-2026-10-14.md).

## 14 October candidate: vertex-repack loop

The production repacker now visits attributes before vertices, avoiding repeated
format/absent-attribute checks. ASan/UBSan golden cases pass and every benchmark
output hash matches the unchanged implementation. Quiet-host forward/reverse
runs show roughly 27–34% less CPU time for 32–2,048 vertices. This is an Apple
Silicon CPU microbenchmark, **not Android FPS**, and does not identify #470's
regression. Adreno 8xx all-draw repacking remains enabled. See the
[measurements and limits](artifacts/2026-10-14/android-input-cpu-renderer.md#470-cheaper-vertex-repacking).

## What we know

**The slowness is CPU-bound, on one thread.** The game runs on a single
thread, so speed follows one core's speed. Players' reports agree:

- **Resolution doesn't help:** lowering it does nothing (#167 at 1×/0.75×/0.5×;
  #198 at minimum).
- **Fewer racers do help:** #313 sees more FPS with fewer racers on screen.
- **The game thread is saturated:** on #198's Helio G85 it is 94–97% busy, and
  presenting a frame takes only 2.3–2.6 ms.
- **The Honor X7c needs 36–40 ms** of game-thread time per race frame (#313).

| Phone | Game thread per 12-racer frame | Result |
|---|---|---|
| Pixel 9 Pro XL | about 14.5 ms | 60 FPS |
| Dimensity 7300 (POCO X7, #438), about half the single-core speed | about 29 ms | 30–40 FPS reported |
| Helio G85, about a third | about 45 ms | 20–25 FPS reported |

**What that means for targets:**

- **Mid-range phones need about 2× less game-thread work** to hold 60 FPS.
- **Helio-class phones would need about 3×,** so a steady 30 FPS is the
  realistic goal there.
- **Small tweaks won't close this gap.** Earlier tuning gained 10–14%; this
  needs structural changes.

**Where the game thread goes** (emulator, Luigi Circuit, 12 racers; the shares
match the September Pixel profiles):

| Share | What | Lever |
|---:|---|---|
| 40% | Translated game code, spread over about 890 functions (the top 40 are only 10%) | Translator code quality; memory-access cost below |
| 21% | GX/graphics work on the game thread (FIFO decode, display lists, vertex formats, texture lookups, uniforms) | Move it to another core |
| 11–14% | Scalar floating-point semantics (`EvaluatePpcScalarBinary`, `FinishScalarFp`) | Removing it measured nothing |
| 10% | Android 9 emulated TLS (`__emutls_get_address`), from FP adapters, dispatch and caches | Pass context, or require Android 10 |
| 6.5% | Indirect-call dispatch | Small |
| 6% | Kernel (futex wakeups, partly the emulator) | Small |

**Every guest memory access pays a tax on Android and iOS.** Before each
access, translated code reloads two globals:

1. `g_requiresCheckedAccess`, a fallback for 16 KiB-page phones;
2. `gFlatGuestBase`, where game memory starts.

Each reload is a GOT load, a value load and a compare-and-branch. The compiler
can't keep them in registers because guest stores are byte copies that might
alias them. Desktop builds use a compile-time base and pay none of this.

## What has been tried

| Change | Result | State |
|---|---|---|
| Skip unobserved FP status capture, plus an Android Performance Hint on the game thread (candidate 203) | Game-thread CPU 14.7 → 12.65 ms on the Pixel | Shipped in 0.5.1 |
| Android game packs without debug info (`-g0`) | Compile CPU 2,232 → 1,404 s | Shipped in 0.7.5 |
| Audio ARAM window resolved once per voice | Removes the per-sample TLS cost | Shipped |
| CPU-context slot (205), native TLS (API 29), 512-function layout | No reliable gain (September, Pixel) | Rejected |
| Pass `ctx` to the FP adapters instead of a TLS lookup | TLS samples 10.4% → 2.5%; no measurable frame-time change | Rejected; patch kept |
| Exact fast path for normal FP results | Inlined: `.text` +12%, about 10% **slower**. Out of line: no change | Rejected; patch kept |
| Flat-memory locals (read both globals once per function) | `.text` −6.4% (116.4 → 109.0 MB); −1.4% user time over 8 pairs, inside the noise | **Candidate:** needs a phone A/B |
| Profile-guided optimization (PGO) of the game pack | 12 October, quiet Mac, 4 alternating cold-boot rounds on the training race: game thread **7.88 → 6.40 ms/frame (−19%)**, an upper bound. On 14 October, unprofiled Mario Circuit also favors PGO. On 24 October, a three-session Original + Retro Rewind profile: quiet pairs on unprofiled Mario Circuit **7.81 → 6.91 ms (−12%)**, pack 13% smaller | **Shipped in 0.8.6 (Android APK).** PadMint builds need a published profile first. [24 October record](artifacts/2026-10-24/pgo-release.md) |

Patches and the PGO dump source are in [`tools/android-perf`](../tools/android-perf/README.md).

## The test bed and its limits

[`tools/android-perf`](../tools/android-perf/README.md) builds variants,
deploys them over an emulator install (game data kept), drives the menus into a
race and reports game-thread CPU per frame, alternating base and candidate.

Rules learned the hard way:

- **Never use emulator FPS.** The emulator's host graphics transport caps races
  near 40 FPS.
- **Cold-boot the emulator for every run.** It leaks host memory with each app
  restart, reaching 30 GB after a few hours, and slows down. `ab.sh` does this.
- **Use a quiet machine.** Other chats' builds (BlueWake PGO, SunPad loops)
  pushed the load average to 184 and invalidated a whole A/B. Check
  `sysctl -n vm.loadavg` before trusting a run.
- **Headless runs need `-gpu host`.** With `-no-window`, `-gpu auto` falls
  back to software rendering: the emulator takes about ten cores and races run
  at 10–20 FPS, which also explains part of the 10 October noise. `ab.sh` now
  passes `-gpu host` (60 FPS, about 1.2 cores).
- **Drive menus with touch only.** `adb shell input keyevent` makes Android
  register a controller; the game then asks about GameCube rumble at the
  licence screen and touch A no longer answers it.
- **Resolution is about ±5%** (±0.4 ms) between cold-boot runs, so only changes
  around 10% or more are resolvable here.
- **The emulator runs on M3 Max cores,** which hide load and branch costs that
  phone cores, especially little in-order cores, do not. Changes that remove
  instructions look smaller here than they will on phones.
- **Physical confirmation still needs a phone that reproduces the slowness.**
  The current loop's ground rule is that no test phones get bought; that is
  Chris's call to revisit.

## Next steps, in order

1. **PGO for PadMint builds.** The Android APK ships with it from 0.8.6.
   iPhone, iPad and Mac builds would need a published `.profdata` (function
   names and counts derived from running the game; Chris to decide), and a
   profile recorded on the Apple runtime. Re-record the Android profile with
   every translation change (`KP_BENCH_COURSE=mario` keeps an unprofiled check).
2. **Phone A/B for flat-memory locals** (and optionally the explicit-context
   change). If it gains, implement it properly:
   - **Translator:** emit an entry macro before `goto <entry>` in
     `CxxLinearCodeGenerator.cs` (beside `EmitHoistedGqrPrologue`).
   - **Runtimes:** define the locals in the Android and iOS runtimes, both of
     which use a launch-time base. Other runtimes define the macro empty.
   - **Upstream:** offer it to WiiCompiled through patchzyy (#339).
3. **Move GX FIFO decode off the game thread** (the 21%). Design first:
   - which GX calls must stay synchronous (draw sync, EFB/texture copies the CPU
     reads, peeks);
   - guest memory lifetime: display lists and vertex arrays live in guest RAM,
     which the game can change after the call.
   Aurora already has a frame worker (`aurora.cpp`). This is multi-day work
   with a risk of garbled geometry.
4. **Small items, each under 2%:**
   - make the vertex-layout hash incremental (`gx_dl.cpp` `HashScanLayoutState`, about 1.7%);
   - display-list cache front-cache misses (about 1%);
   - the TLS check in `DispatchKnownTranslatedCpuTargetStatic` on every translated call.
5. **Product decision:** requiring Android 10 (API 29) gives native TLS across
   the whole runtime. The September native-TLS trial was inconclusive on the
   Pixel; re-measure with the current bench before deciding.

## Open issues

- **Performance:**
  - #339 (patchzyy's request; slow-phone reports are folded into it).
  - #438 (POCO X7, Mali, Dimensity 7300; also a Retro WFC 61070 error).
  - #470 (Honor MTN-NX3, Adreno 810; 0.7.15/0.8.1 logs reviewed above).
  - #465 is closed by its reporter; 1× avoids its reported high-resolution
    thermal slowdown. The requested 1.5× UI option is prepared, not a CPU fix.
- **Not performance, so don't mix them in:**
  - Adreno 6xx/7xx invisible characters (#104, #301; next step is a different
    way to hand bone matrices to the GPU, Chris's decision, [loop, Phase 2](CURRENT-LOOP.md#phase-2-android-graphics-and-stability));
  - PowerVR (#304);
  - Honor textures (#431);
  - 60 Hz launch flicker (#390);
  - Moto G75 crash (#332);
  - games that open briefly (#370);
  - cup-end crash (#131).
- **Mac input lag:** Wii Remote with Classic Controller Pro (#306) is input
  latency, not frame time.

When replying on #339, post measured before/after numbers only, and keep
emulator, Pixel and reporter results separate.

## Needs Chris

- A quiet machine window for benchmarks, or pausing other chats' long builds.
- No slow test phone gets bought (decided 11 October). Remote device labs are
  the proposed substitute; see the
  [11 October handoff](RESEARCH-HANDOFF-2026-10-11.md#research-remote-device-labs).
- Android 9 support, if native TLS proves worth it.
- Whether a PGO profile may be published for PadMint builds.

## Resuming

1. Fetch main. Check `gh release list` and open issues for new performance
   reports.
2. Read this page, then the
   [investigation](artifacts/2026-10-10/android-cpu-investigation.md).
3. **Set up the bench:** [`tools/android-perf/README.md`](../tools/android-perf/README.md).
   It needs the private game pack and translation from a self-build, and the
   phone AVD with imported game data.
4. Confirm the machine is quiet, run base three times to see today's spread,
   then pick the next step above.

