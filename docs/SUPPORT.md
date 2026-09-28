# KartPad support

Start with [KartPad and WiiCompiled reports](REPORTING.md) to choose a
destination and understand which logs to attach. WiiCompiled is the original
runtime project; a KartPad report must identify the modified app it came from.
You can report suspected shared runtime problems directly to WiiCompiled;
use KartPad for app/platform problems or an uncertain cause. No maintainer
handoff is required.

Maintainers and automated support agents: start at the [support-agent hub](SUPPORT-AGENTS.md)
for priorities, replies, diagnostics and build-test handoffs.

Use the [platform downloads](../README.md#downloads) and include the
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
The current Android release (retired)
includes transfers for Original, Retro Rewind and Retro Rewind (Separate Save).
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

**Mac VSync:** public 0.4.17/build 39 has no VSync switch. The experimental,
restart-required option is merged in [PR #255](https://github.com/chrissotraidis/kartpad/pull/255)
and has passed local build/package and native settings checks, but is not in a
new public Mac download. Physical tearing and pacing acceptance for
[#250](https://github.com/chrissotraidis/kartpad/issues/250) remain open.

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

The Android 0.4.12-android.2 diagnostic beta (retired)
adds optional **Renderer Validation** on the chooser, off by default. When
requested for a graphics report, compare the same scene/settings with it off
and on, then turn it off for normal play. It enables actual game-renderer
validation and bounds protection and may slow gameplay; it is not a fix.
Older diagnostic builds include bounded `process-exits.json` OS metadata on
Android 11+. A missing record does not establish no crash, and a manual stop
can produce a user-requested exit. See the [beta test steps](releases/v0.4.12-android.2.md).

**Android private reporting candidate:** describe the problem in **Report a
Problem…**, choose the visible destination, then tap **Open GitHub Draft**.
No local file or missing-log explanation is required to open the browser.
Attach reviewed logs or screenshots on GitHub. Returning to the app keeps your
draft. If no browser can open it, the screen shows an error and keeps the draft.
These labels describe the private candidate, not a newly published release;
older builds use **Report on GitHub…** and may ask for a log choice first.

**Android:** **••• → Report a Problem… → Share Report…** produces a short
version/device/profile summary and your answers. It does **not** automatically
include runtime logs. Choose **Export Private Logs…** in that report screen,
or **Export Private Diagnostics…** on the Original/Retro Rewind chooser, to
save logs locally. Exporting neither uploads a file nor selects an attachment.

**The session chooser is a source change awaiting a tested release.** In builds
with **Choose the game session**, select the run that failed before saving the
ZIP. The displayed timestamp is the console's last modification time, not a
verified session start time. After a crash and relaunch, the newest run may not
be the failed one. The selection remains fixed while the save picker is open.

That export includes only the selected session's `console.log` and available
`crash_*.txt`, plus a README and export-time context. It excludes other sessions,
root-level `android-health.log`, OS exit history, and memory dumps. Long logs
retain their header and recent tail with an explicit omission marker. Read the
session's own startup information for its version; the installed/export-time
app version may differ. Missing session metadata is unknown.

Older builds have no session chooser and can include several runs, health
history and OS exit records. Open the ZIP locally and select the relevant
`Logs/<session>/` text yourself. If a runtime must be stopped before exporting,
close it after the failure; do not clear logs or app storage. A manual close
can create an OS exit record and does not establish a crash.

For **renderer validation**, review the chosen `console.log` for warnings or
errors (`validation`, `error`, `warning`, `Dawn`, `WebGPU`). Share startup/version
information and nearby failure context. No logged error is required to report
visible corruption. For performance, include matching `KartPadPerf`/CPU/GPU
lines where available; their timestamps use elapsed time since boot and missing
metrics are not zero. Older exports may additionally contain health samples.

Open the ZIP locally and review it before choosing a relevant text attachment.
Do not upload the whole private archive. Remove usernames, private paths,
IP/MAC addresses, console/account IDs, friend codes, tokens and other personal
data from excerpts. No USB debugging or root is needed.

**iPhone/iPad:** After reproducing the problem, open **••• → Report a
Problem…** and describe what happened. If the app crashed, reopen it first.

**iPhone 17 Pro Max / iOS 27 startup report:** the [#196 retest](https://github.com/chrissotraidis/kartpad/issues/196#issuecomment-5651820707)
still fails on 0.4.17/build 39: Retro crashes roughly two seconds after its
KartPad screen and Original still fails. The earlier iPhone 14 test does not
resolve this device-specific result. The next evidence is the promised new crash
analytics labelled by mode; preserve the installation and data.

In the **private reporting candidate**, choose **Continue to GitHub…**.
**Preparing Report…** remains visible while diagnostics are collected. On the
review screen, either review the text and choose **Choose Project — I’ll Attach
the Log**, or use **Continue Without a Log**. Select KartPad or WiiCompiled to
open its draft in the embedded Safari view. No explanation is required to
continue without a log. Cancelling destination selection or closing the browser
returns to the review. A loading failure offers retry, copy link, or return.

**Save or Share Log…** saves or shares the reviewed file; attach it manually on
GitHub. **Share Report…** remains available from the initial prompt. The report
includes device/settings details and current/previous session logs; it has no
Android-style session picker yet.

Older builds use **Report on GitHub** and an external browser. Reports are in
**Files → On My iPhone/iPad → KartPad → Diagnostics**. Newer builds name the
file **Latest-KartPad-Diagnostic.log**; older builds use
**Latest-SunPad-Diagnostic.log**. Opening a draft does not upload either file.
These candidate changes have not been announced as a public release.

**Mac:** **Help → Save Diagnostics Report…** creates a bounded report with
settings and current/previous session tails. Review it before attaching.

**Apple TV:** follow [`collect-tvos-diagnostics.sh`](../scripts/collect-tvos-diagnostics.sh)
and the [testing guide](TVOS-TESTING.md), then share reviewed, relevant excerpts.

For any platform, a report should say what happened, what you expected, how
to repeat it, and the exact version and hardware. Game images, extracted game
files, saves, complete app containers/NAND, signing material, and identities
do not belong in a public issue.
