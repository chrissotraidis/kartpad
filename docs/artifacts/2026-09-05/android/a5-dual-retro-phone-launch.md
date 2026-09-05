# Android A5 dual Retro phone-emulator launch

Date: 2026-09-05

Target: visible `KartPad_API_36_ARM64`, API 36, `arm64-v8a`, 4 KiB pages

## Falsifiable subgoal

From the production two-card selector, launch the retained validated Retro
Rewind 6.12.5 installation through a true dual-product APK and reach its
rendered title without a native abort. Preserve the existing tablet AVD and do
not publish the APK or any private input.

## Failure-driven corrections

The currently installed DNS-fixture APK contained only the base translated
product. Retro selection therefore failed closed with `selected profile is not
linked: retro_rewind`; its common exception cleanup then exposed a second bug
by calling the ImGui WebGPU shutdown backend before Aurora had initialized.
Aurora cleanup now returns safely when no ImGui context exists.

The first complete dual retry selected `retro_rewind`, initialized Vulkan and
audio, and loaded the translated registries, but correctly stopped because the
fresh AVD configuration did not name either runtime content root. The ordinary
game-data importer already owns relative `dvd_root = "GameData"`. The Retro
installer now atomically adds relative
`retro_rewind_root = "RetroRewind/RetroRewind6"` after successful activation,
and fails the worker closed if that durable configuration update fails. The
selector performs the same idempotent repair after validating an existing pack,
so an app update does not require reinstalling 6.12.5.

## Result

- The app-private Original `main.dol` and Retro `Code.pul` matched the accepted
  hashes before and after `adb install -r`.
- The dual runtime activated the `retro_rewind` mod and translated-function
  profiles, registered the canonical Retro overlay, and reached the branded
  Retro Rewind title with the production touch overlay.
- At the temporary 1280x720 performance size, the exact final APK held the
  title at approximately 34 FPS. The size override was then removed.
- At the AVD's native 2400x1080 metrics, the selector fits and retains the iOS
  48-point mark, 34-point title, 20-point tagline, 12/24-point spacing,
  equal 96-point cards, 18-point card spacing, colors, and content insets. The
  earlier clipped selector was caused by retaining 420 dpi while reducing the
  display to 1280x720, not by the production phone layout.
- The emulator was left visible at the installed production selector with
  about 3.35 GiB free. The storage-constrained tablet AVD was not modified.

The exact local-only dual debug APK is  
`9c20099ab98f04dfde1d83e16fcb229936ccf7d1a596dbb0b1245ad1aa5cb4c7`.

Fresh dual source preparation reproduced the shutdown patch. The 110-test
suite passes with one intentional skip, together with the strict APK/privacy
audit, repository safety audit, and whitespace check.

## Classification

**Pass for selector-to-validated-Retro launch and rendered title on the API 36
phone emulator, plus safe pre-Aurora failure cleanup and durable installer
runtime-path ownership.** This is not physical-device, performance, online,
matchmaking, race, or release-candidate acceptance. No APK/AAB or private data
was published.
