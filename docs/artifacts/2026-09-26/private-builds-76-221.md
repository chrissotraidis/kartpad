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

