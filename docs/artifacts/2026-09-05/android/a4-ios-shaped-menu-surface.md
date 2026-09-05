# Android A4 iOS-shaped menu surface

Date: 2026-09-05

## Falsifiable subgoal

Replace Android's narrow platform `PopupMenu` with a KartPad-owned landscape
surface that visually follows the current iOS hierarchy, while keeping every
existing Android action reachable and functional.

## Implementation

- The menu is now a right-anchored, rounded, light card with a compact KartPad
  header, dark system-style icons, row separators, an FPS checkmark, and
  chevrons for nested sections.
- Controls, Display, and Game Data & Saves open as compact replacement pages
  with a working back header instead of platform-dependent cascading popups.
- The card height is bounded by the current display and its content scrolls,
  so the complete hierarchy remains reachable on the native 2400x1080 phone
  viewport.
- Opening the menu still clears all active touch owners before presenting UI.
  Existing actions and their privacy/storage boundaries are unchanged.
- The emulator walker no longer clears the shared app package. It derives the
  expected FPS toggle from retained preferences and accepts either populated or
  empty Mii state, so menu validation does not delete imported game content.

## Emulator result

The visible API 36 ARM64 phone AVD rendered the top-level card and the complete
Controls replacement page at native 2400x1080. The automated menu walker then
reached all eight title/top-level rows, five Controls actions, two Display
actions, six Game Data & Saves actions, and all 16 action destinations.

The legacy walker's package reset removed retained emulator state during the
first run. The already-approved 6.12.5 pack and prior empty save were restored
directly into app-private storage, then verified byte-for-byte at Code.pul
SHA-256 `622485319f…`, version SHA-256 `671c8a9299…`, and save SHA-256
`708c7a040e…`. The visible selector again reports **Installed 6.12.5**. No
private data was copied into public device storage.

## Validation

- `scripts/test-android-menu-parity.sh phone`: pass
- fixture APK compilation: pass
- repository unit suite: 110 pass, one intentional skip
- changed shell script lint/syntax and whitespace: pass
- exact local `KartPadDual` debug APK audit: pass, SHA-256
  `898a03bed41a95af41537f626ffee6928b609aec397bde7643cdc48c136517d7`

## Classification

**Pass for iOS-shaped Android menu presentation and complete phone-emulator
reachability.** This is not physical-device visual, accessibility-service,
font-scale, or OEM-windowing acceptance. No APK/AAB or private artifact was
published.
