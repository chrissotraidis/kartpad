# KartPad known issues

Current for **KartPad 0.8.1** (14 October 2026). Each item links its GitHub
issue, where updates appear first. If your problem isn't here, see the
[reporting guide](REPORTING.md). The September evidence register is kept in
the [archive](archive/known-issues-through-2026-09.md).

## Setup and game data

- **Mac build stops at `CERTIFICATE_VERIFY_FAILED` before compilation (#475).**
  A secure download failed its certificate check. The cause on the reported Mac
  is still unconfirmed. A prepared recipe correction keeps PadMint's own Python
  during preflight instead of selecting another Python from PATH; it is not in
  0.8.1. Keep certificate verification enabled. [Report](https://github.com/chrissotraidis/kartpad/issues/475)


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
  the riders still invisible (13 October). Next: pass each vertex's bone index
  to the GPU directly. That experiment is built and off by default; synthetic
  software-GPU checks pass, but no affected Adreno result yet. The Moto G85's 0.8.1 log still shows missing bodies,
  with matrix rows off; it does not test that option. A new
  [OnePlus OPD2403 report](https://github.com/chrissotraidis/kartpad/issues/472)
  shows the same visible symptom, with GPU/driver evidence still pending.
- **OnePlus 15:** its Adreno 8xx graphics were fixed by **Automatic** in
  0.7.10 (reporter-confirmed). This does not establish all Adreno 8xx devices
  as fixed. If karts or item boxes go missing in Retro
  Rewind, choose **Experimental: fix broken characters** instead.
- **PowerVR GPUs** (for example Moto G54): the 3D scene breaks up. The cause is
  not found yet; 0.7.10's log ruled out the GPU's shader limit. [#304](https://github.com/chrissotraidis/kartpad/issues/304)
- **Moto G75:** crashes while loading the game; we need a diagnostic log.
  [#332](https://github.com/chrissotraidis/kartpad/issues/332)
- **AYN Thor:** black bands remain with Fill Screen in 0.8.1, confirmed by
  the reporter's race photos. The cutout change did not resolve this. A
  delayed SDL window-style command can restore windowed mode after KartPad
  hides the system bars. A correction is under test; Android 14 fixture
  evidence is recorded in the [14 October review](ISSUE-TRIAGE-2026-10-14.md).
  It is not in the published 0.8.1 and still needs Thor confirmation.
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
- **Honor Magic 8 Lite / Adreno 810: reported regression** from previously
  playable builds. Both 0.7.15 and 0.8.1 logs show slow gameplay at 1× with a
  busy main thread and no pending shader compilation in the slow samples.
  The newer session also reaches severe thermal status. The responsible
  change is not identified; different sessions are not a controlled A/B.
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
- **Mac: Wii Remote with Classic Controller Pro** has input lag and no D-pad.
  [#306](https://github.com/chrissotraidis/kartpad/issues/306)
- **Mac: the Wii Remote disappears from Controller Settings once a Nunchuk or
  Classic Controller Pro is attached; a Wii Remote Plus (RVL-CNT-01-TR) won't
  connect.** Reported on 0.8.1 after pairing with WiimotePair rather than
  KartPad's own pairing window. Not diagnosed. [#476](https://github.com/chrissotraidis/kartpad/issues/476)

## Online

- **Retro Rewind online says "Invalid pack version! Please update or reinstall
  your pack to log in. Error Code: 22010".** Retro WFC accepts only the current
  Retro Rewind. Android updates Retro Rewind inside the app. iPhone, iPad and
  Mac have it built in, so they need a new build: KartPad 0.8.0 with PadMint
  0.5.1 or newer for Retro Rewind 6.13.1. Retro Rewind updates almost always
  change its game code, so this repeats with each one.
- **Finding a room fails on mobile data** (error 86420) while Wi-Fi works. Many
  carriers block the direct player-to-player connections the game uses; use
  Wi-Fi or a VPN. [#405](https://github.com/chrissotraidis/kartpad/issues/405)
- **An online race can drop with "You were disconnected from the other players."** Seen twice in 0.7.15 Android emulator tests on Retro WFC, each partway through a race; KartPad returned to the menu and signed in again. Not yet confirmed on a phone, where the network differs.
- **Moving an online identity or rating** between devices doesn't fully work.
  [#234](https://github.com/chrissotraidis/kartpad/issues/234) More in [online status](ONLINE.md).

## Waiting for players to confirm

These have a fix or explanation and are open until someone affected confirms
it: the crash after the last race of a cup ([#131](https://github.com/chrissotraidis/kartpad/issues/131), no crash in automated
full cups on 0.7.10), the hourly update notice ([#377](https://github.com/chrissotraidis/kartpad/issues/377)), auto-hiding the ⋯ button ([#402](https://github.com/chrissotraidis/kartpad/issues/402)), and from 0.8.0 Shake to Trick
([#430](https://github.com/chrissotraidis/kartpad/issues/430)) and the app icon choice ([#437](https://github.com/chrissotraidis/kartpad/issues/437)).

## Feature requests

Separate music and game-sound volume ([#411](https://github.com/chrissotraidis/kartpad/issues/411)) is in ••• → **Sound…** on
Android (0.7.14) and iPhone/iPad (0.7.15), and in **Game → Game Settings… →
Audio** on Mac.

iPhone, iPad and Mac can't update themselves: each new KartPad, and almost
every Retro Rewind update, needs a new build from PadMint. From 0.8.0 the apps
say when an update is out.

Ghost import/export ([#295](https://github.com/chrissotraidis/kartpad/issues/295)), older iOS and macOS versions ([#300](https://github.com/chrissotraidis/kartpad/issues/300)),
AirPlay and external displays ([#100](https://github.com/chrissotraidis/kartpad/issues/100)), DSU controller apps ([#91](https://github.com/chrissotraidis/kartpad/issues/91)) and
Wiimmfi ([#90](https://github.com/chrissotraidis/kartpad/issues/90)). They're open, with no release planned yet.
