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
  <img alt="iPhone and iPad physical builds accepted" src="https://img.shields.io/badge/iPhone%20%2F%20iPad-physical%20builds%20accepted-30D158">
  <img alt="Retro Rewind supported" src="https://img.shields.io/badge/Retro%20Rewind-6.12.7-FF375F">
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
| Android ARM64 | [0.4.10-android.1 · code 21](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.10-android.1) | [Android 9+ with Vulkan](docs/INSTALL_ANDROID.md) |
| iPhone / iPad preview | [0.4.13 · build 29](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.13-ios.1) | [iOS/iPadOS 16+; re-sign the IPA](docs/INSTALL_IPA.md) |
| Apple Silicon Mac | [0.4.11 · build 26](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.11-macos.1) | [macOS 14+](docs/INSTALL_MACOS.md) |
| Apple TV experimental preview | [0.4.11 · build 9](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.11-tvos.1) | [tvOS 17+; re-sign the IPA](docs/INSTALL_TVOS.md) |

Android also has an **[unstable 0.4.13 preview · code 28](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.13-android-preview.1)**
with Retro rating transfer and expanded diagnostics. Physical acceptance remains
pending; it is not a verified graphics, slowdown or online-stall fix.

The iPhone/iPad preview adds a generic ARM64 CPU baseline, KartPad chooser
artwork and richer problem reports. Older-device startup confirmation and
physical acceptance of build 29 remain open. See its
[release notes](docs/releases/v0.4.13-ios.1.md).

Download the checksums and accompanying notices with each package. **Update in
place using the same signing identity; do not uninstall or clear app data.**
Private Android previews use a different signer and need a backed-up migration.

## Playing

- Choose **Mario Kart Wii** or **Retro Rewind** when KartPad opens. Retro
  Rewind 6.12.7 content installs separately; KartPad requires a matching native
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
Retro WFC login, worldwide matchmaking and live racing were owner-reported.
Earlier iPhone/iPad builds have physical gameplay acceptance. These results do
not establish every device, the latest previews, complete online results or
reconnect behavior. Native private-room hosting and Wiimmfi support for
Original remain unfinished. [Online status](docs/ONLINE.md) records the limits.

Startup shader compilation, track-dependent dips and warm slowdown remain
known issues. Android's suggested starting point is **1x Native**. Sustained
60 FPS and external-display output are not generally verified.

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

KartPad is free software under [GPLv3](LICENSE), including its WiiCompiled
modifications and the integrated application where GPLv3 requires. GPL rights
to use, modify and redistribute the software are separate from game-content
rights. See [rights, licenses and Corresponding Source](RIGHTS_AND_LICENSES.md).
Mario Kart, Wii and game imagery belong to their respective rights holders.
KartPad is not affiliated with or endorsed by Nintendo.
