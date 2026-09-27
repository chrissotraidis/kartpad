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

