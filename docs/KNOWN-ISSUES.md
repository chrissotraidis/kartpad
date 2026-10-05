# KartPad known issues

Current for **KartPad 0.7.10** (5 October 2026). Each item links its GitHub
issue, where updates appear first. If your problem isn't here, see the
[reporting guide](REPORTING.md). The September evidence register is kept in
the [archive](archive/known-issues-through-2026-09.md).

## Setup and game data

- **KartPad asks for a "Wii common key".** That only happens with
  **Import or Reimport Wii Disc Image…**. Use **Import from Extracted Game Data
  Folder…** with a folder from Dolphin's **Extract Entire Disc** instead; it
  needs no key. Steps: [Android](INSTALL_ANDROID.md#2-make-your-game-data-folder),
  [iPhone/iPad](INSTALL_IPA.md#2-make-your-game-data-folder).
- **"Ready to play", then a black screen or a crash right after starting.**
  Usually the game data copy didn't finish (for example a folder half
  downloaded from a cloud drive). 0.7.10 checks every file and names the
  missing ones; copy the folder again and reimport. [#370](https://github.com/chrissotraidis/kartpad/issues/370)
- **Only PAL (Europe) RMCP01 revision 0 works.** USA, Japan and Korea discs
  aren't supported yet. [#203](https://github.com/chrissotraidis/kartpad/issues/203)

## Graphics (Android)

- **Snapdragon 8 Gen 3 and older Adreno GPUs** (Adreno 6xx and 7xx, for example
  Galaxy S24 Ultra and Moto G85): characters missing, white or washed out while
  tracks look fine. **Help → Character Graphics Test…** has workarounds that
  help on some phones; there's no automatic fix yet. [#104](https://github.com/chrissotraidis/kartpad/issues/104), [#301](https://github.com/chrissotraidis/kartpad/issues/301)
- **Snapdragon 8 Elite / Adreno 8xx:** fixed by **Automatic** in 0.7.10
  (confirmed on the OnePlus 15). If karts or item boxes go missing in Retro
  Rewind, choose **Experimental: fix broken characters** instead.
- **PowerVR GPUs** (for example Moto G54): the 3D scene breaks up. The cause is
  not found yet; 0.7.10's log ruled out the GPU's shader limit. [#304](https://github.com/chrissotraidis/kartpad/issues/304)
- **Moto G75:** crashes while loading the game; we need a diagnostic log.
  [#332](https://github.com/chrissotraidis/kartpad/issues/332)
- **AYN Thor:** black bars even with full screen. [#202](https://github.com/chrissotraidis/kartpad/issues/202)

## Graphics (Apple)

- **iPhone 16:** the screen flickers while the game starts, then plays
  normally. [#390](https://github.com/chrissotraidis/kartpad/issues/390)
- **Mac, two players:** characters drawn outside their karts. [#127](https://github.com/chrissotraidis/kartpad/issues/127)

## Performance

- **Short pauses** the first time a menu or course appears, while KartPad
  prepares its graphics. They get rarer the more you play.
- **Slow on mid-range and older phones**, and higher render resolutions cost a
  lot. Start at **1×**. The speed work is tracked in [#339](https://github.com/chrissotraidis/kartpad/issues/339).

## Controllers

- **Controllers that send nothing, or the wrong buttons:** 0.7.6 to 0.7.8
  fixed several cases (ipega and other "keyboard" gamepads, a controller left
  with no player). Still waiting on confirmation. [#378](https://github.com/chrissotraidis/kartpad/issues/378)
- **Single Joy-Cons** aren't supported. [#324](https://github.com/chrissotraidis/kartpad/issues/324)
- **Mac: Wii Remote with Classic Controller Pro** has input lag and no D-pad.
  [#306](https://github.com/chrissotraidis/kartpad/issues/306)

## Online

- **Finding a room fails on mobile data** (error 86420) while Wi-Fi works. Many
  carriers block the direct player-to-player connections the game uses; use
  Wi-Fi or a VPN. [#405](https://github.com/chrissotraidis/kartpad/issues/405)
- **Moving an online identity or rating** between devices doesn't fully work.
  [#234](https://github.com/chrissotraidis/kartpad/issues/234) More in [online status](ONLINE.md).

## Waiting for players to confirm

These have a fix or explanation and are open until someone affected confirms
it: the crash after the last race of a cup ([#131](https://github.com/chrissotraidis/kartpad/issues/131), no crash in automated
full cups on 0.7.10), the hourly update notice ([#377](https://github.com/chrissotraidis/kartpad/issues/377)), the iPad folder
picker ([#380](https://github.com/chrissotraidis/kartpad/issues/380)) and auto-hiding the ⋯ button ([#402](https://github.com/chrissotraidis/kartpad/issues/402)).

## Feature requests

Ghost import/export ([#295](https://github.com/chrissotraidis/kartpad/issues/295)), older iOS and macOS versions ([#300](https://github.com/chrissotraidis/kartpad/issues/300)),
AirPlay and external displays ([#100](https://github.com/chrissotraidis/kartpad/issues/100)), DSU controller apps ([#91](https://github.com/chrissotraidis/kartpad/issues/91)) and
Wiimmfi ([#90](https://github.com/chrissotraidis/kartpad/issues/90)). They're open, with no release planned yet.
