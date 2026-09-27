# Open-issue loop, 27 September 2026

Reviewed every open issue on chrissotraidis/kartpad (58 open at the start). Local fixes from
this loop are listed in `tester-replies-round2.md`; this file records the issue review.

## New evidence reviewed

- **#310 (iPad 9th gen, build 59):** the six crash screenshots show the abort came from
  `KartPadDiagnosticCrashProbe` inside a `UIAlertController` action, which is the
  "Test Native Crash… → Crash Test" menu item. It only exists when
  `KartPadSystemDiagnosticsIsCandidate()` is true, which build 59 shipped with by mistake.
  Current releases are audited with `KartPadDiagnosticsCandidate=NO`. The later online-lobby
  crash on build 60 has no report; asked for one on 0.5.3.
- **#196 (iPhone 17 Pro Max):** build 60 crash is `FatalMissingGuestTarget` from
  `InvokeIndirectCpu` in `ModuleLinker::CallModule` (StaticR) under `StrapScene::calc`.
  Consistent with a modified StaticR.rel; `ad8a76a` (in v0.5.1 and later) validates StaticR
  before launch and names modified data. Asked the reporter to try 0.5.3.

## Closed

#329 (duplicate of #102), #325, #215, #305, #302, #248, #205 (duplicate of #303).

## Pinged with the relevant newer build

Android performance (0.5.4): #103, #167 (es), #169, #198, #204, #207, #278, #296.
Android launch exits, asking for Export Private Diagnostics if still failing: #143, #200,
#208 (es), #236. Snapdragon character options: #166, #301. iPhone/iPad 0.5.3: #135, #309.

## Left without a new reply (no relevant change since the last reply)

#5, #90, #91, #100, #101, #119, #127, #128, #192, #194, #197, #199, #202, #203, #206,
#234, #257, #273, #295, #300, #304, #306. Issues updated 26–27 Sep already have a current reply.


## #102 all-draws result and Automatic default change

- itsgeri (Z Fold 8, Adreno 840, 0.5.4, Retro N64 Wario Stadium) with "fix characters and track
  textures": menus fully fixed and track/wall textures now correct, but other karts and item
  boxes mostly invisible in races. inkwreck2 (OnePlus 15, Adreno 840, Original Mario Circuit)
  sees every opponent with the same option, at about 50 FPS.
- Emulator check on 0.5.5-test2 / 234 (log: `repack mode=all_draws source=override`):
  Original Luigi Circuit shows item boxes and karts; Retro SNES Mario Circuit 1 shows all
  opponents on the grid. The CPU repack itself is not dropping objects; the Fold 8 loss is
  driver- or course-specific.
- Changed Automatic on Adreno 8xx from mode 2 to mode 1 (runtime `1b681f2`, pinned in
  `22845632`). Mode 1 is the option the Fold 8 tester confirmed fixes characters and karts in
  menus and races. Mode 2 stays a manual choice. Asked itsgeri whether Original also loses karts.
- Test build 234 (signed `c1dbe0a0…`, installed on AVD) still has the mode 2 Automatic; the
  next build picks up the change.


## Getting logs from reporters (evening)

- **Launcher bug fixed:** Help → Export Private Diagnostics refused to save when no game session
  existed ("Choose the game session again before exporting."), which is exactly the case of phones
  that close before writing a log (#143, #200, #208, #236). It now exports with Android's exit
  records and crash traces.
- **Crash prompt:** after the game process ends unexpectedly (crash, ANR, non-zero exit, or a
  foreground memory/signal kill) within the last day, the chooser offers Save Diagnostics once,
  then a prefilled GitHub draft. Verified on build 0.5.5-test3 / 235 (release signer
  `c1dbe0a0…`): `am crash` on the game process → prompt → ZIP with session
  `base_…_pid5881` and `java_crash`/`base` exit → GitHub new-issue link. Not re-offered
  on relaunch; a force-stop with a paused game does not prompt. Android only; iOS has no reliable
  equivalent, since iOS ends background apps without a record.
- Bug form and `docs/SUPPORT.md` now give the export steps directly.
- Asked for a diagnostics export on #192, #206, #257, #313.

