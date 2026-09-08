# iPad and iPhone physical acceptance

Native tvOS has its own controller, storage-recovery, and external-testing
matrix in [`docs/TVOS.md`](TVOS.md). Do not extend the iPhone/iPad results below
to Apple TV.

Earlier KartPad builds have physical execution acceptance on iPad and iPhone.
The [current iPhone/iPad preview](releases/v0.4.13-ios.1.md) needs its own pass.
The 0.3.0 iPad run also downloaded, verified, installed, launched, and played a
single-player match in Retro Rewind 6.12.4. This document is the repeatable
hardware-regression procedure for future builds. The public repository and IPA
contain no disc image, extracted game assets, saves, signing identity, or
provisioning profile.

## Historical 2026-09-02 Preview 4 candidate

The in-place iPad build-10 run accepted the revised menu and dual-mode
lifecycle. Retro Rewind launched, a physical controller connected and navigated
correctly, and the three-dot control retained its ellipsis/circular appearance
through use. After exiting and reopening KartPad, Original Mario Kart Wii
launched and the existing license remained selectable. This is physical
acceptance of that working-tree candidate, not a published-IPA claim. Folder
auto-detection still requires the external reporter's signed-container retest.
The later experimental-feature candidate was installed over the same bundle
without uninstalling; the complete 5,745-file, 4.8-GB Application Support/NAND
tree matched byte-for-byte before and after, and KartPad launched and remained
running. Actual `.mii` rendering and Wii Remote/Nunchuk hardware behavior remain
external acceptance gates.

## Before testing

- Record the exact candidate source/build and use your own supported PAL
  `RMCP01`, revision 0 WBFS/ISO in Files. Back up the installed state and update
  in place with the same signing identity; do not remove existing game data
  to simulate a clean first launch.
- Build the unsigned device app with `scripts/build-ios-device-game-app.sh`,
  then sign/install it locally with your Apple development team in Xcode.
- Start on iPad. Do not begin iPhone acceptance until the iPad run is closed.
- Pair at least one extended GameController-compatible controller; two are
  useful for checking stable multiplayer slots.

## Repeatable acceptance pass

1. **Clean first launch (separate test installation):** with no installed game
   data, choose the WBFS/ISO in the native picker. Confirm visible progress, successful extraction, and a
   same-session transition into the Mario Kart Wii title.
2. **Identity and persistence:** reach the title and a live race, close the
   app normally, relaunch, and confirm no second import is required and the
   existing save remains available.
3. **Touch:** steer, accelerate, brake/reverse, drift, use an item, pause, and
   navigate menus. Hold A for one second: it must turn cyan and keep accelerating
   after finger-up. Tap A again to unlock; opening a modal or handing off to a
   controller must clear the lock. Confirm compact R matches L.
4. **Three-dot menu:** open and dismiss the root menu by tapping outside and by
   choosing an action. Confirm the ellipsis never blanks and no square replaces
   the circular border. Open Controls, Display, Multiplayer, Game Data & Saves,
   Show FPS Counter, and Report a Problem. No held input may survive a modal.
5. **Controller handoff:** while touch controls are visible, connect or wake the
   first controller. It must take Player 1, clear touch state, and hide touch
   controls by default. Drive and navigate with it. Disconnect or sleep it;
   touch must return without stale steering or buttons.
6. **Multiplayer:** connect a second controller and verify the Multiplayer view
   reports stable Player 1 and Player 2 assignments. Disconnect/reconnect in a
   different order and confirm stale input clears while retained controllers
   keep their slots.
7. **Lifecycle:** background and foreground during title and race, rotate only
   through supported landscape orientations, and recover without a black frame,
   stuck audio, lost input, or save corruption.
8. **Device quality:** listen for clean audio; assess touch and motion feel;
   watch frame pacing through title, menus, and a representative twelve-racer
   course; note thermals, memory pressure, and battery behavior.
9. **Retro Rewind:** select Retro Rewind, confirm the official version check,
   install the matching official pack when needed, launch it, and reach a
   playable single-player match. When Retro WFC is available, test live online
   separately rather than treating the external outage as an install failure.
10. **Player identity:** open Game Data & Saves → Player Identity and rename
    the active Mii. Restart, then confirm the original-game and Retro Rewind
    licenses linked to that Mii show the new name while preserving their friend
    codes and progress. Appearance import remains experimental: import a
    standard 74-byte `.mii`, select it through License Settings → Change Mii,
    and confirm that removing only the imported entry leaves saves intact.

Direct Wii Remote/Nunchuk pairing is a separate macOS-only acceptance pass.
Record the remote revision, macOS version, pairing result, Nunchuk inputs,
disconnect/reconnect behavior, and bounded **Save Diagnostics Report…** output.

Run iPad and iPhone sequentially. Record the exact device class, OS version,
commit, executable hash, controller model, and any failure's bounded diagnostics
report without publishing device identifiers. Earlier physical execution is
recorded above; sustained performance, thermals, subjective audio, motion feel, and
broader controller/touch coverage remain narrower per-build gates.
