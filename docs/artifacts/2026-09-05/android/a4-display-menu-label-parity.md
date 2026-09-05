# Android A4 Display menu label parity

## Scope

This checkpoint aligns Android's user-visible Display choices with the current
iOS wording. Aspect Ratio now presents `Original 4:3`, `16:9 (Experimental)`,
and `Fill Screen (Experimental)`. Render Resolution now presents
`1× (Native)`, `2×`, `3×`, and `4×`.

The underlying setting indices and native display bridge are unchanged.

## Emulator evidence

On the visible API 36 ARM64 Pixel 6, the real three-dot popup exposed Display,
then its real nested popup exposed Aspect Ratio and Render Resolution. Opening
each dialog through those menu rows showed all exact labels above; the default
render choice exposed `1× (Native)` as checked. Every row remained inside the
2400x1080 viewport.

## Build and audit

The complete translated Original/Retro runtime rebuilt locally. Its APK
SHA-256 is:

`3a14664a60a3f656a0f46e669ef575b9f2a67d0797c099fbb3e5f08bb9ce1934`

No APK/AAB or private artifact was published.

## Classification

**Pass for iOS-equivalent Display choice labels and real Pixel 6 menu
traversal.** This does not change or close physical rendering/performance
acceptance.
