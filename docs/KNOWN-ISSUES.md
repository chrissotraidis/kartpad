# KartPad known issues

Reviewed for **KartPad 0.7.14** (7 October 2026). Each item links its GitHub
issue, where updates appear first. If your problem isn't here, see the
[reporting guide](REPORTING.md). The September evidence register is kept in
the [archive](archive/known-issues-through-2026-09.md). Engineering order and
acceptance gates are on the [bug-fix priority board](MAINTENANCE-BOARD.md).

## Setup and game data

- **KartPad asks for a "Wii common key".** That only happens with
  **Import or Reimport Wii Disc Image…**. Use **Import from Extracted Game Data
  Folder…** with a folder from Dolphin's **Extract Entire Disc** instead (or,
  on Android 0.7.11, **Import Game Data Zip…**); it needs no key. Steps:
  [Android](INSTALL_ANDROID.md#2-make-your-game-data-folder),
  [iPhone/iPad](INSTALL_IPA.md#2-make-your-game-data-folder).
- **"Ready to play", then "The game stopped because the game data is
  incomplete" (often naming a movie such as `thp/title/title_SD_50.thp`).**
  The game data copy didn't finish, for example a folder only partly
  downloaded from iCloud Drive or another cloud drive. Make sure the whole
  folder is downloaded (in Files or Finder: **Download Now**), copy it again
  and reimport. From 0.7.14, KartPad checks every file when you
  import and on the game chooser, so this shows up there with the file's name
  instead of after you press Play. [#370](https://github.com/chrissotraidis/kartpad/issues/370)
- **Android, fixed in 0.7.13: "The game stopped because DVD data is
  unavailable" the first time you play Retro Rewind right after downloading
  it.** Starting it again worked. Before 0.7.13, the download left the game
  with settings read before KartPad set them up.
- **Only PAL (Europe) RMCP01 revision 0 works.** USA, Japan and Korea discs
  aren't supported yet. [#203](https://github.com/chrissotraidis/kartpad/issues/203)

## Graphics (Android)

- **Snapdragon 8 Gen 3 and older Adreno GPUs** (Adreno 6xx and 7xx, for example
  Galaxy S24 Ultra and Moto G85): characters missing, white or washed out while
  tracks look fine. **Help → Character Graphics Test…** has workarounds that
  help on some phones; there's no automatic fix yet. [#104](https://github.com/chrissotraidis/kartpad/issues/104), [#301](https://github.com/chrissotraidis/kartpad/issues/301)
  From 0.7.12, **Report a Problem** logs include a draw self-check. The retained
  Galaxy S24 Ultra and Moto G85 results do **not** rule out the vertex path or
  establish bone lookup as the root cause: empty draws are inconclusive, and
  a different image need not be correct. Existing logs are sufficient for the
  next investigation; no repeated capture or settings sweep is needed.
- **Snapdragon 8 Elite / Adreno 8xx:** fixed by **Automatic** in 0.7.10
  (confirmed on the OnePlus 15). If karts or item boxes go missing in Retro
  Rewind, choose **Experimental: fix broken characters** instead.
- **PowerVR GPUs** (for example Moto G54): the 3D scene breaks up. The cause is
  not found yet. The earlier shader-limit repair and 0.7.14 draw comparisons
  do not establish correct gameplay; a different comparison image is not a fix. [#304](https://github.com/chrissotraidis/kartpad/issues/304)
- **Moto G75:** crashes while loading the game; we need a diagnostic log.
  [#332](https://github.com/chrissotraidis/kartpad/issues/332)
- **AYN Thor:** black bars even with full screen. [#202](https://github.com/chrissotraidis/kartpad/issues/202)

## Graphics (Apple)

- **iPhone 16 and iPad Air 4th gen:** the screen flickers while the game
  starts, then plays normally. The game image and FPS panel disappear while
  touch buttons remain; presentation is under investigation. Refresh rate has
  not been established as the cause. [#390](https://github.com/chrissotraidis/kartpad/issues/390)
- **Mac, two players:** characters drawn outside their karts. [#127](https://github.com/chrissotraidis/kartpad/issues/127)

## Performance

- **Short pauses** the first time a menu or course appears, while KartPad
  prepares its graphics. They get rarer the more you play.
- **Slow on mid-range and older phones**, and higher render resolutions cost a
  lot in GPU-limited scenes. Several race reports remain slow even at minimum
  resolution, so reducing resolution is not a general cure. CPU frame time and
  stutter work are tracked in [#339](https://github.com/chrissotraidis/kartpad/issues/339).

## Controllers

- **Controllers that send nothing, or the wrong buttons:** 0.7.6 to 0.7.8
  fixed several cases (ipega and other "keyboard" gamepads, a controller left
  with no player). Still waiting on confirmation. [#378](https://github.com/chrissotraidis/kartpad/issues/378)
- **Single Joy-Cons:** input changes shipped in 0.5.3, but actual single-controller
  operation is still unconfirmed. [#324](https://github.com/chrissotraidis/kartpad/issues/324)
- **Mac: Wii Remote with Classic Controller Pro** has input lag and no D-pad.
  [#306](https://github.com/chrissotraidis/kartpad/issues/306)

## Online

- **Finding a room fails on mobile data** (error 86420) while Wi-Fi works. Many
  carrier/network paths can restrict direct player-to-player connections; the
  reporter uses a VPN as a workaround. This report does not prove the carrier's
  exact NAT configuration or establish an app-side fix. [#405](https://github.com/chrissotraidis/kartpad/issues/405)
- **Restoring an online identity or rating** can be incomplete even on the same
  phone: raw-save/rating backups may omit Mii, country and console-identity state.
  [#234](https://github.com/chrissotraidis/kartpad/issues/234) More in [online status](ONLINE.md).

## Waiting for players to confirm

These have a fix or explanation and are open until someone affected confirms
it: the crash after the last race of a cup ([#131](https://github.com/chrissotraidis/kartpad/issues/131), no crash in automated
full cups on 0.7.10), the first next-release Android self-update from 0.7.14
([#377](https://github.com/chrissotraidis/kartpad/issues/377)) and the iPad folder
picker ([#380](https://github.com/chrissotraidis/kartpad/issues/380)).

Auto-hiding the ⋯ button in DeX is now reporter-confirmed
([#402](https://github.com/chrissotraidis/kartpad/issues/402#issuecomment-5994763404)).
The closed vivo launch report also now has a positive gameplay result, with poor
speed still reported ([#200](https://github.com/chrissotraidis/kartpad/issues/200#issuecomment-6012081573)).

## Feature requests

Separate music and game-sound volume, including muting the game to play your
own music ([#411](https://github.com/chrissotraidis/kartpad/issues/411)), shipped
on Android in 0.7.14 under ••• → **Sound…**. The iPhone/iPad change remains in
#420/#416 with physical audio acceptance open. On the Mac it's already in
**Game → Game Settings… → Audio**.

Optional **Controls → Shake to Trick…** ([#430](https://github.com/chrissotraidis/kartpad/issues/430))
is in draft #435/#416, not released. Physical gesture and in-race checks remain open.

Retro ghost transfer ([#295](https://github.com/chrissotraidis/kartpad/issues/295);
Original export is already confirmed), older iOS and macOS versions ([#300](https://github.com/chrissotraidis/kartpad/issues/300)),
AirPlay and external displays ([#100](https://github.com/chrissotraidis/kartpad/issues/100)), DSU controller apps ([#91](https://github.com/chrissotraidis/kartpad/issues/91)) and
Wiimmfi ([#90](https://github.com/chrissotraidis/kartpad/issues/90)). They're open, with no release planned yet.
