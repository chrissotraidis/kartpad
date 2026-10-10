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
  <img alt="Retro Rewind supported" src="https://img.shields.io/badge/Retro%20Rewind-6.13.1-FF375F">
  <img alt="Game data not included" src="https://img.shields.io/badge/game%20data-not%20included-FF453A">
  <a href="https://github.com/chrissotraidis/padmint"><img alt="Build KartPad with PadMint (optional)" src="https://img.shields.io/badge/PadMint-optional%20build-3EB489"></a>
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

KartPad is free. On Android, download it from the
[releases page](https://github.com/chrissotraidis/kartpad/releases/latest). On
iPhone, iPad and Mac, [PadMint](https://github.com/chrissotraidis/padmint)
builds it on your own computer from your own disc. Either way, you add your own
Mario Kart Wii game data the first time you open it. The Android download
includes KartPad's translated game code but no game files: no disc image, no
courses, music or textures, and no console keys. You supply those from your
own disc.

| You want KartPad on | Get it | Then |
|---|---|---|
| **Android** | `KartPad-v…-android.apk` from the releases page | [Android](#android) |
| **iPhone or iPad** | Build it with [PadMint](https://github.com/chrissotraidis/padmint) | [iPhone and iPad](#iphone-and-ipad) |
| **Mac** (Apple Silicon) | Build it with [PadMint](https://github.com/chrissotraidis/padmint) | [Mac](#mac) |

**You need** your own Mario Kart Wii: PAL (Europe) **RMCP01** revision 0 (other
regions are not supported), and:

- **Android:** an ARM64 phone or tablet with Vulkan and Android 9 or newer,
  with about 6 GB free.
- **iPhone and iPad:** iOS or iPadOS 16 or newer, and Sideloadly, AltStore or
  SideStore with your own Apple ID, plus a computer to run PadMint.
- **Mac:** an Apple Silicon Mac with macOS 14 or newer, to run PadMint and play.

### Your game data

KartPad needs your game's files once. Either:

- **An extracted folder (easiest).** In [Dolphin](https://dolphin-emu.org),
  right-click Mario Kart Wii → **Properties → Filesystem**, right-click the
  disc, choose **Extract Entire Disc** and keep the `DATA` folder it makes
  (KartPad doesn't need `UPDATE` or `CHANNEL`).
  [PadMint](https://github.com/chrissotraidis/padmint) also saves one, named
  `KartPad game data`, when it builds KartPad.
- **Your disc image.** KartPad can import an ISO or WBFS directly (Android also
  accepts RVZ). This needs your own Wii's 16-byte common key saved as
  `common-key.bin`, for example from a BootMii NAND backup of your console.
  KartPad does not include it and we cannot provide it.

### Android

1. Install `KartPad-v…-android.apk`. It updates an older KartPad and keeps your
   saves; don't uninstall first.
2. Copy your game data folder to the phone. It's about 2,000 files and all of
   them must arrive: a USB cable is most reliable, or zip the folder, send the
   zip any way you like and extract it with **Files by Google**. KartPad can't
   pick a folder inside Google Drive.
3. Open KartPad and tap **Import Game** on the Mario Kart Wii card. At
   **Game Data & Saves**, tap **Import from Extracted Game Data Folder…**, pick
   the folder, tap **Use this folder** and **Allow**, then **Done**. If you
   played before, your game data is already there: tap **Play Game**.
4. For Retro Rewind, tap **Set Up Game** on its card and KartPad downloads the
   official pack.

Coming from a PadMint game pack? Install the new APK over it. KartPad no longer
needs the pack and frees the space it took.

From 0.7.14, KartPad updates itself: when **Update available** shows on the
game chooser, tap it and **Update Now**. The first time, Android asks you to
allow KartPad to install apps.

### iPhone and iPad

1. In [PadMint](https://github.com/chrissotraidis/padmint), choose **KartPad**,
   your disc image and **iPhone/iPad**. Install the IPA it makes with
   Sideloadly, AltStore or SideStore. To keep your saves, install it over your
   KartPad with the same tool and Apple ID. PadMint also makes your
   `KartPad game data` folder.
2. First time only: get your game data folder onto the device (AirDrop from a
   Mac, a zip you unzip in the Files app, iCloud Drive once it has fully
   downloaded, or a USB drive). In KartPad, tap
   **Import Game** on the Mario Kart Wii card, then **Import from Extracted
   Folder…**, and pick the folder in the Files window that opens.

See [iPhone/iPad setup](docs/INSTALL_IPA.md) for more.

### Mac

1. In [PadMint](https://github.com/chrissotraidis/padmint), choose **KartPad**,
   your disc image and **Mac**, then move the **KartPad** app it makes to
   Applications.
2. If macOS says it can't check the app, choose **Done**, then
   **System Settings → Privacy & Security → Open Anyway**.
3. Import your game data folder when KartPad asks for it.

See [Install on Mac](docs/INSTALL_MACOS.md) for more.

### PadMint

[PadMint](https://github.com/chrissotraidis/padmint) builds KartPad from your
own disc on your own computer: choose **KartPad**, your disc image and where
you'll play, and it makes your copy and your `KartPad game data` folder. From
0.7.14 it's how iPhone, iPad and Mac get KartPad, and it still works for
Android.

### Which file is which

| File on the release page | What it is |
|---|---|
| `KartPad-v…-android.apk` | **Android: install this.** Ready to play with your game data |
| `KartPad-v…-ios-for-padmint.ipa` | The iPhone app without game code. PadMint uses it; don't install it by itself |
| `KartPad-v…-padmint.json`, `SHA256SUMS` | Used by PadMint and for checking downloads |
| `KartPad-v…-source.tar.gz`, `KartPad-v…-notices.zip` | Source code and license notices |

0.7.9 to 0.7.13 also had ready-to-play iPhone/iPad and Mac downloads. They stay
on those release pages but won't get updates; build newer versions with PadMint.

### Updating KartPad

- **Android:** from 0.7.14, KartPad updates itself (**Update available →
  Update Now**). You can also install the new APK over your current KartPad.
- **iPhone, iPad and Mac:** build the new version with PadMint and install it
  over your current KartPad. From 0.8.0, KartPad tells you when a new version
  is out: **Update available** on the iPhone/iPad game chooser, or
  **Help → Check for Updates…** on Mac.

Your saves and game data stay.

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
  Rewind 6.13.1 content installs separately; KartPad requires a matching native
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

On Android, yes: the APK on the releases page is ready to play, and you add
your own game data the first time. On iPhone, iPad and Mac, build KartPad with
PadMint from your own disc (from 0.7.14; 0.7.9 to 0.7.13 had ready-to-play
downloads that won't get updates). See [Get KartPad](#get-kartpad).

</details>

<details>
<summary>KartPad asks me for a "Wii common key". What is that?</summary>

You chose **Import or Reimport Wii Disc Image…**. Reading a disc image needs a
key from your own Wii, which most people don't have and KartPad can't provide.
Go back and choose **Import from Extracted Game Data Folder…** (iPhone/iPad:
**Import from Extracted Folder…**) with a folder from Dolphin instead. It needs
no key. See [Your game data](#your-game-data).

</details>

<details>
<summary>Dolphin made DATA, UPDATE and CHANNEL folders. Which one do I use?</summary>

`DATA`. You can also pick the folder that contains all three; KartPad finds
`DATA` inside it.

</details>

<details>
<summary>It says "Ready to play" but the game goes black or crashes on start</summary>

Usually some game files didn't copy, often from a cloud drive that hadn't
finished downloading. KartPad 0.7.10 and newer check every file and tell you
which are missing. Copy the folder again (a USB cable, or one zip file) and
import it again. See [Android](docs/INSTALL_ANDROID.md#3-copy-it-to-the-phone)
or [iPhone/iPad](docs/INSTALL_IPA.md#3-copy-it-to-the-device).

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

Retro WFC works with Retro Rewind 6.13.1. On the Android emulator, KartPad
0.7.15 signed in, joined a worldwide room and raced against other players. In
those tests the room disconnected twice during a race; each time the app
returned to the menu and could sign in again. It isn't verified on every device
or network. Native room hosting and Original Wiimmfi compatibility remain
unfinished. See [online status](docs/ONLINE.md) and
[friend-room guidance](docs/MULTIPLAYER.md#private-friend-rooms).

If finding a room fails on mobile data but works on Wi-Fi, your carrier is
blocking the direct player-to-player connections the game uses. Use Wi-Fi or a
VPN ([#405](https://github.com/chrissotraidis/kartpad/issues/405)).

</details>

<details>
<summary>Does KartPad support Retro Rewind, and what if it updates?</summary>

Yes, with the separately installed **6.13.1** content and matching compiled profile. Almost every Retro Rewind update changes the mod's game code (`Code.pul`): 22 of its last 24 updates did. KartPad compiles that code into the app ahead of time, so a Retro Rewind update needs a new KartPad build; replacing files alone does not update the compiled game code. On Android the new build arrives through **Update available → Update Now**. On iPhone, iPad and Mac, build it with PadMint and install it over your current KartPad; iOS doesn't let a sideloaded app compile new code on the device. Apple checks the version before launch; Android checks the official version during installation and validates installed content at launch.

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

The first time a menu or course appears, KartPad prepares its graphics, which causes short pauses; heat and higher render resolutions make things slower. Start at **1×**. Broken characters on Android depend on the GPU: Snapdragon 8 Elite (Adreno 8xx) is fixed by **Automatic** in 0.7.10, while older Adreno and PowerVR GPUs are still open. [Known issues](docs/KNOWN-ISSUES.md) lists what's open for each device family.

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

## Community and support

[Join the Discord](https://discord.gg/xwHfUD2bxW) for help and news. It is one
community for KartPad and its sibling projects, such as BlueWake, MeleePad and
SunPad: ask about setup, installing, and building with PadMint, share how it
runs on your device, and hear about new releases first.

Found a bug? [Open an issue](https://github.com/chrissotraidis/kartpad/issues)
with your device, its OS version, and the steps that led to it.

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
