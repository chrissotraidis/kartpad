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

