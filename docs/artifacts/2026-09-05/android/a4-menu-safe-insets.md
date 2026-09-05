# Android A4 menu system-bar and cutout safety

Date: 2026-09-05

## Falsifiable subgoal

Keep KartPad's three-dot trigger and complete iOS-shaped menu card outside the
status-bar, navigation-bar, and display-cutout safe regions on the native
landscape phone viewport.

## Rejected first placement

The prior fixed 8 dp trigger margin and 60 dp popup offset did not account for
modern Android's transient system bars. On the API 36 phone, the status icons
could occupy the same top-right strip as the trigger. Moving the card below the
safe trigger removed the collision but reduced the short landscape viewport
enough to hide `Report a Problem…`; the existing complete-menu walker rejected
that attempt.

The first two-orientation test launched the menu only after each rotation. A
live rotation with the card already open then exposed stale popup geometry: the
card stopped at x=2272 against the new right cutout instead of retaining its
12 dp margin. That intermediate result was also rejected.

## Accepted implementation

- API 30 and newer use `getInsetsIgnoringVisibility` for system bars plus the
  display cutout, so a temporarily hidden status bar still reserves its safe
  region.
- API 28 and 29 use the maximum stable, visible-system, and display-cutout
  insets on each relevant edge.
- The trigger adds its normal 8 dp top and 12 dp end margins inside those safe
  bounds.
- The open card begins 8 dp below the safe top and intentionally covers its
  trigger. Its maximum height also reserves the safe bottom and another 16 dp,
  preserving the full iOS-sized card on a short landscape phone.
- Configuration changes dismiss the transient card, neutralize touch input,
  and request fresh trigger insets. An inset-edge change also dismisses the
  card because opposite landscape can change only the cutout edge while the
  resource orientation remains `landscape` and therefore produces no Android
  configuration callback.

## Emulator evidence

On the visible API 36 ARM64 phone at native 2400x1080 and `font_scale=1.0`:

- WindowManager reported a 63 px top status zone and a 63 px bottom navigation
  zone, with bottom navigation beginning at y=1017.
- The rendered KartPad card bounds were `[1528,84][2368,975]`: 21 px below the
  top safe boundary and 42 px above bottom navigation.
- The final row bounds were `[1652,886][2342,975]`, proving that
  `Report a Problem…` remained fully present rather than being clipped.
- The full menu walker passed 8 title/top rows, 5 Controls rows, 2 Display rows,
  6 Game Data rows, and all 16 action destinations.
- A window-manager rotation lock could not drive the sensor-landscape activity,
  but emulator accelerometer input did. At rotation 3 the 128 px cutout moved
  to the right/menu edge and the card moved left exactly 128 px, from
  `[1528,84][2368,975]` to `[1400,84][2240,975]`.
- The menu walker now repeats that opposite-landscape check automatically and
  requires the card to remain below status, left of the right cutout, and above
  navigation before restoring the canonical orientation.
- The stronger walker first rotates while the menu is open. It requires the
  stale card to disappear and the trigger to move to
  `[2124,84][2240,200]`; reopening then produces the correctly inset card at
  `[1400,84][2240,975]`.

## Validation and restoration

- source-only fixture build: pass
- complete phone menu/action walker: pass
- exact `KartPadDual` build: pass
- strict APK/privacy audit: pass
- repository suite: 110 pass, one intentional skip
- repository safety and whitespace checks: pass
- exact unpublished dual APK SHA-256:
  `ab10b1e9bbd201ad2866d4f9b92d3349db2e541d32b9437f68504eb560b547d6`

The exact dual APK was reinstalled with `-r`. The retained Retro `Code.pul`,
version marker, and save still matched SHA-256 `622485319f…`, `671c8a9299…`,
and `708c7a040e…`; the selector again showed **Installed 6.12.5**. Temporary
APK and screenshots were moved to Trash.

## Classification

**Pass for system-bar/cutout-safe trigger/card layout in both landscape
orientations and complete action reachability on the API 36 phone emulator.**
OEM cutouts, foldables, multi-window, and physical-device acceptance remain
open. No APK/AAB was published.
