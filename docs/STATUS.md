# KartPad status

## Current status: 9 October 2026

**Latest release: [KartPad 0.7.15](https://github.com/chrissotraidis/kartpad/releases/tag/v0.7.15) (build 260).**
Android gets a ready-to-play APK that now updates itself. iPhone, iPad and Mac
build KartPad with PadMint (the release carries the PadMint inputs). 0.7.15
moves Retro Rewind to 6.13.1, which Retro WFC needs for online play.
Players add their own game data the first time. Work in progress follows
the [current goal loop](CURRENT-LOOP.md); open problems by device are in
[known issues](KNOWN-ISSUES.md).

| Platform | How players get it | State |
| --- | --- | --- |
| Android | Ready-to-play APK from Releases; updates itself from 0.7.14 | Main platform; most open reports |
| iPhone / iPad | Built with PadMint, signed by the player's sideloading tool | Stable on tested devices |
| Apple Silicon Mac | Built with PadMint, or `scripts/self-build-macos.sh` | Experimental |
| Apple TV | Experimental source build | Experimental |

### 0.7.9 to 0.7.15

| Version | What changed | Checked |
| --- | --- | --- |
| 0.7.9 | Ready-to-play downloads (#403); hourly update check (#397) | Android 16 emulators (update and fresh install), iOS Simulator, Mac race |
| 0.7.10 | Startup checks every game file and names missing ones (#370); fatal errors show a message instead of a black screen on iPhone/iPad; Automatic uses the full repack on Snapdragon 8xx (#316); PowerVR logs whether shaders exceed the GPU's inter-stage limit (#304); the ⋯ button hides with a controller (#402) | Emulator (data check, missing file, ⋯ hiding, update and fresh-import races); iPad Pro (fatal message, final IPA); Mac (game runs) |
| 0.7.11 | Game data screens put the extracted folder first and say plainly that a disc image needs your Wii's key; Android imports a zip of the game data; Getting Started explains the Dolphin steps | Emulator: truncated zip refused with a clear message; the release APK reaches a race after a fresh zip import and as an update over 0.7.10 (0.7.3 → 0.7.10 → 0.7.11, data kept); Dolphin's parent folder imports. iPad Pro: release IPA installed in place. Mac: game runs at 60 FPS |
| 0.7.12 | Android draw self-check: once per session one character draw is drawn two ways off screen and the log says `match`, `mismatch` or `inconclusive`; Report a Problem shows the result at the top. Same pack interface as 0.7.11 | Emulator: `match` on normal runs, `mismatch` with a deliberately broken copy (also in the exported log), `match` with the CPU repack on; release APK reaches a race over 0.7.11 (data kept) and after a fresh folder import. iPad Pro: release IPA installed in place and launched. Mac: game runs at 60 FPS. Not yet run on a physical Android phone |
| 0.7.13 | The self-check draws a third copy with the other bone-matrix lookup (`result=indexing` when only that copy draws); Retro Rewind starts on the first Play after downloading it (it used to say "No DVD root is configured"). Same pack interface | Emulator: `indexing` with both layout copies deliberately emptied, `match` on normal runs; Retro Rewind download then Play reaches the game. iPad Pro: installed in place and launched. All files checked by anonymous download against `SHA256SUMS` |
| 0.7.14 | Android updates itself (#377): download, check against `SHA256SUMS` and the signing key, Android confirms. Every game file is checked at import and on the chooser, so an incomplete copy names the missing file before Play (all platforms). Android music and game-sound sliders (#411). Android APK plus PadMint inputs only; no ready-to-play IPA or Mac zip. Same pack interface | Emulator: a 0.7.12-labelled build updated itself to the published 0.7.13 twice (permission page, download, verify, install), save unchanged, game data intact; cancel keeps the old version; full file check on complete and broken data. 344 repo tests |
| 0.7.15 | Retro Rewind 6.13.1 (official pack plus update), required for Retro WFC. iPhone/iPad keep Retro saves and ghosts when replacing the pack. Android save/ghost writes verified before completing; **Help → Cancel Pending Ghost Import**. Compressed Original ghosts imported in replayable form. iPhone/iPad music and game-sound controls. Apple motion: flat device steers straight, shake still works. PadMint Mac bootstrap fetches Retro Rewind and the translator source. Same pack interface | Emulator: the signed APK installs over 0.7.14 with all app data unchanged and reaches a race; fresh zip import reaches a race; Retro 6.13.1 install, Retro race, Retro WFC sign-in, worldwide room and an online race (one mid-race room disconnect, recovered); a real compressed Chadsoft ghost imported and replayed. iPad Pro: installed in place with saves/settings unchanged. iPad Simulator: 6.12.8 to 6.13.1 upgrade kept a save. Mac: clean PadMint build. Sound, motion and ghost replay not yet hands-on on an iPhone/iPad |

**Confirmed by players on 0.7.10:** the OnePlus 15's graphics with Automatic
(#316, closed) and no crashes in 20 minutes of Grand Prix and online play on an
iPad (#310, closed).

### What remains

Things decided for later are in the [to-do list](TODO.md), starting with
updates on iPhone, iPad and Mac (only Android updates itself).

- **Setup.** 0.7.11 addresses the 4 October Discord confusion: the extracted
  folder comes first, the key requirement is stated up front, and Android takes
  a zip so cloud transfers can't silently drop files.
- **Android 3D drawing.**
  - Adreno 8xx: fixed by Automatic in 0.7.10.
  - Adreno 6xx/7xx (#104, #301): no automatic fix. The 0.7.12 and 0.7.13
    self-check logs from both phones show character bodies drawing nothing with
    either vertex layout and with either bone lookup on its own. Only the two
    changes together drew bodies on the S24 (white, about 24 FPS, the
    "fix invisible characters" test option). The self-check has answered what
    it can; the next step is a different way of handing the bone matrices to
    the GPU, a decision for Chris (see [the loop](CURRENT-LOOP.md), B2).
  - PowerVR (#304): 0.7.12's log shows character pieces "exploding" with both
    vertex layouts, so the vertex layout isn't the cause; the shader limit was
    ruled out on 4 October. A 0.7.13 log was requested.
- **Startup:** Moto G75 crash (#332, no diagnostic yet); flicker while a game
  opens on the iPhone 16 and iPad Air 4th gen (#390: the game draws one frame
  in nine during the safety-screen fade). Both are 60 Hz screens; it isn't seen
  on the 120 Hz iPad Pro or on a simulated iPhone 16 (0.5.1, 4,225 frames
  checked). Needs a real 60 Hz device to reproduce.
- **Online over mobile data (#405):** carriers block direct player-to-player
  connections; Wi-Fi or a VPN works. Not fixable in KartPad without a relay.
- **Sound levels (#411):** in progress. Android has ••• → **Sound…** (merged,
  #419); iPhone/iPad is in #420 and needs a tap-through on the iPad; the Mac
  already has Game → Game Settings… → Audio. Ships in the next 0.7.x release
  once heard on a device.
- **Controllers:** ipega and similar fixed in 0.7.6 to 0.7.8, awaiting
  confirmation (#378); single Joy-Cons (#324); Mac Wii Remote with Classic
  Controller Pro (#306).
- **Game flow and data:** the crash after a cup's last race (#131) doesn't
  happen on 0.7.10 in automated full cups, including at 3x
  ([record](artifacts/2026-10-04/android/131-cup-ceremony-harness.md)); awaiting
  a player retest. AYN Thor screen area (#202); identity and rating transfer
  (#234); Mac two-player rendering (#127).
- **Performance (#339, patchzyy's request).**
  - Runtime: candidate 203 (skip unobserved FP status capture, game-thread
    Performance Hint) cut game-thread CPU in a 12-player Cookie Land battle on
    the Pixel 9 Pro XL from 14.70–14.79 ms to 12.65 ms and shipped in 0.5.1
    ([ledger](artifacts/2026-09-23/android-copy-stream-loop.md)); candidate 205
    was rejected.
  - Compile: the `-g0` change cut compile CPU from 2,232 s to 1,404 s (0.7.5).
  - Next: same-machine baselines, then one candidate at a time (Track C).
- **WiiCompiled.** KartPad's runtime is based on upstream `8346376`; upstream
  has since merged macOS support, PSQ fallback fixes and a shader wait screen.
  Draft #384 is the start of the sync, which changes the pack interface and
  ships as **0.8.0**. Earlier KartPad fixes reached upstream through
  [#244](https://github.com/patchzyy/Wiicompiled/pull/244) and
  [#251](https://github.com/patchzyy/Wiicompiled/pull/251); the next candidates
  are in Track D.

### Next versions

- **0.7.11** (released 5 October): clearer game data screens and zip import on
  Android.
- **0.7.12** (released 5 October): the Android draw self-check (Track B1).
  Next is reading the reporters' self-check lines (B2).
- **0.8.0** (pack interface change): WiiCompiled sync plus measured speed work
  from #339.

Status through 29 September (source-only period, 0.5.x packages and earlier
acceptance) is in the [archive](archive/status-2026-09-08-to-09-29.md); before
that, [status through 7 September](archive/status-through-2026-09-07.md).
