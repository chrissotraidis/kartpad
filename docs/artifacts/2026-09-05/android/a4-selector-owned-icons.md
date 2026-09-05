# Android A4 selector owned icons

## Scope

This checkpoint narrows the remaining visual difference between Android's game
selector and the current iOS selector. It does not claim pixel identity between
platform font renderers or physical-device acceptance.

## Change

The Android selector previously used legacy `android.R.drawable` assets. On the
Pixel Tablet those rendered as a small compass-like mark, a diamond direction
arrow for Original, and a platform-specific undo glyph. They did not match the
iOS selector source even though the surrounding gradient, hierarchy, colors,
cards, spacing, and copy already did.

Three KartPad-owned 48-point vector assets now provide the same visual language
as iOS:

- orange steering wheel above the KartPad title;
- checkered flag for Mario Kart Wii / Original;
- go-backward arrow for Retro Rewind.

The vectors are tintable, density independent, contain no third-party bitmap,
and no longer vary with the Android platform's legacy drawable set.

## Emulator proof

The source-only APK was installed on the visibly running pinned API 36 ARM64
Pixel Tablet emulator. At 2560x1600, the complete selector remained centered
and unclipped; UI Automator exposed the KartPad mark, title, tagline, explanatory
copy, both mode cards, recovery action, and status line with bounded rectangles.
The screenshot SHA-256 is
`d0b259f372e21151525229f31a07b67978cbd199866dee05036630a1a4d8c3c2`
and remains untracked at `/private/tmp/kartpad-selector-owned-icons.png`. The
source-only APK SHA-256 is
`283223fc48b6708b251cafb3b2d39c561e2ee760f17790b827b00da7220513fa`.

The complete translated dual-runtime APK then rebuilt successfully and passed
the strict package/privacy audit at SHA-256
`0d0dccc38878a9937a09d3b770dad16792654c1d5c86d72edafbd98710b778f7`.
The 74-test suite passes with one intentional skip; Android lint, repository
safety, and whitespace checks also pass.

## Classification

Pass for the owned selector iconography and visible emulator composition. The
disabled gray mode-card state in this source fixture is expected because the
wiped emulator contains no private RMCP01 game data; installed-data runs retain
the iOS-equivalent blue and pink card colors. No package, private data, UI dump,
or screenshot was published.
