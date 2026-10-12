# Android performance: where we stand

Updated 10 October 2026. **Start here** for #339 and slow-phone reports. Evidence
behind every number is in the
[10 October investigation](artifacts/2026-10-10/android-cpu-investigation.md).
The September Pixel experiments are in the
[archived handoff](archive/android-performance-handoff-2026-09-23.md).

## Release context

- Public: **0.8.0** (12 October; WiiCompiled sync, update notices, Shake to
  Trick, app icons), tagged at `60383d6a`. Its app code is the same as
  `c0056a6f`, where the APK and IPA were built.
- 0.8.0 contains no speed work. Nothing on this page has shipped yet.

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
| Profile-guided optimization (PGO) of the game pack | 12 October, quiet Mac, 4 alternating cold-boot rounds on the bench race: game thread **7.88 → 6.40 ms/frame (−19%)**; every PGO run beat every base run. The profile came from the same Luigi Circuit race, so this is the upper bound | **Candidate:** check an unprofiled track, then decide how it ships |

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

1. **Finish the PGO check.** Measured −19% on the profiled bench race (above).
   - Still needed: the same A/B on a track the profile didn't see. Reach it by
     touch (the stick or D-pad by touch did not move the cup cursor in a
     headless run; key events trigger the rumble prompt), or collect a new
     profile on another track plus a Retro Rewind race and bench Luigi Circuit.
   - Then decide how it ships: the APK can be built with a profile, but
     PadMint builds would need a published `.profdata` (function names and
     counts derived from running the game; Chris to decide). The release APK
     compiles translated code in the full Gradle graph, so the profile has to
     reach the shard targets there as well as `scripts/build-game-pack.sh`.
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
  - #444 (Honor, Snapdragon 6s Gen 3; no reply yet).
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

