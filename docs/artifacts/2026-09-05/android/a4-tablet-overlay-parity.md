# Android A4 Pixel Tablet overlay parity

## Scope

This checkpoint starts from `d8bf406` and closes the emulator portion of the
tablet touch-layout gate. It does not claim physical tablet ergonomics, haptic
feel, thermal behavior, a touch-only race, or physical-device acceptance.

## Change

- Added a pinned API 36 ARM64 Pixel Tablet AVD alongside the existing Pixel 6
  and 16 KiB phone lanes.
- Ported the accepted iPad defaults instead of stretching the phone layout:
  the 172 dp move stick, 112 dp C-stick, 104 dp A, 76 dp B, 62 dp X/Y/Z,
  132 x 62 dp L, 280 x 62 dp R, 116 x 62 dp Start, and 48 dp D-pad cells use
  the same normalized centers as `SunPadGameOverlay.mm`.
- Kept saved normalized origins and per-control scaling authoritative and
  bounded every final control rectangle to the Android safe frame.
- Added a debug-only source-fixture switch that exposes the real overlay to UI
  Automator without packaging game data.
- Extended the cold-boot fixture to verify all 14 accessibility hit targets and
  require the tablet R target to be exactly 560 px wide at 320 dpi and wholly
  inside the 2560 px screen.

## Device proof

`./scripts/run-android-fixture.sh KartPad_API_36_TABLET_ARM64` passed on the
pinned Pixel Tablet profile:

- Android API 36, ARM64, 4 KiB pages;
- physical surface 2560 x 1600 at 320 dpi;
- 4 GiB guarded/aliased guest memory;
- two million scheduler operations and one million register-checked switches;
- SDL controller contract;
- Dawn/Vulkan readback and presentation;
- opposite-landscape surface recreation and three background/foreground
  recreations;
- 14 independently named accessibility targets;
- R bounds `[2000,950][2560,1075]`, width 560 px, fully in bounds.

The unchanged Pixel 6/API 36/4 KiB lane then passed the same memory,
scheduler/controller, Dawn/Vulkan, orientation, and three-cycle lifecycle
fixture, guarding the shared phone layout path against regression.

The source-only APK SHA-256 is
`25890fbfc3e43a247dc6ebfc6165db37a8ba857e374040229178f5c56219ae62`.
The final local screenshot SHA-256 is
`58b2ee10507c921bbfe0c51ef719ad158bb1b7619da193bf7b38e6f73550817a`;
it contains only the source fixture's solid surface and controls and remains
untracked at `/private/tmp/kartpad-android-pixel-tablet-touch-final.png`.

The same visible Pixel Tablet then opened the real launcher at 2560x1600. Its
responsive two-column composition retained the diagonal navy/purple/wine
background, orange mark, centered title stack, equal Original/Retro cards, and
subordinate Manage Game Data action without clipping. All expected labels were
present in the UI hierarchy. That local source-only selector capture has
SHA-256 `e3076df8bf399159fc05dd19d5afc016c3e01e3eaee263ccc21d82413bc1a66c`
and remains untracked at
`/private/tmp/kartpad-android-pixel-tablet-selector-final.png`.

The run also exposed and repaired two reproducibility defects rather than
weakening its checks: the standalone controller fixture still expected an
obsolete synthesized ZL bit, and the Pixel Tablet requires a different virtual
accelerometer axis than the naturally portrait Pixel 6 to reach reverse
landscape. The accepted mapping remains left shoulder to ZR and left trigger
to L.

## Classification

Pass for canonical Android-tablet default geometry, source-only visual review,
accessible hit-map coverage, safe-frame containment, Vulkan presentation, and
orientation/lifecycle behavior on the pinned emulator. Physical Android phone
and tablet touch-only races and hands-on ergonomics remain open.

No APK/AAB, private game content, save, raw log, device identifier, UI dump, or
screenshot was published.
