# Android A4 touch settings and KartPad menu checkpoint

Date: 2026-09-04

## Scope

This is an accepted emulator implementation checkpoint on
`codex/android-a4-touch-settings`. It accepts only the tested A4 slice below,
not feature-complete A4 or physical-device behavior.

The slice targets touch layout/settings parity and replacement of Android's
one-item overflow menu with KartPad's consolidated iOS hierarchy.

## Implemented in the working tree

- `KartPadTouchSettings` persists presentation, layout, controller-handoff,
  C-stick, FPS, aspect-ratio, and render-resolution choices app-privately.
- `KartPadOverlayView` supports editor selection, normalized drag persistence,
  per-control sizing and visibility, grouped D-pad editing, reset, and
  right-stick publication. The runtime patch writes right-stick state into
  both KPAD status formats.
- Touch settings expose opacity, all-control size, hide-on-controller, modern
  C-stick direction, Move Controls, and Reset This Device Layout. Back from
  the editor reopens the settings dialog.
- Z moved upward from normalized Y `0.43507883` to `0.410` and slightly inward
  from X `0.97125` to `0.969`, removing the nearly tangent X/Z placement in
  the supplied `2400x1080` screenshot.
- The overflow now has a disabled `KartPad` title plus Multiplayer, Show FPS
  Counter, Controls, Display, Game Data & Saves, and Report a Problem.
  Nested entries mirror the current iOS hierarchy.
- FPS, aspect ratio, and resolution use a JNI runtime bridge; Retro Rewind
  opens its existing installer; multiplayer reports the active profile and
  offers Retro setup; game-data status validates the Retro installation; and
  problem reporting opens Android sharing or KartPad's GitHub issue form with
  a bounded, path-free summary.
- Gravity motion steering matches iOS calibration, dead zone, sensitivity,
  direction inversion, touch-stick precedence, lifecycle clearing, persistence,
  and physical-controller priority. Custom controller remapping, Android game-
  data/save management, Mii management, and direct Wii Remote support remain
  unfinished and are disclosed in-product.

## Emulator evidence completed before pause

The preceding incremental APK was exercised in the visible standalone API 36
ARM64 emulator. Settings changed live; R and the grouped D-pad were moved and
resized; Hide/Show worked; layout and presentation choices persisted across
force-stop/relaunch; Reset restored defaults; and both hide-on-controller
policy states were exercised with a virtual controller.

Those runs predate the new Z coordinate, full menu, display JNI bridge, and
final reset-preservation correction. They do not accept the current tree.

## Accepted emulator evidence

- The exact local `KartPadDual` APK built successfully with SHA-256
  `ae96d3e2bcd340b64d9b76cb6a05059bef99b90b24ac7111d159b7d4e05f51e5`.
  It came from a fresh runtime preparation and new CMake directory; the dual
  build completed in 25m46s.
- The production selector displayed both Original and installed Retro Rewind
  6.12.5. Retro selection reached the branded title with separated X/Z buttons
  and the full top-level menu; the in-game switch returned to the selector.
- Controls, Display, and Game Data & Saves submenus rendered. FPS, 4:3/16:9/fill,
  resolution, touch settings/editor, multiplayer status, Retro manager, and the
  bounded report route were exercised in the exact-build sequence.
- Motion Steering rendered every action as an accessible Android button. The
  emulator gravity sensor registered as type 9. Acceleration injection produced
  neutral `0.0`, opposite values near `-0.30` and `+0.30`, and an inverted value
  near `+0.30` for the original negative tilt. Enabled/inverted/2.0x restored
  after a full process restart. The test left Off/standard/1.0x and neutral.
- The fresh artifact's own smoke repeated selector-to-Retro launch, opened the
  full motion sheet, registered gravity type 9, and produced approximately
  `-0.302` for an injected tilt without a fatal signal. It was again left Off
  with neutral gravity.
- Focused Android and Apple touch contracts passed: 18 tests. Android lint,
  the strict APK package/privacy audit, repository safety, all 462 unified-diff
  hunks across 53 patches, pinned sources/input, the unchanged iOS overlay
  snapshot, and `git diff --check` passed.

## Remaining A4 work

1. Implement custom controller remapping and one-to-four-player settings parity.
2. Implement Android game-data import/reimport/removal and save management.
3. Port Mii import/list/remove/create flows.
4. Add virtual accessibility nodes and canonical tablet layout acceptance.
5. Complete physical-phone/tablet touch, motion, haptic, controller, storage,
   performance and thermal acceptance.

No APK, AAB, private game content, save, trace, or screenshot was published.
