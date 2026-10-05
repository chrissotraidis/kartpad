# Install KartPad on Android

KartPad's Android download is ready to play. You install the APK, then add
your own Mario Kart Wii game data the first time you open it. You don't need
PadMint or a game pack. What changed in each version is on the
[releases page](https://github.com/chrissotraidis/kartpad/releases).

## What you need

- An ARM64 phone or tablet with Vulkan and Android 9 or newer, with about
  6 GB free.
- Your own Mario Kart Wii: PAL (Europe) **RMCP01**, revision 0. Other regions
  don't work yet.
- A computer with [Dolphin](https://dolphin-emu.org) to extract the game data
  (the easiest way), or your disc image plus your own Wii common key.

## 1. Install the app

Download `KartPad-v…-android.apk` from the
[latest release](https://github.com/chrissotraidis/kartpad/releases/latest) on
the phone and open it. If Android asks, allow your browser or file manager to
install apps. If you already have KartPad, install over it; **don't uninstall
first**, or you lose your saves.

To check the download, compare it with `SHA256SUMS` from the same release
(`shasum -a 256` on Mac, `sha256sum` on Linux, `Get-FileHash` in PowerShell).

## 2. Make your game data folder

In Dolphin on your computer:

1. Right-click Mario Kart Wii in the game list and choose **Properties**.
2. Open the **Filesystem** tab, right-click the disc at the top, and choose
   **Extract Entire Disc**. Pick an empty folder.
3. Dolphin makes three folders: `DATA`, `UPDATE` and `CHANNEL`. KartPad
   only needs `DATA`. You can also give KartPad the folder that holds all
   three; it finds `DATA` inside.

If you used PadMint, it already made this folder for you, named
`KartPad game data`.

## 3. Copy it to the phone

The game data is about 2,000 files. All of them have to arrive, so pick a way
that copies the whole folder:

- **USB cable (most reliable).** Connect the phone, choose **File transfer**
  on the phone, and copy the folder into **Download**. On a Mac, use
  [OpenMTP](https://openmtp.ganeshrvel.com).
- **A zip file.** Zip the folder on the computer, send the one file any way you
  like (Google Drive, Quick Share, a cable), then open it in **Files by Google**
  and choose **Extract**.
- **Google Drive with loose files** is the risky way: KartPad can't pick a
  folder inside Google Drive, and a partly downloaded folder is missing files.
  Download it to the phone as a zip instead.

KartPad 0.7.10 and newer check every game file when the game starts. If some
are missing, KartPad tells you which ones, and you copy the folder again.

## 4. Import and play

1. Open KartPad and tap **Import Game** on the Mario Kart Wii card.
2. Tap **Import from Extracted Game Data Folder…**, pick the folder, then tap
   **Use this folder** and **Allow**.
3. When it says **Game Data Imported**, tap **Done**, then **Play Game**.

For **Retro Rewind**, tap **Set Up Game** on its card. KartPad downloads and
installs the official Retro Rewind 6.12.8 pack (about 1.7 GB).

### Using a disc image instead

**Import or Reimport Wii Disc Image…** reads an ISO, WBFS or RVZ directly, but
it needs your own Wii's 16-byte common key saved as `common-key.bin` (for
example from a BootMii NAND backup). KartPad doesn't include it and we can't
provide it. If KartPad asks you for a key and you don't have one, use the
extracted folder above instead.

## Updating

KartPad checks for a new release at most once an hour when the game chooser
opens. It sends nothing about you. When one is out, **Update available**
appears next to **Help** and opens the APK download.

Install each new APK over the old one. Your saves, game data and Retro Rewind
stay. **Never uninstall or clear storage to update.** Android only accepts an
update signed by the same key, so a copy you built yourself can't update the
public app (or the other way around) without uninstalling. Back up your saves
first if you ever have to.

## Controls and settings

Open **⋯** (top right) during a game for Controls, Display, Game Data & Saves,
Multiplayer and **Report a Problem…**. The full menu is in
[mobile settings](SETTINGS.md).

- **Touch controls** can be moved, resized and hidden in
  **Controls → Touch Control Settings…**. The movement stick follows where you
  first put your thumb.
- **Controllers:** pair them in Android's Bluetooth settings. Touch controls
  hide while one is connected; with **Hide on controller** on, the ⋯ button
  hides too and comes back when you touch the screen. Buttons can be remapped
  in **Controller Button Mapping…**, and players assigned in
  **Controller Player Setup…**. See [controls and multiplayer](MULTIPLAYER.md).
- **Render resolution:** start at **Display → Render Resolution → 1×** and
  raise it if your phone keeps up.
- **Character graphics:** if characters or tracks look broken, open **Help →
  Character Graphics Test…** on the game chooser. **Automatic** is right for
  most phones; the other options are workarounds for specific Snapdragon GPUs.
- **On launch:** on the chooser, choose whether KartPad asks every time or
  opens Original or Retro Rewind directly.

The first time you see a course or menu, KartPad prepares its graphics, which
can cause short pauses. They get rarer the more you play. KartPad doesn't
promise a steady 60 FPS on every phone; the Pixel 9 Pro XL is the tested
device.

## Saves

Saves live in KartPad's private storage, so a file manager can't see them. Use
**⋯ → Game Data & Saves → Manage Saves…** to export a backup or restore a
`rksys.dat` from a PC or Dolphin. Original and Retro Rewind have separate
saves. See [save transfer](SUPPORT.md#android-save-transfer).

## Report a problem

In the game, open **⋯ → Report a Problem…**. On the game chooser, **Help →
Export Private Diagnostics…** saves the logs from a session that crashed.
Review a log before attaching it; never attach game files, saves or keys.
The [reporting guide](REPORTING.md) says what to include and where to file it.

For source builds, see [android/README.md](../android/README.md). See
[rights and licenses](../RIGHTS_AND_LICENSES.md) for what the release contains.
