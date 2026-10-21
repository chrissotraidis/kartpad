# KartPad known issues

Current for **KartPad 0.8.1** (15 October 2026). Each item links its GitHub
issue, where updates appear first. If your problem isn't here, see the
[reporting guide](REPORTING.md). The September evidence register is kept in
the [archive](archive/known-issues-through-2026-09.md).

## Setup and game data

- **Mac build stops at `CERTIFICATE_VERIFY_FAILED` before compiling.** A
  secure download failed its certificate check. The 0.8.1 recipe could switch
  from PadMint's own Python to another one on PATH during setup; 0.8.3 keeps
  PadMint's Python. The cause on the reporting Mac isn't confirmed. Keep
  certificate checks on. [#475](https://github.com/chrissotraidis/kartpad/issues/475)
- **KartPad says "Game Data Import Failed" or asks for a "Wii common key".**
  You selected a disc image (ISO or WBFS). On iPhone and iPad the dialog tells
  you to save `common-key.bin` in **On My iPhone/iPad → KartPad** and import
  the disc again. You do not need that key. Choose **Import from Extracted
  Folder…** (on Android, **Import from Extracted Game Data Folder…**, or **Use
  Extracted Folder…** on the **Disc Images Need Your Wii's Key** dialog) with
  a folder from Dolphin's **Extract Entire Disc**. A zip of that folder also
  works (**Import Game Data Zip…** on Android 0.7.11 and newer). Steps:
  [Android](INSTALL_ANDROID.md#2-make-your-game-data-folder),
  [iPhone/iPad](INSTALL_IPA.md#2-make-your-game-data-folder).
- **"Ready to play", then "The game stopped because the game data is
  incomplete" (often naming a movie such as `thp/title/title_SD_50.thp`).**
  The game data copy didn't finish, for example a folder only partly
  downloaded from iCloud Drive or another cloud drive. Make sure the whole
  folder is downloaded (in Files or Finder: **Download Now**), copy it again
  and reimport. From 0.7.14, KartPad checks every file when you import and on
  the game chooser, and names the missing file there instead of after you press
  Play. [#370](https://github.com/chrissotraidis/kartpad/issues/370)
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
  help on some phones; there's no working automatic fix yet. [#104](https://github.com/chrissotraidis/kartpad/issues/104), [#301](https://github.com/chrissotraidis/kartpad/issues/301)
  From 0.7.12, **Report a Problem** logs include a one-line draw self-check
  that tells us whether this phone draws characters differently from the
  CPU path, without changing anything on screen. On the Galaxy S24 Ultra it
  showed that the vertex path isn't the cause, and 0.7.13 showed the bone
  matrix lookup alone isn't either: on these GPUs only both workarounds
  together draw bodies, and then white. A real fix needs a renderer change;
  you don't need to send more logs for this.
  0.8.0 tried one: on these GPUs **Automatic** reads the game's matrices the
  standard way instead of through Dawn's integer rewrite, together with the
  character fix. On the Galaxy S24 Ultra (Adreno 750) the characters are still
  invisible with it; the rest of the race draws normally at 60 FPS. On some
  Adreno phones that drew characters before, it hid them, so 0.8.1
  returns **Automatic** to 0.7.15's behaviour; the native-uniforms path stays
  a Character Graphics Test option. 0.8.1 also adds **Help → Character Graphics Test → Experimental: matrix rows
  like Dolphin**, which reads the bone matrices as plain rows, the way Dolphin
  does. On the Galaxy S24 Ultra it doesn't: 0.8.1's log shows it active and
  the riders still invisible (13 October). A 0.8.1 log from the Moto G85
  ([#301](https://github.com/chrissotraidis/kartpad/issues/301)) still has
  missing bodies with that option off, so it doesn't test matrix rows on that
  phone. A OnePlus tablet (OPD2403, Android 16, 0.8.1) shows faces with the
  bodies missing after the in-app graphics options were tried
  ([#472](https://github.com/chrissotraidis/kartpad/issues/472)); whether that
  is the same failure as the S24 isn't known yet. The next version adds
  **Experimental: bone index per vertex**, which passes each vertex's bone
  index to the GPU directly. It draws characters on the Android emulator; it
  hasn't been tried on an affected phone yet. A Honor 400 Smart (Snapdragon 6s
  Gen 3, [#492](https://github.com/chrissotraidis/kartpad/issues/492)) shows
  only floating heads on 0.8.3 with every current option.
- **Snapdragon 8 Elite / Adreno 8xx:** fixed by **Automatic** in 0.7.10
  (confirmed on the OnePlus 15). If karts or item boxes go missing in Retro
  Rewind, choose **Experimental: fix broken characters** instead.
- **PowerVR GPUs** (for example Moto G54): the 3D scene breaks up. The cause is
  not found yet; 0.7.10's log ruled out the GPU's shader limit. [#304](https://github.com/chrissotraidis/kartpad/issues/304)
- **Moto G75:** crashes while loading the game; we need a diagnostic log.
  [#332](https://github.com/chrissotraidis/kartpad/issues/332)
- **AYN Thor:** black bars even with full screen. Photos on 0.8.1 still showed
  the bars with Fill Screen on. SDL could switch the game window back out of
  fullscreen after KartPad hid the system bars; 0.8.3 keeps it fullscreen
  (checked on an Android 14 emulator). It still needs confirming on a Thor.
  [#202](https://github.com/chrissotraidis/kartpad/issues/202)

## Setup on iPhone and iPad

- **Choosing the extracted folder in Files: Open does nothing.** Two players
  (an iPad and an iPhone) report it on real devices. 0.7.4 fixed the greyed-out
  Open button, but only in the Simulator. Workaround: put the folder (with
  `sys` and `files` directly inside) in **On My iPhone/iPad → KartPad**, then tap
  **Import from Extracted Folder…**. 0.8.1 opens a picker that only
  chooses folders and always reports back after Open; it works in the
  Simulator, and a real device has to confirm it. The latest follow-up uses a
  third-party IPA and DATA download without a PadMint build, so it does not
  yet test the supported 0.8.1 path. The `ios-for-padmint.ipa` alone cannot play
  the game; importing DATA does not supply the translated game code. [#380](https://github.com/chrissotraidis/kartpad/issues/380)

## Graphics (Apple)

- **iPhone 16 and iPad Air 4th gen:** the screen flickers while the game
  starts, then plays normally. Possibly linked to 60 Hz screens; not seen on a
  120 Hz iPad Pro. [#390](https://github.com/chrissotraidis/kartpad/issues/390)
- **Mac, two players:** characters drawn outside their karts. [#127](https://github.com/chrissotraidis/kartpad/issues/127)

## Performance

- **Short pauses** the first time a menu or course appears, while KartPad
  prepares its graphics. They get rarer the more you play.
- **Slow on mid-range and older phones.** The game runs on one processor core,
  so its speed follows that core's speed. Lowering the render resolution
  usually helps little; resolutions above 1× still cost GPU time, so start at
  **1×**. The speed work is tracked in [#339](https://github.com/chrissotraidis/kartpad/issues/339).
- **Honor Magic 8 Lite (Snapdragon 6 Gen 4):** much slower since the latest
  update. 0.8.3 cuts the CPU time of the vertex repack both logs show busy
  (27–34% less in large test cases, same output), but there's no phone
  measurement yet and the cause of the slowdown isn't known.
  [#470](https://github.com/chrissotraidis/kartpad/issues/470)

## Controllers

- **Controllers that send nothing, or the wrong buttons:** 0.7.6 to 0.7.8
  fixed several cases (ipega and other "keyboard" gamepads, a controller left
  with no player). Still waiting on confirmation. [#378](https://github.com/chrissotraidis/kartpad/issues/378)
- **Single Joy-Cons** aren't supported. [#324](https://github.com/chrissotraidis/kartpad/issues/324)
- **Mac, fixed in 0.8.0: a controller that shows as connected does nothing.**
  Xbox, PlayStation and Switch Pro controllers assigned to Player 1 were
  ignored because the keyboard was also active for Player 1. From 0.8.0 the
  keyboard and the controller both work.
- **Mac Wii Remote.** A Classic Controller Pro has input lag and no D-pad
  ([#306](https://github.com/chrissotraidis/kartpad/issues/306)). On 0.8.1, a
  Wii Remote Plus (`RVL-CNT-01-TR`) did not connect, and an original remote
  left Controller Settings when a Nunchuk or Classic Controller was attached
  ([#476](https://github.com/chrissotraidis/kartpad/issues/476)). Both are the
  same Mac Wii Remote path.

## Online

- **Retro Rewind online says "Invalid pack version! Please update or reinstall
  your pack to log in. Error Code: 22010".** Retro WFC accepts only the current
  Retro Rewind. Android updates Retro Rewind inside the app. iPhone, iPad and
  Mac have it built in, so they need a new build: KartPad 0.8.5 with the latest PadMint,
  for Retro Rewind 6.13.4. Retro Rewind updates almost always
  change its game code, so this repeats with each one.
- **Finding a room fails on mobile data** (error 86420) while Wi-Fi works. Many
  carriers block the direct player-to-player connections the game uses; use
  Wi-Fi or a VPN. [#405](https://github.com/chrissotraidis/kartpad/issues/405)
- **An online race can drop with "You were disconnected from the other players."** Seen twice in 0.7.15 Android emulator tests on Retro WFC, each partway through a race; KartPad returned to the menu and signed in again. Not yet confirmed on a phone, where the network differs.
- **Moving an online identity or rating** between devices doesn't fully work.
  [#234](https://github.com/chrissotraidis/kartpad/issues/234) More in [online status](ONLINE.md).

## Confirmations

The crash after the last race of a cup ([#131](https://github.com/chrissotraidis/kartpad/issues/131)) did not happen in automated
full cups on 0.7.10; it stays open for a player retest. Android updates itself
from 0.7.14, and iPhone, iPad and Mac show an update notice from 0.8.0
([#377](https://github.com/chrissotraidis/kartpad/issues/377)); those Apple
platforms still install through PadMint. Hiding the ⋯ button with a controller
([#402](https://github.com/chrissotraidis/kartpad/issues/402)) was confirmed
and is closed. Shake to Trick ([#430](https://github.com/chrissotraidis/kartpad/issues/430))
and the app icon choice ([#437](https://github.com/chrissotraidis/kartpad/issues/437))
shipped in 0.8.0 and are closed.

## Feature requests

Separate music and game-sound volume ([#411](https://github.com/chrissotraidis/kartpad/issues/411)) is in ••• → **Sound…** on
Android (0.7.14) and iPhone/iPad (0.7.15), and in **Game → Game Settings… →
Audio** on Mac.

iPhone, iPad and Mac can't update themselves: each new KartPad, and almost
every Retro Rewind update, needs a new build from PadMint. From 0.8.0 the apps
say when an update is out.

An optional touch control that holds the item button ([#473](https://github.com/chrissotraidis/kartpad/issues/473))
and a second screen on dual-screen Android devices ([#454](https://github.com/chrissotraidis/kartpad/issues/454))
are requested and not in 0.8.1.

Ghost import/export ([#295](https://github.com/chrissotraidis/kartpad/issues/295)), older iOS and macOS versions ([#300](https://github.com/chrissotraidis/kartpad/issues/300)),
AirPlay and external displays ([#100](https://github.com/chrissotraidis/kartpad/issues/100)), DSU controller apps ([#91](https://github.com/chrissotraidis/kartpad/issues/91)) and
Wiimmfi ([#90](https://github.com/chrissotraidis/kartpad/issues/90)). They're open, with no release planned yet.
