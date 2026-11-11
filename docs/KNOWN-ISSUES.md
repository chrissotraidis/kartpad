# KartPad known issues

Current for **KartPad 0.8.10** (9 November 2026). Each item links its GitHub
issue, where updates appear first. If your problem isn't here, see the
[reporting guide](REPORTING.md). The September evidence register is kept in
the [archive](archive/known-issues-through-2026-09.md).

## Setup and game data

- **Fixed in 0.8.6: every PadMint build of 0.8.5 stopped in preflight with
  `WiiCompiled does not match dependencies.lock.json`.** On 23 October the
  upstream WiiCompiled project turned one of its folders into a submodule, and
  0.8.5's setup could no longer check out the version KartPad pins. 0.8.6
  checks out the pinned version directly. Build 0.8.6 with PadMint; you don't
  need to delete anything, because a new release gets a fresh source folder.
  [#509](https://github.com/chrissotraidis/kartpad/issues/509)
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

- **Characters missing, white or washed out on Snapdragon phones**, while
  tracks look fine; often only a face, eyes or a moustache draws. Every
  affected phone that has sent a log uses Qualcomm's own graphics driver from
  the **512.762** series: the Galaxy S24 and S24 Ultra and a OnePlus tablet
  (OPD2403), all Adreno 750, and the Moto G85 (Adreno 619). The two phones
  seen on the older 512.502 driver (Adreno 640 and 650) don't have the
  problem, and Adreno 8xx draws characters with **Automatic**.
  **A Turnip driver fixes it on both phones that have tried one.** The Galaxy
  S24 Ultra draws every character on both graphics engines with Turnip v30
  (Mr. Purple's PurpleVK build), and the Moto G85 does on Classic with an
  AdrenoTools driver. Custom drivers really load from 0.8.9 (0.8.6 to 0.8.8
  quietly used the phone's driver whatever you chose), and from 0.8.10 a
  driver that freezes the game or breaks the picture is switched off at the
  next start, so trying one is safe:
  1. **⋯ → Graphics & Performance → GPU Driver → Add Driver…**, then
     **Download a Driver…** for a recent Turnip release, or **Install from a
     .zip File…** for a package you downloaded yourself.
  2. Restart the game. The **GPU Driver** row says whether the driver loaded.

  Not every Turnip build works on every phone. On the S24 Ultra, Mainline
  Turnip v32 froze the game twice and KartPad went back to the phone's driver.
  On the Moto G85 the WiiCompiled 0.9 (Beta) engine shows black screens with
  either driver, so stay on **Classic** there. Turnip can also be slower than
  the phone's driver (a Poco F4 lost frame rate with it). The Galaxy S24,
  OnePlus tablet and Honor 400 Smart reports haven't said yet whether a
  driver helps.

  The **Character Graphics Test** options under **Graphics Diagnostics…** don't
  fix this on the phone's own driver. The S24 Ultra tried each of them between
  0.7.3 and 0.8.4 (repacked vertices, native uniform buffers, matrix rows like
  Dolphin, a bone index per vertex); the history is in
  [#104](https://github.com/chrissotraidis/kartpad/issues/104). A different
  driver draws the same frames correctly, so the fault is in how the 512.762
  driver runs KartPad's character shaders. What exactly it trips on isn't
  known, and finding it needs one of these phones.
  [#104](https://github.com/chrissotraidis/kartpad/issues/104),
  [#301](https://github.com/chrissotraidis/kartpad/issues/301),
  [#472](https://github.com/chrissotraidis/kartpad/issues/472),
  [#492](https://github.com/chrissotraidis/kartpad/issues/492),
  [#552](https://github.com/chrissotraidis/kartpad/issues/552)
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

- **Choosing the extracted folder in Files: Open does nothing.** Players report
  this on real iPhone and iPad hardware. **Import from Extracted Folder…** opens
  a picker that only chooses folders and always reports back after Open, so a
  current build should return an answer instead of stalling on Open; the
  Simulator passes and device confirmation is still open. Two things to rule
  out first: a folder still stored in the cloud that has not finished
  downloading, and an app installed inside a sandboxing loader such as
  LiveContainer, which is not a verified way to run KartPad. Workaround: put
  the folder (with `sys` and `files` directly inside) in **On My iPhone/iPad →
  KartPad**, then import it from there. The `ios-for-padmint.ipa` alone cannot
  play the game; importing DATA does not supply the translated game code.
  [#380](https://github.com/chrissotraidis/kartpad/issues/380),
  [#539](https://github.com/chrissotraidis/kartpad/issues/539)

## Graphics (Apple)

- **iPhone 16, iPhone 18 Pro and iPad Air 4th gen:** the screen flickers while
  the Wii safety screen fades out, then plays normally. Cause found: the game
  draws that screen while the Wii's "VI black" is still on, and KartPad showed
  a black frame between the game's own frames; which one reached the screen was
  down to timing, so it wasn't about 60 Hz screens. Fixed for the next version
  (black no longer covers the game's frames); confirmed on the iPhone 18 Pro
  Simulator, not yet on an affected iPhone. [#390](https://github.com/chrissotraidis/kartpad/issues/390)
- **Mac, two players:** characters drawn outside their karts. [#127](https://github.com/chrissotraidis/kartpad/issues/127)

## Performance

- **Short pauses** the first time a menu or course appears, while KartPad
  prepares its graphics. They get rarer the more you play.
- **Slow on mid-range and older phones.** The game runs on one processor core,
  so its speed follows that core's speed. Lowering the render resolution
  usually helps little; resolutions above 1× still cost GPU time, so start at
  **1×**. The speed work is tracked in [#339](https://github.com/chrissotraidis/kartpad/issues/339).
- **Android, WiiCompiled 0.9 (Beta) engine: much slower than Classic on many
  phones, in menus and races (fixed in 0.8.7).** The beta locked its
  game, graphics-command and render threads onto a single CPU core. On a Pixel
  9 Pro XL at 4× render resolution, a Luigi Circuit race ran at 19–22 FPS on
  0.8.6's beta and 48–60 FPS with the fix, with the phone cool both times.
  Lowering the resolution doesn't help, because the limit is that one core.
  Because the game's clock follows its frame rate, the slowdown also made
  races run in slow motion. 0.8.7 also reports real frame times to Android, so
  the phone raises its CPU speed when frames run long; on the same Pixel the
  race then held 60 FPS at 3×. On 0.8.6, use **⋯ → Graphics & Performance →
  Graphics Engine → Classic**.
- **Android: slow motion after several cups in a row.** Partly fixed in
  0.8.9. KartPad kept the textures and shaders of every course until it was
  restarted (a Galaxy S10 Lite grew from about 650 MB to 1.1 GB over two
  cups); it now releases them. On 0.8.10 the same phone played four cups in a
  row cleanly, then slowed again after one cup was restarted several times,
  with memory still at 650 MB. Its log shows the game's one busy thread
  working 88–95% of the time even while it holds 60 FPS (about 15.6 ms of
  each 16.7 ms frame), so anything extra, such as the phone warming up, drops
  it below 60 FPS and the race runs in slow motion. On a phone this close to the
  limit, **⋯ → Graphics & Performance → 30 FPS Races** keeps races at normal
  speed. [#510](https://github.com/chrissotraidis/kartpad/issues/510)
- **Android: menus drop to 15–30 FPS, often after something interrupts the
  game** (a notification, the volume panel, switching apps), and stay slow
  until the next race. Cause found for the menus that play video thumbnails
  (the main menu and the single-player menus): the game decodes those videos
  on a background thread, and KartPad let that thread finish a whole video
  frame before the game's own frame could start. Once one game frame started
  late, the video fell behind and kept the following frames late too. A fix
  is prepared for the next version; it has been measured on the Android
  emulator only. The slow Retro WFC lobby in
  [#554](https://github.com/chrissotraidis/kartpad/issues/554) plays no video
  and isn't explained yet. Races aren't affected.
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
  same Mac Wii Remote path. The unreleased runtime corrects the Classic
  Controller D-pad mapping, which was reading a hat the controller never
  reports, and keeps a saved player slot when an extension changes the
  remote's device ID. Neither has been checked on a physical controller yet.

## Online

- **Retro Rewind online says "Invalid pack version! Please update or reinstall
  your pack to log in. Error Code: 22010".** Retro WFC accepts only the current
  Retro Rewind, and KartPad compiles Retro Rewind's game code into the app, so
  every platform needs a matching KartPad: 0.8.8 for Retro Rewind 6.13.5. On
  Android, install the update over your current app; KartPad then downloads the
  new pack. On iPhone, iPad and Mac, build 0.8.8 with the latest PadMint.
  KartPad 0.8.7 and earlier can't sign in or install Retro Rewind since 6.13.5
  came out ([#547](https://github.com/chrissotraidis/kartpad/issues/547)).
  Retro Rewind updates almost always change its game code, so this repeats
  with each one.
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

A second screen on dual-screen Android devices
([#454](https://github.com/chrissotraidis/kartpad/issues/454)) is requested and
not released. The optional touch control that holds the item button shipped in
0.8.5 ([#473](https://github.com/chrissotraidis/kartpad/issues/473)).

Retro Rewind ghost import/export ([#295](https://github.com/chrissotraidis/kartpad/issues/295)), older iOS and macOS versions ([#300](https://github.com/chrissotraidis/kartpad/issues/300)),
AirPlay and external displays ([#100](https://github.com/chrissotraidis/kartpad/issues/100)), DSU controller apps ([#91](https://github.com/chrissotraidis/kartpad/issues/91)) and
Wiimmfi ([#90](https://github.com/chrissotraidis/kartpad/issues/90)). They're open, with no release planned yet.
Original Mario Kart Wii ghost export works from **Game Data & Saves**; only the
Retro Rewind comparison-ghost transfer is still unfinished.
