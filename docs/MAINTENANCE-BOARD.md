# Maintenance work and test board

## 14 November long-standing issues pass (0.8.10 released, 0.8.11 pending in #570)

All 25 open issues were re-read with their comments, and every attached log was
downloaded again and analysed from the files. Code was checked before any
earlier diagnosis was reused. Tests ran on the arm64 Android emulator
(`KartPad_088_Acceptance_20261107`, started read-only). **Nothing here is phone
evidence.** Nothing was posted on any issue, and #570 was not touched.

**Changed (all unmerged)**

| Change | Where | Checked on the emulator | Not checked |
| --- | --- | --- | --- |
| A game thread whose entry function returns now exits through `OSExitThread` and the scheduler picks the next thread | [wiicompiled#30](https://github.com/chrissotraidis/wiicompiled/pull/30) | The old hand-off logs `failed to switch away while parking` after the first Retro WFC sign-in; with the change, ten sign-ins (41 thread exits) log nothing. Menus, sign-in and an Original Grand Prix race work | Any phone; rooms and online races; the beta engine in play |
| The idle scheduler wakes at the next `OSSleepTicks` deadline instead of a 1 ms slice later | [wiicompiled#31](https://github.com/chrissotraidis/wiicompiled/pull/31) | The main loop's 0.5 ms online sleep takes 0.76 ms instead of 1.6–1.7 ms per frame at the Retro WFC menu | Whether a phone near its limit gains frame rate |
| A `KartPadSched` line after each `KartPadCPU` line: time per game thread, idle time, main-thread sleeps and blocking network waits | [wiicompiled#32](https://github.com/chrissotraidis/wiicompiled/pull/32) (stacked on #30) | Names the movie decoder at the main menu and the sound thread online; appears in the saved diagnostic log | A log from a slow lobby, which is what it is for |
| KartPad's Android pin for the three changes | Draft [#571](https://github.com/chrissotraidis/kartpad/pull/571) | The app builds; the pack interface fingerprint is unchanged (`63fd43a8…`) | — |

**Findings**

- **#554, slow Retro WFC lobby: two runtime faults found, cause of the big
  slowdown still not shown.**
  - *Thread exit.* A game thread that ended by returning from its entry
    function switched straight to the main thread's fiber with the
    running-thread pointer cleared. If the main thread was asleep it carried
    on early, and until it next blocked its `OSSleepTicks` calls returned at
    once, its mutex calls did nothing and a blocking network call would fail
    with −101. Seven of the eight logs in #554 have the trace
    (`OSSleepTicks: thread 0x80347498 failed to switch away while parking`,
    logged once per session, right after the NAS sign-in), and no log from any
    other issue has it.
  - *Idle slices.* Online, the game's main loop sleeps 0.5 ms once per frame
    (not twice, as the 11 November note said). With nothing else runnable
    that sleep lasted 1.6–1.7 ms.
  - *What the logs say about the slowdown.* `elapsed_ms` in these logs is
    device uptime, so each log's distance from a reboot is known. The 0.8.10
    stock-driver log is slow in the lobby from the start of a process that
    began 12 minutes after boot, with no pause in that process (host thread
    69–77% busy, 80–102 ms of CPU per presented frame, first-visit shader
    compiles in the same window). The fresh-reboot Turnip log slows from 54
    to 33 FPS in the lobby with no pause either. So a pause is one trigger,
    not a requirement. In the 0.8.9 before/after pair the picture is
    different: after the pause the host thread is only 37–47% busy while
    frames take 65–100 ms, so more than half of each frame is waiting. The
    graphics present phases stay near 3 ms throughout. In two logs the long
    gaps (0.75–1.3 s without a present) follow GameSpy host-name lookups,
    which block the main thread.
  - *Ruled out by reading the code:* Android's timer slack and process
    groups (on Android 14 the notification shade and volume panel do not
    change them, and the process-level change is symmetric); an alarm or
    audio backlog after the pause (periodic alarms skip missed periods, audio
    catch-up is capped at 100 ms).
  - *Not reproduced:* a Home-screen trip at the Retro Rewind main menu on
    released 0.8.9 left the emulator at 60 FPS (4 ms of CPU per frame; the
    host is too fast to show it).
- **Snapdragon characters (#104, #301, #472, #492, #552): no renderer change;
  the bodies are lost as geometry, whichever way the bone matrices are
  fetched.** In the S24 Ultra's 0.8.8 and 0.8.9 logs the draw self-check
  reports `drawn_game=0 drawn_other=0 drawn_constant=0` on Qualcomm 512.762.1
  for every body draw it tried (117 to 177 vertices), and
  `688/688/688 result=match` on the same phone with Turnip. The three copies
  differ only in how vertices and bone matrices reach the shader, and all
  three cover nothing, so no single fetch method is at fault; the six failed
  attempts each changed one.
  A state dump of the real draws (a local diagnostic build on the emulator,
  Original game, character select, Mario and Bowser) shows what every
  skinned part is drawn with: no alpha test, no blending, depth test
  less-or-equal with depth writes, back-face culling, and one directional
  light on both colour and alpha (spot attenuation with constant terms, the
  light about 1e10 units away). Nothing in that state can discard a pixel, so
  a body that covers nothing was lost before the fragment shader: bad
  positions, clipping, culling or depth. That rules out the lighting and
  alpha paths. It would also fit what players see, if the parts that survive
  (eyes, a moustache) are drawn with a single matrix and the far models that
  still draw (#472) use fewer bones; neither was checked. Bowser alone draws
  on the beta engine (#104), and his skinned parts use the same lighting,
  alpha, blend, depth and cull state as Mario's on Classic, so the difference
  is not there. The dump is
  `tools/android-perf/patches/android-runtime-skinned-draw-state-dump.patch`.
  Renderer Validation, which turns Dawn's validation and buffer robustness
  back on, did not change the picture on the S24 Ultra in September (0.4.12).
  What skinned draws have that the working ones lack is the per-vertex
  matrix choice and the 20-matrix (plus 10 normal-matrix) uniform block.
- **#510: the remaining slow motion is heat on a phone with no headroom.**
  In log11 (0.8.10) memory is 645 MB, Android reports thermal status 1 with
  headroom 0.82 (0.76 at most in the clean four-cup log10), battery 15%, and
  the game thread needs 17–23 ms per frame where it needed 15.6 ms. The
  restarted cup isn't shown to matter.
- **The beta engine already does the "GX off the game thread" step.**
  Released 0.8.9 on the emulator, Luigi Circuit Grand Prix, same 30 s window
  (30 FPS Races was on in this AVD): Classic's game thread used 11.04, 9.58,
  10.97 and 9.73 ms per presented frame; the beta's used 7.92, 7.94 and
  7.41 ms, about a quarter less, with its FIFO thread at 4.6–4.9% of a core.
  The Mac's load average was 4–6, so this is a rough figure.
- **#566 (new, Galaxy S25, Adreno 830, 0.8.10, Retro Rewind at 1×):** the log
  agrees with the report. Game-thread CPU per frame goes from 8–10 ms to
  13–18 ms late in the session and windows fall to 47–59 FPS, while Android
  still reports thermal status 0 (headroom 0.77–0.83, battery 37–39 °C).
  The session is on the beta engine (`renderer=aurora-wiicompiled`). Memory is
  2.0–2.4 GB in every sample and flat across the log's window, with 4,760
  pipelines created since the start. 0.8.9's cache fix was measured on
  Classic; whether the beta engine releases a course's shaders and textures
  wasn't checked.
- **#476:** the reporter's 12 November report on 0.8.10 (remote unassigned
  until set to Player 1; an extension attached after launch drops the remote)
  is the behaviour #569 changes; it is waiting for 0.8.11.
- **#537:** the game's disc-error screen needs a failed file read, and KartPad
  logs `ERROR: DVD read failed` with the file when that happens. Online,
  before a race, the likely read is the voted course from the Retro Rewind
  pack. Unproven without the log.

**Open issues by state**

| Issue | State after this pass | Next step |
| --- | --- | --- |
| #104 #301 #472 #492 #552 Snapdragon characters | Turnip works on two phones. Bodies are lost as geometry in all three self-check copies | Build the geometry self-check below; ask #552, #472, #492 once for a Turnip result. #301's reporter calls Classic fixed with a custom driver; the issue stays open only for his Classic frame rate |
| #554 slow Retro WFC lobby | Two scheduler faults fixed in PRs; the 40–100 ms frames are unexplained | Merge #30–#32, ship, ask for one lobby log with `KartPadSched` lines |
| #510 slow motion after cups | Heat with no CPU headroom; memory fixed | Reply: 30 FPS Races, or try the beta engine at 60 |
| #339 performance | Beta engine measured a quarter lighter on the game thread (emulator) | Phone measurement of Classic against beta; then decide whether Classic needs its own off-thread GX |
| #566 frame rate drops after an hour (S25) | Analysed, heat | Reply; check the beta engine's caches |
| #537 Retro WFC disc-error kick | Waiting since 29 October | Leave open until 0.8.11 is out, then close if silent |
| #304 PowerVR | Waiting since 12 October | Same; the geometry self-check would also serve this GPU |
| #127 Mac two-player rendering | Not run | Needs a Mac build with game data and two controllers |
| #539 LiveContainer import | Waiting since 30 October | Close if silent |
| #475 Mac certificate | Waiting since 31 October; the reply said about two weeks | Close |
| #476 Mac Wii Remote | Fix in 0.8.11 (#569), untested on hardware | Ask the reporter to build 0.8.11 |
| #295 Retro ghosts | Draft #375 | See the table below |
| #534 #531 #449 #300 #234 #203 #100 #91 #90 | Requests | See the table below |

**Requests: feasibility and next step**

| Issue | Judgement | Concrete next step |
| --- | --- | --- |
| #234 identity transfer | Feasible, medium. Online identity is more than the save: console ID, MAC address, serial and the NAND files beside `rksys.dat` | Write the list of files and values that make up the identity, then one export and import on Android, proved by two emulator installs signing in to the local WFC server (`scripts/test-android-local-wfc-server.sh`) as the same profile |
| #295 Retro ghosts | Close to done; draft #375 passes its transfer tests | Replay coverage: one imported ghost per course slot kind (original, retro, custom) on the emulator, then the iPhone picker |
| #300 older iOS and macOS | Unknown until built | Build the iOS app with the deployment target at 15.0 and list what fails (SDL 3, Dawn, UIKit calls). No device here runs iOS 15, so a pass would still be untested |
| #100 external displays | Partly addressed by #567 and #568 in 0.8.11, which have not run on a device | Device check of 0.8.11 over USB-C; [plan](EXTERNAL-DISPLAYS.md) |
| #91 DSU controllers | Feasible, large; scope is written in [FUTURE-FEATURES](FUTURE-FEATURES.md#dsu--cemuhook-motion-controllers-on-apple-tv) | Not started. First piece: a DSU packet parser with tests, no UI |
| #90 Wiimmfi | Not feasible as asked: Wiimmfi's patches change game code and its rules bind a console identity | Decline Wiimmfi; evaluate WiiLink WFC for Original Mario Kart Wii, which uses the same payload mechanism KartPad already pins for Retro WFC |
| #449 LAN play | Feasible in two parts. The server exists (the pinned `wfc-server` the local test uses) | An advanced "WFC server address" setting, and a page on running the server on a computer on the same network. Hosting on a phone is a separate, larger job |
| #203 RMCE01, NAND, cheats | Large. The Android runtime has 586 hooks keyed to PAL addresses | Check that a published PAL-to-NTSC-U address map covers all 586 before promising anything. NAND transfer is #234. Cheats are unscheduled |
| #534 Item Fever | Needs the mod's code changes compiled in | No change |
| #531 Android WBFS extraction | Proposal | No change |

**Not done**

- No phone ran anything. The Poco F4 in #554 is still the test for all three
  runtime changes.
- No room was joined. The Retro WFC lobby in a room is still unprofiled.
- The geometry self-check for Snapdragon characters is described, not built.
- #127 was not run.
- The iOS, macOS and tvOS runtimes have the same scheduler code and none of
  these changes.

### Picking this up (14 November)

1. **Merge the runtime PRs** in this order: wiicompiled#30, #32 (retarget to
   `kartpad-android` once #30 is in), #31. Then move KartPad's pin from the
   test stack (`codex/longstanding-stack`, `e0663e4`) to the merged
   `kartpad-android` head. No header changed, so the 0.8.11 game pack
   still loads.
2. **After a release has them, ask #554 for one log** saved in the slow lobby.
   Read the `KartPadSched` lines: a large `other_threads_ms` names the
   thread to give a preemption point (as the movie decoder got); a large
   `idle_ms` with `net_wait_ms` says the main thread is blocked on the
   network; a large `main_ms` puts it in the main thread itself.
3. **Geometry self-check for Snapdragon characters.** In
   `aurora-main/lib/gfx/kartpad_selfcheck.cpp`, when all copies of a body
   draw cover nothing, replay it three more times off screen and log the
   covered pixels of each: with culling off and the depth test set to
   always; with every vertex forced to the draw's first bone matrix; and
   with the bone matrices read from a small uniform block that holds only
   the ones the draw uses. Also log the draw's clip-space bounds computed on
   the CPU from the same vertices and matrices, so the log says where the
   body should have been. Count any written pixel (clear to a sentinel
   colour, not zero). One log from a 512.762 phone then says whether the
   positions, the per-vertex choice or the large block loses the body.
4. **#510 and #339.** Measure Classic against the beta on a phone, same race.
5. **Housekeeping.** Close #475; close #539, #537 and #304 if still silent
   after 0.8.11; run #127.

**Reproducing the emulator checks.** Build the app only (no header changes,
so an existing pack with fingerprint `63fd43a8…` loads), install it the
way the [11 November notes](#picking-this-up) describe, then:

```sh
adb shell setprop debug.kartpad.thread_exit_reschedule 0   # old hand-off; 1 or unset = fixed
adb shell setprop debug.kartpad.idle_sleep_to_timer 0      # 1 ms idle slices; 1 or unset = fixed
```

Set them before each start. Sign in to Retro WFC, stay on its menu, and read
`sleep_took_ms` in the `KartPadSched` lines. The `failed to switch away`
line is in the session's `console.log` under
`files/KartPad/Logs`, not in logcat. Signing out and in again from the Retro
WFC menu (B, Yes, A) repeats the thread exits; do not press A on the menu
itself, which starts a search on the live service.


## 11 November focus pass (after 0.8.10)

All 24 open issues were re-read and the logs attached to #104, #301, #472,
#510, #552 and #554 were analysed again. Profiling and the fix below ran on
the arm64 Android emulator (`KartPad_088_Acceptance_20261107`, started
read-only, so that AVD is unchanged). Nothing here is phone evidence.

**Status: paused on 11 November.** The documentation from this pass is on
main. The code is not: the runtime change is open as
[wiicompiled#27](https://github.com/chrissotraidis/wiicompiled/pull/27)
(branch `codex/thp-decode-preemption`) and the pin and menu text are in draft
[#564](https://github.com/chrissotraidis/kartpad/pull/564) (branch
`codex/focus-pass-20261111`). [Picking this up](#picking-this-up) has the
order of work and the commands.

**Findings**

- **Snapdragon characters are a Qualcomm 512.762 driver fault.** Every affected
  log is on that driver series: S24 Ultra (512.762.41, then 512.762.1 after an
  Android update), S24 (512.762.1), OnePlus OPD2403 (512.762.41) and Moto G85
  (512.762.45). The Poco F4 and S10 Lite, on 512.502.0, have no character
  problem. Turnip draws every character on the S24 Ultra on both engines and
  on the Moto G85 on Classic. The driver is the fault, and a custom driver is
  the fix players can use today. [KNOWN-ISSUES](KNOWN-ISSUES.md#graphics-android)
  now leads with those steps. Menu text that points Snapdragon players to
  the GPU Driver row is in #564.
- **A low-priority game thread could hold up every frame.** Game threads are
  fibers on one host thread and were never preempted, so the movie decoder
  behind the main and single-player menus ran past the main thread's retrace.
  On the emulator the main menu fell to 15–28 FPS after any hitch and held 60
  with a preemption point in the decoder
  ([measurements](ANDROID-PERFORMANCE-HANDOFF.md#11-november-a-background-game-thread-could-hold-up-every-frame)).
- **#554 is narrowed, not solved.** Every slow sample is in an online menu
  scene; races on the same phone hold 60 FPS at 13–15 ms of game-thread CPU.
  Slow windows sit at four display periods per frame (p50 65–69 ms) with
  40–100 ms of game-thread CPU per frame, in both the Retro WFC lobby (the
  globe scene) and the menu between races. The menu between races starts the
  movie player, so the finding above may cover it; the lobby has no movie
  player and isn't explained. On the emulator the Retro WFC start page costs
  5–9 ms per frame: 64% the main thread, about 30% the game's sound thread and
  audio callbacks, under 1% network processing. The reporter's trigger (a
  notification, the volume panel, KartPad's own menu) is a pause and resume
  of the game. Their accounts differ on whether restarting KartPad is enough
  or only a reboot helps.
- **#510's phone has no headroom.** In the 0.8.10 log the game thread is
  88–95% busy at 15.6 ms per frame while it still holds 60 FPS, and memory
  stays near 650 MB, so 0.8.9's cache fix worked and what remains is CPU
  headroom. 30 FPS Races is the setting for that phone today.

**Changed on the branches (not merged)**

- Runtime: a preemption point at each THP macroblock row
  ([wiicompiled#27](https://github.com/chrissotraidis/wiicompiled/pull/27)).
  The pack interface fingerprint changes. Both Android runtimes build and
  export the new entry point. KartPad's gitlink points at the pull request's
  head until it merges.
- App: on Snapdragon phones the GPU Driver row reads "Phone's driver. Add
  Turnip here if characters are missing." and the Graphics Diagnostics row
  reads "Character tests for Snapdragon phones. Try GPU Driver first." Other
  phones keep the old Graphics Diagnostics text.
- Docs (merged): known issues brought up to 0.8.10; the performance handoff
  has the profile, the fix and its limits.

**Open issues by state**

Confidence is the chance the next step closes the issue without a device in
hand.

| Issue | State | Next step | Confidence |
| --- | --- | --- | --- |
| #104 #301 #472 #492 #552 Snapdragon characters | Workaround confirmed on two phones (Turnip). Cause is the 512.762 driver | Ask #552, #472 and #492 for a Turnip result. A real fix needs a 512.762 phone or a captured failing draw | High for the workaround; low for a renderer fix (six blind attempts failed) |
| #554 slow online menus | Narrowed to online menu scenes. The preemption fix may cover the menu between races; the lobby is unexplained | Ship the fix, then ask for one log. For the lobby, profile a phone in a room or a second local client | Low to medium until a phone runs the fix |
| #510 slow motion after cups | Memory fixed in 0.8.9. Phone is CPU-bound with no headroom | Recommend 30 FPS Races; game-thread speed work in #339 | Medium: 30 FPS Races should hold; 60 FPS needs the #339 work |
| #339 performance | Game thread is the limit. New: no preemption of background game threads. The Pixel 10a reporter's online course-select stutter (8 November) is in the same menu scene; untested | Phone check of the preemption fix; then GX off the game thread | Medium |
| #537 Retro WFC "disc error" kick | Waiting for a 0.8.8+ log since 29 October | Close if silent | Unknown without the log |
| #539 iPhone folder import inside LiveContainer | Waiting for the reporter since 30 October | Close if silent; LiveContainer isn't a supported way to run KartPad | Low |
| #476 Mac Wii Remote extensions | Runtime correction unreleased and untested on a controller | Needs a physical Wii Remote on a Mac | Low |
| #475 Mac PadMint certificate | Waiting; planned to close around 14 November | Close if silent | n/a |
| #304 PowerVR | Waiting for a 0.8.8+ log | Close if silent | Low |
| #127 Mac two-player rendering | Fix shipped in 0.4.17, never confirmed; no report since September | Run two players on a current Mac build and close or reopen with evidence | High that it is already fixed |
| #234 identity transfer | Design work, not started | Backlog | n/a |
| #295 Retro ghosts | Draft #375 | Replay coverage and iPhone check | Medium |
| #534 #531 #449 #300 #203 #100 #91 #90 | Requests | No change | n/a |

**Not done**

- No phone has run the preemption fix. Sharik7's Poco F4 (#554) is the test.
- The iPhone and iPad runtime has the same scheduler and doesn't have the
  change. Those devices are faster, so nobody has reported it there.
- The Retro WFC lobby wasn't profiled in a room: joining public rooms from a
  test client isn't something to do on the live service, and the local WFC
  service needs a second client.
- `scripts/ios_release.py` still reads the 0.5.3 build record, so the
  repository's IPA audit fails on current builds while PadMint's passes. It
  needs moving to the PadMint release layout or deleting.
- The primary checkout at `/Users/chrissotraidis/GitHub/kartpad` is on
  `codex/candidate-cpu-handoff-record`, about 1,100 commits behind main, with
  103 modified or untracked files from September. It wasn't touched.

### Picking this up

In this order. Each step stands alone, so stop after any of them.

1. **Run the fix on a phone.** The owner's Pixel was attached over adb during
   this pass and was left alone. Build a release-signed APK from #564 with
   its own game pack (the pack interface fingerprint changed, so the 0.8.10
   pack won't load), install it over the existing app so data is kept, and
   compare with `adb shell setprop debug.kartpad.guest_preemption 0` against
   `1`, set before each start. Sit on the Retro Rewind main menu for a minute,
   pull down the notification shade, and read the `KartPadPerf` and
   `KartPadCPU` lines. A fast phone may not show the fault; the Poco F4 in
   #554 is the phone that does.
2. **Merge.** Merge wiicompiled#27, move #564's gitlink from the pull
   request's head (`7e5d308`) to the merge commit, then merge #564. Neither
   needs a release by itself.
3. **Ask the reporters once.** After a release has the fix: #554 for one log
   from the menu between online races. Now, without waiting: #552, #472 and
   #492 for a Turnip result. Nothing was posted on any issue in this pass.
4. **#554's lobby.** Profile the game thread in a full room. The first
   suspect is the network thread running past the main thread's 0.5 ms
   sleeps, the same exposure the movie decoder had. A phone in a room, or a
   second client on the local WFC service
   (`scripts/test-android-local-wfc-server.sh`), is needed; a lone client
   on the Retro WFC start page doesn't show it.
5. **iPhone and iPad.** Carry the preemption point to `vendor/runtimes/ios`
   once the Android change has run on a phone.
6. **Housekeeping.** Check #127 with two players on a current Mac build and
   close it; close #475, #537, #539 and #304 if still silent; fix or delete
   `scripts/ios_release.py`; decide what to do with the stale primary
   checkout.

**Rebuilding the test build.** In a worktree of #564 with submodules
initialised and `.android-bootstrap` linked from a checkout that has it:

```sh
export KARTPAD_DISCIO_JNI_ROOT=<a built dolphin-android-discio-jni>
export KP_TRANSLATION=<private/self-build/retro-rewind/translation>
tools/android-perf/build-variant.sh preempt   # about 15 minutes
```

The build refuses to start unless KartPad's gitlink matches the runtime
submodule's HEAD, so stage the gitlink after any runtime commit. The perf app
is debug-signed: on an emulator, move `files` and `shared_prefs` aside as
root, uninstall, install, move them back and `chown` them, then push the
pack as `tools/android-perf/deploy.sh` does. Start the acceptance AVD with
`-read-only` so it stays as it was.

**Repeating the measurement.** Start Retro Rewind, press A twice to reach the
main menu, clear logcat and wait 80 s. To stand in for a slower phone, find
the game thread (the thread that logs `KartPadPerf`) and make it share a
core:

```sh
adb shell "taskset -p 8 <tid>"
adb shell "taskset 8 sh -c 'while :; do :; done' &"
```

Without the fix the result varies a lot between runs (27 and 43 FPS in two
tries), so take several. To profile:
`simpleperf record -t <tid> -e cpu-clock -f 2000 --duration 15 --call-graph fp`,
with the unstripped pack from `build/perf/v-preempt/pack-work/*/build/` and
`libmain.unstripped.so` in the symfs
([profiling notes](../tools/android-perf/README.md#profiling-a-running-race)).
The THP decoder is `func_801B3BAC` and the functions it calls up to
`func_801B6858`; the video decode thread's loop is `func_805529A8`.

**Scratch that won't survive.** Reporter logs, emulator screenshots and
profiles from this pass were in `/tmp/kartpad-focus`; the logs can be
downloaded again from the issues. The worktree
`/Users/chrissotraidis/.codex/worktrees/kartpad-focus-1111` holds #564's
branch and about 7 GB of ignored build output, including the test build.

## 8 November issue loop (after 0.8.8)

All 26 open issues were re-read, new logs were analysed, and the changes below
were tested on the arm64 Android emulator (`KartPad_088_Acceptance_20261107`,
release-signed local build over 0.8.8 with its data kept). Nothing here is
physical-device evidence. Branch: `codex/loop-20261108`.

**Fixed on the branch**

- **Custom GPU drivers never loaded (0.8.6–0.8.8).** `--wrap=dlopen` in libmain
  redirected linkernsbypass's `&dlopen` to KartPad's wrapper, so adrenotools
  stopped at `linkernsbypass_unavailable` on every device. Fixed with a
  `dlsym` lookup; Stable Turnip v2 now reports `state=loaded` on Classic and on
  the WiiCompiled 0.9 engine, then falls back as designed (no Adreno GPU).
  Found from #554's Poco F6 log. Affects #104, #301, #472, #492, #552.
- Driver status is visible: menu row, driver list, one-time message and
  problem reports name a driver that didn't load and the failing step.
- **Add Driver… → Download a Driver…** lists and installs AdrenoTools packages
  from three GitHub sources; checked end to end on the emulator.
- **Shake to Trick → Sensitivity** on Android and iPhone/iPad (#553). Android
  checked on the emulator; iOS unit-tested (the Simulator has no motion sensor).
- iPhone/iPad report button renamed **Save Diagnostic Log…** to match Android.
- Android health lines now include `battery_pct` (#339 request), plus
  `thirty_fps_races` and `simpler_computer_karts` (also in the report header),
  because #510's log9 couldn't show whether 30 FPS Races was on during the races.
- **Mac:** the same flicker and memory fixes are in draft wiicompiled #25; the full
  translated Mac app builds and passes the package audit, but hasn't been run yet.
- **iOS start-up flicker (#390):** found and fixed: VI black no longer covers the
  game's own frames (wiicompiled #24, runtime pin bumped). Checked on the iPhone 18 Pro
  Simulator with the full translated game: menus, Shake to Trick sheet, renamed
  report button and a start-up recording without black frames.

**Open issues by state**

| Issue | State | Next step |
| --- | --- | --- |
| #104 #301 #472 #492 #552 Snapdragon characters | Lead reopened: drivers never loaded before | Ask reporters to try Turnip once the driver fix ships |
| #554 Poco F6 Retro WFC | Restart fixed it; room screen still slow on one phone; Turnip never loaded | Retest with working drivers |
| #339 performance | Pixel 10a 0.8.8: thermal status 2, ~3 GB used, 43–300 MiB free late in session; the stutter window isn't in the 256 KiB log | Ship the #550 memory fix; longer capture of course select |
| #510 slow motion after cups | Cause found: two renderer caches kept every course until restart (textures, and shader modules: ~35 MiB per new course). Both bounded in wiicompiled #23 (Android, #550) and #24 (iOS, #555). Emulator: native growth over 8 rounds 104 → 20 MiB; textures flat. 0.8.8 log9 (S10 Lite, 2 cups at 60): main-thread CPU per frame 14 → 19–23 ms, PSS 650 MiB → 1.1 GiB, thermal headroom 0.40 → 0.90, so heat is likely a second cause. 30 FPS Races confirmed working on the 0.8.9 candidate on both engines (emulator GP race at 30.0 FPS) | Phone test over several cups on 0.8.9; if it still slows, recommend 30 FPS Races |
| #390 iOS start-up flicker | Cause found: VI-black presents interleaved with the game's own frames during the fade (Simulator counter: 44–52 game frames and 60 black presents a second). Fixed in wiicompiled #24 (iOS) and #23 (Android, which had the same overlap: ~120 black presents at start-up, now 3); no black after the first game frame | Confirm on an affected iPhone |
| #553 shake sensitivity | Done on branch | Ship |
| #537 Retro WFC "disc error" kick | Waiting for a 0.8.8 log | — |
| #539 LiveContainer import | Waiting for reporter | — |
| #476 Mac Nunchuk | Waiting for a 0.8.7+ report | — |
| #475 Mac PadMint certificate | Waiting; close around 14 November if silent | — |
| #304 PowerVR | Waiting for a 0.8.8 log | — |
| #295 Retro ghosts | Draft #375 | Replay coverage and iPhone check |
| #534 #531 #449 #300 #234 #203 #127 #100 #91 #90 | Requests / backlog | No change this loop |

**Menu parity.** Main menu, Multiplayer, Controls, Display, Graphics &
Performance, Sound and Game Data & Saves now match on Android and iPhone/iPad,
row for row and in order (checked from the emulator's UI tree and the
Simulator's accessibility tree). iPhone/iPad gained **Multiplayer → Country…**
and Android's Local Split-Screen / Controller Setup rows; Disable Bloom and 30
FPS Races read the same on both. 30 FPS Races and Simpler
Computer Karts were ported to the iOS runtime (wiicompiled #24) and checked on
the iPhone 18 Pro Simulator: races run at 30 FPS with the option on, and all 11
computer karts load the split-screen models. Graphics Engine, GPU Driver and
Graphics Diagnostics stay Android-only (no iPhone/iPad equivalent).

**Driving the game in the iOS Simulator.** `axe key` reaches the game as Wii
Remote 1's keyboard: arrows are the D-pad, Return is A and Backspace is B, but
each key must be held for about 0.3 s (`axe key 40 --duration 0.3`); shorter
presses are missed by the per-frame poll. Touch A also works with a 0.45 s hold.
On Retro Rewind's course screen each Right moves a whole page of cups, so
reaching one named course this way is slow. Replaying #375's imported 3DS
Bowser's Castle ghost is still not done.

**30 FPS Races and Retro Rewind menus.** The option also put Retro Rewind's
title screen and menus at 30, because Retro Rewind's frame-rate routine runs
for every scene. It now changes only race scenes (scene kind 2); menus stay at
60. Checked on the Android emulator and the iPhone 18 Pro Simulator, with one
`[KartPadFrameRate] scene …` log line per scene change.


## Current work (14 October)

The [current goal loop](CURRENT-LOOP.md) sets the order of work after 0.8.1. [STATUS.md](STATUS.md) and [KNOWN-ISSUES.md](KNOWN-ISSUES.md) are kept
current with each release. Everything below on this board is a dated snapshot:
useful evidence, not current next actions.

Performance (#339) is resumed from the
[performance handoff](ANDROID-PERFORMANCE-HANDOFF.md), not from the
`warmed-performance` rows below.

## 1 October focused execution

The [67-issue review](FOCUSED-REVIEW-2026-10-01.md) and
[active goal loop](FOCUSED-LOOP-2026-10-01.md) supersede the next actions in the
dated snapshots below. Baseline is main `978a9f1c`, published KartPad 0.7.3 and
PadMint 0.2.8. Engineering is progressing locally; no generic reporter retest
or diagnostic request is needed for this pass.

- #347 was closed as completed: its interface fingerprint shipped in 0.7.0
  with recorded race/cache/mismatch gates. A compatible pack still needs the
  existing app-state check.
- #196's reporter confirms both modes now launch; retain Retro warmup and online
  searching separately from the original startup crash. #235's Honor X7c reaches
  races; #235 was closed, with remaining performance tracked in #313.
- #216's Tab A9+ reporter confirms both Original and Retro launch. Missing bodies,
  lag and the older Tab A report remain separate. #102's Fold reporter confirms
  the manual all-draw workaround; this does not prove every Automatic selection.
- #327's latest iPhone16 result is launch-only flicker, with other gameplay working.
  #370 stays open with a live but black M2 iPad surface after the safety screen.
- #304's previous PowerVR candidate was absent from 0.7.3 and raised a 14-variable
  device back to 16. The [corrected dependency and actual empty APK](artifacts/2026-10-01/powervr-device-limits.md)
  pass native limit/shader and content/state checks. The release-style empty app
  plays a race segment on an owned emulator. The hosted archive and normal
  consumer with an empty Dawn cache pass exact hash checks; handset acceptance
  remains open.
- RVZ extraction is verified locally against the matching ISO: all 2,043 file
  hashes match; wrong region/revision are rejected. This is extraction/folder
  evidence, not new picker, race or all-platform player-build acceptance.

Scoped intake update: 22 September 2026; 63 open issues. The older family and release snapshots below retain their dates. Start at the
[support-agent hub](SUPPORT-AGENTS.md). The [priority source](maintenance-priorities.json)
owns ordering, readiness, exact next actions and acceptance; this board records
support decisions and evidence. Refresh GitHub and local ownership before acting.
The [device matrix](COMPATIBILITY-MATRIX.md) preserves target-specific observations.

## 23 September Android optimization loop

[Private candidate comparisons](artifacts/2026-09-23/android-candidate-comparison.md)
now include repeated stationary Cookie Land battles and a matching Mailbox/FIFO
reversal. Displayed cadence and guest CPU are measured separately. The supplied
Reddit reports are classified in the [loop ledger](artifacts/2026-09-23/android-optimization-loop.md),
including sustained slowdown, resolution-change freeze and input/handheld requests.
None is closed from this Pixel-only evidence. CPU-affinity and cache-size
experiments without reliable gains are removed, as are unproven scalar fast paths
and helper calling-convention changes. Private build 195 retains guarded FIFO and
bounded diagnostics. Exact-artifact Original/Retro offline and bounded lifecycle
checks completed; significant pipeline-related hitches remain. The
[morning report](artifacts/2026-09-23/android-morning-report.md) records the
installed artifact and acceptance limits. No new public build was published.

## 21 September evening loop

[All 63 open issues](artifacts/2026-09-21/open-issue-inventory.md) have a new
issue-specific reply with a retained URL. No issues were automatically closed.
[The active evening goal](artifacts/2026-09-21/evening-goal-loop.md) continues
engineering after intake rather than waiting for another generic log collection.

- Build60 has reported A10X/iPad improvements (#135/#310), with remaining stalls
  and #310 online-transition crash. #196 supplied a build60 missing-guest-target
  stack; diagnostic-off is not its fix.
- Honor X7c #235 now reaches races in the same reporter's #313; 15 FPS performance
  remains. #295 Original export works; Retro transfer is the remaining feature.
- Android RVZ descriptor import passes the full Pixel system-picker import: all
  2,043 extracted file hashes match, and both saves/five preferences are unchanged.
  Normal private code167 subsequently launches Original and Retro, with a short
  Original acceleration/pause/quit check. Not yet published; other providers/devices
  and full player-driven acceptance remain separate.
- A link-only control reproduces released code135 BuildID. Function-only local
  binding removes 10,873 internal jump slots while preserving dynamic exports
  and API28. This is artifact evidence, not an FPS improvement yet.

- #216 A9+ now installs code135 after a fresh download and loads Original;
  missing character bodies and lag remain. Retro is untested, and the older Tab A
  is a separate unresolved case. #316's screenshot confirms displaced geometry.
- [PR315](https://github.com/chrissotraidis/kartpad/pull/315) retains local binding,
  background cache persistence, snapshot/CP-summary and inactive-key reductions,
  and one ARAM TLS lookup per voice. Targeted work removal is verified; whole-frame
  gains remain within run variation. API29 TLS stays opt-in, API28 is default.

## 20 September post-release priorities

[Current issue and enhancement audit](artifacts/2026-09-20/post-release-issues-and-enhancements.md)
supersedes the dated pre-release build/distribution instructions below.
v0.5.0 is public. The new S24/code135 result in #104 still fails character
rendering; #198 reports waiting, not improved performance. #302's pin correction
is shipped and its release follow-up was missed.

Explicit smaller follow-ups: Android shake-to-trick parity (Apple has it),
Retro ghost transfer (#295; Original export is now reporter-confirmed), and separate Mac Classic/Android ipega input
paths. Auto-accelerate, shared D-pad/trigger mappings, the L1 item preset and
combined release assets are already implemented. Larger NAND/identity, USA,
cheat, DSU, external-display and older-OS requests remain explicitly scoped in
the audit rather than hidden inside broad threads. No new binary is produced by
this review and no reporter acceptance is inferred from source checks.

## Historical: 19 September intake decisions

The [latest evidence review](artifacts/2026-09-19/recent-issues-and-build-evidence.md) and [37-thread inventory](artifacts/2026-09-19/github-review-inventory.md) supersede older generic waiting states for the specific subcases below. Other historical rows are not newly validated. Additional build distribution is on hold; no new reporter capture is needed for these three decisions.

| Priority / card | Evidence and next owner action |
|---|---|
| 1 / `android-vulkan-loader` | #303 adds a Redmi Note 11/code119 missing-debug-utils failure to #301 and the newer Tab A9+ #216 subcase. Internal backport exists in code123/124; affected-driver acceptance is open. Engineering owns internal validation and graceful failure handling. [Reply](https://github.com/chrissotraidis/kartpad/issues/303#issuecomment-5737578364). |
| 1 / `android-powervr-capability` | #304 Moto G54/code121 rejects the PowerVR inter-stage shader limit, then aborts. Exact symbols match. Current candidates do not fix it. Engineering owns review of the upstream instance toggle, honest device/pipeline limits and shader requirements, plus graceful rejection. [Reply](https://github.com/chrissotraidis/kartpad/issues/304#issuecomment-5737578636). |
| 2 / `retro-wfc-payload-pin` | #302 reproduces a 28,992-byte signed payload against a 28,968-byte pin. Engineering owns executable/translation review and clean self-build before pin promotion. [Reply](https://github.com/chrissotraidis/kartpad/issues/302#issuecomment-5737579079). |

#275's new thanks/waiting reply is recorded without another prompt. Existing negative geometry results and CPU-heavy captures remain unresolved; no new device acceptance was supplied. See the dated review for every recent thread's disposition and the limits of the new upstream lead.

## Owner Android acceptance failed (19 September)

Pixel 9 Pro XL/code125 crashed with an exact-symbol native allocation failure
in a background shader compiler. The owner also reports slowdowns and a pause.
[Crash, timing, memory and regression comparison](artifacts/2026-09-19/pixel-code125-memory-crash.md)
now take precedence over further candidate distribution. Existing owner gameplay
is monitored without interruption; iOS gameplay remains untested.

[Code126 correction](artifacts/2026-09-19/pixel-regression-correction.md) is built and
audited: stable Dawn identity, bounded speculative replay and demand-work wakeups.
Owner session completion and cold/warm physical acceptance remain pending.

## Current engineering sequence (19 September)

Local cross-platform stabilization is recorded in the
[build review](artifacts/2026-09-19/cross-platform-stabilization.md).
The old assignments below are historical; this sequence supersedes their
build requests. No further reporter builds or repeat-log requests are planned.

1. Finish local package/source checks for the conservative candidate: verified
   Retro-WFC payload, shared timer/renderer corrections and Android loader fix.
   The payload repair includes a measured 4102-function profile gate.
2. Complete owner gameplay acceptance. The iPhone 14/build52 and Pixel 9 Pro XL/code125
   are installed in place; [signing, state preservation and launcher evidence](artifacts/2026-09-19/owner-phone-deployment.md)
   are recorded. Original/Retro races, relaunch and warmed performance remain open.
   These phones do not close #301/#216/#303 or any geometry report.
3. Investigate PowerVR #304 as a separate adapter/device/pipeline capability
   contract, including graceful failure. Neither code125 nor the depth lab
   claims to support this device.
4. Continue batch ownership/refactoring for #137, actual-draw reproduction for
   #102/#104/#166, and CPU attribution for #198/#275/#135. Avoid a broad rewrite
   or speculative performance claims.
5. Review upstream Kamek continuation follow-up `8e0cc968` separately; migration
   to source did not automatically import it. Preserve the current candidate
   while testing any translator change against old/new generated graphs.

## Earlier family snapshot (13 September)


Counts below are distinct non-maintainer issue authors at this snapshot, excluding
comment-only corroboration. Closed duplicates #209/#210/#224–232 collapse historically
under #208, #237 under #236, and #233 under #211. Families
overlap, so these numbers cannot be summed into total affected users. The selector
refreshes counts in its generated local context, not by automatically promoting
popular reports. Historical work and old requests remain in the
[previous board](https://github.com/chrissotraidis/kartpad/blob/2028ab3/docs/MAINTENANCE-BOARD.md);
the next actions below supersede those dated assignments.

| Priority / card | Issues / authors | Current decision and next actor |
| --- | --- | --- |
| 0 / `retro-save-loss` | #169 / 1 | `source-corrected-awaiting-reporter`: Android pack activation now preserves both Retro WFC save branches; see source finding and fixture (local record unavailable in this checkout) and the [public update](https://github.com/chrissotraidis/kartpad/issues/169#issuecomment-5644596717). The original build-21 report still needs its exact exit-versus-pack-replacement boundary and current-candidate data-preserving acceptance. Do not deliberately lose more data. |
| 1 / `android-exits` | #143, #200, #205, #208, #235–236, #128, #131, #207, #215, #216 / 11 open cases | `awaiting-reporter`: one matching exit classification per distinct launch/cup/race subcase. Closed #209/#210/#224–232 remain historical duplicates under #208; #236 is canonical for closed #237. #235 and #236 remain separate Honor X7c and OPPO CPH2669 device subcases. Similar wording does not establish a common runtime defect. |
| 1 / `ios27-startup` | #196 / 1 | `released-awaiting-device`: public v0.4.17-ios.1 (retired) is the corrected unsigned IPA, SHA-256 `d322484192dde92139ed8aac66c9abd7764b91f97895840995ef17f0ff49f9ff`. Anonymous audit and owner iPhone 14 / iOS 26.6.2 in-place data preservation passed. The matching iPhone 17 Pro Max/iOS 27 Original+Retro launch/race/relaunch gate remains open; see [platform handoff](artifacts/2026-09-13/platform-candidate-handoff.md). |
| 2 / `android-online` | #206 / 1 | `awaiting-reporter`: await #206's already requested Wi-Fi endurance confirmation beyond the prior four/five-race window. #123 is closed upstream and remains historical evidence only; closure is not technical online acceptance. |
| 3 / `adreno-geometry` | #102, #104, #120, #137, #166, #193, #211 / 7 | `awaiting-owner`: release operator and affected-device tester establish compatible signing/delivery for the retained dynamic/literal/dynamic character-draw comparison. Closed #233 is preserved as an SM-S928B/Retro subcase under #211, not a separate active case. The host has no release keystore; see Android signing preflight (local record unavailable in this checkout). No GPU-wide cause or correction is established. |
| 4 / `warmed-performance` | #198, #167, #103, #169, #195, #204, #207, #135 / 8 | `awaiting-owner`: #198 tester is willing. The prepared profiler needs compatible signing or an approved data-preserving route **and** private delivery before capture. The host has only a debug keystore; see Android signing preflight (local record unavailable in this checkout). Retained Debug-signed APK is not a public-app in-place upgrade. |

## Release-candidate sequence

The current delivery order is: (1) revalidate and hand off the clean #196
iOS candidate for compatible signing and matching iPhone 17 Pro Max/iOS 27
acceptance; (2) prepare merged PR #219 for a signer-compatible Thor/Odin test;
(3) prepare merged PR #157 for the same-scene two-player Mac comparison. See
the reconciliation artifact (local record unavailable in this checkout).
PR #112 remains a separate conflicting integration lane. The older preparation
sentence is superseded by the code80 handoff below; package publication does not
claim a verified affected-device gameplay fix.

The sequence has advanced: the iOS, macOS, and Android packages are now public,
while affected gameplay gates remain open. Android `v0.4.17-android.1` / code80
was published after code79 physical Retro race/touch acceptance and code80
anonymous/package audits. Code80 was not physically installed before the test
phone disconnected, so this is a release/package fact, not code80 device or
online/results acceptance. Exact hashes, source and boundaries are recorded in
the [platform handoff](artifacts/2026-09-13/platform-candidate-handoff.md).

## Active owned investigation

`#248` / draft `252` remains owned by the existing investigator. Fresh 622-test
coverage and generated-graph checks pass, but generated-module growth is 41.3%
and the exact `0x807EF16C` crash is still unproven. Do not merge, broadly bump
the upstream pin, or spawn a competing worker. The next decision is whether the
growth gate can be reduced or the crash can be attributed; native compilation
and actual Item Change/Item Rain acceptance remain subsequent gates.

These are checkpoints, not verified fixes. Finish available preparation before
parking work. If one of these owner actions becomes locally executable, update
that card to `ready-local`; an owner label alone is not a permanent external block.
If all remain blocked, choose genuinely ready known work below and add a bounded
card rather than repeating passing tests or an unanswered request.

## Evidence and outstanding requests

Use the [hub's request fields](SUPPORT-AGENTS.md#send-a-concrete-build-test-handoff)
when creating/updating a handoff. A request is not evidence that a test started.

| Request / evidence | Disposition and next gate |
| --- | --- |
| [#196 published build audit](https://github.com/chrissotraidis/kartpad/issues/196#issuecomment-5642179928), corrected simulator runtime (local record unavailable in this checkout) and [build-integrity correction](artifacts/2026-09-12/issue196-rel-report-build-integrity.md) | Public v0.4.16-ios.2/build 36 still contains the reported aggregate-shard load. The new clean `0.4.16/build38.96.2` candidate now passes the isolated simulator lifecycle for Original and Retro 6.12.8 with data preserved and no translated crash markers. Regenerate a signed candidate; matching iOS 27 hardware acceptance remains unperformed. |
| [#123 closed upstream](https://github.com/chrissotraidis/kartpad/issues/123) and [last maintainer response](https://github.com/chrissotraidis/kartpad/issues/123#issuecomment-5644306282) | GitHub records `CLOSED` / `COMPLETED` at 2026-09-12T07:41:52Z. The final comment separates a music workaround for menu lag from reported online-race frame drops. This is a support-state reconciliation, not a technical fix or race/results/reconnect acceptance; do not assign more #123 work unless it is reopened with new evidence. |
| [#206 cellular/Wi-Fi comparison](https://github.com/chrissotraidis/kartpad/issues/206#issuecomment-5642749400) | `awaiting-reporter`: [acknowledgement posted](https://github.com/chrissotraidis/kartpad/issues/206#issuecomment-5642834780). On Samsung SM-S921W / Android 14 / build 65, mobile data worked once while Wi-Fi reportedly works normally. This is sufficient to isolate a network-dependent subcase; it does not prove a NAT, carrier or guest-runtime cause. Keep it separate from #123. Await the already requested confirmation that Wi-Fi passes beyond the prior four/five-race window before claiming a stable workaround; do not repeat the acknowledgement, known build/device questions or generic log request. |
| [#211 / closed #233 renderer evidence](https://github.com/chrissotraidis/kartpad/issues/211#issuecomment-5649620538) | `needs-one-detail`: Galaxy S24 family character corruption remains in the renderer lane. Closed #233 is retained as the SM-S928B/build-65/Retro subcase under #211; do not count it separately or infer a GPU-wide cause. |
| [#166 additional device request](https://github.com/chrissotraidis/kartpad/issues/166#issuecomment-5628217442) | `requested`: exact device/build/profile and available renderer lines for the added report. Existing synthetic checks do not clear the failing gameplay draw. No duplicate probe/request. |
| [#198 willingness](https://github.com/chrissotraidis/kartpad/issues/198#issuecomment-5640922655) | `preparing`: existing warmed evidence justifies a bounded function profile. Signer compatibility/data preservation and private delivery are maintainer dependencies. Do not re-ask willingness, attach the APK publicly or represent installation/testing as started. |
| [#167 completed comparison](https://github.com/chrissotraidis/kartpad/issues/167#issuecomment-5608282606) | Supplied Infinix Hot 60 Pro / Android 16 / KartPad 0.4.11 / Original details and unchanged 1x aspect comparison are sufficient to stop that settings sweep. A selected warmed profile is a different decision; don't ask for the same device/build again. |
| [#215 launch/exit evidence](https://github.com/chrissotraidis/kartpad/issues/215#issuecomment-5648868060) | `awaiting-reporter`: Xiaomi 25057RN09G / Android 15/API 35 / build 65 now has the Android-home boundary for both Original and Retro. Await one short redacted exit result if available; no reinstall, data clear, ROM or save is requested. |
| [#216 black-surface/exit reply](https://github.com/chrissotraidis/kartpad/issues/216#issuecomment-5643186097) | `awaiting-reporter`: Galaxy Tab A (8.4-inch, 2020), One UI 3.1, Android 11/API 30, reported 0.4.16 Android; exact build unconfirmed. Both Original and Retro show a black game surface with touch controls, then exit. Reply is posted; await only chooser-versus-Android-home destination, selected profile/import completion and one short redacted exit result. Keep separate from #215 and renderer hypotheses. |
| [#208 canonical launch report](https://github.com/chrissotraidis/kartpad/issues/208) | `requested`: chooser versus Android home, profile/import state and matching exit result. Closed #209/#210 and #224–232 remain linked historical reposts and do not justify new requests or separate engineering assignments. |
| [#234 save/identity transfer](https://github.com/chrissotraidis/kartpad/issues/234#issuecomment-5647599209) | `awaiting-reporter`: Galaxy S25 Ultra / build 65 reports missing Mii/name/rating and a changed console identity after restoration from a Wheel Witch save backup on the same phone. Classified as a same-device backup-restoration subcase under save/rating lifecycle. No private save or serial is requested. |
| [#235 Honor X7c launch evidence](https://github.com/chrissotraidis/kartpad/issues/235#issuecomment-5649459291) | `awaiting-reporter`: Honor X7c / Original 1.0 WBFS reaches a black screen with interactive controls, then returns to Android home after about 3–5 seconds. This is now a classified native launch/render exit boundary, separate from other devices; no WBFS, reinstall or data clear is needed. |
| [#236 OPPO A40 launch evidence](https://github.com/chrissotraidis/kartpad/issues/236#issuecomment-5648868168) | `awaiting-reporter`: OPPO CPH2669 / Android 14 / build 65 confirms a repeatable Original/base black screen followed by Android home, with corroborating #237 now closed as a duplicate. Await one matching redacted exit result if available; no reinstall or data clear. |
| [#215 Android-home confirmation](https://github.com/chrissotraidis/kartpad/issues/215#issuecomment-5648868060) | `awaiting-reporter`: Xiaomi 25057RN09G / Android 15 / build 65 now has the decisive return boundary: Android home after the black screen for both Original and Retro. This is actionable native/OS-exit evidence; no release is promised before reproduction and compatible-device testing. |
| [#236 Android-home confirmation](https://github.com/chrissotraidis/kartpad/issues/236#issuecomment-5648868168) | `awaiting-reporter`: OPPO CPH2669 / Android 14 / build 65 now has the decisive return boundary: Android home after the Original black screen. This remains a separate device case. |
| Closed duplicate cleanup (local record unavailable in this checkout) | `reconciled`: #209/#210/#224–232 are closed under #208; #237 is closed under #236; #233 is closed under #211. Originals retain the evidence and remain the only active memberships. |

For #215/#216, use the existing requests; do not ask for another reinstall, data
clear, ROM or save. The reports establish repeated symptoms, not a classified
OS exit or a common runtime defect.

Private artifact identities, symbols and handoff process references remain in the
ignored local maintenance checkpoint. Before delivering or installing, recheck the
actual retained file, source, signer and authorization; old prose is not provenance.

## Other issue families

These reports remain tracked even when outside the six leading work cards. Read
current comments and the linked source scope before promoting one into active work.

| Family | Reports / bounded next decision |
| --- | --- |
| Retro installation/version | #192 download/import and #194 updater design. Verify current app/official pack and last completed step; separate executable compatibility from a request for automatic updates. |
| Input/system UI | #119 bars, #184 mapping, #197 controller/touch handoff, #202 aspect/display. #197 now has in-game menu and ipega/touch evidence; next is a fresh touch-only offline menu after close/relaunch, then controller reconnect. Match physical/touch and chooser/gameplay paths; no renderer patch for an unclassified button/inset report. #184 has a bounded feature scope in [future features](FUTURE-FEATURES.md#android-d-pad-and-shoulder-remapping). |
| D-pad support question | [#238 corrected answer](https://github.com/chrissotraidis/kartpad/issues/238#issuecomment-5649620435) asks how to enable Android D-pad. The release-source path is **Move controls → select the dim D-pad → Show → Back/Done**; no engineering defect or diagnostic request is established. |
| External display | #100 and #199. Match local-only, wired and AirPlay transitions/recovery separately. Existing Metal/source checks are not affected-display acceptance. |
| Apple controls/projection/multiplayer | #5, #91, #101, #127; PR #157 is merged and needs a clean Mac candidate/same-scene two-player comparison. PR #112 remains open/conflicting and requires a separate bounded integration/test; do not block #157 on it. |
| Apple performance | #135. A10X startup is already accepted; remaining frame-rate concern needs its own affected-device comparison, separate from Android CPU/GPU hypotheses. |
| Save/rating lifecycle | #105 manual transfer is accepted; automatic two-way sync and Mii scope remain distinct. #169 lost progress must be classified separately from performance and system bars. |
| Feature/compatibility | #90 Original Wiimmfi, #91 controller/DSU, #203 disc revision/NAND/cheats. Define requested behavior, supported input and implementation boundary; do not request generic logs for missing features. |
| Governance | #92 remains an upstream review dependency; do not create recurring runtime work from it. |

## Preserve accepted subscopes

- [#188](https://github.com/chrissotraidis/kartpad/issues/188#issuecomment-5633416311)
  is closed after reporter-confirmed Mii import on v0.4.16-android.1 / AYN Thor in
  Original and Retro. It is not waiting for another initial import request.
- [#135](https://github.com/chrissotraidis/kartpad/issues/135#issuecomment-5599088464)
  confirms the A10X startup correction; roughly 30–35 FPS remains a separate concern.
- [#105](https://github.com/chrissotraidis/kartpad/issues/105#issuecomment-5597997983)
  confirms manual save/rating transfer. Automatic synchronization is not implemented.

For every update, distinguish source corrected, candidate, host/simulator,
physical/reporter acceptance and release. Commit reviewed public queue changes
in the maintenance loop; no status-page edit establishes that a build is stable.
