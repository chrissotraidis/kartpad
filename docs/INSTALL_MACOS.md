# Install KartPad on Apple Silicon Mac

> [!IMPORTANT]
> **No Mac download for KartPad 0.7.6.** Earlier Mac apps are no longer
> published. Android and iPhone/iPad are available through [Get KartPad](../README.md#get-kartpad).
> The settings, save and troubleshooting guidance below still applies to
> installed Mac apps.

## Historical Mac installation (0.5.0)

The steps in this section describe an existing local copy of the retired app;
there is no download to obtain here. For a new local development build, see
[Build it yourself](#build-it-yourself).

KartPad 0.5.0 (build 59) was an ad-hoc-signed native arm64 app for Apple Silicon Macs
running macOS 14 or newer. It contains the Original Mario Kart Wii and Retro
Rewind executable profiles but no disc image, extracted game assets, Retro
Rewind pack, saves, account data, or Apple signing identity.

**Update before online play.** This build retains the console-serial correction
reported in [#94](https://github.com/chrissotraidis/kartpad/issues/94). It preserves
identities, friend codes and saves; existing incorrect server-side history or
bans may need service-admin review. Do not reset identities to work around them.

1. If you already have the retired `KartPad-v0.5.0-macos-arm64.zip` and its
   matching `SHA256SUMS.txt`, verify that existing copy before using it.
2. Run `shasum -a 256 KartPad-v0.5.0-macos-arm64.zip` and compare the
   result with the ZIP row in `SHA256SUMS.txt`. The shared source archive is optional
   for normal installation. Then extract the ZIP and move
   `KartPad.app` to Applications after quitting the old app. Replace only the
   application, not its Application Support folder or your game-data folders.
3. Open KartPad. If Gatekeeper blocks the ad-hoc-signed community app,
   Control-click it, choose **Open**, review the warning, and choose **Open**
   again. Do not disable Gatekeeper system-wide.
4. Choose your own extracted PAL `RMCP01` revision-0 `DATA` folder when asked.
   It must contain both `sys/` and `files/`; KartPad validates the disc identity
   and executable hash before launching.
5. To use Retro Rewind, choose **Data → Choose Retro Rewind Data…** and select
   the `RetroRewind6` folder from the exact supported 6.12.8 full pack. Then
   choose **Game → Retro Rewind**, quit, and reopen KartPad. Use **Game →
   Original Mario Kart Wii** and reopen to switch back. Saves and settings are
   kept separately from the selected game-data folders.

If **Unsupported Retro Rewind Data** appears, use the exact pack version shown
in the alert. A newer pack needs a KartPad build that explicitly supports it;
check the notes for your installed build before changing the content. KartPad
does not automatically update Retro Rewind.
Keep your existing data and saves; a rejected folder selection does not modify
the folder.

## Menus and input

- **Game** switches the game for the next launch and opens display/audio
  settings.
- **Data** changes validated data folders, manages Miis, and opens data/cache
  locations.
- **Controls → Controller Settings…** detects and maps ordinary SDL-compatible
  controllers for up to four local players. **Control Reference…** shows every
  keyboard binding.
- Keyboard defaults are `WASD` steering, `U`/Return accelerate and confirm,
  `M`/Delete brake/back, `E` drift, Left Shift item, arrows tricks, Space
  pause, and Tab select.
- The mouse or trackpad operates native menus and settings. The cursor remains
  visible, but Mario Kart Wii has no mouse-driving control; use the keyboard or
  a mapped controller during gameplay.
- Direct Wii Remote/Nunchuk pairing is experimental and macOS-only.

Configuration and saves live under `~/Library/Application Support/KartPad`.
Regenerable graphics caches live under `~/Library/Caches/KartPad`. Replacing
the app does not remove either folder, but back up important saves before
manually deleting application data.

## Experimental Wii Remote and Nunchuk

Enable **Controls → Experimental Wii Remote + Nunchuk**, use the Wii Remote's
red **SYNC** button to pair, attach the Nunchuk, then select **Wii Remote +
Nunchuk (Experimental)** in Controller Settings. The intended hardware is an
original `RVL-CNT-01` or Wii Remote Plus `RVL-CNT-01-TR`.

This opt-in path pairs through the Mac's Bluetooth hardware without a DolphinBar
and hands input to SDL. It uses private macOS Bluetooth interfaces and is not a
Mac App Store workflow. Actual pairing, Nunchuk input, reconnect and long-session
behavior need wider hardware testing. iPhone/iPad do not provide this direct
pairing path; a similarly named informational menu is not support for it.

## Build it yourself

This is a developer workflow, separate from PadMint's mobile game packs.
It currently accepts the exact pinned development WBFS by full-image SHA-256;
it does not have the pack builder's provisional ISO/RVZ acceptance. A different
dump is rejected even if its filename says RMCP01. See the
[Apple source-build guide](BUILDING.md#mac-self-build) for the pinned-input checks.

Install the [Apple build prerequisites](BUILDING.md#prerequisites), then run:

```sh
./scripts/self-build-macos.sh /path/to/your/Mario-Kart-Wii.wbfs
open build/KartPad.app
```

The workflow fetches and verifies pinned public dependencies and the exact
Retro Rewind inputs, translates both executable profiles from the supported
user-owned image, builds the dual app, configures both private data roots, and
audits the result. It also launches the local app to set `dvd_root` and
`retro_rewind_root` in your existing KartPad configuration. Back up that
configuration and important saves before running it if you already use the Mac
app. Generated inputs and the resulting personalized app remain
ignored local files because KartPad does not clear redistribution rights in
the game-derived material. This publication policy does not restrict your
rights to modify or redistribute GPL-covered software under the GPL; see
[`RIGHTS_AND_LICENSES.md`](../RIGHTS_AND_LICENSES.md).
