# KartPad

<p align="center">
  <strong>Mario Kart Wii and Retro Rewind, native for Android, iOS, iPadOS, and macOS.</strong><br>
  Native static recompilation through Vulkan on Android and Metal on Apple platforms, with touch controls, motion steering, controllers, and optional Retro Rewind content. tvOS is currently an experimental preview.
</p>

KartPad is an Apple and Android fork and productization of
[WiiCompiled](https://github.com/patchzyy/Wiicompiled), the original static
recompilation project for Mario Kart Wii. It adds native controls, a dual-game
chooser, game-data management, packaging, and release workflows.

<p align="center">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple%20Silicon-arm64-0A84FF?logo=apple">
  <img alt="Metal renderer" src="https://img.shields.io/badge/renderer-Metal-5E5CE6">
  <img alt="Android ARM64 with Vulkan" src="https://img.shields.io/badge/Android-ARM64%20%2F%20Vulkan-3DDC84?logo=android">
  <img alt="Ahead-of-time static recompilation" src="https://img.shields.io/badge/PowerPC-static%20recompilation-FF9F0A">
  <img alt="macOS development target" src="https://img.shields.io/badge/macOS%20target-14%2B-0A84FF">
  <img alt="iPhone and iPad 0.4.14" src="https://img.shields.io/badge/iPhone%20%2F%20iPad-0.4.14-0A84FF">
  <img alt="Retro Rewind supported" src="https://img.shields.io/badge/Retro%20Rewind-6.12.8-FF375F">
  <img alt="Game data not included" src="https://img.shields.io/badge/game%20data-not%20included-FF453A">
</p>

![KartPad running a race on DK Summit on iPad](docs/images/kartpad-dk-summit-ipad.png)

> [!IMPORTANT]
> **Bring your own game data.** KartPad requires a legally obtained supported
> PAL `RMCP01` revision 0 Mario Kart Wii image. Downloads contain translated
> game logic, but no disc image, extracted game assets, Retro Rewind pack or
> saves. Apple IPAs require local re-signing; tvOS remains experimental.
>
> **Update before online play.** The downloads below include the console-serial
> correction for [#94](https://github.com/chrissotraidis/kartpad/issues/94).
> Older affected builds should stay offline. Updating preserves identities and
> saves; existing server-side identity history or bans require service-admin review.
>
> **AI disclosure:** KartPad uses substantial AI assistance for code, tests,
> documentation, debugging and maintenance. Some support replies and maintenance
> tasks are automated. There is no audited percentage of AI-generated code.
> Build, test and device records describe what was checked. This disclosure
> concerns KartPad's workflow, not the authorship of its upstream projects.

## Downloads

| Platform | Download | Setup |
| --- | --- | --- |
| Android ARM64 | [0.4.16 Android 2 · code 65](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.16-android.2) | [Android 9+ with Vulkan](docs/INSTALL_ANDROID.md) |
| iPhone / iPad | [0.4.15 · build 34](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.15-ios.1) | [iOS/iPadOS 16+; re-sign the IPA](docs/INSTALL_IPA.md) |
| Apple Silicon Mac | [0.4.15 · build 34](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.15-macos.1) | [macOS 14+](docs/INSTALL_MACOS.md) |
| Apple TV experimental preview | [0.4.11 · build 9](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.11-tvos.1) | [tvOS 17+; re-sign the IPA](docs/INSTALL_TVOS.md) |

**Android 0.4.16 Android 2 is now available.** It refreshes the translated
Retro Rewind 6.12.8 graph and retains the console-serial correction required by
Retro WFC profiles. Physical Pixel 9 Pro XL acceptance confirmed launch,
touch controls, Retro WFC login and worldwide lobby entry. Frame drops and
stutter during online connection and gameplay remain known issues; sustained
60 FPS is not claimed. It adds the refreshed game chooser,
reviewed-log reporting, Retro pack-update save protection and native rendering
improvements. Local Pixel 9 Pro XL tests at 2x/Fill measured about **58 FPS versus
40–50 FPS** in the warm Grand Prix menu with the change enabled versus disabled;
race gains were smaller. The owner accepted the final payload on hardware.
These local mode comparisons are not an across-device or old-public-versus-new-public
benchmark. Menu delays and device-specific graphics issues remain open. See the
[measurements and release notes](docs/releases/v0.4.16-android.2.md).

**iPhone/iPad 0.4.15** adds an actual log-review screen, an unchecked acknowledgment
and an explanation when logs cannot be attached. It retains the newer chooser
and setup help. **macOS 0.4.15** brings the Metal view-lifetime correction to Mac;
it does not establish a tearing or performance fix. See the
[iPhone/iPad](docs/releases/v0.4.15-ios.1.md) and
[macOS](docs/releases/v0.4.15-macos.1.md) notes.

Download the checksums and accompanying notices with each package. The releases
also include the [source bundle and rebuild instructions](docs/artifacts/2026-09-10/android-source-delivery.md). **Update in
place using the same signing identity; do not uninstall or clear app data.**
Private Android previews use a different signer and need a backed-up migration.

## Playing

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
the current Android release adds owner-confirmed Retro WFC login and worldwide
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

Yes—use the [platform downloads above](#downloads). The current official iPhone/iPad build is **0.4.14 build 33**; Mac and Apple TV have separate packages. Apple IPAs need re-signing. Every package requires your own supported game data. A [Personal IPA Builder](docs/BUILDER.md) is also available.

</details>

<details>
<summary>Are Android and Apple TV supported?</summary>

Android has a playable ARM64/Vulkan APK for Android 9+, plus an explicitly unstable preview. Device-specific graphics corruption, freezes and slowdowns remain unresolved; a successful Pixel run does not certify other phones. Apple TV is an **experimental** tvOS 17+ preview with separate controller and hardware acceptance. See [Android setup](docs/INSTALL_ANDROID.md) and [Apple TV setup](docs/INSTALL_TVOS.md).

</details>

<details>
<summary>Does online multiplayer work?</summary>

The owner confirmed Retro WFC login and worldwide lobby entry on the current
Android build. Separate isolated-server tests covered race results and lobby
return, but complete production online behavior, reconnect and every device are
not established. Native room hosting and Original Wiimmfi compatibility remain
unfinished; entering a server address does not implement them. See [online
status](docs/ONLINE.md) and [friend-room guidance](docs/MULTIPLAYER.md#private-friend-rooms).

</details>

<details>
<summary>Does KartPad support Retro Rewind, and what if it updates?</summary>

Yes, with the separately installed **6.12.8** content and matching compiled profile. A newer Retro pack can require a new KartPad build; replacing files alone does not update translated game code. Apple checks the version before launch; Android checks the official version during installation and validates installed content at launch. Follow your [platform setup guide](#downloads) if a compatibility update is requested.

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

Package size varies by platform and version; the iPhone/iPad IPA download is about **45 MB**. Extracted base-game data is roughly **2.5 GiB**, and Retro content, the original image and temporary installation files require more. Android setup recommends at least **6 GiB free**. Check the platform guide and leave room for updates; the IPA download size is not the installed-data footprint.

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

No. Check [current platform acceptance](docs/STATUS.md), [known issues](docs/KNOWN-ISSUES.md) and [technical debt](docs/TECH-DEBT.md). Report your exact build, device/OS, selected game, settings and reproducible steps using the [bug form](https://github.com/chrissotraidis/kartpad/issues/new?template=bug_report.yml). Export a problem report using the [support guide](docs/SUPPORT.md), review it before sharing, and keep saves, identities and game data private.

</details>

## Build and contribute

WiiCompiled translates PowerPC game code ahead of time; KartPad compiles it for
ARM64 and renders through Vulkan on Android or Metal on Apple platforms.

- [Apple builds](docs/BUILDING.md): prerequisites, Mac self-build and iOS workflows.
- [Android builds](android/README.md): source-only shell and complete runtime.
- [Documentation](docs/README.md): user guides, architecture and release evidence.
- [Current status](docs/STATUS.md) and [maintenance board](docs/MAINTENANCE-BOARD.md):
  accepted results, active work and outstanding tests.

For a bug report, include the exact app/build, device, OS, game, settings and
reproduction steps. Review diagnostics before sharing; never attach game data,
saves, account identifiers or signing material. Use the
[report form](https://github.com/chrissotraidis/kartpad/issues/new?template=bug_report.yml).

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
