# KartPad

<p align="center">
  <strong>Mario Kart Wii and Retro Rewind, native for Android, iOS, iPadOS, and macOS.</strong><br>
  Native static recompilation through Vulkan on Android and Metal on Apple platforms, with touch controls, motion steering, controllers, and optional Retro Rewind content. tvOS is currently an experimental preview.
</p>

KartPad builds on [WiiCompiled](https://github.com/patchzyy/Wiicompiled), the
original Mario Kart Wii static recompilation project created by
[patchzyy](https://github.com/patchzyy). WiiCompiled provides the foundational
translator and runtime; KartPad maintains the Apple and Android integration,
native controls, game chooser, game-data management, packaging, and releases.
The projects are independently maintained.

<p align="center">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple%20Silicon-arm64-0A84FF?logo=apple">
  <img alt="Metal renderer" src="https://img.shields.io/badge/renderer-Metal-5E5CE6">
  <img alt="Android ARM64 with Vulkan" src="https://img.shields.io/badge/Android-ARM64%20%2F%20Vulkan-3DDC84?logo=android">
  <img alt="Ahead-of-time static recompilation" src="https://img.shields.io/badge/PowerPC-static%20recompilation-FF9F0A">
  <img alt="macOS development target" src="https://img.shields.io/badge/macOS%20target-14%2B-0A84FF">
  <img alt="iPhone and iPad" src="https://img.shields.io/badge/platform-iPhone%20%2F%20iPad-0A84FF">
  <img alt="Retro Rewind supported" src="https://img.shields.io/badge/Retro%20Rewind-6.12.8-FF375F">
  <img alt="Game data not included" src="https://img.shields.io/badge/game%20data-not%20included-FF453A">
  <a href="https://discord.gg/xwHfUD2bxW"><img alt="Join the KartPad Discord" src="https://img.shields.io/badge/Discord-Join%20the%20community-5865F2?logo=discord&amp;logoColor=white"></a>
</p>

![KartPad running a race on DK Summit on iPad](docs/images/kartpad-dk-summit-ipad.png)

> [!IMPORTANT]
> **Bring your own game data.** KartPad requires a legally obtained supported
> PAL `RMCP01` revision 0 Mario Kart Wii image. tvOS remains experimental.
>
> **AI disclosure:** KartPad uses substantial AI assistance for code, tests,
> documentation, debugging and maintenance. Some support replies and maintenance
> tasks are automated. There is no audited percentage of AI-generated code.
> Build, test and device records describe what was checked. This disclosure
> concerns KartPad's workflow, not the authorship of its upstream projects.

## Get KartPad

KartPad is free. The app on the [releases page](https://github.com/chrissotraidis/kartpad/releases/latest)
contains no game code: you make the game part with
[PadMint](https://github.com/chrissotraidis/padmint) from your own Mario Kart
Wii disc. Nothing from your disc is uploaded, and neither KartPad nor PadMint
includes game files or console keys.

| You want KartPad on | You have | Follow |
|---|---|---|
| **Android** | a Windows, Mac or Linux computer | [1. PadMint](#1-make-your-copy-with-padmint), then [2. Android](#2-android) |
| **Android** | only the phone | PadMint's [Android, phone only](https://github.com/chrissotraidis/padmint#android-phone-only-experimental) (experimental) |
| **iPhone or iPad** | a Mac with Apple Silicon (M1 or newer) | [1. PadMint](#1-make-your-copy-with-padmint), then [3. iPhone and iPad](#3-iphone-and-ipad) |
| **iPhone or iPad** | a Windows or Linux computer | the same steps (experimental) |

**You need** your own Mario Kart Wii disc image: PAL (Europe) **RMCP01**
revision 0, as ISO, WBFS or RVZ (other regions are not supported), and:

- **Android:** an ARM64 phone or tablet with Vulkan and Android 9 or newer.
- **iPhone and iPad:** iOS or iPadOS 16 or newer, and Sideloadly, AltStore or
  SideStore. Building on a Mac also needs [Xcode](https://apps.apple.com/app/xcode/id497799835).
- About 16 GB free on the computer, and 6 GB on the phone or tablet.

**Versions:** always use the [latest PadMint](https://github.com/chrissotraidis/padmint/releases/latest)
and the [latest KartPad](https://github.com/chrissotraidis/kartpad/releases/latest).
PadMint always builds for the latest KartPad.

### 1. Make your copy with PadMint

1. Download the ZIP for your computer from the
   [latest PadMint](https://github.com/chrissotraidis/padmint/releases/latest),
   unzip it and start it:
   - **Windows:** double-click `PadMint.cmd`. If Windows says it protected
     your PC, choose **More info**, then **Run anyway**.
   - **Mac:** once, run `xcode-select --install` in Terminal. Then double-click
     `PadMint.command`. The first time, choose **Done**, then **System
     Settings → Privacy & Security → Open Anyway**.
   - **Linux:** run `sh padmint.sh` in the folder (needs Python 3.9+ and Git).
2. Drag your disc image into the window and press Enter. On a Mac with Apple
   Silicon, then choose **Android** or **iPhone/iPad**.
3. Keep the window open. The first build takes about 15 minutes to an hour
   (about 4 GB of tools); later builds take a few minutes.

PadMint saves these in your Downloads folder. Keep them to yourself: they are
made from your disc.

| | What it is |
|---|---|
| `KartPad-v…-android-personal.so` | the Android **game pack** |
| `KartPad-v…-ios-personal.ipa` | the complete iPhone/iPad app |
| `KartPad game data` folder | the game's tracks, music and menus |

### 2. Android

1. Install the `KartPad-v…-android.apk` from the
   [latest release](https://github.com/chrissotraidis/kartpad/releases/latest).
   It updates an older KartPad and keeps your saves; don't uninstall first.
2. Copy the `.so` file **and** the `KartPad game data` folder to the phone
   (USB cable, Google Drive, Quick Share).
3. Open KartPad and tap the button on the Mario Kart Wii card (**Import Game**,
   or **Play Game** if you played before). At **Add your game pack**, tap
   **Choose file** and pick the `.so`.
4. At **Game Data & Saves**, tap **Import from Extracted Game Data Folder…**,
   pick the `KartPad game data` folder, then tap **Done**. (Updating from 0.5.x?
   Your game data is already there.)
5. Tap **Play Game**. For Retro Rewind, tap **Set Up Game** on its card and
   KartPad downloads the official pack.

### 3. iPhone and iPad

1. Install the `.ipa` with Sideloadly, AltStore or SideStore. Updating?
   Install it over your KartPad with the same tool and Apple ID to keep your
   saves.
2. First time only: get the `KartPad game data` folder onto the device.
   AirDrop it from a Mac, or put it in iCloud Drive, on a USB drive or in a
   cloud drive app. In KartPad, tap **Import Game** on the Mario Kart Wii card,
   then **Import from Extracted Folder…**, and pick the folder in the Files
   window that opens.

See [iPhone/iPad setup](docs/INSTALL_IPA.md) for more.

### Other ways to add game data

- **Dolphin:** right-click Mario Kart Wii → **Properties → Filesystem**,
  right-click the disc, choose **Extract Entire Disc** and import the `DATA`
  folder it makes, as above.
- **Disc image:** import your ISO or WBFS (Android also accepts RVZ). This
  needs your own Wii's 16-byte common key saved as `common-key.bin`, for
  example from a BootMii NAND backup of your console. KartPad and PadMint do
  not include it and we cannot provide it.

### Updating KartPad

- **Android:** install the new APK. Your game pack keeps working. If an update
  ever needs a new one, KartPad says **This KartPad needs a new game pack**: run
  PadMint again and choose the new `.so` (later swaps: **Help → Replace Game
  Pack**).
- **iPhone and iPad:** run PadMint again for the new `.ipa`. It reuses your
  earlier work, so it takes a few minutes.

There is no Mac download at the moment.

### Source maintenance

**0.4.22 moved KartPad to maintained WiiCompiled source** with pinned platform
branches, preserving the existing game behavior and repository history. Source
parity, rollback and build checks passed; the owner accepted loading, running
and starting games on iPad and Android. macOS reached a race in the host smoke
check. New-license Retro WFC login worked on iPad; an existing profile's serial
mismatch reproduced on both builds and remains unresolved. Completed online
races/reconnect and broader hardware coverage are not new claims.
See the [migration validation](docs/source-maintenance/VALIDATION.md).

## Playing

**Need help or found a bug?** [Where to report and follow up](docs/REPORTING.md).
Suspected runtime bugs can go [directly to WiiCompiled](https://github.com/patchzyy/Wiicompiled/issues/new/choose); identify your KartPad build.
Use KartPad for app/platform problems or when the cause is unclear.

[Frequently asked questions](#frequently-asked-questions) · [Controls](docs/MULTIPLAYER.md) · [Save transfer and troubleshooting](docs/SUPPORT.md)

- Choose **Mario Kart Wii** or **Retro Rewind** when KartPad opens. Retro
  Rewind 6.12.8 content installs separately; KartPad requires a matching native
  profile when the mod updates. Follow your platform's setup guide above.
- Touch controls, motion steering and controllers are available on mobile;
  Mac also supports keyboard input. Touch layouts can be moved, resized and
  hidden. See [controls and multiplayer](docs/MULTIPLAYER.md).
- On iPhone/iPad, **••• → Return to KartPad Menu** pauses the current game.
  **Resume** continues it; switching games or applying license edits requires
  fully closing and reopening the app. See [iPhone/iPad setup](docs/INSTALL_IPA.md).
- For save transfer, player identity, display settings or diagnostics, see the
  [support guide](docs/SUPPORT.md) and [known issues](docs/KNOWN-ISSUES.md).

Android Original gameplay with a Razer Kishi was accepted on Pixel 9 Pro XL;
earlier Android testing confirmed Retro WFC login and worldwide
lobby entry on that device. Frame drops, stutter, complete results and reconnect
remain open.
The iPad release candidate has owner-accepted controller gameplay and menu
checks. These results do not establish every device, complete online results or
reconnect behavior. Native private-room hosting and Wiimmfi support for
Original remain unfinished. [Online status](docs/ONLINE.md) records the limits.

Startup shader compilation, track-dependent dips and warm slowdown remain
known issues. Android's suggested starting point is **1x Native**. Sustained
60 FPS and external-display output are not generally verified.

## Frequently asked questions

<details>
<summary>Can I download an IPA or playable app?</summary>

Yes: the app is on the releases page, and you add the game from your own disc
with PadMint. See [Get KartPad](#get-kartpad).

</details>

<details>
<summary>PadForge says "KartPad cannot be built for android yet"</summary>

PadForge is PadMint's old name. From KartPad 0.7.1, only PadMint can read
KartPad's build recipe. Download
[PadMint](https://github.com/chrissotraidis/padmint/releases/latest) and run it
instead: it moves your PadForge folder over and reuses the tools it already
downloaded.

</details>

<details>
<summary>Are Android and Apple TV supported?</summary>

Android targets ARM64/Vulkan on Android 9+. Device-specific graphics corruption, freezes and slowdowns remain unresolved; a successful Pixel run does not certify other phones. Apple TV is an **experimental** tvOS 17+ preview with separate controller and hardware acceptance. See [Android setup](docs/INSTALL_ANDROID.md) and [Apple TV setup](docs/INSTALL_TVOS.md).

</details>

<details>
<summary>Does online multiplayer work?</summary>

The tested iPad migration build reached Retro WFC with a new license. An existing
license's serial mismatch reproduced on both old and new builds. Earlier Android
tests reached Retro WFC and the worldwide lobby, but this release does not claim
a newly verified complete online race/reconnect sequence or compatibility on
every device. Native room hosting and Original Wiimmfi compatibility remain
unfinished. See [online status](docs/ONLINE.md) and
[friend-room guidance](docs/MULTIPLAYER.md#private-friend-rooms).

</details>

<details>
<summary>Does KartPad support Retro Rewind, and what if it updates?</summary>

Yes, with the separately installed **6.12.8** content and matching compiled profile. A newer Retro pack can require a new KartPad build; replacing files alone does not update translated game code. Apple checks the version before launch; Android checks the official version during installation and validates installed content at launch. Follow your [platform setup guide](#get-kartpad) if a compatibility update is requested.

</details>

<details>
<summary>How do I switch between Mario Kart Wii and Retro Rewind?</summary>

Choose the game when KartPad opens. On iPhone/iPad, **••• → Return to KartPad Menu** pauses the session; **Resume** continues it. Choose **Use on Next Launch** for the other game, fully close the app, then reopen it. Returning to the chooser alone does not apply pending license edits. Mac game selection also applies after reopening. See the platform installation guides for their distinct flows.

</details>

<details>
<summary>How do touch controls, acceleration lock and motion steering work?</summary>

On iPhone/iPad, hold **A for one uninterrupted second** to lock acceleration; tap A again to release it. Touch settings let you move, resize, hide and restore controls, including the normally hidden D-pad for tricks. Motion steering is optional and offers recenter, inversion and sensitivity. See the [mobile controls guide](docs/MULTIPLAYER.md#iphone-and-ipad-touch-and-motion-controls) for floating-stick behavior and controller handoff. Android has its own [controls/settings guide](docs/INSTALL_ANDROID.md).

</details>

<details>
<summary>Can I use controllers or local split-screen?</summary>

Yes. Pair controllers in the operating system, choose Multiplayer in the game and press each pad’s mapped A button to register. On iPhone/iPad, the first controller shares Player 1 with touch; the other players keep stable slots. Full three/four-player and reconnect acceptance remains incomplete. See [controller setup and adapter limits](docs/MULTIPLAYER.md).

</details>

<details>
<summary>Can KartPad set my player name or import a custom Mii?</summary>

On iPhone/iPad, **••• → Game Data & Saves → Player Identity…** manages names and exact license slots. Restart to apply edits. Standard 74-byte `.mii` appearance import is experimental, not a full Wii Mii editor. Renaming a Mii and renaming one license are different actions. See [identity instructions](docs/INSTALL_IPA.md#player-identity). Android save/rating transfer does not include the Mii database.

</details>

<details>
<summary>Can I connect a Wii Remote and Nunchuk without a DolphinBar?</summary>

Experimentally, on **macOS only**, using the direct Bluetooth pairing flow. It still needs broader original-hardware, reconnect and long-session testing; it is not an iPhone/iPad feature. See [pairing instructions and hardware limits](docs/INSTALL_MACOS.md#experimental-wii-remote-and-nunchuk).

</details>

<details>
<summary>How much storage does KartPad use?</summary>

Package size varies by platform and version; the iPhone/iPad app is about **65 MB**. Extracted base-game data is roughly **2.5 GiB**, and Retro content, the original image and temporary installation files require more. Android setup recommends at least **6 GiB free**. Check the platform guide and leave room for updates; the app size is not the installed-data footprint.

</details>

<details>
<summary>Does this repository include Mario Kart Wii?</summary>

No disc image or extracted retail assets are included. Supply your own legally obtained supported PAL **RMCP01 revision 0** image. Public packages contain compiled translated logic, so software licensing and game-content rights are separate; see [rights and provenance](RIGHTS_AND_LICENSES.md). Do not request or attach game data in issues.

</details>

<details>
<summary>Is KartPad a general Wii emulator?</summary>

No. It is a game-specific static recompilation for supported Mario Kart Wii and Retro Rewind profiles, not a loader for arbitrary Wii games.

</details>

<details>
<summary>Is KartPad using Dolphin or streaming from a Mac?</summary>

The game runs locally as native ARM64 code translated by WiiCompiled, with Vulkan on Android and Metal on Apple platforms. It is not streamed from another computer or run inside the Dolphin emulator. KartPad does use Dolphin-derived components, including game-data handling; [third-party notices](THIRD_PARTY_NOTICES.md) preserve that attribution.

</details>

<details>
<summary>Does KartPad use a PowerPC JIT on iPhone or iPad?</summary>

No. PowerPC code is translated ahead of time and compiled into the app. The iPhone/iPad app does not JIT-compile PowerPC or execute a newly downloaded PowerPC patch. New executable profiles require a compatible app build.

</details>

<details>
<summary>Why is it slow or freezing, and are distorted graphics fixed?</summary>

First-use shader/pipeline compilation can cause stalls, and heat or higher render resolution can worsen performance. **Not every freeze is shader compilation.** Android has separate unresolved character corruption, online-menu stalls and cup-transition crashes. Start at **1x Native**, but do not treat a settings change or passing renderer probe as a confirmed fix. Use [known issues](docs/KNOWN-ISSUES.md) and [diagnostic guidance](docs/SUPPORT.md) to match your symptoms; the preview adds useful changes and logs, not a blanket stability guarantee.

</details>

<details>
<summary>Why are the inherited experimental modes absent?</summary>

Those settings applied to Sunshine-specific CPU-clock and 60 FPS behavior and did not affect KartPad’s Mario Kart Wii runtime. They were removed because they were misleading no-ops. Use actual display controls and the [performance guidance](docs/PERF.md).

</details>

<details>
<summary>Do saves survive an update, and can I transfer Retro ratings?</summary>

Supported in-place updates preserve saves; **do not uninstall or clear app data**. Keep backups and the same signing identity/bundle ID. Android private previews have a different signer and need a planned migration. Raw save backups do not include every companion file: Android preview 1 adds matched offline Retro rating restore, and the reporter confirmed that workflow succeeded. Mii transfer and online/server synchronization remain separate unfinished work. See [save and rating transfer](docs/SUPPORT.md).

</details>

<details>
<summary>Is everything finished? How do I report a problem?</summary>

No. Check [current platform acceptance](docs/STATUS.md), [known issues](docs/KNOWN-ISSUES.md) and [technical debt](docs/TECH-DEBT.md). Report your exact build, device/OS, selected game, settings and reproducible steps using the [reporting guide to choose KartPad or WiiCompiled](docs/REPORTING.md). Export a problem report using the [support guide](docs/SUPPORT.md), review it before sharing, and keep saves, identities and game data private.

</details>

## Build and contribute

Maintainers and automated support agents: start at the [support-agent hub](docs/SUPPORT-AGENTS.md)
for priorities, replies, diagnostics and build-test handoffs.

WiiCompiled translates PowerPC game code ahead of time; KartPad compiles it for
ARM64 and renders through Vulkan on Android or Metal on Apple platforms.

- [Apple builds](docs/BUILDING.md): prerequisites, Mac self-build and iOS workflows.
- [Android builds](android/README.md): source-only shell and complete runtime.
- [Source maintenance](docs/source-maintenance/README.md): editable WiiCompiled source, upstream comparison, and migration status.
- [Documentation](docs/README.md): user guides, architecture and release evidence.
- [Current status](docs/STATUS.md) and [maintenance board](docs/MAINTENANCE-BOARD.md):
  accepted results, active work and outstanding tests.

For a bug report, include the exact app/build, device, OS, game, settings and
reproduction steps. Review diagnostics before sharing; never attach game data,
saves, account identifiers or signing material. Choose the relevant tracker in the
[reporting guide](docs/REPORTING.md).

## Credits and license

KartPad builds on [WiiCompiled](https://github.com/patchzyy/Wiicompiled),
Aurora/Dawn, SDL and Dolphin-derived work. SunPad supplies the pinned mobile
touch/menu component; [its provenance](apple/third_party/sunpad/UPSTREAM.md)
and [third-party notices](THIRD_PARTY_NOTICES.md) record attribution and licenses.
[Original artwork provenance](branding/PROVENANCE.md) is recorded separately.

Aedan Pilkington contributed the native macOS controller and settings
enhancements, including controller assignment and remapping, persistent
profiles, keyboard remapping, settings shortcuts, and fullscreen/notch
integration. See the [macOS controller and settings guide](docs/MACOS_CONTROLLER_OVERHAUL.md)
for implementation details and source-build testing instructions. These are
source-build enhancements; they should not be read as features of the
published Mac release until a corresponding release is published.

KartPad is free software under [GPLv3](LICENSE), including its WiiCompiled
modifications and the integrated application where GPLv3 requires. GPL rights
to use, modify and redistribute the software are separate from game-content
rights. See [rights, licenses and Corresponding Source](RIGHTS_AND_LICENSES.md).
Mario Kart, Wii and game imagery belong to their respective rights holders.
KartPad is not affiliated with or endorsed by Nintendo.
