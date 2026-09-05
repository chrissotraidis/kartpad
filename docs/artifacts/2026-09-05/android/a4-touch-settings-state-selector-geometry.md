# Android A4 touch-settings state and selector geometry

Date: 2026-09-05

## Outcome

Android now exercises the global Touch Control Settings widgets through a real
process restart, and the Original/Retro Rewind selector more closely follows
the current iOS `KartPadFirstLaunchViewController` geometry.

The selector uses the iOS 12-point spacing between mark, title, tagline, and
body, the iOS 24-point body-to-card spacing and card content insets, a 96-point
card height, 17-point body copy, and the iOS 18-point upward stack offset. A
KartPad-owned accessible button view centers each symbol together with its
two-line label instead of leaving Android compound drawables at the card edge.

The settings comparison also found a real default mismatch: Android selected
Fill Screen for a fresh preference store while iOS selects Original 4:3.
Android now defaults to Original 4:3; an existing user's stored choice is not
changed.

## Emulator evidence

- Visible API 36 Pixel 6: the settings flow selected 3x rendering, 64% opacity,
  120% global size, controls visible with a controller, and Modern C-stick,
  then force-stopped and verified those exact widget states in a new process.
- Visible API 36 Pixel Tablet: the same widget/process flow passed.
- The source-fixture JNI receiver observed `fps=true aspect=0 scale=3.0`, so
  the render choice crossed the same native display-settings call used by the
  translated runtime.
- The stricter selector raw-frame/accessibility gate passed at 2400x1080 and
  2560x1600. It now verifies the four iOS-derived vertical gaps, card height,
  and centered icon/label contents in addition to labels, colors, equal card
  geometry, mark size, and gradient direction.
- The rebuilt tablet card accepted an actual tap and logged
  `A3 mode chooser selected=base`.
- The final translated dual-runtime APK was installed on the visible tablet;
  its production selector rendered with the corrected composition.

Initial fixture attempts correctly exposed three harness gaps: the source
library lacked the display-settings JNI receiver, `CompoundButton.performClick`
can return false after toggling without a direct listener, and the SeekBar
two-argument setter's Boolean means animation rather than user input. The final
fixture uses a narrow source-only JNI receiver, verifies checked state, and
drives `ACTION_SET_PROGRESS` through accessibility.

## Verification

- Pixel 6 and Pixel Tablet settings process flows: pass.
- Pixel 6 and Pixel Tablet selector visual contracts: pass.
- Focused selector tap: pass.
- Python suite: 85 passed, one intentional skip.
- Android lint, strict APK/privacy audit, repository safety, shell syntax, and
  whitespace: pass.
- Final local-only translated APK SHA-256:
  `a221911feec75a9eb295fa418980635f8811fa64524269e7b7f610cf56391abe`.

## Classification

**Pass for global touch-setting widget persistence and iOS-derived selector
geometry on the canonical emulator phone/tablet lanes.** Physical-device
rendering, touch ergonomics, haptic feel, and touch-only races remain open. No
APK, AAB, private game data, screenshot, or log was published.
