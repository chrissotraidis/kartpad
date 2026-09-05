# Android A4 menu hierarchy reachability

Date: 2026-09-05

## Outcome

A new source-only emulator gate opens the real Android three-dot menu and then
independently traverses each submenu. It prevents a row that exists in source
but is missing or unreachable in the rendered `PopupMenu` from being counted
as parity.

The gate requires:

- eight top-level rows: KartPad, Switch Game Version, Multiplayer, FPS,
  Controls, Display, Game Data & Saves, and Report a Problem;
- five Controls rows: player setup, button mapping, touch settings, motion
  steering, and the explicit Wii Remote + Nunchuk platform boundary;
- two Display rows: aspect ratio and render resolution; and
- six Game Data & Saves rows: disc import, extracted-folder import, removal,
  Retro Rewind, saves, and Miis.

It then starts from a fresh real menu for each of 16 action checks and requires
the destination UI for switching game version, Multiplayer, reporting,
controller mapping (including a real scroll to its lower actions), touch
settings, motion steering, the Wii Remote platform boundary, both Display
dialogs, game-data removal, saves, Miis, and Retro Rewind management. On an
empty source fixture the Mii route must show its exact first-run database
boundary instead of pretending that an initialized Mii database exists.
Disc-image import must expose the source build's explicit no-DiscIO boundary,
while extracted-folder import must reach Android DocumentsUI. Neither check
selects or imports a file.
The FPS row is activated from a cleared preference store and must persist
`show_fps=false`, proving that the checkmark is wired to state rather than only
drawn.

The menu now also uses KartPad-owned semantic equivalents of the current iOS
symbols instead of recycling unrelated icons: hand for touch settings,
gyroscope for motion steering, antenna for Wii Remote, circular arrows for
game-data import, trash for removal, and person-plus for Mii management. The
gate requires all 7 actionable top-level icons plus 5 Controls, 2 Display, and
6 data-submenu icons to exist in the rendered hierarchy.

## Emulator evidence

The visible API 36 Pixel Tablet and Pixel 6 both passed the complete real-menu
traversal:

`Android menu parity passed: lane=<lane> top=8 controls=5 display=2 data=6 actions=16`

This is 21 reachable rows across the consolidated hierarchy plus 16 routed
destinations. The fixture is gated out of translated game-runtime builds and
uses no private data.

The complete translated runtime rebuilt at APK SHA-256
`a5310650f970ea45ea26d7414392215fb7912915bc601401df162c9c23d4093f`.
The strict package/privacy audit, Android lint, and 86-test suite with one
intentional skip pass.

## Classification

**Pass for rendered menu hierarchy/icon reachability and 16 representative
action routes on the canonical emulator phone/tablet lanes.** The gate does
not claim that physical-device dialogs, external Android pickers, controllers,
or haptics have been accepted.
