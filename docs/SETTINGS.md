# Mobile settings

Android and iPhone/iPad use the same hierarchy for shared controls. The table describes 0.8.7. Open **•••** (top right) while a game is running.

| Menu | Options, in order |
| --- | --- |
| Main | Return to KartPad Menu; Multiplayer; Controls; Display; Graphics & Performance (Android); Sound; Game Data & Saves; Report a Problem |
| Controls | Controller Button Mapping; Touch Control Settings; Controller Player Setup; Shake to Trick; Motion Steering; Experimental Wii Remote + Nunchuk |
| Display | Show FPS Counter; FPS Counter Size; Aspect Ratio; Render Resolution; Disable Bloom; App Icon |
| Graphics & Performance (Android) | Graphics Engine; 30 FPS Races; Simpler Computer Karts; GPU Driver (Snapdragon); Graphics Diagnostics |
| Game Data & Saves | Player Identity; Time Trial Ghosts; Manage Saves; Manage Retro Rewind; Import or Reimport Wii Disc Image; Import from Extracted Folder; Remove Stored Game Data |

On Android, on/off settings show a switch and a one-line description, and tapping one flips it without leaving the menu; settings with choices show the current choice under their name. Graphics & Performance holds Android-only options. The Mac has its own layout: the menu bar and **KartPad → Settings…** (Graphics, Audio, Controllers, Game & Data, Advanced). It has no touch, motion or Android-only options, and it has no in-app save backup, ghost transfer or soundtrack import. On Mac, **Data → Show KartPad Data** opens `~/Library/Application Support/KartPad`, where settings and Original saves live, and soundtrack files go in Retro Rewind's `MyStuff` folder (see below and the [Mac install guide](INSTALL_MACOS.md)). Native file pickers and Retro Rewind installation workflows differ between platforms.

## Time Trial Ghosts

Open **Game Data & Saves → Time Trial Ghosts**. Choose the Original license and use the import/export actions for `.rkg` files. Imports are validated and applied at the next complete app restart. Importing replaces the downloaded comparison ghost, not the personal best. Pending imports apply to the latest save, preserving progress made before restarting; a backup is retained. Exports support personal-best and downloaded ghosts.

Since 0.7.15, a compressed import expands a validated `.rkg` into the native comparison slot before replay. Exporting that imported ghost therefore produces an uncompressed 10,240-byte file with the same recorded inputs, rather than the original compressed file bytes. Ghosts imported by older builds need to be imported again from their source file to receive this correction; existing saves are not automatically rewritten.

This release transfers ghosts from the Original game profile only. Retro Rewind ghost transfers are not implemented, including original Wii courses played inside Retro Rewind. If a file fails, report the app build, course and import/export step; do not post your full save or identity publicly.

## Retro Rewind music

Retro Rewind soundtrack packs work from 0.8.4. Each track is a `.brstm` file named like one in Retro Rewind's own `strm` folder, for example `104_N.brstm` and `104_F.brstm` for that track's final lap. A file with that name replaces the track; the others keep Retro Rewind's music. Changes apply the next time KartPad starts, and your music stays when Retro Rewind updates. [#441](https://github.com/chrissotraidis/kartpad/issues/441)

- **Android and iPhone/iPad:** **Game Data & Saves → Retro Rewind Music… → Add Music…**, then choose `.brstm` files or a pack's `.zip`. **Remove All** goes back to Retro Rewind's music.
- **Mac:** put the files in the `MyStuff` folder inside the `RetroRewind6` folder you chose for KartPad, as you would for Dolphin.

## Controls and display

Controller Button Mapping supports D-pad directions and triggers, optional shared physical actions, and the Use L1 for Items preset. Controller Player Setup remains separate. Touch layout controls and motion steering remain available.

**Rumble** (Android, from 0.8.4) is in Controller Button Mapping and is on by default. A controller with its own motor rumbles; when player one's controller has none, such as a handheld's built-in controls, the device vibrates instead. Touch-only play does not vibrate.

**Android controller mapping:** L3 and R3 stick clicks are available as physical buttons. Assign **D-pad Up — Trick / Wheelie**, or choose **Use L3 for Tricks**. **Rumble strength** runs from 0% to 200%; 100% is standard strength. It scales controller motors and handheld device vibration where amplitude control is supported.

**Touch auto-accelerate** is under Controls → Touch Control Settings. OFF uses ordinary touch A press/hold/release; ON retains the one-second touch hold-to-latch behavior. The choice persists and does not change physical controller buttons.

**Touch item hold** (Android and iPhone/iPad) is beside it and off by default. With it on, holding touch L for 0.67 seconds keeps the item held behind your kart after you lift your finger, so you can steer and drift while trailing a shell or banana; L turns blue. Press L again to let go. Opening the menu or leaving the game lets go too. [#473](https://github.com/chrissotraidis/kartpad/issues/473)

Motion steering supports calibration and sensitivity. **Controls → Shake to Trick…** is a separate option on Android and iPhone/iPad, off by default. It sends D-pad Up for tricks in the air and wheelies on bikes; tilt steering can stay off. Physical controllers take priority. If the device has no supported motion sensor, the option explains that D-pad Up is still available. Mac and Apple TV do not offer handset shake input.

FPS Counter Size offers Small, Medium and Large on both platforms. Render Resolution can reduce GPU workload; it does not fix a CPU bottleneck or guarantee a faster race. Start with 1x Native on Android.

**Disable Bloom** (Android and iPhone/iPad, from 0.8.7) is under **Display**. It removes the glow around bright areas when the next scene loads and keeps that choice after restarting KartPad. Bloom stays enabled by default. Mac already offers the same setting under **KartPad → Settings… → Graphics** (also **Game → Game Settings…**).

## Saves and reports

Player Identity contains license rename and Mii selection/repair. Save restore validates size/checksums, stages changes and preserves backups. Export first before destructive data management. Keep the existing app and signing identity when updating.

Report a Problem offers a reviewable diagnostic flow. The iPhone/iPad form scrolls and adapts to the keyboard. Android private diagnostic ZIPs may include bounded retained system crash/ANR traces; these are excluded from public issue metadata. Apple reports add lifecycle, thermal, memory and display context. More diagnostics help investigations; they do not establish that a crash or performance problem is fixed.
