# KartPad status

## Current status: 5 October 2026

**Latest release: [KartPad 0.7.10](https://github.com/chrissotraidis/kartpad/releases/tag/v0.7.10) (build 253).**
Downloads are ready to play: the Android APK, the iPhone/iPad IPA and the Mac
app include the game code, and players add their own game data the first time.
PadMint stays an option for building your own copy. Work in progress follows
the [current goal loop](CURRENT-LOOP.md); open problems by device are in
[known issues](KNOWN-ISSUES.md).

| Platform | How players get it | State |
| --- | --- | --- |
| Android | Ready-to-play APK from Releases | Main platform; most open reports |
| iPhone / iPad | Ready-to-play IPA from Releases, signed by the player's sideloading tool | Stable on tested devices |
| Apple Silicon Mac | Ready-to-play ZIP from Releases, or `scripts/self-build-macos.sh` | Experimental |
| Apple TV | Experimental source build | Experimental |

### 0.7.9 and 0.7.10

| Version | What changed | Checked |
| --- | --- | --- |
| 0.7.9 | Ready-to-play downloads (#403); hourly update check (#397) | Android 16 emulators (update and fresh install), iOS Simulator, Mac race |
| 0.7.10 | Startup checks every game file and names missing ones (#370); fatal errors show a message instead of a black screen on iPhone/iPad; Automatic uses the full repack on Snapdragon 8xx (#316); PowerVR logs whether shaders exceed the GPU's inter-stage limit (#304); the ⋯ button hides with a controller (#402) | Emulator (data check, missing file, ⋯ hiding, update and fresh-import races); iPad Pro (fatal message, final IPA); Mac (game runs) |
| 0.7.11 | Game data screens put the extracted folder first and say plainly that a disc image needs your Wii's key; Android imports a zip of the game data; Getting Started explains the Dolphin steps | Fresh emulator: new screen, truncated zip refused with a clear message, zip import reaches a race, Dolphin's parent folder imports |

**Confirmed by players on 0.7.10:** the OnePlus 15's graphics with Automatic
(#316, closed) and no crashes in 20 minutes of Grand Prix and online play on an
iPad (#310, closed).

### What remains

- **Setup.** 0.7.11 addresses the 4 October Discord confusion: the extracted
  folder comes first, the key requirement is stated up front, and Android takes
  a zip so cloud transfers can't silently drop files.
- **Android 3D drawing.**
  - Adreno 8xx: fixed by Automatic in 0.7.10.
  - Adreno 6xx/7xx (#104, #301): no automatic fix; the character test options
    are the only route.
  - PowerVR (#304): the reporter's 0.7.10 log reached a race and no shader went
    over the Moto G54's limit of 14, so that cause is ruled out. The real cause
    is unknown. Track B adds a draw self-check to the logs.
- **Startup:** Moto G75 crash (#332, no diagnostic yet); iPhone 16 flicker while
  a game opens (#390: the game draws one frame in nine during the safety-screen
  fade; not seen on the iPad Pro).
- **Online over mobile data (#405):** carriers block direct player-to-player
  connections; Wi-Fi or a VPN works. Not fixable in KartPad without a relay.
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

- **0.7.11** (app-only): clearer game data screens and zip import on Android.
  The draw self-check (Track B) follows in a later app release.
- **0.8.0** (pack interface change): WiiCompiled sync plus measured speed work
  from #339.

Status through 29 September (source-only period, 0.5.x packages and earlier
acceptance) is in the [archive](archive/status-2026-09-08-to-09-29.md); before
that, [status through 7 September](archive/status-through-2026-09-07.md).
