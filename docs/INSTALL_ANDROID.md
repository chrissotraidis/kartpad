# Install KartPad on Android

> [!IMPORTANT]
> **KartPad 0.7.4 is the current Android release.** The APK contains no game
> code: you make a game pack with PadMint on your own Windows, Mac or Linux
> computer, or on the phone itself (experimental), and add it in the app.
> Follow [Get KartPad](../README.md#get-kartpad)
> for the steps. Older version notes below are kept for reference; the
> settings, save and troubleshooting guidance still applies.

## Current update

**0.7.4 / build 247** keeps your game pack: install the APK over your current
KartPad and play. It includes a renderer fix for phones with PowerVR graphics
(not yet confirmed on a PowerVR phone), and PadMint reuses a compatible game
pack without translating your disc again. See the
[release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.7.4).

### Earlier: 0.7.3

**0.7.3 / build 246** keeps your game pack: install the APK over your current
KartPad and play. Nothing changes in the app. This release is for PadMint:
making the game pack on an Android phone (Termux) now also works on later
runs, and PadMint can make the iPhone app on Windows and Linux. See the
[release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.7.3).

### Earlier: 0.7.2

**0.7.2 / build 245** keeps your game pack: install the APK over your current
KartPad and play. It stops the game running too fast after you come back from
another app, and Automatic uses the character fix on newer Adreno phones. See
the [release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.7.2).

### Earlier: 0.7.1

**0.7.1 / build 243** keeps your 0.7.0 game pack: install the APK over your
current KartPad and play. PadForge is now called PadMint, and the app's
buttons and links say so. See the
[release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.7.1).

### Earlier: 0.7.0

**0.7.0 / build 242** keeps your game pack working across KartPad updates.
Updating to 0.7.0 needs one last new game pack; after that, a new APK asks for
one only when an update changes how KartPad loads the game. It updates earlier
versions in place with the same signing key, keeping saves. See the
[release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.7.0).

### Earlier: 0.6.1

**0.6.1 / build 241** adds **Help → Replace Game Pack** for swapping the pack
you added, and PadMint now also saves a `KartPad game data` folder you can
import with no key. It updates 0.5.x and 0.6.0 in place with the same signing
key, keeping saves. Already playing 0.6.0? You can stay on it; updating means
making a new game pack for 0.6.1. See the
[release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.6.1).

### Earlier: 0.6.0

**0.6.0 / build 240** makes the APK game-code-free. KartPad asks for your
PadMint game pack the first time you play and keeps one pack per KartPad
version. Importing a disc image now uses your own `common-key.bin`; an
extracted game data folder needs no key. It updates 0.5.x in place with the same
signing key, keeping saves. See the
[release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.6.0).

### Earlier: 0.5.0

**0.5.0 / code 135** (retired)
adds a persistent Auto-accelerate opt-out, fixes controller assignment, and
corrects generated vehicle thumbnails, framebuffer copies and graphics-startup
failures. The owner confirmed the thumbnail repair on the tested Pixel. This
is not a general Android FPS or compatibility guarantee. See the
[release notes](releases/v0.5.0.md). Update in place using the same signing
identity; do not uninstall or clear app data.

The latest update also aligns the mobile settings order and labels, adds **Game Data & Saves → Time Trial Ghosts** for Original `.rkg` transfers, expands controller remapping, and provides Small/Medium/Large FPS counters. The iPhone report form now scrolls correctly. See [mobile settings](SETTINGS.md) for supported workflows and platform differences.

## Download and first launch

**Only have an Android phone?** Follow PadMint's
[phone-only setup](https://github.com/chrissotraidis/padmint#android-phone-only-experimental).
It needs about 25 GB free and 8 GB of memory; the 6 GiB below is for installing
and playing with a pack built on a computer. In Termux, the file-selection number
means the number beside a filename in PadMint's list, such as `1`. It does not
mean the Mario Kart Wii disc ID `RMCP01`. Wait for the list before entering it.

1. Make your game pack with PadMint as described in
   [Get KartPad](../README.md#get-kartpad). From the
   [latest release](https://github.com/chrissotraidis/kartpad/releases/latest),
   download `KartPad-v0.7.4-android.apk` and `SHA256SUMS`.
2. Use an ARM64 phone/tablet with Vulkan and Android 9/API 28 or newer. The
   tested physical device is Pixel 9 Pro XL; the oldest OS/vendor GPU combinations
   and all other phones are not certified. Allow at least 6 GiB free for setup,
   plus space for the source image and optional Retro Rewind installation.
3. Verify the APK against `SHA256SUMS` (`shasum -a 256 FILE.apk` on macOS,
   `sha256sum FILE.apk` on Linux, or `Get-FileHash FILE.apk -Algorithm SHA256`
   in PowerShell). Open it on the phone and, if requested, allow that browser or
   file manager to install this app. No USB debugging is required for normal
   installation. Revoke that install permission afterward if you enabled it.
4. Open KartPad and tap the Mario Kart Wii card. Choose **Choose file** and pick
   your `KartPad-v0.7.4-android-personal.so` game pack. Then import your own
   PAL **RMCP01 revision 0** game data: the `KartPad game data` folder PadMint
   saved (no key needed), or an ISO/WBFS/RVZ image plus your own
   `common-key.bin`. The exact
   profile's identity checks must pass. Keep the original image backed up;
   neither the APK nor this repository supplies it or the key.
5. Choose Retro Rewind to download, verify and install the separately hosted
   official **6.12.8** pack. Use matching current content; if KartPad reports a
   newer incompatible profile, wait for a matching KartPad update. Never bypass
   the checks or replace executable files manually.

The next Android source build also accepts RVZ through the same system picker;
the public 0.5.0 APK still accepts ISO/WBFS. RVZ import decompresses the selected
image into KartPad's existing private game-data layout. It saves space for the
source image, not the installed extracted data, and still requires free space
for extraction and the existing RMCP01 revision-0 validation. No intermediate
full ISO is created.

## Preferred Game

Code 83 adds **Preferred Game…** to the game selector and paused
KartPad menu. **Ask Every Time** is the default; you can choose Original or
Retro Rewind for the next fresh launch. Changing it leaves the current game
paused and does not start a game immediately. Earlier code 80 does not include this preference.

The chooser still validates game data before starting. Missing or incompatible
content leaves you at the selector, and an explicit next-launch game choice
takes precedence. **Return to KartPad Menu** and **Restart to Selector** remain
ways to reach the menu without automatically launching again. This preference
does not check for or install online updates.

## Updating safely

KartPad checks GitHub for a newer release at most once a day when the game
chooser opens. It sends nothing about you or your game. When one is out,
**Update available** appears next to **Help**: it opens the APK download or the
release notes, which say whether the update also needs a new game pack.

Install future public APKs over the existing public app. Keep the same signing
identity and use a forward version code. Export the **Original Mario Kart Wii**
save through **Game Data & Saves → Manage Saves…** before updating, and keep
your owned image separately. Version `0.4.10-android.1` does not back up Retro
Rewind saves; it always targets Original. Version `0.4.12-android.1` adds a
profile selector for Original, Retro Rewind and Retro Rewind (Separate Save).
Export each initialized profile separately. Save exports do not include Miis,
console identity, preferences or downloaded content. See
[save transfer and its limits](SUPPORT.md#android-save-transfer).
Never uninstall or clear storage as an update step.

**Private preview users:** earlier hardware previews use a different local
debug certificate. Android will reject the public release as an in-place update
over those previews. Do not uninstall to force it through: preserve the working
preview and its app data, and plan a deliberate backed-up migration separately.
The first public package was code 21; the testing preview was code 28. The
current public package is code 93.
Changing a package signature is not a save migration.
Self-built APKs similarly cannot update public builds unless the signer matches.

Earlier previews also lack the issue #94 console-serial correction. Do not use
those builds online. The fix writes the full numeric serial expected by the
game; it does not reset your identity or saves. Incorrect CSNums already stored
in a server account's history may require server-admin cleanup. Do not delete
licenses, regenerate identities or clear app data to work around a server ban.

## Controls and performance

The three-dot menu contains Controls, Display, Game Data & Saves, Multiplayer,
and local reporting tools. Touch controls are movable, resizable and hideable;
the floating movement stick follows your initial thumb position within its
pickup area. Existing custom layouts are preserved.

Version 0.4.17 adds **Display → FPS Counter Size… → Small / Medium /
Large**. This changes the counter text only; the separate **Show FPS Counter**
toggle controls visibility. It also keeps the touch editor's **Back** and
**Show/Hide** actions on screen in narrow landscape layouts. Small is the default; the size choice is saved across restarts.

Version 0.4.17 also adds **R** and **D-pad Up** under Controller Button Mapping.
Assigning Right Shoulder to D-pad Up swaps its former R assignment to avoid
triggering both actions. Existing valid custom mappings are retained; the
affected Thor/Odin controller still needs its own trial.

The maintainer accepted Original Grand Prix gameplay using Razer Kishi, with
touch controls hiding automatically when connected. The default mapping is
A/B/X/Y directly, left stick to steer, Start to pause, left shoulder to Z,
left trigger to L, and right shoulder/right trigger to R. Check your exact
controller model; reconnect, rumble, multiple pads and every Kishi generation
are separate acceptance cases.

Start with **Display → Render Resolution → 1x Native**. Increase resolution if
performance permits. Original 4:3 is the conservative aspect setting; widescreen
and Fill Screen remain experimental. Pixel play at 3x was accepted, but the
initial pipeline-compilation queue can cause pronounced hitches, and warm or
track-dependent slowdown remains. This release does not promise sustained 60 FPS.
Retro WFC login and worldwide lobby entry were accepted on the exact tested
device. Complete results, reconnect and network-transition coverage remain open;
frame drops and stutter remain known performance issues.

## Save location and PC transfer

Saves live in internal app-private storage, so they are not visible in a normal
file manager under `Android/data`. Use **••• → Game Data & Saves → Manage Saves…**
to export or restore a `rksys.dat` through the system picker. The testing update
asks you to choose the matching profile first. Follow
the [transfer steps and profile limitations](SUPPORT.md#android-save-transfer);
root access is not needed.

## Report a problem

Include the Android app version, phone model, OS/API, game/profile and track,
render resolution/aspect, controller model, how long it ran, and whether it was
a cold or repeat launch. Enable **Show FPS Counter** and describe when it dips.
Use **Export Private Diagnostics…** on the launch chooser to save logs locally
after reproducing it. The [support guide](SUPPORT.md#collect-a-useful-report)
explains which excerpts to share and how this differs from **Report a Problem…**.
Runtime, renderer-phase and bounded battery/thermal diagnostics are retained
locally; the app does not upload those reports automatically. Shell profiling
is enabled in the first release; the later testing builds disable shell profiling.
Public game packages are non-debuggable.

In **0.4.14**, Report a Problem asks you to select a readable text
log and confirm that you reviewed it, or explain why logs cannot be included.
Exporting diagnostics does not select or approve an attachment. If you open
GitHub, attach the reviewed file manually to the issue draft. Opening a share
sheet does not send anything until you choose a destination and complete it.

Review diagnostics before sharing; do not attach raw private archives, game
images, extracted assets, saves, account/device identifiers or signing keys to
public issues. [Open an issue](https://github.com/chrissotraidis/kartpad/issues)
with the minimal sanitized report. A clean compile or emulator FPS is not proof
of physical performance.

For source builds, see [android/README.md](../android/README.md). See
[rights and licenses](../RIGHTS_AND_LICENSES.md) for the community-release boundary.
