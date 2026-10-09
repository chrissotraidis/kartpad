# Install KartPad on iPhone and iPad

On iPhone and iPad, [PadMint](https://github.com/chrissotraidis/padmint) builds
KartPad on your computer from your own disc. You sideload the IPA it makes,
then add your own Mario Kart Wii game data the first time you open it. (0.7.9
to 0.7.13 also had a ready-to-play IPA; it won't get updates.) What changed in
each version is on the
[releases page](https://github.com/chrissotraidis/kartpad/releases).

## What you need

- A computer to build the IPA with PadMint. The candidate Intel Mac route
  uses full Xcode and its iOS platform to build an ARM64 iPhone/iPad app.
  It does not make KartPad playable on an Intel Mac. Intel support needs
  both a PadMint version that offers the target and a published KartPad
  recipe that declares it; the 0.7.15 release recipe does not yet do so.
  Older Macs must use an Xcode version supported by their macOS.

  Candidate verification: a native Intel Mac running macOS 15 and Xcode 16.4
  passed translator code-generation tests and the production pack compiler,
  symbol checks and IPA insertion with synthetic inputs
  ([CI run](https://github.com/chrissotraidis/kartpad/actions/runs/37945644981)).
  A complete private-disc build also passed locally with Intel x64 tools under
  Rosetta and Xcode 27: 350.53 seconds, an ARM64 iOS 16 library, matching app/pack
  interface fingerprints, and IPA structure validation. Rosetta is additional
  build evidence, not a physical Intel Mac or device gameplay test. The produced
  IPA has not been installed and played on a device.

- iOS or iPadOS 16 or newer.
- A sideloading tool with your own Apple ID:
  [Sideloadly](https://sideloadly.io), [AltStore](https://altstore.io) Classic
  or [SideStore](https://sidestore.io). AltStore PAL can't install arbitrary
  IPAs.
- Your own Mario Kart Wii: PAL (Europe) **RMCP01**, revision 0. Other regions
  don't work yet.
- A computer with [Dolphin](https://dolphin-emu.org) to extract the game data
  (the easiest way), or your disc image plus your own Wii common key.

## 1. Install the app

In [PadMint](https://github.com/chrissotraidis/padmint), choose **KartPad**,
your disc image and **iPhone/iPad**, and install the IPA it makes with your
sideloading tool. To update later, build the new version with PadMint and
install it over your current KartPad **with the same tool and the same Apple
ID**; that keeps your saves and game data. A free Apple ID's signature lasts 7
days, so refresh it in your tool before it runs out.

KartPad doesn't check for updates itself on iPhone and iPad. Watch the
[releases page](https://github.com/chrissotraidis/kartpad/releases) or the
Discord.

## 2. Make your game data folder

In Dolphin on your computer, right-click Mario Kart Wii, choose
**Properties → Filesystem**, right-click the disc at the top and choose
**Extract Entire Disc**. Dolphin makes `DATA`, `UPDATE` and `CHANNEL`;
KartPad needs `DATA`. If you used PadMint, it already made a folder named
`KartPad game data`.

## 3. Copy it to the device

The folder is about 2,000 files and all of them have to arrive. Good ways:

- **AirDrop** from a Mac.
- **iCloud Drive**: copy it in on the computer, then on the device make sure it
  has finished downloading (no cloud icons) before importing.
- **A zip file**: send one zip any way you like, then tap it in the Files app to
  unzip it.
- A USB drive or another cloud app in the Files app.

KartPad 0.7.10 and newer check every game file when the game starts. If some
are missing, KartPad says which ones instead of showing a black screen; copy
the folder again and reimport.

## 4. Import and play

1. Open KartPad and tap **Import Game** on the Mario Kart Wii card.
2. Choose **Import from Extracted Folder…** and pick the folder in the Files
   window. KartPad copies the game data into its own storage and leaves your
   folder untouched.
3. Tap **Play Game**.

For **Retro Rewind**, tap **Set Up Game** on its card. KartPad downloads and
installs the official Retro Rewind 6.12.8 pack (about 1.7 GB).

### Using a disc image instead

**Disc Image (Needs Wii Key) or Other Folder…** also reads an ISO or WBFS (convert RVZ
first), but a disc image needs your own Wii's 16-byte common key saved as
`common-key.bin` in **Files → On My iPhone/iPad → KartPad**. KartPad doesn't
include it and we can't provide it. Without a key, use the extracted folder.

## Playing

Open **•••** during a game for Controls, Display, Game Data & Saves,
Multiplayer and **Report a Problem…**; the full menu is in
[mobile settings](SETTINGS.md). Hold **A** for one second to lock acceleration,
tap it again to release. Controllers, touch layouts and motion steering are
covered in [controls and multiplayer](MULTIPLAYER.md).

**••• → Return to KartPad Menu** pauses the game; **Resume** continues it. To
switch between Original and Retro Rewind, choose **Use on Next Launch**, then
close KartPad from the app switcher and open it again.

## Player identity

To rename an online name, open **••• → Game Data & Saves → Player Identity… →
Rename or Delete Licenses…**, choose the Original or Retro Rewind profile and
the license slot, then **Rename License…**. The license keeps its friend code,
records and progress.

**Delete License…** removes the license's friend code, records and progress;
read the confirmation carefully. Either change applies after you close KartPad
from the app switcher and reopen it. KartPad backs up the save first.

**Edit Mii Name…** renames a Mii and the licenses linked to it. **Import Mii
Appearance…** takes a standard 74-byte `.mii` file. To make a new license,
choose **New** in the game and pick your Mii.

## Files and saves

In the Files app, **On My iPhone/iPad → KartPad** is KartPad's Documents
folder: put `common-key.bin` or a disc image there. Saves, Retro Rewind and
Miis live in KartPad's private storage instead. Use **••• → Game Data & Saves →
Manage Saves…** to back up or restore a save. Deleting KartPad deletes them, so
update in place and back up before changing tools or Apple IDs.

## Report a problem

Open **••• → Report a Problem… → Save or Share Report…**. Review it before
attaching; never attach game files, saves or keys. The
[reporting guide](REPORTING.md) says what to include. Online play has its own
[status page](ONLINE.md).

[PadMint](https://github.com/chrissotraidis/padmint) can still build your own
copy on a computer; it uses `KartPad-v…-ios-for-padmint.ipa`, which doesn't
work on its own. See [rights and licenses](../RIGHTS_AND_LICENSES.md) for what
the release contains.
