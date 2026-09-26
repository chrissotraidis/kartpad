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

