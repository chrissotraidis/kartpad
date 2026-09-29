# G8 macOS title, audio, and input

Status: **Pass** on 2026-08-28.

KartPad's native Apple arm64 runtime loaded the complete PAL main DOL plus
`StaticR.rel` graph (29,637 translated functions), ran the Mario Kart Wii intro,
and rendered the title and Select License menu through Aurora, pinned Dawn, and
Metal at the native 60 Hz cadence.

Hands-on Computer Use playtest:

- `Return` produced a Wii Remote A edge and advanced the title to Select License.
- `Right` changed the focused menu item to Options.
- `Left`, then `Return`, opened the New License confirmation.
- `Q`, mapped to Wii Remote 1, returned to Select License.
- SDL key-down edges are latched until the next KPAD sample, so short macOS key
  taps are not lost between guest polls. The runtime log confirms Mario Kart
  polls `KPADGetUnifiedWpadStatus` and `KPADRead` (16 samples).

Audio proof:

- Config was unmuted at master/music/effects/UI/voice gain `1.0`.
- SDL opened the host playback stream at 32 kHz stereo, gain 1.
- A non-silent game PCM block reached the host stream with peak sample 3988 and
  6,372 bytes queued.
- An independent 4.46-second AVFoundation loopback capture of the active Jump
  Desktop Audio output measured mean `-36.2 dB` and peak `-17.6 dB` across
  427,776 samples. Only the numeric analysis is retained; the temporary raw
  game-audio capture is not published.

Evidence:

- `title-screen.jpeg` — Mario Kart Wii title and A-button prompt.
- `final-build-select-license.jpeg` — final audio-instrumented build after A.
- `keyboard-navigation-confirm.jpeg` — second A opens New License confirmation.
- `keyboard-back-navigation.jpeg` — Wii Remote 1 returns to Select License.
- The runtime console log (DOL/REL initialization, Metal, input polling and
  non-silent host playback) is kept privately by the maintainer; runtime logs of
  translated builds are not published.
- `audio-loopback-analysis.txt` — system-output capture metadata and volume
  analysis.

No Simulator was booted and no second game instance was running. Disc content,
NAND, generated translations, caches, and raw captured audio remain private and
ignored.
