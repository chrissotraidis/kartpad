# Overnight loop, 27–28 September 2026 (JST)

Goal: keep working open issues until 07:00 JST with Android first; verify on the Android emulator,
iPhone/iPad simulators and macOS; physical devices in the morning. Nothing pushed or published.

## 22:15 check-in: new evidence

| Issue | Who / device | New evidence | Action |
| --- | --- | --- | --- |
| #330 (new) | S25+ (SM-S936U), 0.5.4 | Video: after returning from the background the race timer runs about 6–7 s per real second for the rest of the clip | Root cause found and fixed (below) |
| #102 | itsgeri, Z Fold 8 (Adreno 840) | All-draws option: Original "flawless"; Retro loses other karts and item boxes | Advised per-mode option; Retro-only loss still open |
| #166 | Nemesis2478, HONOR (Adreno 829) | All-draws option fixed the texture glitches | Closed as fixed by the option; answered stutter / 120 FPS questions |
| #193 | TheBiggieSmalls, S24 Ultra (Adreno 750), 0.5.4 | "Fix invisible characters" active (`repack mode=on`, `shader_variant=constant`); only eyes and mustache draw | Narrowed to skinned (per-vertex matrix) draws; next investigation |
| #196 | XopticW, iPhone 17 Pro Max, 0.5.3 | Crash gone; "Mario Kart Wii works flawlessly"; Retro stutters first laps; Retro online won't load | Asked what happens online |
| #135 | A10X iPad, 0.5.3 | Worse: 10 FPS course select, 20 FPS mode/class menus (was 35–40) | 3a688ad (#327) is strictly faster; suspect first-launch background prewarm on 3 cores; asked about a second launch |

## #330: game runs too fast after the background (Android)

- **Cause:** `AdvanceRetrace` records `lastRetrace = lastRetrace + interval`, not "now", so after
  a pause of N seconds `AdvanceDueRetraces` sees N×60 retraces as due and runs them back to back
  (up to 8 per poll, every poll) until it has replayed the whole pause. On Android the game thread
  is not blocked by presentation (native-rate FIFO runs on a separate presenter; see
  `best_present_mode`), so the game runs as fast as the phone allows: faster phone, faster game,
  exactly as reported.
- **Fix:** `vi_pacing::NextRetraceStamp` (runtime `src/hle/vi_pacing.h`): a backlog longer than
  3 s is dropped and the clock resyncs to now; shorter stalls (loading is 1.5–2 s) catch up as
  before. Logged as `[vi] dropped N ms retrace backlog after a stall` (first 20). Same change in
  the Android, iOS, macOS and tvOS runtimes (`cbfbc44`, `d147801`, `5d469a1`, `d83c777`; pinned in
  `4674dfa8`).
- **Checks:** `runtime/tests/vi_pacing_tests.cpp` passes in all four runtimes; the Android unity file
  containing `vi.cpp` compiles with the real NDK flags; iPhone 16 simulator with the fix, process
  paused 30 s with SIGSTOP during the attract demo: log shows `dropped 31508 ms retrace backlog` and
  play continues normally.
- **Why the simulator can't show the bug itself:** the same pause on the unfixed simulator build
  also looked normal (title screen held ~11 s in both runs). Apple presentation waits for vsync on
  the game thread, which caps the replay at 60 FPS; this is why #330 is an Android report. The
  Android emulator runs the game slower than real time, so it can't show it either.
- **Morning check (Pixel):** start a race, press Home for 60 s, return: the race timer should
  advance one second per second, and the exported log should show the `dropped … backlog` line.


## 23:00–23:45

### #193 (S24 Ultra, invisible bodies): eligibility ruled out

- Added a mode-2 log line for skinned (PNMTXIDX-direct) draws that keep the dynamic lookup
  (runtime `4624085`, pinned in the parent).
- Build 0.5.5-test4 / 236 on the emulator, "fix invisible characters" option, A-spam through
  character select, kart select and the race intro: **no skipped recipes**; 11 constant-lookup
  shader variants, all `postex=20 nrm=10`. So on the S24 the bodies vanish inside the constant
  shader itself. The one untested change on that path is `2ff436e` (texture-matrix indices through
  the same switch), which 0.5.4 does not have. Needs a test build on an S24.

### #135 (A10X iPad): real regression, not the first-launch preparation

- Tester: still 10 FPS on course select after a second full launch. `3a688ad` (#327) only adds a
  failed fast-path check before the same slow read, so it can't explain 35 → 10 FPS. Asked for a
  Report a Problem export from course select.

### Simulator input for iOS checks

- iOS runtime `eecd79e`: `KARTPAD_SIM_INPUT="A@5000,DOWN@7000,A@7500+20000"` presses GameCube
  buttons on port 0 (simulator builds only, `TARGET_OS_SIMULATOR`). Pass with
  `SIMCTL_CHILD_KARTPAD_SIM_INPUT=… xcrun simctl launch`. A press every 1.5 s from 8 s reaches a
  50cc Grand Prix race on Luigi Circuit; the race timer ran 30.5 s over 30 s of wall time.

### #304 (PowerVR BXM-8-256): Dawn rejects the only GPU

- Moto G54 log: `Insufficient Vulkan limits for maxInterStageShaderVariables` → no adapter.
  PowerVR reports the Vulkan floor of 64 components; our Dawn (`b0fd045`) requires 72
  (16 × 4 + 8). Upstream Dawn main (`99807f3`) added `VulkanRelaxMaxInterStageShaderVariables`,
  accepting 14 variables on ImgTec. KartPad's GX shaders use at most 14 locations (2 lighting +
  2 colors + 2 channels + 8 texcoords).
- New `prototypes/stabilization/dependencies/dawn-imgtec-interstage-floor.patch`: accept the 64
  floor on ImgTec (this Dawn's PhysicalDevice can't see instance toggles, so no toggle), plus an
  Android test property `debug.kartpad.dawn_interstage_floor=1` that makes any GPU report the floor.
  Built with `build-dawn-android.sh` (seed restored from the pinned 13abc3bc archive): identity
  `70112ffd…`, archive `014027e7…`, library `a6ad79d7…`, CMake targets unchanged (`f914f68f…`).
  `package-dawn-android.py` gained `--identity` (default unchanged).
- Test build 0.5.5-test5 / 237 uses it through a temporary local lock edit (restored; production
  lock unchanged). Next: emulator with the test property set.


## 23:45–00:20

### #304 PowerVR: emulator check of the Dawn patch

- 0.5.5-test5 / 237 (release signer `c1dbe0a0…`, patched Dawn `70112ffd…`) with
  `debug.kartpad.dawn_interstage_floor=1`: adapter `ready`, Luigi Circuit race renders with no
  shader or pipeline errors in the log. The log didn't print the limit, so runtime `35257c4` adds
  `Adapter maxInterStageShaderVariables: N`; build 238 carries it. Property reset to 0 afterwards.
- Replied on #304 with the cause, and that it's unverified on a real PowerVR phone.

### Retro Rewind on the iPhone simulator

- Pack 6.12.8 downloaded from the pinned URL (sha `9dc9f689…`, matches `RetroRewindRelease`) and
  extracted into the simulator app's `Library/Application Support/KartPad/RetroRewind`.
- With scripted input: title → license → Single Player → 200cc SNES Mario Circuit 1 race; and
  Retro WFC → privacy notice → Permit → "Connecting to Retro WFC…" → VS Worldwide (197 players) →
  Retro VS → character select → joined a live room. Left immediately. So Retro online works on
  current iOS source; #196's "won't load me in" needs the tester's details.

### Build notes

- `scripts/build-android-game-app.sh` rejects `~/GitHub/kartpad/build/dolphin-android-discio-jni`
  (pre-RVZ). Use `build/discio-rvz2-jni` in this worktree.
- For a Dawn test build, point `dependencies.lock.json` at the local archive, start the build, then
  restore the production lock (`work/dawn-imgtec/dependencies.lock.production.json`). The build only
  reads the lock at dependency preparation.


## 00:20–00:30

- **#304 confirmed on the emulator:** build 0.5.5-test6 / 238, floor forced: log shows
  `Adapter maxInterStageShaderVariables: 14` (the relaxed path), adapter ready, character select
  and races render. Without the patch this GPU configuration returns "No supported adapters".
  Remaining gate: a real PowerVR BXM phone (Moto G54, #304).
- **#330 on macOS:** Mac runtime built with the pacing change (`build/macthp/runtime-build/RetroRewind`,
  contains the `retrace backlog` string); compiles and links cleanly.
- **#313 (Honor X7c, Adreno 610):** tester sent a 0.5.0 export. Main thread 86% busy, 29.5 ms CPU per
  frame, pipelines all built (`queued=0`), FPS 51 → 24 as the race went on at 0.5× resolution:
  CPU-bound. Asked for the same on 0.5.4.
- **#101 (Fill Screen, iPhone 15 Pro Max):** screenshot shows the 3D and HUD stretched horizontally,
  as expected for a 4:3 game shown full width without widening the projection. Not changed tonight.


## 00:35

- **#101 (Fill Screen):** iPhone 16 simulator, Fill Screen (`SunPadAspectRatioMode=2`), Luigi Circuit:
  3D is Hor+ and correctly proportioned (screenshot `work/issue101/fill.png`); only the 2D HUD is a little
  wide. The report's 7 Sep screenshot predates the dynamic EGG canvas. Asked the reporter to recheck on
  0.5.3. Simulator setting restored to Original.

## Morning checks on physical devices

1. **Pixel, #330:** start a race, Home for 60 s, return. The timer should advance 1 s per second, and the
   exported log should show `[vi] dropped … ms retrace backlog after a stall`.
2. **Pixel, crash prompt:** force a crash (`adb shell am crash <game pid>`), reopen KartPad, save the ZIP from
   the prompt, and confirm the GitHub draft opens.
3. **Pixel, regression pass on the newest test APK:** Original and Retro race, one online race, and
   Automatic character mode shows `repack mode=off source=auto` (the Pixel isn't Adreno).
4. **iPad, #330 and #327:** Home for 60 s mid-race, return, and confirm normal speed. Cup select stays at 60 FPS.
5. **Still needs testers' phones:** #304 PowerVR (Moto G54), #193 S24 (runtime `2ff436e`), #102 Retro on
   Z Fold 8 with all-draws, #135 A10X course select.

Test APKs, all signed with the release key `c1dbe0a0…`: `work/android238/kartpad-238.apk` is the newest
(pacing fix, crash prompt, Automatic mode 1, PowerVR Dawn patch, #193 logging).


## 00:40 GPU and symptom table, from every issue's logs

| GPU (driver date) | Phone | Symptom | Issue |
| --- | --- | --- | --- |
| Adreno 610 | Honor X7c, Redmi Note 11 | renders; CPU-bound (Honor X7c 29 ms/frame) | #313, #303 |
| Adreno 618 | — | slow | #275 |
| Adreno 619 (Jan 2026) | Moto G85 | **invisible bodies, only eyes and face**; CPU 17–22 ms/frame | #301 |
| Adreno 619 (May 2025) | Galaxy Tab S7 FE | "graphics different", crash before first race | #102 |
| Adreno 650 | Retroid Pocket 5 | renders perfectly; frame drops | #103 |
| Adreno 732 | Xiaomi Pad 7 | renders correctly | #166 |
| Adreno 740 | ROG Phone 7S | launch crash (debug labels), fixed in 0.5.1 | #321 |
| Adreno 750 (Jun and Sep 2025) | S24 Ultra, Lenovo TB710FU | **invisible bodies, only eyes and mustache**; option 1 and "invisible" option don't help | #104, #193, #211, #323 |
| Adreno 829 / 840 | HONOR, Z Fold 8, OnePlus 15, S26, Red Magic 11 | **vertex explosion**; option 1 fixes characters, option 2 also fixes textures (Original); Retro loses karts on Fold 8 | #102, #137, #166, #308, #316 |

So "invisible bodies" spans two generations (619 and 750) while 650/732 are fine. It is not tied to one
GPU model, and Automatic (8xx only) does not cover it. #301 was asked to try option 1 on 0.5.4; its
result decides whether 619 behaves like 750.

#301 also reports the game "freezing while FPS shows 60 unless given constant input". Its 0.5.0 log
is CPU-bound (84–90% main-thread occupancy). The #330 backlog cap may change how a starved guest
thread recovers; recheck with the reporter after the next build.


## 00:50 #135 (A10X iPad slower since 0.5.1)

- Build 60's runtime (`36e5f73`) prewarmed 128 pipelines at launch. Since 0.5.1 the runtime keeps 512
  (~460 MB) and, once per OS build, compiles every recorded recipe (up to 4096) in the background. The
  warm-up marker is only written when that pass finishes, so on a slow 3-core A10X with 4 GB it can restart
  every launch. That matches "10 FPS on course select, still 10 after a second launch".
- Fix (iOS `$(git -C vendor/runtimes/ios log --oneline -1 | cut -c1-7)`, macOS matching for parity): under 6 GB, retain 128 and skip the
  warm-up pass; 6 GB+ unchanged. New log line `Pipeline prewarm plan: retain N, warm-up pass yes/no`.
  Test override `KARTPAD_PREWARM_LOW_MEMORY=1`.
- Simulator: normal launch "retain 512 … 511 pipelines in 0.2 s"; forced low-memory "retain 128, warm-up
  pass no (under 6 GB) … 128 pipelines", scripted run reaches a Luigi Circuit race normally.
- Trade-off: after an iOS update, low-memory devices can stutter once on each first-seen effect in races
  (as build 60 did). Morning check: none here; needs the A10X tester.

## 00:55 #101 follow-up and #135 reply

- Kode-Z retested 0.5.3 on iPhone 15 Pro Max (2796x1290): 3D proportions match the simulator's Hor+ view,
  but 2D HUD elements (countdown, place, timer) are visibly wide. Open item: 2D layout in Fill Screen.
- Told #135 the likely cause and that the next update restores the lighter launch prewarm under 6 GB.

## 01:00 #101: HUD measurement (temporary probe, removed)

Logged every orthographic projection in a Luigi Circuit race on the iPhone 16 simulator (2556x1179, 2.17:1):

- Original 4:3: race HUD layout 608x527 (1.15:1) shown in a 4:3 viewport, so the game's own HUD is
  about 1.16x wide there too; that is how the Wii draws it.
- Fill Screen: the same layout becomes 1016x527 (1.93:1) in a 2.17:1 viewport, about 1.13x wide.
- So Fill Screen's HUD is no wider, relative to its height, than the original 4:3 game. Screenshots side by
  side (`work/profile/ortho-0.png`, `ortho-2.png`) agree. The "stretched" impression on #101 is most
  likely the wider field of view (Hor+), which makes nearby geometry at the screen edges look pulled
  sideways, not a HUD bug. Not replying again until there's something concrete; the earlier reply
  overstated the HUD point and should be corrected with any follow-up.

## 01:05

- Android emulator build 238 log: exactly one `[vi] dropped 76190 ms retrace backlog` after the app sat in the
  background; none during normal slow emulator play, so the cap doesn't fire on a merely slow device.
- Dawn upstream (`99807f3`) vs ours: no new Qualcomm-specific toggles, so no upstream driver workaround to
  borrow for #193/#301.
- #101 closed: reporter says Fill Screen looks fine after trying again.
- Started the iPad device build `build/ios88` (tmux `kp-ios88b`) for the morning test.
- Morning handoff written to `docs/artifacts/2026-09-28/morning-handoff.md`.

## 01:15 #301 idle freeze: not reproduced on the simulator

- iPhone simulator, Class select left with no input for ~6.5 min, screenshot every 20 s: every consecutive pair
  differs (menu keeps animating). So the report is Android- or device-specific; the Pixel morning pass
  includes 5 min idle on a menu.


## 01:05

- #313: tester's email reply mentions a new export that GitHub didn't attach (email replies drop files). Asked him to upload in the browser and confirm the version.
- #119 (system bars): emulator build 238, swipe down/up shows the bars during a game; they hide again within ~6 s both times. Asked the reporter to recheck on 0.5.4.


## 01:40 #313 on 0.5.4

- Honor X7c (Adreno 610), 0.5.4/232, 0.5x, 16:9: race main-thread CPU 36-42 ms per frame (88-92% busy), 20-25 FPS; worst 70-78 ms/frame (12-13 FPS) in some stretches; first launch after update queued 403 pipelines. Thermal 0, no power save. Same CPU-bound profile as 0.5.0 (29 ms at 24 FPS in a different scene): 0.5.4 did not move this phone. Told the tester plainly; no more files needed.


## 02:10

- #196: Retro online "just keeps searching" on iPhone 17 Pro Max; the simulator joined a live room on current source. Asked for a Report a Problem export after 2 min of searching and Wi-Fi vs mobile data (#206 showed mobile-data matchmaking failing with 86420).

## 02:45 #135 report disproves the prewarm theory; change reverted

- Report KP-4C6A7EF8 (iPad7,3 = iPad Pro 10.5 A10X, 3 cores, 4 GB, 0.5.3/87): every launch logs
  "Pipeline prewarm finished: ~506 pipelines in 0.5 s, warm-up pass skipped". So the full warm-up was not
  running and launch prep was not the cause. Footprint ~0.9 GB, fine.
- Frame telemetry: 50-59 FPS in menus, then 17-22 FPS (p50 58 ms) at course select, in all three sessions,
  including one with thermal state 0. Slow presentation jobs show 36-40 ms in drawable acquire, i.e. the GPU
  is behind. Thermal state was "serious" (2) from launch in two of three sessions, which makes it worse.
- Reverted the under-6 GB prewarm change in the iOS and macOS runtimes (revert commits above); the parent pin
  is updated below. Corrected the reply on #135.
- Open: what makes course select GPU-heavy on the A10X since build 60. Candidates to compare with build 60:
  render size (window 1112x834, native 2224x1668 at 1x) and the preview video path. Needs a build 60 vs 87
  frame capture on an A10X-class device.
