# Install KartPad on Mac

On Apple Silicon Macs (M1 or newer) with macOS 14 or newer,
[PadMint](https://github.com/chrissotraidis/padmint) builds KartPad from your
own disc. You add your own Mario Kart Wii game data the first time you open it.
(0.7.9 to 0.7.13 also had a ready-to-play Mac download; it won't get updates.)
The Mac version is experimental: it's tested less than Android and
iPhone/iPad.

## Install

1. In [PadMint](https://github.com/chrissotraidis/padmint), choose **Mario Kart Wii**,
   your disc image and **This Mac** under **Where will you play?**, and move the
   **KartPad** app it makes to Applications. To update, build the new version
   with PadMint, quit KartPad and replace the app; your settings and saves stay.
   The Mac build needs PadMint 0.5.1 or newer and Xcode (install it from the
   App Store and open it once). PadMint supplies the other build tools.
   If a download stops with `CERTIFICATE_VERIFY_FAILED` or "unable to get local
   issuer certificate" ([#532](https://github.com/chrissotraidis/kartpad/issues/532)),
   start PadMint using `PadMint.command` from its Mac download, which uses
   Apple's Python. If you deliberately use Python from python.org, run
   `Install Certificates.command` in its folder under Applications first.
   If the check still fails, check your Mac's date and certificate updates, or
   ask your network administrator about HTTPS access. Keep certificate
   verification enabled and retry; your disc and completed downloads can stay.
2. If macOS says it can't check the app, choose **Done**, then
   open **System Settings → Privacy & Security** and choose **Open Anyway**.
   The app isn't notarized by Apple, which is why macOS asks. Don't turn off
   Gatekeeper.
3. When KartPad asks for game data, choose your extracted Mario Kart Wii
   folder (PAL **RMCP01**, revision 0). You can reuse PadMint's files below.
   To make a `DATA` folder yourself, in
   [Dolphin](https://dolphin-emu.org) right-click the game, choose
   **Properties → Filesystem**, right-click the disc and choose
   **Extract Entire Disc**. You can change it later with
   **Data → Choose Mario Kart Wii Data…**.

## Reuse PadMint's game files

The Mac build produces an app ZIP. It also extracts Original and Retro Rewind
while building, but doesn't put a separate `KartPad game data` folder in
Downloads. You can copy those prepared files into a local folder you will keep:

1. In Finder, choose **Go → Go to Folder…** and enter
   `~/.padmint/games/kartpad-v0.8.7/`. Use the version folder matching the app
   you built. This is PadMint's usual location; if you set `PADMINT_HOME`, use
   that folder instead of `~/.padmint`.
2. Copy `private/self-build/disc` to your chosen location. When KartPad asks
   for Original game data, select that copied `disc` folder; it contains
   `files` and `sys`, just like Dolphin's `DATA` folder.
3. For Retro Rewind 6.13.4 (KartPad 0.8.5 to 0.8.7), also copy the whole
   `private/builder/retro-rewind-downloads/6.13.4-extracted` folder there.
   In KartPad, choose **Data → Choose Retro Rewind Data…** and select the
   `RetroRewind6` folder inside your copy. Then follow the game-switching
   steps below.

Keep the chosen copies in place. Retro Rewind can store saves beside
`RetroRewind6`, so keep its whole enclosing folder when backing it up or moving
it. If these folders aren't present, check which version and location PadMint
used in its build log, or use the Dolphin and official Retro Rewind downloads
described here. There is no need to edit KartPad's configuration or delete any
existing game files or saves.

## Missing This Mac option

If PadMint only offers **iPhone/iPad** and **Android**:

1. Close PadMint's Terminal window. Download the latest
   [PadMint for Mac](https://github.com/chrissotraidis/padmint/releases/latest/download/PadMint-macos.zip),
   extract it, then open `PadMint.command` from the **new folder**. You need
   PadMint 0.5.1 or newer. Each folder has its own game list; refreshing the
   browser or opening an older folder does not update it.
2. Check **Apple menu → About This Mac**. **Chip: Apple M…** is supported.
   An Intel Mac can build KartPad for iPhone/iPad experimentally, but cannot
   build or play the Mac version.
3. On Apple Silicon, PadMint **0.5.2** can still hide **This Mac** if it runs
   under Rosetta. Close PadMint's Terminal window. Open Terminal, type `cd `
   (with a space), drag the newly extracted PadMint folder from Finder into
   Terminal and press Return. Then start PadMint natively:

   ```sh
   arch -arm64 /bin/bash ./PadMint.command
   ```

Keep your disc images, completed builds, caches and saves. None need deleting
to restore the Mac option.

## Retro Rewind

The Mac app doesn't download Retro Rewind. You can reuse PadMint's prepared
files above, or download and extract the official Retro Rewind 6.13.4 full
pack (`6.13.4-full.zip`), then choose **Data → Choose Retro Rewind Data…** and select
its `RetroRewind6` folder. Choose **Game → Retro Rewind**, quit and reopen
KartPad. **Game → Original Mario Kart Wii** and reopening switches back.

KartPad needs the exact Retro Rewind version it was built for. If it says the
data is unsupported, use the version it names; a newer pack needs a KartPad
update.

## Menus and input

- **Game** switches the game for the next launch and opens display and audio
  settings.
- **Data** changes the game data folders, manages Miis and opens the data and
  cache folders.
- **Controls → Controller Settings…** detects and maps controllers for up to
  four players. Select **Keyboard** to see or change your current keys.
- The default keyboard mapping shown there uses `WASD` to steer, Return to
  accelerate and confirm, Backspace (Delete on a Mac keyboard) to brake and
  go back, Left Option to drift, Left Control for items, Left Shift for rear
  view, arrow keys for tricks and menu directions, and Space to pause.
- The mouse works in KartPad's menus but doesn't drive; use the keyboard or a
  controller in races.

Settings and Original saves are in `~/Library/Application Support/KartPad`,
graphics caches in `~/Library/Caches/KartPad`. Retro Rewind can store saves
beside its selected data folder; keep that enclosing folder too. Replacing the
app keeps these files.

## Experimental Wii Remote and Nunchuk

Turn on **Controls → Experimental Wii Remote + Nunchuk**, press the red
**SYNC** button on the Wii Remote to pair, attach the Nunchuk, then choose
**Wii Remote + Nunchuk (Experimental)** in Controller Settings. It is meant for an
original `RVL-CNT-01` or a Wii Remote Plus `RVL-CNT-01-TR`, without a
DolphinBar. On 0.8.1, one Mac report says the Plus remote never connects, and
the original remote leaves Controller Settings when a Nunchuk or Classic
Controller is attached
([#476](https://github.com/chrissotraidis/kartpad/issues/476)). It uses private
macOS Bluetooth interfaces and needs more hardware testing; reconnecting and
long sessions may not work yet. A Classic Controller Pro on a Wii Remote has
input lag and no D-pad ([#306](https://github.com/chrissotraidis/kartpad/issues/306)).

## Build it yourself

Developers can build the Mac app from their own disc image. Install the
[Apple build prerequisites](BUILDING.md#prerequisites), then run:

```sh
./scripts/self-build-macos.sh /path/to/your/Mario-Kart-Wii.wbfs
open build/KartPad.app
```

It records the disc-image hash and does not require it to match one reference
file. The extracted game must be PAL RMCP01 revision 0, with the supported
`sys/main.dol` and `files/rel/StaticR.rel` hashes. It fetches
and verifies the pinned dependencies and Retro Rewind inputs, translates both
games, builds and audits the app, and sets `dvd_root` and
`retro_rewind_root` in your KartPad configuration. Back up that configuration
and your saves first if you already use the Mac app. The result stays a private
local build; see [`RIGHTS_AND_LICENSES.md`](../RIGHTS_AND_LICENSES.md) and the
[Apple source-build guide](BUILDING.md#mac-self-build).

Report problems with your macOS version and Mac model; see the
[reporting guide](REPORTING.md).
