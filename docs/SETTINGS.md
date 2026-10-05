# Mobile settings

Android and iPhone/iPad share this menu order (KartPad 0.7.10). Open **•••** (top right) while a game is running.

| Menu | Options, in order |
| --- | --- |
| Main | Return to KartPad Menu; Multiplayer; Show FPS Counter; Controls; Display; Game Data & Saves; Report a Problem |
| Controls | Controller Button Mapping; Touch Control Settings; Controller Player Setup; Motion Steering; Experimental Wii Remote + Nunchuk |
| Display | Aspect Ratio; Render Resolution; FPS Counter Size |
| Game Data & Saves | Player Identity; Time Trial Ghosts; Manage Saves; Manage Retro Rewind; Import or Reimport Wii Disc Image; Import from Extracted Folder; Remove Stored Game Data |

Android also has Android Graphics Diagnostics under Display. This is device-specific troubleshooting, not an Apple setting. Native file pickers and Retro Rewind installation workflows differ between platforms.

## Time Trial Ghosts

Open **Game Data & Saves → Time Trial Ghosts**. Choose the Original license and use the import/export actions for `.rkg` files. Imports are validated and applied at the next complete app restart. Importing replaces the downloaded comparison ghost, not the personal best. Pending imports apply to the latest save, preserving progress made before restarting; a backup is retained. Exports support personal-best and downloaded ghosts.

This release transfers ghosts from the Original game profile only. Retro Rewind ghost transfers are not implemented, including original Wii courses played inside Retro Rewind. If a file fails, report the app build, course and import/export step; do not post your full save or identity publicly.

## Controls and display

Controller Button Mapping supports D-pad directions and triggers, optional shared physical actions, and the Use L1 for Items preset. Controller Player Setup remains separate. Touch layout controls and motion steering remain available.

**Touch auto-accelerate** is under Controls → Touch Control Settings. OFF uses ordinary touch A press/hold/release; ON retains the one-second touch hold-to-latch behavior. The choice persists and does not change physical controller buttons.

Motion steering supports calibration and sensitivity. iPhone/iPad additionally offer shake-to-trick; Android currently has tilt steering only.

FPS Counter Size offers Small, Medium and Large on both platforms. Render Resolution can reduce GPU workload; it does not fix a CPU bottleneck or guarantee a faster race. Start with 1x Native on Android.

## Saves and reports

Player Identity contains license rename and Mii selection/repair. Save restore validates size/checksums, stages changes and preserves backups. Export first before destructive data management. Keep the existing app and signing identity when updating.

Report a Problem offers a reviewable diagnostic flow. The iPhone/iPad form scrolls and adapts to the keyboard. Android private diagnostic ZIPs may include bounded retained system crash/ANR traces; these are excluded from public issue metadata. Apple reports add lifecycle, thermal, memory and display context. More diagnostics help investigations; they do not establish that a crash or performance problem is fixed.
