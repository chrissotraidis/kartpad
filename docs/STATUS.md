# KartPad status

## Next release preparation: 29 October 2026

The four Classic runtime correction PRs are merged. The integrated source at
`c3829dfc` passed full Android/iOS builds and clean Mac/iOS PadMint player builds.
The parent [#536](https://github.com/chrissotraidis/kartpad/pull/536) adds mobile
bloom control, import/build error handling and Mac controller diagnostics.
The [31-issue disposition](ISSUE-TRIAGE-2026-10-29.md) records the exact scope.
The Mac exports now use the current red-K icon. Fresh/update Android and
Original/Retro Classic/Beta race checks passed; the isolated Mac reached both
game modes. The [longer memory comparison](artifacts/2026-10-29/integrated-android.md)
reproduced about 233 MiB retained after different courses and reclaimed by
restart. Missing characters and phone slowdown remain unresolved; local tests
do not establish a fix on affected devices.
The public release is still **0.8.6**; no new release is published by this work.

## Current status: 31 October 2026

**0.8.7 (build 272), prepared 31 October, not yet published:** makes the Android WiiCompiled 0.9 (Beta) engine much faster by no longer pinning its threads to one CPU core (#540) and by reporting real frame times to Android's performance hint (#542); fixes iPhone/iPad builds that couldn't start on some self-signed installs (#530, #541); adds Disable Bloom on Android, iPhone and iPad (#535); refuses Retro WFC and Nintendo addresses in the private-server setting (#520); and fixes the Mac Classic Controller D-pad (#306) and Wii Remote player slot (#476). See the [release notes](releases/v0.8.7.md).

**0.8.6 (build 268), 25 October:** fixes PadMint builds of every target, which stopped in preflight after upstream WiiCompiled turned `aurora-main` into a submodule (#509); gives the game a console country for the online flag and globe (#511); adds Android 30 FPS Races, Simpler Computer Karts and custom GPU drivers on a new ⋯ → Graphics & Performance page; ships the WiiCompiled 0.9 graphics engine on Android as an opt-in beta beside the default Classic engine; ports WiiCompiled fixes through v0.9.0; compiles the Android game pack with a race profile (about 12% less game-thread CPU on an unprofiled course in emulator pairs, pack 13% smaller; [record](artifacts/2026-10-24/pgo-release.md)); and includes the iPhone/iPad save-picker fix (#506), bounded Mii reads (#507) and diagnostic session labels (#508). See the [release notes](releases/v0.8.6.md).

**0.8.5 (build 267), 21 October:** Retro Rewind 6.13.4, Android rumble strength (0–200%), L3/R3 controller mappings for tricks, and a shorter 0.67-second touch item hold on Android and iPhone/iPad. See the [release notes](releases/v0.8.5.md). Gameplay and device testing were skipped at the owner's request; no new graphics or performance fix is claimed.

**0.8.4 (build 266), 20 October:** Android rumble, with device vibration for controllers without a motor (#497); Retro Rewind soundtrack packs on Android and iPhone/iPad (#499); an optional touch item hold (#500); the bone-index Character Graphics Test option for Adreno phones (#498). It also has the PadMint setup wording (#494), builder download retries (#495) and the 16 GB recipe (#490). The [release notes](releases/v0.8.4.md) record what was checked: each new feature in Android emulator races, and PadMint's clean Mac player check. Rumble on a real handheld or a controller with its own motor, soundtrack playback by ear, and the bone-index option on an affected Adreno phone are still unchecked.

**0.8.3 (build 265):** Retro Rewind 6.13.3 support, including the runtime's double-precision fused FP helpers its new game code needs. [Release notes](releases/v0.8.3.md) record what was checked. 0.8.2 fixed Mac repeat builds, keyboard mapping and a Retro model lookup fault ([notes](releases/v0.8.2.md)). The latest published files are on the [releases page](https://github.com/chrissotraidis/kartpad/releases/latest).

**0.8.1 (build 263), 13 October:** Automatic character drawing for Adreno 6xx/7xx is back to 0.7.15, because 0.8.0 hid characters on some Snapdragon phones that had drawn them. It does not fix the Galaxy S24 Ultra ([#104](https://github.com/chrissotraidis/kartpad/issues/104)): Dolphin-style matrix rows were tried on 0.8.1 and the riders stayed invisible. Mac builds accept any RMCP01 image whose extracted game files match.
[PadMint 0.5.1](https://github.com/chrissotraidis/padmint/releases/tag/v0.5.1) (12 October)
builds KartPad for Mac again and for iPhone/iPad on Intel Macs (experimental).
[PadMint 0.5.2](https://github.com/chrissotraidis/padmint/releases/tag/v0.5.2) (15 October) adds GalaxyPad and does not change that KartPad route.
Android gets a ready-to-play APK that now updates itself. iPhone, iPad and Mac
build KartPad with PadMint (the release carries the PadMint inputs) and, from
0.8.0, say when a new version is out. 0.8.0 moves to the latest WiiCompiled
engine, fixes controllers on the Mac, tries a fix for invisible characters on
Adreno 6xx/7xx (not fixed on the Galaxy S24 Ultra, #104), and adds Shake to Trick and a choice of app icons.
Players add their own game data the first time. Work in progress follows
the [current goal loop](CURRENT-LOOP.md); open problems by device are in
[known issues](KNOWN-ISSUES.md).

| Platform | How players get it | State |
| --- | --- | --- |
| Android | Ready-to-play APK from Releases; updates itself from 0.7.14 | Main platform; most open reports |
| iPhone / iPad | Built with PadMint, signed by the player's sideloading tool | Stable on tested devices |
| Apple Silicon Mac | Built with PadMint, or `scripts/self-build-macos.sh` | Experimental |
| Apple TV | Experimental source build | Experimental |

### 0.7.9 to 0.8.1

| Version | What changed | Checked |
| --- | --- | --- |
| 0.7.9 | Ready-to-play downloads (#403); hourly update check (#397) | Android 16 emulators (update and fresh install), iOS Simulator, Mac race |
| 0.7.10 | Startup checks every game file and names missing ones (#370); fatal errors show a message instead of a black screen on iPhone/iPad; Automatic uses the full repack on Snapdragon 8xx (#316); PowerVR logs whether shaders exceed the GPU's inter-stage limit (#304); the ⋯ button hides with a controller (#402) | Emulator (data check, missing file, ⋯ hiding, update and fresh-import races); iPad Pro (fatal message, final IPA); Mac (game runs) |
| 0.7.11 | Game data screens put the extracted folder first and say plainly that a disc image needs your Wii's key; Android imports a zip of the game data; Getting Started explains the Dolphin steps | Emulator: truncated zip refused with a clear message; the release APK reaches a race after a fresh zip import and as an update over 0.7.10 (0.7.3 → 0.7.10 → 0.7.11, data kept); Dolphin's parent folder imports. iPad Pro: release IPA installed in place. Mac: game runs at 60 FPS |
| 0.7.12 | Android draw self-check: once per session one character draw is drawn two ways off screen and the log says `match`, `mismatch` or `inconclusive`; Report a Problem shows the result at the top. Same pack interface as 0.7.11 | Emulator: `match` on normal runs, `mismatch` with a deliberately broken copy (also in the exported log), `match` with the CPU repack on; release APK reaches a race over 0.7.11 (data kept) and after a fresh folder import. iPad Pro: release IPA installed in place and launched. Mac: game runs at 60 FPS. Not yet run on a physical Android phone |
| 0.7.13 | The self-check draws a third copy with the other bone-matrix lookup (`result=indexing` when only that copy draws); Retro Rewind starts on the first Play after downloading it (it used to say "No DVD root is configured"). Same pack interface | Emulator: `indexing` with both layout copies deliberately emptied, `match` on normal runs; Retro Rewind download then Play reaches the game. iPad Pro: installed in place and launched. All files checked by anonymous download against `SHA256SUMS` |
| 0.7.14 | Android updates itself (#377): download, check against `SHA256SUMS` and the signing key, Android confirms. Every game file is checked at import and on the chooser, so an incomplete copy names the missing file before Play (all platforms). Android music and game-sound sliders (#411). Android APK plus PadMint inputs only; no ready-to-play IPA or Mac zip. Same pack interface | Emulator: a 0.7.12-labelled build updated itself to the published 0.7.13 twice (permission page, download, verify, install), save unchanged, game data intact; cancel keeps the old version; full file check on complete and broken data. 344 repo tests |
| 0.7.15 | Retro Rewind 6.13.1 (official pack plus update), required for Retro WFC. iPhone/iPad keep Retro saves and ghosts when replacing the pack. Android save/ghost writes verified before completing; **Help → Cancel Pending Ghost Import**. Compressed Original ghosts imported in replayable form. iPhone/iPad music and game-sound controls. Apple motion: flat device steers straight, shake still works. PadMint Mac bootstrap fetches Retro Rewind and the translator source. Same pack interface | Emulator: the signed APK installs over 0.7.14 with all app data unchanged and reaches a race; fresh zip import reaches a race; Retro 6.13.1 install, Retro race, Retro WFC sign-in, worldwide room and online races (two mid-race room disconnects on the emulator, each recovered); a real compressed Chadsoft ghost imported and replayed. iPad Pro: installed in place with saves/settings unchanged. iPad Simulator: 6.12.8 to 6.13.1 upgrade kept a save. Mac: clean PadMint build. Sound and motion not yet hands-on on an iPhone/iPad |
| 0.8.0 | Build 262. WiiCompiled upstream sync (display lists that overflow the staging batch now draw instead of dropping models; TLS sessions stop cleanly after a failed write). Mac: a connected controller works alongside the keyboard instead of being ignored. Android Adreno 6xx/7xx: native uniform buffers plus character repack for invisible characters (#104, #301). Update notices on iPhone, iPad and Mac. Shake to Trick on Android and iPhone/iPad. App icon choice (red K, Circuit, Mono). Android Fill Screen draws under display cutouts. Android identity/Mii writes keep their recovery request on failure. Retro Rewind error 22010 guidance. PadMint 0.5.1: Intel Mac iPhone builds; Mac builds without Homebrew tools. New pack interface | Emulator: the release-signed APK installs over public 0.7.15 with all 2,076 app data files unchanged and races at 60 FPS; a fresh install imports a game data zip through the Files picker and races. Pixel 9 Pro XL (Mali): a test-signed copy of the same app code updated in place and raced at 60 FPS. iPad Pro: the published iPhone/iPad app with its pack installed in place with 34 critical files unchanged, both games ready; its game code matches the build 261 test that ran Original at 60 FPS. Mac: PadMint player build (Apple Python, empty PadMint folder); controller fix covered by a virtual-controller test. Adreno fix active but still no bodies on the Galaxy S24 Ultra (#104). Mac physical controllers, Shake to Trick and the icon picker not yet confirmed on a hands-on device |
| 0.8.1 | Build 263. Android: Automatic no longer turns on native uniform buffers and the character repack for Adreno 6xx/7xx, as in 0.7.15 (0.8.0's change hid characters on phones that drew them before). Mac: PadMint builds accept any RMCP01 disc image whose extracted game files match, not one exact image. iPhone/iPad: folder-only picker for extracted folders, and imports always report back (#380). Android: Character Graphics Test option for Dolphin-style matrix rows (#104, #301). Same pack interface | Emulator: the release-signed APK installs over published 0.8.0 with all 2,083 app data files unchanged and races; a fresh install imports the game data zip through the Files picker and races. iPad (A16) Simulator: folder picker imports the extracted folder. Mac: PadMint player build from an ISO with a different hash (Apple Python, empty PadMint folder), before tagging and from the published release; app 0.8.1 (263) passes codesign. Adreno behaviour checked by code comparison with 0.7.15 only; no affected phone or physical iPad yet |

**Confirmed by players on 0.7.10:** the OnePlus 15's graphics with Automatic
(#316, closed) and no crashes in 20 minutes of Grand Prix and online play on an
iPad (#310, closed).

### 14 October follow-up

[Issue triage](ISSUE-TRIAGE-2026-10-14.md) records the new 0.8.1 reports and
public replies. A local Android window correction removes the bands reproduced
on Android 14; the Thor itself still needs confirmation. Android also has a
1.5× resolution choice prepared for the next build (#465). The same pass
reproduced a cursor/JNI abort on the Android 14 baseline and prepared a fix
that services cursor changes from the scheduler stack. These changes are not
in the published 0.8.1. The follow-up also fixes short taps being consumed by
one input reader before another, passes a normal fresh-import race, and repairs
the Android fork's CI. A measured vertex-repack CPU optimization and an off-by-default
native bone-index experiment are in the drafts; neither establishes a fix for
#470 or missing Adreno bodies. #475's Mac certificate report prompted a tested
correction to retain PadMint's Python during preflight. [Evidence and remaining
gates](artifacts/2026-10-14/android-input-cpu-renderer.md).

#470's Adreno 810 slowdown is confirmed in logs; the responsible change is
unknown. #472 adds a OnePlus OPD2403 missing-body report with GPU/driver evidence
pending. #380's new follow-up uses an unverified third-party IPA without PadMint,
so it does not establish a failure of the supported 0.8.1 picker.

### What remains

Things decided for later are in the [to-do list](TODO.md). iPhone, iPad and
Mac show update notices from 0.8.0 but still need a PadMint rebuild for each
KartPad release and almost every Retro Rewind update; automatic rebuilds belong
in PadMint.

- **Setup.** 0.7.11 addresses the 4 October Discord confusion: the extracted
  folder comes first, the key requirement is stated up front, and Android takes
  a zip so cloud transfers can't silently drop files.
- **Android 3D drawing.**
  - OnePlus 15 graphics: reporter-confirmed with Automatic in 0.7.10.
    Do not generalize that result to all Adreno 8xx devices.
  - Adreno 6xx/7xx (#104, #301): no automatic fix. The 0.7.12 and 0.7.13
    self-check logs from both phones show character bodies drawing nothing with
    either vertex layout and with either bone lookup on its own. Only the two
    changes together drew bodies on the S24 (white, about 24 FPS, the
    "fix invisible characters" test option). The self-check has answered what
    it can. Shipped in 0.8.0: on Adreno 6xx/7xx, Automatic
    turns off Dawn's uniform-buffer rewrite and repacks character vertices
    (see the [11 October handoff](RESEARCH-HANDOFF-2026-10-11.md#update-12-october-dawn-rewrites-every-uniform-read)).
    On the Galaxy S24 Ultra (Adreno 750) it doesn't help: 0.8.0's log shows
    it active and the self-check still drawing nothing, with the race at 60 FPS
    (#104, 12 October), and it hid characters on Adreno phones that drew them
    in 0.7.15 (Discord, 13 October), so Automatic goes back to 0.7.15's behaviour
    in 0.8.1. Matrix rows shipped in 0.8.1 as a Character Graphics Test option
    and failed on the S24 Ultra (13 October: the option was on, and the riders
    stayed invisible). The Moto G85's 0.8.1 log (#301) still has missing bodies
    with that option off. A OnePlus tablet (#472) shows faces only on 0.8.1
    after the in-app options were tried; the cause isn't confirmed. Next: pass
    each vertex's bone index to the GPU.
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
- **Sound levels (#411):** music and game-sound controls are on Android
  (0.7.14), iPhone/iPad (0.7.15) and Mac. The iPhone/iPad audio session mixes
  with other apps, so Spotify keeps playing; a hands-on check on an iPad is
  still outstanding.
- **Controllers:** ipega and similar fixed in 0.7.6 to 0.7.8, awaiting
  confirmation (#378); single Joy-Cons (#324); Mac Wii Remote with Classic
  Controller Pro (#306). On 0.8.1 a Mac Wii Remote Plus did not connect, and an
  original remote left Controller Settings when a Nunchuk or Classic Controller
  was attached (#476, same path as #306).
- **Game flow and data:** the crash after a cup's last race (#131) doesn't
  happen on 0.7.10 in automated full cups, including at 3x
  ([record](artifacts/2026-10-04/android/131-cup-ceremony-harness.md)); awaiting
  a player retest. AYN Thor black bars remain on 0.8.1 with Fill Screen on
  (#202); a later fullscreen correction is not in 0.8.1. Identity and rating transfer
  (#234); Mac two-player rendering (#127).
- **Performance (#339, patchzyy's request).** Slow phones are limited by one
  CPU core running the game; lowering resolution barely helps. Shipped so far:
  about 14% less game-thread CPU (0.5.1) and 37% less compile CPU (0.7.5).
  The 10 October investigation found where the rest goes and two unmeasured
  candidates (flat-memory locals, PGO). On 14 October, matched emulator pairs
  on Mario Circuit (not in the training profile) used less game-thread CPU with
  PGO; that result is in draft
  [#474](https://github.com/chrissotraidis/kartpad/pull/474), is not shipped,
  and is not phone FPS. An Honor Magic 8 Lite (Snapdragon 6 Gen 4) is much slower
  since the latest update (#470); that is not fixed in 0.8.1. The phone check
  waits until the Thor correction and the Adreno bone-index attempt. **Start at the
  [performance handoff](ANDROID-PERFORMANCE-HANDOFF.md)** for findings,
  the bench and the next steps.
- **WiiCompiled.** 0.8.0 syncs the translator and all four runtimes to
  upstream `bd219e3`; the fork's `kartpad-*` branches point at the 0.8.0 pins.
  Earlier KartPad fixes reached upstream through
  [#244](https://github.com/patchzyy/Wiicompiled/pull/244) and
  [#251](https://github.com/patchzyy/Wiicompiled/pull/251).

### Next versions

- **After 0.8.1, in this order:** the Thor fullscreen correction (#202), then
  one Adreno bone-index attempt (#104, #301, #472), then one phone check of
  draft #474 covering #339 and the Honor Magic 8 Lite slowdown (#470). Do not
  ship that speed change from emulator numbers. See the
  [current loop](CURRENT-LOOP.md).

Status through 29 September (source-only period, 0.5.x packages and earlier
acceptance) is in the [archive](archive/status-2026-09-08-to-09-29.md); before
that, [status through 7 September](archive/status-through-2026-09-07.md).
