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
   A PadMint 0.5.1 build can stop during the first tool download, before
   compilation starts ([#475](https://github.com/chrissotraidis/kartpad/issues/475)).
   That is not an out-of-memory failure or a rejected disc. Keep certificate
   verification on. PadMint 0.5.2's notes do not include a fix for it.
2. If macOS says it can't check the app, choose **Done**, then
   open **System Settings → Privacy & Security** and choose **Open Anyway**.
   The app isn't notarized by Apple, which is why macOS asks. Don't turn off
   Gatekeeper.
3. When KartPad asks for game data, choose your extracted Mario Kart Wii
   `DATA` folder (PAL **RMCP01**, revision 0). To make it, in
   [Dolphin](https://dolphin-emu.org) right-click the game, choose
   **Properties → Filesystem**, right-click the disc and choose
   **Extract Entire Disc**. You can change it later with
   **Data → Choose Mario Kart Wii Data…**.

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

The Mac app doesn't download Retro Rewind. Download the official Retro Rewind
6.13.0 full pack and the 6.13.1 update, extract the update over the full pack,
then choose **Data → Choose Retro Rewind Data…** and select
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
  four players. **Control Reference…** lists every keyboard binding.
- Keyboard defaults: `WASD` to steer, `U` or Return to accelerate and
  confirm, `M` or Delete to brake and go back, `E` to drift, Left Shift for
  items, arrow keys for tricks, Space to pause and Tab for select.
- The mouse works in KartPad's menus but doesn't drive; use the keyboard or a
  controller in races.

Settings and saves are in `~/Library/Application Support/KartPad`, graphics
caches in `~/Library/Caches/KartPad`. Replacing the app keeps both.

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
