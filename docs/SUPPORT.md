# KartPad support

Start with [KartPad and WiiCompiled reports](REPORTING.md) to choose a
destination and understand which logs to attach. WiiCompiled is the original
runtime project; a KartPad report must identify the modified app it came from.
You can report suspected shared runtime problems directly to WiiCompiled;
use KartPad for app/platform problems or an uncertain cause. No maintainer
handoff is required.

Maintainers and automated support agents: start at the [support-agent hub](SUPPORT-AGENTS.md)
for priorities, replies, diagnostics and build-test handoffs.

Use the [platform downloads](../README.md#get-kartpad) and include the
exact app version/build in a report. Update over the existing installation;
do not uninstall or clear storage to troubleshoot. Follow the platform's
backup instructions before changing saves or signing identities.

## Read a disc revision without sharing the image

For a raw Wii `.iso` or an extracted `sys/boot.bin`, run this from a KartPad
source checkout with Python 3:

```sh
python3 scripts/inspect-disc-header.py "/path/to/your/game.iso"
```

It reads only the 28-byte header and prints the six-character disc ID, disc
number and numeric revision. It does not upload or modify the file, print its
path, or extract game content. Share only those three metadata fields if asked.
WBFS/RVZ/WIA and other containers are not parsed by this helper; do not rename a
compressed image to `.iso` or assume its first bytes are a raw disc header.

This identifies metadata only. `RMCE01` output does not enable USA compatibility;
KartPad's validated profile remains RMCP01, disc 0, revision 0. The separate
[#203 compatibility request](https://github.com/chrissotraidis/kartpad/issues/203)
still needs a verified translation profile before a playable candidate exists.

## Android save transfer

KartPad stores saves in Android's **internal app-private storage**, so its save
folder is not exposed through a normal file manager under `Android/data`.
KartPad transfers saves for Original, Retro Rewind and Retro Rewind (Separate Save).
Root access is not needed:

1. Copy the PC's raw Mario Kart Wii `rksys.dat` to Downloads on the phone.
   Use a copy and keep the PC original. A Wii `data.bin`, ghost `.rkg`, save
   state, or whole NAND archive is not the supported input.
2. Open Original Mario Kart Wii, then **••• → Game Data & Saves → Manage
   Saves…**, select the matching profile, and use **Export Save Backup…** first
   if you have existing progress.
   Export is enabled once an initialized, valid save exists.
3. Choose **Restore Save Backup…**, check the destination profile, then
   **Choose Backup…** and select the copied `rksys.dat`.
   KartPad validates its size, header, and checksum before staging it.
4. Choose **Restart Now** to apply it before gameplay starts. KartPad also
   retains a backup of the previous save. Check the expected licenses and
   progress offline before continuing.

**Older public build:** `0.4.10-android.1` always targets the Original PAL save,
even when opened while playing Retro Rewind. It does not export or restore Retro
Rewind saves. Update to the current public build for that transfer; keep the PC copy and
verify the resulting progress offline. In the PC WiiCompiled → Android Retro
Rewind/PAL case, the initial save-only restore left ratings at 5000. After the
matching rating companion was imported, the reporter confirmed that ratings
and offline progress transferred correctly in
[#105](https://github.com/chrissotraidis/kartpad/issues/105). This confirms that
manual handoff; whole-Mii-database import and automatic two-way synchronization
remain separate requests.

**Profile selection:** Choose **Original Mario Kart Wii**, **Retro Rewind**, or
**Retro Rewind (Separate Save)** to match the source. The third profile is for
Retro Rewind's Separate Save option. Each export and restore targets only that
profile. Android activity recreation retains the file-picker destination;
missing or invalid destination state rejects the result. Existing pending
Original restores remain compatible. Transfers are manual; automatic Syncthing
synchronization is not implemented.

The importer accepts a raw 2,867,200-byte `RKSD0006` save with a valid core
checksum. That validation does not prove cross-region, cross-mod, or online
identity compatibility. A save transfer does not transfer the Mii database or
console identity. If the source is Dolphin, another WiiCompiled build, or
Retro Rewind, name it and the game region when asking for migration help.
Never post the save or NAND publicly.

**Restoring a backup from the same phone:** the backup's contents still matter.
Importing a raw save and its matching rating companion does not restore the Mii
names/appearance, console identity or country configuration. The same-phone
Wheel Witch backup case in [#234](https://github.com/chrissotraidis/kartpad/issues/234)
remains unresolved; code 80 does not add a complete identity/NAND migration.
If an identity or country warning appears, preserve the existing profiles and
backup rather than creating new data or resetting identity to get past it.

**Retro Rewind ratings:** Raw `rksys.dat` transfer does not include
`RRRating.pul`, Miis or console identity. In a shared Dolphin NAND, the rating
file is usually under `Wii/shared2/Pulsar/RetroRewind6/RRRating.pul`.

[0.4.13 preview 1](releases/v0.4.13-android-preview.1.md) adds
**Restore Retro Ratings…**. Restore the matching Retro save first, restart and
let Retro create its local rating file, then choose the matching PC companion.
The app validates online profile IDs, backs up the destination and selectively
merges matching records before gameplay. Both Retro save modes share ratings
for the same online ID; unrelated records are preserved. Unsupported/custom
NAND configurations are refused.

Keep the original save and rating file backed up and verify licenses and
ratings **offline** before online play. The reporter in
[#105](https://github.com/chrissotraidis/kartpad/issues/105) confirmed successful
ratings and offline-information transfer on 8 September. This does not establish
complete migration, transfer Miis or synchronize server ratings. Older diagnostic betas lack
the companion action. Never replace rating files while the game runs, edit
ratings, reset identity or publish saves, Miis or friend codes. Automatic
Syncthing/two-way folder synchronization is not implemented.

On Mac, **Data → Show KartPad Data** opens KartPad's support directory. Quit
the game before backing it up. On Apple TV, use
[`backup-tvos-state.sh`](../scripts/backup-tvos-state.sh) as described in the
[testing guide](TVOS-TESTING.md); its cache storage can be purged by tvOS.
Android's save-picker instructions do not imply the same UI exists on Apple.

## Display and performance

**Mac VSync:** the Mac app's graphics settings have an experimental
**VSync** option; quit and reopen KartPad to apply it.

**Original 4:3** and **Widescreen 16:9 (Experimental)** fit the selected aspect
inside the display; black bars can be expected. **Fill Screen (Experimental)**
uses the actual surface aspect and dynamic game projection. It is intended to
expand the view, but some scenes or HUD elements may still distort. It is not
a guarantee that every screen renders correctly at a phone's wider aspect.

For a stretched image, compare 16:9 and Fill Screen on the same track and
camera view. Include both screenshots, app/OS version, and whether it affects
the 3D world, menus/HUD, or both. Use 4:3 or 16:9 as a temporary workaround.
See [#101](https://github.com/chrissotraidis/kartpad/issues/101).

For Android geometry/texture corruption, try a repeat of the same race at
**1x Native / Original 4:3** and report whether the defect persists. Include
phone/OS details, Original versus Retro Rewind, track and character/vehicle,
and startup renderer information plus warnings from the logs below. On a
foldable, include the screen in use and whether folding/resizing preceded the
failure. Similar GPU names do not establish identical drivers or a root cause.
See [#102](https://github.com/chrissotraidis/kartpad/issues/102) and
[#104](https://github.com/chrissotraidis/kartpad/issues/104).

For frame drops, enable KartPad's **Show FPS Counter** and compare a cold and
repeat run of the same course. Record resolution, aspect, game/battery mode,
time since launch, charging state, and whether audio also stutters. Samsung
Game Booster/Game Booster+ battery-saver settings affected the report in
[#103](https://github.com/chrissotraidis/kartpad/issues/103). Compare settings
one at a time; higher resolution is not an established performance fix.
Low GPU utilization alone cannot distinguish CPU, shader compilation,
presentation, or power/thermal limits.

AirPlay mirroring and a dedicated external-display game view are different
paths. Neither is currently accepted as supported iPhone/iPad output.
For black video with working audio, report the phone/tablet and OS, TV/monitor,
cable/adapter or AirPlay receiver, whether the device itself keeps rendering,
and whether connecting before versus after game launch changes the result.
See [#100](https://github.com/chrissotraidis/kartpad/issues/100) and the
[Apple/Android external-display test plan](EXTERNAL-DISPLAYS.md).

## Collect a useful report

Say what happened, what you expected, how to make it happen again, and your
KartPad version, device and OS. Screenshots or a short video help with
graphics problems.

**Android:** in the game, open **⋯ → Report a Problem…** and fill in the three
boxes.

- **Open GitHub Draft** opens a filled-in issue in your browser.
- **Save Diagnostic Log…** asks which game session had the problem and saves its
  log. After a crash, reopen KartPad first; the newest session may not be the
  one that crashed, so pick the right time.
- **Share Report…** shares the summary without logs.

If the game won't start at all, use **Help → Export Private Diagnostics…** on
the game chooser instead. It saves a ZIP with the chosen session's log, any
crash traces Android kept, and a README. Open it yourself and attach the
`console.log` or the relevant part, not the whole ZIP.

**iPhone/iPad:** open **••• → Report a Problem…**, describe it, then choose
**Save or Share Report…** to save the report file, or **Review & Continue to
GitHub…** to open a draft. If the app crashed, reopen it first; the report
includes the previous session's log.

**Mac:** **Help → Save Diagnostics Report…** saves the settings and the recent
log of this and the previous session.

**Apple TV:** use [`collect-tvos-diagnostics.sh`](../scripts/collect-tvos-diagnostics.sh)
and the [testing guide](TVOS-TESTING.md).

For graphics problems on Android, **Renderer Validation** on the chooser adds
extra checks to the log. It slows the game and isn't a fix; turn it off again
after one test.

Review any log before attaching it. Remove usernames, paths, IP addresses,
friend codes and account IDs you don't want public. Never attach disc images,
game files, saves, NAND backups, keys or signing material.
