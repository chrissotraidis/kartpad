# Android A4 selector, menu, and touch visual parity

## Scope

This checkpoint narrows three visible Android/iOS differences without claiming
physical-device acceptance:

- the launch selector now contains only the two iOS-equivalent Original and
  Retro Rewind cards;
- selecting either card with no installed game data opens the shared game-data
  manager and retains the selected profile for a successful return;
- the three-dot hierarchy uses KartPad-owned symbols for its top-level actions
  and sections on Android 10 and newer while retaining text/functionality on the
  Android 9 minimum;
- a raw-frame touch-overlay contract covers both accepted phone and tablet
  geometry, palette, safe bounds, grouped D-pad layout, and R sizing.

The iOS oracle was the current `KartPadFirstLaunchViewController`, menu rewrite,
and `SunPadGameOverlay` default-layout code. In particular, the accepted iPad
layout places Z left of X while the accepted iPhone layout places Z right of X;
the visual contract therefore requires a non-overlapping gap in either order.

## Visible emulator checks

One API 36 ARM64 Pixel Tablet emulator was kept visible throughout these checks.

- The 2560x1600 selector raw-frame contract passed with 742 px equal cards,
  exact `(8,125,255)` / `(245,56,99)` fills, and the expected diagonal gradient.
- With app data absent, the selector showed only the two enabled mode cards and
  the settled `Download 6.12.5 • Extra content + Retro WFC` subtitle. Tapping
  Mario Kart Wii opened the accessible **Game Data & Saves** screen.
- The source-only menu fixture displayed owned go-backward, multiplayer,
  speedometer, game-controller, display, folder, and report symbols. Opening
  **Controls** exposed Controller Player Setup, Controller Button Mapping,
  Touch Control Settings, Motion Steering, and Experimental Wii Remote +
  Nunchuk.
- The Pixel Tablet touch contract passed with all 14 accessible targets,
  212 px X/Z separation, a 560 px R pill, and the expected composited palette.
  The Pixel 6 lane had already passed the same contract at 2400x1080 with a
  32 px X/Z gap and equal 237 px L/R pills.

Screenshots, raw RGBA frames, and UI dumps remain local and untracked; none
contains private game data.

After the source-only checks, the final translated APK was installed in place
and its settled two-card selector was visibly rechecked on the same Pixel
Tablet.

## Build and audit

The complete translated Original/Retro Android runtime rebuilt locally. Its
APK SHA-256 is:

`5c0554814023e3cd80c035a5b2c21c882e2bfce511e2c780c817e6e53279eaf9`

Android lint, the 77-test Python suite with one intentional skip, repository
safety, strict package/privacy audit, and whitespace checks pass. The APK was
not published.

## Classification

**Pass for the canonical emulator selector flow, iconized consolidated menu,
and automated phone/tablet touch visual contracts.** Physical touch ergonomics,
haptics, vendor-device rendering, and touch-only race acceptance remain open.
