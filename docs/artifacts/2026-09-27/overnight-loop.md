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

