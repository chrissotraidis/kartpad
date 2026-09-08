# Install KartPad on Apple Silicon Mac

KartPad 0.4.11 (build 26) is an ad-hoc-signed native arm64 app for Apple Silicon Macs
running macOS 14 or newer. It contains the Original Mario Kart Wii and Retro
Rewind executable profiles but no disc image, extracted game assets, Retro
Rewind pack, saves, account data, or Apple signing identity.

**Update before online play.** This build corrects the console-serial collision
reported in [#94](https://github.com/chrissotraidis/kartpad/issues/94). It preserves
identities, friend codes and saves; existing incorrect server-side history or
bans may need service-admin review. Do not reset identities to work around them.

1. Download `KartPad-v0.4.11-macos.1-arm64.zip` and `SHA256SUMS` from the
   [corrected Mac release](https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.11-macos.1).
2. Run `shasum -a 256 -c SHA256SUMS`, then extract the ZIP and move
   `KartPad.app` to Applications after quitting the old app. Replace only the
   application, not its Application Support folder or your game-data folders.
3. Open KartPad. If Gatekeeper blocks the ad-hoc-signed community app,
   Control-click it, choose **Open**, review the warning, and choose **Open**
   again. Do not disable Gatekeeper system-wide.
4. Choose your own extracted PAL `RMCP01` revision-0 `DATA` folder when asked.
   It must contain both `sys/` and `files/`; KartPad validates the disc identity
   and executable hash before launching.
5. To use Retro Rewind, choose **Data → Choose Retro Rewind Data…** and select
   the `RetroRewind6` folder from the exact supported 6.12.7 full pack. Then
   choose **Game → Retro Rewind**, quit, and reopen KartPad. Use **Game →
   Original Mario Kart Wii** and reopen to switch back. Saves and settings are
   kept separately from the selected game-data folders.

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

## Build it yourself

Install the [Apple build prerequisites](BUILDING.md#prerequisites), then run:

```sh
./scripts/self-build-macos.sh /path/to/your/Mario-Kart-Wii.wbfs
open build/KartPad-self-built.app
```

The workflow fetches and verifies pinned public dependencies and the exact
Retro Rewind inputs, translates both executable profiles from the supported
user-owned image, builds the dual app, configures both private data roots, and
audits the result. Generated inputs and the resulting personalized app remain
ignored local files because KartPad does not clear redistribution rights in
the game-derived material. This publication policy does not restrict your
rights to modify or redistribute GPL-covered software under the GPL; see
[`RIGHTS_AND_LICENSES.md`](../RIGHTS_AND_LICENSES.md).
