# Android A4 Touch Control Settings visual contract

## Scope

This checkpoint makes the complete Android Touch Control Settings surface a
repeatable phone/tablet emulator gate. The debug/source-only fixture opens the
real production dialog over the normal touch overlay; its entry point is
disabled whenever the translated game runtime is present.

The verifier requires the iOS-parity settings and actions to be present in the
accessibility tree: 1x--4x render resolution, global opacity, global control
size, controller-triggered hiding, modern C-stick direction, layout editing,
per-device layout reset, and Done. It also requires every node to remain inside
the viewport, native 1x to be selected by default, and the landscape
composition to keep sliders on the left and actions on the right. The raw
capture header independently proves the expected RGBA dimensions.

## Emulator evidence

The visible API 36 ARM64 Pixel Tablet passed at 2560x1600:

```text
Android touch-settings visual contract passed: viewport=2560x1600 text=13 actions=7 columns=left-sliders/right-actions render=1x
```

The visible API 36 ARM64 Pixel 6 passed at 2400x1080:

```text
Android touch-settings visual contract passed: viewport=2400x1080 text=13 actions=7 columns=left-sliders/right-actions render=1x
```

The untracked local screenshots have SHA-256 values
`7a61a4aca45eb9d3067058f2883dbf2be3ac9641bacaf3cd72aad414f67ee879`
(tablet) and
`8aed621f35571bb35e18ecb21bfd8ad8f2c0c50b5c7f664e8c4a15fa04c51627`
(phone). They contain no private game content and were not added to Git.

The first tablet automation attempt found the dialog visibly complete but
could not obtain a hierarchy because rapid repeated `uiautomator dump` calls
on API 36 collided with an already-registered UiAutomation service. The final
runner uses bounded three-second retries; both canonical lanes then passed.

## Build and audit

The complete translated Original/Retro runtime rebuilt locally. Its APK
SHA-256 is:

`188c235d9a324a84e0fee38cc37ec192687741da4273616f83028a9ab5b8ff93`

No APK/AAB or private artifact was published.

## Classification

**Pass for complete Touch Control Settings visibility, viewport containment,
accessibility naming, default render selection, and two-column composition on
the canonical phone and tablet emulators.** This does not prove physical-device
font/vendor rendering, touch feel, or layout-editor ergonomics.
