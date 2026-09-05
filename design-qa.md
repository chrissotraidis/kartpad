# Android selector design QA

final result: passed

## Target

The target is KartPad's production iOS first-launch selector implemented in
`apple/ios/KartPadRuntimeOverlayHost.mm`: diagonal navy/purple/wine background,
orange steering mark, centered white title/tagline/message, and equal blue and
pink rounded cards with leading mode icons and title/subtitle hierarchy.

## Compared render

Android API 36 ARM64 emulator, 2400x1080 landscape, final screenshot:
`/private/tmp/kartpad-android-selector-ios-parity-final.png`.

## Result

- P0: none.
- P1: none. Both mode cards are fully visible, readable, enabled, and retain
  their Original/Retro behavior.
- P2: none. The background direction/colors, content width, card geometry,
  spacing, typographic hierarchy, and blue/pink mode distinction match the iOS
  composition at the Android viewport.
- P3: Android uses the closest platform-provided compass/directions glyphs in
  place of iOS-only SF Symbols. Manage Game Data remains as a small subordinate
  recovery action beneath the cards; iOS exposes recovery elsewhere.

The final emulator hierarchy also confirms that both mode cards and the recovery
action retain accessible labels and bounds.
