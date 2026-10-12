# #131 cup ceremony harness and results

Date: 2026-10-04. Runtime: KartPad 0.7.10 (Android runtime `3e13d6e` plus this
harness). Emulator: `KartPad079_FreshImport`, Android 16, run `-read-only` so
nothing persists.

## Question

Does the game crash after the last race of a Grand Prix, on the way into the
ending (#131: POCO X8 Pro, 0.4.12, 3x render resolution, Original and Retro)?

## Harness (debug builds and test environment only)

It extends the RKG replay fixture from
[2026-09-03](../../2026-09-03/android/a2-debug-input-replay.md):

- `files/KartPad/Diagnostics/TestInput.finish-frames` holds a frame count, for
  example `420`, optionally followed by `first`. A debug build then sets
  `KARTPAD_RKG_FORCE_FINISH_V2`, `..._FRAME_V2` and
  `..._EACH_RACE_V2`, and `..._FIRST_V2` for `first`.
- Each race, the fixture drives from the countdown and finishes the local racer
  through the game's own finish call after that many frames. It then hands
  input back to the menus and arms again at the next countdown, for the four
  races of a cup. The ending scenes also have a countdown, so it stops arming
  after four races.
- `first` records the finish as 1st (race progress set to a full race) so
  the cup reaches the trophy ceremony instead of the no-trophy ending.
- Menus are driven by tapping the on-screen A button every 2.5 s
  (`adb shell input tap`).

Release builds never read these variables. No RKG, game data or save is
committed.

## Results

| Run | Render resolution | Placement | Ending | Result |
| --- | --- | --- | --- | --- |
| 1 | 1x | 12th each race | `loser_demo.szs` + `Award.szs` ("Better luck next time") | Ending loaded, no crash (the fixture re-armed in the ending; fixed before run 2) |
| 2 | 1x | Forced 1st | `winningrun_demo.szs` + `Award.szs` (trophy) | Ceremony played, returned to the menus in the same process |
| 3 | 3x | Forced 1st | Trophy ceremony | Played at about 8 FPS, returned to the menus in the same process |

Mushroom Cup, 50cc, Original (base) profile. Not covered: Retro Rewind cups, a
real phone, other cups.

## Conclusion

On 0.7.10's runtime the transition after the last race and both endings work
on the emulator, including at 3x. #131 was reported on 0.4.12; it needs a
retest on a current version by an affected player.
