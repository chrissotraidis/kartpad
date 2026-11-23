# DriftDroid parity goal loop

Started 23 November 2026. Owner decisions are marked **Chris**.

## Objective

Make KartPad on Android at least as fast as DriftDroid on the same phone, in the same scenes, and
prove it with numbers. Keep every KartPad feature and keep iPhone, iPad and Mac working. Do
whatever it takes inside the boundaries below. Port DriftDroid's runtime changes, write our own,
or change defaults, as long as the measurements improve and the game stays correct.

Players compare the two apps by feel: slow motion in races, stutter in menus, hitches when a
race loads. Parity means none of those is worse in KartPad.

## What parity means

KartPad reaches parity when, for every scene below and under both test conditions, its numbers
are no worse than DriftDroid's beyond the measurement noise (about ±5%, see the
[performance handoff](ANDROID-PERFORMANCE-HANDOFF.md#the-test-bed-and-its-limits)).

**Scenes** (Original Mario Kart Wii, Classic engine, default settings in both apps):

| Scene | Main number | Also record |
| --- | --- | --- |
| Main menu, idle 60 s | game-thread CPU per frame | video thread time |
| Select Cup, idle 60 s | game-thread CPU per frame | worst frame |
| Grand Prix race 1, Luigi Circuit, 12 karts | game-thread CPU per frame | FPS, p95 frame time |
| Mario Circuit (a course outside the PGO profile) | game-thread CPU per frame | FPS |
| Confirming a course until the countdown | worst frame, frames over 50 ms | pipeline waits |

Retro Rewind is a second check. DriftDroid 1.4.0 runs 6.13.4 and KartPad runs 6.13.5, so its
numbers are recorded but don't decide parity.

**Conditions.**

- **Free core.** The arm64 emulator on a quiet Mac, as the existing bench runs it.
- **Shared core.** The game thread pinned to one core beside a busy loop, the stand-in for a slow
  phone used on 11 November. This is the condition #576 and #584 describe.
- **Phone.** The Pixel 9 Pro XL, once each goal's emulator result is in. A slow phone (Helio G99
  class) would be the decisive test. See decisions for Chris.

Game-thread CPU per frame is the main number because emulator FPS is capped near 40 by the host
graphics transport. FPS counts only on the phone.

## The reference build

DriftDroid v1.4.0 (`DriftDroid-v1.4.0.apk`, 2 November 2026), checked against its published
`SHA256SUMS`. It is installed on our own test emulators and phones, with game data from our own
disc, and is never modified. It is marked profileable, so `simpleperf` can sample it like our
perf builds. A newer DriftDroid release becomes the reference only after a fresh baseline.

## Boundaries

- **Never publish game code.** That covers DriftDroid's APK and its translated code, our game
  packs, extracted disc files, saves and profiles recorded from the game. All of it stays in
  ignored folders (`build/perf/`, `private/`) and out of commits, PRs, issues and releases.
  Numbers, function names from our own source and charts can be published.
- **DriftDroid's source is GPL-3.0, like the runtime.** Port changes as narrow source changes, with
  the upstream commit and file in the commit message and a comment where the code was adapted, as
  `frame_rate_lock.cpp` does.
- **Same change on every runtime.** A shared runtime change goes to the Android, iPhone/iPad, Mac
  and tvOS forks, and to the translator copy when it adds or removes a native override. Apple
  forks get at least a compile check per change and PadMint player checks at release.
- **No regressions.** A change that makes any scene slower beyond noise, changes gameplay or
  breaks a race, online play, ghosts or saves is reverted, even if another scene got faster.
- **Releases and public replies need Chris.** Candidate releases stay drafts until he publishes.

## Rules for each iteration

1. Work on the lowest goal that isn't done. Record its state in the journal below.
2. One change per PR, with before and after numbers from `tools/android-perf` (cold boot per run,
   alternating A and B, at least three rounds each, `vm.loadavg` noted). A change under 10% that
   the bench can't resolve needs a `simpleperf` profile showing where the time went.
3. Keep a change only if it is faster beyond noise, or neutral and required by a later goal.
4. Math and decoder replacements need a bit-exact or documented-tolerance check against the code
   they replace.
5. After each merged goal, rerun the parity table for both apps and update it here.
6. Stop and ask Chris only for a decision listed below, hardware, a release or a public post.

## Goals

**P0. Baseline both apps.** Install DriftDroid 1.4.0 and current KartPad on the same emulator image
(separate installs, same disc data). Extend `bench.sh` and `capture-window.py` to drive
DriftDroid's menus too (package `com.driftdroid.android`, game thread `SDLThread`). Fill in the
parity table for both conditions. *Done when* the table has three repeatable rounds per app,
scene and condition.

**P1. Explain the gap.** Profile both apps with `simpleperf` in the race and at Select Cup under the
shared-core condition. Group samples into translated game code, GX command decoding, texture and
display-list work, audio, OS and scheduler code, and waits. *Done when* a ranked list accounts for
at least 80% of the per-frame difference, each item with its milliseconds. This list orders P3
to P6, and items it shows to be worth nothing are dropped.

**P2. The interrupt-flag fix.** Carry the guest interrupt-enable state across thread switches
(DriftDroid `ef99dbe`, `fiber_manager.cpp`). Without it, retraces, alarms and audio blocks that
should run during drawing are skipped after a switch. KartPad's 0.8.11 preemption points make
such switches more common. *Done when* it's merged on all runtimes, with numbers.

**P3. DriftDroid's October speed batch,** one item per PR, in the order P1 ranks them. On Switch
the batch took a race from 22.2 to 19.0 ms per frame.

- Native `PSMTXConcat`, `PSMTXMultVec`, `MTX44Copy` and `memcpy` (`native_math.cpp`), bit-exact
  against the translated versions.
- The direct native-call list (`native_cpu_calls.inc`, about 80 more small natives).
- Immediate-mode draws with direct attributes collected and submitted whole.
- Textures whose guest object is unchanged rebound without revalidating.
- The immediate-mode vertex layout published only when it changes.
- The display-list scan cache in one cache line per slot, with a prefetched successor hint.
- The other GX speedups in `1d10913` and `9040d29` that apply outside the Switch.

*Done when* every item is merged or rejected with numbers.

**P4. Threads.** Decode GX commands on a worker thread (DriftDroid's threaded GX, `threaded_gx`,
`aurora-main/lib/gx/fifo.cpp` and its sync points), and place the game, GX worker, audio mixer and
frame worker threads on suitable cores. Confirm the audio mix worker is on by default on Android.
*Done when* threaded GX is on by default with races, menus, item boxes, ghosts and online checked,
or rejected with numbers.

**P5. Menus and loading.** Native menu-movie decoding (#595), then a faster decoder if P1 still
shows it, scene pipeline replay before a course is confirmed (#584's stall), and anything P1
finds in scene transitions. *Done when* the Select Cup and course-confirm rows reach parity.

**P6. Display and heat.** Check that KartPad asks Android for 60 Hz like DriftDroid does
(`Surface.setFrameRate`). Compare background shader rebuild behaviour, and DriftDroid's thermal
resolution scaling (opt-in there) for #566. *Done when* each is matched or shown not to matter.

**P7. Everything else P1 found.** Dawn and Aurora differences, PGO coverage of menus and Retro
Rewind, translator output, and the Beta engine if it stays a choice.

**P8. Confirm on a phone and ship.** Run the parity table on the Pixel 9 Pro XL for both apps, and on
a slow phone if Chris provides one. Cut a release with the numbers in its notes, add a "speed on
your phone" table to the README, show "Vulkan" in the Graphics Engine row (#576 read "Classic" as
no Vulkan), and draft replies for #576, #584 and #554. *Done when* the release is published (Chris)
and the table holds on the phones we have.

**After parity.** Keep both apps in the table at every release, so a regression or a new DriftDroid
speedup shows up at once.

## Decisions for Chris

1. **A slow test phone.** Emulator shared-core runs only stand in for one. A used Helio G99 phone
   (the chip in #576 and #584) would prove parity where players feel it. The 11 October rule says
   no test phones are bought.
2. **Release cadence.** Ship each goal as it lands (smaller releases, sooner feedback), or one parity
   release after P4.
3. **The Beta engine.** Whether parity work also targets WiiCompiled 0.9 (Beta), or only Classic.

## Journal

Newest first. One entry per iteration: goal, change, numbers, PR, next step.

- **23 November.** Loop written. Open PRs from the 22–23 November pass are in
  [CURRENT-LOOP](CURRENT-LOOP.md). P0 not started.

