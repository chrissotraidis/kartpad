# Android A4 menu large-text containment

Date: 2026-09-05

## Falsifiable subgoal

Keep every Android KartPad menu label readable and reachable at Android's 200%
system font scale on the native landscape phone viewport.

## Rejected first attempt

The initial implementation multiplied logical font scale while comparing it
with pixel row heights. The emulator screenshot proved the result wrong:
`Switch Game Version…` and `Game Data & Saves` wrapped but remained in 44 dp
rows, visibly clipping their second lines.

## Accepted implementation

- Each menu row now measures its title at the actual 16 sp pixel size and the
  precise available text width after icon, padding, checkmark, and chevron
  reservations.
- Rows expand to one or two measured line heights, with 44 dp retained as the
  minimum touch target.
- Labels are bounded to two lines with an end ellipsis. The existing card-level
  scrolling exposes rows that cannot fit simultaneously at enlarged text.
- SP conversion uses `TypedValue.applyDimension`, avoiding the deprecated
  `scaledDensity` field.
- The popup is dismissed on activity pause so a large scrollable menu cannot
  retain a stale window across lifecycle changes.

## Emulator evidence

At `font_scale=2.0` on the visible API 36 ARM64 phone:

- top-level wrapped rows expanded from 116 px to 253 px where required;
- the top card scrolled rather than vertically clipping labels;
- the Controls page exposed Controller Player Setup, Controller Button
  Mapping, Touch Control Settings, Motion Steering, and Experimental Wii
  Remote + Nunchuk across its top and bottom scroll positions;
- every visible long label retained both lines inside its row.

The previous exact dual APK was preserved before fixture installation. After
the test, Android font scale was restored to `1.0`, the newly built dual APK
was installed with `-r`, and the retained Retro Code.pul and save still matched
SHA-256 `622485319f…` and `708c7a040e…`. The selector remained active.

## Validation

- source-only fixture build: pass
- exact `KartPadDual` build: pass
- strict APK/privacy audit: pass
- repository suite: 110 pass, one intentional skip
- repository safety and whitespace: pass
- exact unpublished dual APK SHA-256:
  `bbb0d08deb58017bd68a354037b232d1449c77a54fa28c120baaae8e9cb659f4`

## Classification

**Pass for 200% font-scale menu containment and reachability on the API 36
phone emulator.** This is not TalkBack, switch-access, OEM font, tablet, or
physical-device acceptance. No APK/AAB was published.
