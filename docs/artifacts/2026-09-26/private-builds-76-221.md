# Private builds: iPad 76 and Android code 221 (26 September 2026)

Both builds are private test builds. The release hold for the iPad menu stutter stays in
place until a play session on build 76 is smooth.

## What changed

- **Menu shader replay (iOS and Android runtimes).** Menu archives under `Scene/UI`
  (language suffix removed; Race and Font excluded) now record the pipelines each menu
  uses and compile them on all workers when that menu loads again. Course keys are
  unchanged.
- **Larger startup prewarm (iOS only).** The first 512 recorded pipelines, up from 128,
  compile in the background at launch. On the iPad's cache, 559 recipes are first used
  within a minute of play, and 299 of those belong to no course. These cover the title
  and menus whose thumbnail copies must wait for their shaders. Android keeps 128
  because of low-memory phones.
- **Controller auto-accelerate (#319, Android and iOS).** New switch, off by default.
  Holding A for one second locks acceleration, and the next press of A releases it. It
  uses the shared latch in `runtime/include/kartpad/input/auto_accelerate.h`. Android
  applies it after button remapping; iOS applies it to physical controllers only.
- **Single Joy-Con on iPhone/iPad (#324).** Controllers that report only a micro
  profile are accepted. The stick steers; A accelerates; X or B drifts; shoulders or Y
  use items; Menu pauses. This is untested with real Joy-Cons. Android relies on SDL's
  defaults (combined pairs; single Joy-Con as a sideways mini gamepad) where the phone
  exposes Joy-Cons to HIDAPI.

## Builds

- iOS runtime `b2e51eb` (branch codex/ios-menu-stall-20260925). Android runtime
  `fda9f78` (branch codex/android-input-menu-20260926). Root `13971a8`.
- iPad build 76: the app audit passed, diagnostics candidate NO, dSYM UUID
  `95B16D1A-E3F0-3255-9950-04F85B7B0D7F`, and the strict signature check passed. It was
  installed in place on the iPad Pro, and the before/after user data manifests (34 files)
  are identical. The app was launched to the game chooser only; no game was started.
- Android code 221 (`0.5.1-review.2`, private release APK, debug signer `61dfb514…`),
  SHA-256 `ad8ba0e42c1f1e26f2c606f99fc8642c7db77afd5b0989fa322522afafe2b28e`.
  It was installed in place on the Pixel 9 Pro XL over 219, and the first-install date
  (6 September) is unchanged. Not played. This APK must not be published: public
  releases need the release signer.

## Checks

- The latch timing test (in `android_gamepad_contract_tests.cpp`) and the Apple physical
  controller test, including a new micro-profile controller case, pass on the Mac host.
- Not yet verified: menu smoothness on the iPad, controller auto-accelerate on a
  device, and any Joy-Con hardware.

## GitHub replies (26 September)

Replies were posted on #319, #320, #322, #323 and #324. No retests were requested
before publication. #322 and #323 were asked for a diagnostic export if the freeze or
crash recurs, and #324 was asked which device and Joy-Con setup they use.


## Follow-up: iPad build 77 and Android code 222

- **Launch prewarm cannot force game-thread compiles (iOS).** The synchronous-build cap now
  counts only first-use (priority) pipelines. Before this change, 512 queued prewarm entries
  could exceed the 256 cap, which would compile new pipelines on the game thread when
  "Skip draws while shaders compile" is off. Demand still promotes a queued prewarm recipe
  to the front. iOS runtime `232484c`.
- **Single sideways Joy-Con (Android).** Android's Bluetooth stack does not give SDL
  HIDAPI access to Joy-Cons, so a lone Joy-Con arrives from the kernel driver in its
  upright layout. The runtime now reads the controller's vendor and product IDs
  (057e:2006 left, 057e:2007 right), rotates the stick to the rail-up grip, and moves the
  thumb buttons to the face positions (left Minus pauses). This runs before the player's
  button remapping, so the mapping screen can correct any per-phone label differences.
  Pairs and other controllers are unchanged. Android runtime `0fcbc65`.
- The host gamepad contract test covers left/right rotation and pass-through for other
  controllers. No Joy-Con hardware was tested.
- iPad build 77 was installed in place, and the before/after user data manifests are identical.
  It was not launched because another task was running BlueWake on the iPad.
- Android code 222 (`0.5.1-review.3`, debug signer `61dfb514…`), SHA-256
  `f122b7348669b3fee22e5fcc881685b7fd53c8d509e11db48257640ea33d5282`, was installed in place
  on the Pixel, and the first-install date is unchanged. Not played.


## Android code 223

The Controller auto-accelerate switch moved from Touch Control Settings to the top of
Controls → Controller Button Mapping, where controller players look. `0.5.1-review.4`,
debug signer, root `cc8d847`, installed in place on the Pixel (first-install date
unchanged). The on-screen check was not possible because the phone was locked.


## iPad build 77 play session and build 78 (26 September, 10:25 JST)

Chris played build 77 on the iPad with an Xbox controller: Original, Grand Prix. He saw
menu slowness, stalling, and dips from 60 to about 45 FPS during races.

Session log `base_1790385932_pid5174`: launch prewarm compiled 503 pipelines in 3.9 s
(Dawn 1049/1115 hits). During the race, each dip matched a single
`Pipeline wait: 63-327 ms persistent=true`. Pipelines created went from 514 to 552 over
the race. Every waited pipeline was already in the device recipe database and linked to
that course scene: 11 of 11 checked, with first use between frames 2569 and 6658. At
roughly 8 ms per pipeline during prewarm against 200-300 ms on demand, these pipelines
were compiled from scratch. The consistent explanation is that the iPadOS 26.7 system
shader cache never held them, because they were last compiled under 26.6.2. This is a
reasoned inference and does not prove Apple's cache behavior.

Build 78 (iOS runtime `f5a5002`):

- Launch prewarm compiles every recorded recipe (limit 4096) on Apple devices with 6 GB
  or more of memory. Other devices keep 512. Memory evidence: build 77 peaked near
  840 MB with 552 pipelines; build 72 reached about 1085 MB with 436.
- Two background compile workers instead of one. Priority work is still taken first.
- Queued prewarm recipes are dropped only when first-use work alone reaches the queue
  cap, so menu first-use builds no longer discard the latest-used race recipes.
- Unexplained: course replay logged "N recorded, 0 queued" in every session. The full
  prewarm makes this path mostly redundant on large devices, but it still needs a
  diagnostic.

Installed in place over the running build 77, and the before/after user data manifests are
identical. Not yet played.


## iPad build 79 and Android code 224: launch graphics notice

The top-left overlay used to show only "N shaders compiling". While launch prewarm runs, it
now reads "Preparing graphics: X of Y" with a second line, "Racing before this finishes
may stutter". Afterwards it returns to the short compile count. The overlay is drawn
whenever the startup screen is hidden. This comes from the new
`aurora_get_pipeline_prewarm_progress` in both runtimes.

iOS also sets background prewarm workers to half of the compile workers (at least one),
and the course replay log now splits recorded recipes into queued, already built,
pending and rejected, to explain the earlier "0 queued" results.

Runtimes: iOS `f2d66d9`, Android `79f1db6`; root `77ed4b9`. Both passed their build
audits and contain the new string. Both were installed in place: the iPad's user data
manifests are identical, and the Pixel's first-install date is unchanged. Build 78 was never
launched, so it has no play data. Not yet played or seen on screen.


## Issue triage (26 September, afternoon)

- #321 (ROG Phone 7S): the reporter's log matches the earlier symbolized
  `vkCmdEndDebugUtilsLabelEXT` crash from the overlay's `PopDebugGroup`. The code 219+
  change removes debug labels from release command buffers. We replied that the fix
  ships in the next release.
- #131 and #323: a crash when leaving the last race of a cup for the trophy ceremony,
  seen on Android in both Original and Retro Rewind. Upstream patchzyy/Wiicompiled#106
  closed a matching Retro Rewind panic ("ARCInitHandle: bad archive format") as a mod bug.
  #131 reports Original too, so this is kept as a KartPad bug. It has no logs and needs a
  reproduction; the next step is a scripted Grand Prix finish on the Mac or an emulator.
- #195 (S25 Ultra): 60 FPS in Time Trials and about 41 in VS points to AI and item
  simulation cost (CPU). Acknowledged.
- #216: Retro Rewind now loads on the reporter's device. Acknowledged.
- #119 (status bar): already handled by `hideGameSystemBars()` on focus. It was not
  re-verified because the Pixel was in use.


## iPad build 79 session and build 80 (26 September, about 12:00 JST)

Chris played build 79 (Star Cup). He saw the cup-select screen locked at 20 FPS and
race dips to about 44-55 FPS.

Session `base_1790389436_pid5314`:
- Full prewarm compiled 1269 pipelines in 18.3 s. Every course replay then reported all
  recorded recipes already built (for example "214 recorded, 214 built").
- Race waits (273, 227 and 100 ms) were on recipes absent from both the build 72 and
  build 77 database snapshots. These were first-ever uses, likely new Star Cup content,
  so launch prewarm cannot cover them. The earlier build 77 class of waits (known
  recipes) did not recur.
- Cup select: about 1200 presents at exactly 50 ms (20 FPS) with no pipeline activity.
  This happened only in build 79. No other session, from build 60 through 77, has a
  20 FPS window. Physical footprint reached 2.2-2.45 GB there and settled at about
  1.52 GB, against about 0.84 GB for build 77: roughly 0.9 MB per retained pipeline. The
  inference is that memory pressure from retaining about 1300 pipelines caused the
  cup-select drop. The stranded-sleeper reconciler (50 ms sampling) was checked and
  logged no resumes.

Build 80 (iOS runtime `ea325f2`):
- Retains only the 512 earliest-use prewarmed pipelines, the same bound as build 77.
- Once per OS build (marker `pipeline_warm_os.txt` in the pipeline cache directory,
  keyed to the kern.osversion value and the GX config version), compiles the remaining
  recorded recipes to refill the system shader cache, then releases them. A recipe the
  game requests or waits on during warm-up is always retained, including one already
  held by a worker.
- The prewarm log reports whether the warm-up pass ran or was skipped.
- Installed in place with identical user data manifests. Not yet played.


## Pixel code 224 session and Android code 225 (26 September, about 12:10 JST)

Chris raced Original on the Pixel 9 Pro XL with code 224 and saw occasional dips. He saw
no shader notice.

Logcat (pid 3123, about 3 minutes):
- 57-60 FPS in five-second windows. Game CPU was 12.4-13.5 ms per present, with the main
  thread 70-80% occupied.
- 11 `KartPadPipelineWait` persistent waits of 8.6-23.6 ms. These are recipes outside
  the 128-recipe Android prewarm; several were the same hashes the iPad waited on. Waits
  are short because the Vulkan driver cache is warm.
- Worst frames of 42-70 ms occurred with no pipeline wait. `present_deadline_lateness`
  reached a maximum of 56 ms, which points to the game thread being late: a CPU spike on a
  budget already ~13 of 16.7 ms. There was no thermal throttling or device-lost event.
- The notice did not appear because Android's 128-recipe prewarm finished before gameplay.

Android code 225 (`0.5.1-review.6`, runtime `3f37a7c`, debug signer):
- Prewarms 512 recipes on phones with 6 GB or more of RAM (128 otherwise). Prewarm
  entries no longer count toward the first-use queue or sync caps.
- Adds `Long present interval` logging (gaps of 50 ms or more, at most once per second).
- Includes the Adreno-gated CPU vertex repack (`a4befb7`, off on the Mali Pixel; see
  [adreno-geometry-root-cause.md](adreno-geometry-root-cause.md)) and the crash and health
  logging additions (`5486906`, `f5699bd`; see
  [android-persistent-issues.md](android-persistent-issues.md)).
- Installed in place on the Pixel: first-install date unchanged, both games "Ready to
  play". Not yet played.


## Pass: expanded pipeline seed (iPad build 81, Android code 226)

No new play sessions or GitHub comments since build 80 and code 225.

- The bundled `initial_pipeline_cache.db` (shared by iOS and Android, merged into
  each device database on every launch) went from 1199 to 1332 recipes. The 133 added
  recipes come from the iPad's recorded database: Star Cup and other courses first raced
  today. All were validated by hash, config version and size, with none rejected. Seed
  metadata version 2 passes the integrity check. Existing players also receive the new
  recipes on their next launch.
- iOS: the warm-up marker now includes the seed version, so a new seed triggers one
  more warm-up on the same OS (runtime `056a7f5`).
- Runtimes: iOS `056a7f5` (seed commit `08a5d72`), Android `102c7a7`.
- iPad build 81 was installed in place with identical user data. Android code 226
  (`0.5.1-review.7`) was installed in place with the first-install date unchanged. Both
  packages contain the 1332-row seed. Neither has been played.


## Pixel code 226 Retro Rewind session and code 227 / iPad build 82

Chris raced Retro Rewind single player on code 226 and saw frequent dips, especially in the
first race.

Logcat (pid 13066): 16 `KartPadPipelineWait` persistent waits, 8 of them 50-178 ms
(for example 177.6, 149.8, 130.6 and 109.7 ms). They were clustered in the first minute
of the race. These are Retro Rewind track recipes never compiled on this phone, so seed
and prewarm cannot cover them. Pipelines created went from 676 to 695. After that the
race held about 60 FPS with game CPU at 11.2-13.4 ms per present.

Root cause of the stall class: each race frame copies the EFB to recurring targets, and
every copy pass requires all preceding draws' pipelines to be ready, so any first-use
shader in a race freezes the frame.

Change (Android `a5f504a`, iOS `3ce544d`): `aurora_set_race_copy_skip` is set true
when a course archive loads and false when a menu archive loads. From 120 frames after
race start, a GXCopyTex whose target was also produced in the previous frame is not
persistent, so an unready draw is skipped for that frame and the next frame redraws it.
This requires "Skip draws while shaders compile" (default on). Menus, one-shot bakes and
the first two seconds of each race remain strict. The expected visible effect is an
object missing for a frame or two in the effect copy, in place of a 50-300 ms freeze.
This has not been verified on a device.

Android code 227 (`0.5.1-review.8`) was installed in place on the Pixel with the
first-install date unchanged. iPad build 82 was installed in place with identical user
data. Neither has been played.


## Owner sessions on code 227 and iPad build 82, then code 228 and iPad build 84

**Pixel, code 227.** Offline single player and Grand Prix held about 60 FPS with no dips,
confirmed by Chris ("working way better now ... no dips at all"). Retro online connected,
but the game thread froze every ~5 s: 24 `KartPadNetStall socket_ioctlv command=12`
(IOCTLV_SO_RECVFROM) waits of 227-1196 ms.

**iPad, build 82 (Retro Rewind profile, `base_1790399397_pid5864`).** The warm-up pass ran
from cache: 1294 pipelines in 0.1 s. Memory peaked at 1.46 GB. Most windows held 60 FPS.
Four persistent waits (327, 77, 325, 100 ms) hit a Retro course never raced before (the
first scene visit recorded 0 recipes), in the menus and near race start. About 13
consecutive 50 ms presents still occurred on cup select, so the 20 FPS cadence did not
come from pipeline memory. The Pixel runs the same screen at full rate on a slower CPU,
which points to GPU or presentation on the iPad, which renders at 4x.

**Changes:**
- Race copies count as recurring when produced within four frames (previously one
  frame), because some effects refresh every other frame. Android `f7347f4`, iOS
  `5a0732f`.
- iOS logs presentation jobs of 30-250 ms (one per second) with their stage
  breakdown, to find the source of the cup-select 50 ms cadence (`5a0732f`).
- Deferred blocking TCP receive (see [deferred-recv.md](deferred-recv.md)): Android
  `c5ad680`, iOS `cbe43de`.

Android code 228 (`0.5.1-review.9`) and iPad build 84 were both installed in place with
data preserved. Neither has been played.

