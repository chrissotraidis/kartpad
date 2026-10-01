# KartPad focused goal loop, 1 October 2026

Owner: this Codex chat (`01a0f4be-5b6d-7b63-8cdb-a990f49f7cbb`).
Status: active. Goal: execute the [focused review](FOCUSED-REVIEW-2026-10-01.md)
through narrow, verified changes that improve setup, reliability and maintenance.

## Loop

1. Refresh main, release, issue evidence and work ownership. Preserve dirty work.
2. Select the next actionable build/import, data-loss or startup problem; use a
   bounded feature/performance task when those need unavailable external evidence.
3. Reproduce or measure the existing behavior before changing code. Record source,
   toolchain, artifact and fixture identity privately where needed.
4. Make the smallest useful change. Run the relevant negative cases and regressions.
   Review the diff again; distinguish a fixture/host result from actual gameplay.
5. Integrate reviewed source into a focused branch/PR, update current documentation
   and record acceptance limits. Publish releases only after AGENTS.md's artifact
   audits and game-pack race gates pass.
6. Reconcile completed issue scopes from retained evidence. Avoid repeat reporter
   requests; ask only for a specific remaining hardware/service fact when necessary.
7. Continue the next pass. After repeated identical failures change the experiment.
   Mark the goal complete only when the accepted scope and required gates are done.

## Execution queue

| Pass | Status | Next acceptance |
|---|---|---|
| Current source / isolation | Verified | Baseline `978a9f1c`, dedicated `codex/focused-maintenance-loop` branch; primary dirty checkout retained. |
| Builder inspect / RVZ | Verified locally | Honest provisional status; matching private ISO/RVZ extraction and exported data; wrong identity/revision rejected. Device importer acceptance remains separate. |
| Build cache / timings | Verified locally | Compatible cache skips translation; disc validation and app-state/TLS check remain enforced. Cached Android/iOS output libraries unchanged. |
| Documentation | Reviewed | Current builder/mobile/Mac routes, upstream ledger and superseded maintenance next actions reconciled. |
| Completed issue scopes | First reconciliation done | #347 and #235 closed; partial #196 remains open. Review began with 67 open issues, now 65. |
| PowerVR / stability | Queued | Existing dependency work reviewed, actual package integration verified, hardware gate explicit. |
| Upstream changes | Review complete; candidate local | All 18 later commits mapped. Narrow bltl candidate passes 658 translator tests and real graph checks; native/game acceptance pending. |
| Controls / Retro ghosts | Queued | Existing feature contracts checked before extending input or storage. |
| CPU / larger features | Queued | Same-device profiling and separate Wiimmfi/DSU feasibility and acceptance. |

## Run record

- Started from live main and inspected the primary checkout and existing worktrees.
  The primary checkout has extensive unrelated edits and another active audit chat;
  existing current worktrees also contain unfinished task work. Created an attached
  worktree under `$CODEX_HOME/worktrees` for this branch. No owner work was reset.
- Repository release instructions require empty public shells, content/package
  audits, and racing with a PadMint-made pack before release. No release is implied
  by a documentation change or a passing host test.
- Available disk space at start was approximately 35 GiB. Reuse existing private
  fixtures/evidence and limit concurrent heavyweight builds; do not remove owner
  files or caches to make room.

Results and the next discriminating experiment are appended here after each pass.

## Pass 1 results

Source baseline: main `978a9f1c8132`; published KartPad 0.7.3 and PadMint 0.2.8.
The translator and runtime gitlinks and dependency lock remain unchanged.

- `inspect` no longer labels an unextracted provisional image as verified. The
  new regression failed on the baseline and passes with the corrected wording;
  known pinned-image recognition is retained.
- The existing private RVZ and matching ISO extract to identical SHA-256 values
  for all 2,043 files. Exported game data has the same manifest. Wrong region and
  revision are rejected. This proves the extraction/export boundary; no new
  physical-device importer or race result is claimed.
- Both pack builders now determine compatible cache reuse before translation.
  Cache hits still prepare pinned Retro inputs, validate disc extraction and run
  the existing app-state/TLS check before packaging. Tests cover cache hits,
  invalid disc identity, failed state checking and changed-interface rebuilding
  for Android and iOS. Cache identity and existing library bytes are unchanged.
- Real cached builds against the published 0.7.3 Android and iOS apps passed.
  Their app hashes were checked against GitHub release asset digests. Both
  packaged library hashes match the original cached libraries byte for byte.
  Android ran in 0.824 seconds and iOS in 4.759 seconds, with translation disabled
  by a guard that would fail if called.
- Two matched Android update measurements used fresh build workspaces, an
  already validated extraction, the same disc/app/cache and two translator
  workers. The original path took 64.426 and 114.990 seconds; corrected runs took
  0.824, 1.457 and 1.471 seconds. Every resulting pack was identical. Host load
  varies; the demonstrated saving is avoiding unnecessary translation on a cache
  hit. These runs do not measure first native compilation, CPU frame time or
  gameplay, and do not establish #339's 40%/10% targets.
- The combined builder/cache/fingerprint/ARM64/game-data/iOS-SDK/link-contract
  checks passed: 60 tests, no skips. After priority reconciliation, the combined
  run including maintenance-loop/state checks passed 125 tests, no skips. The narrow upstream `bltl` candidate first
  reproduced the missing lifting case, then passed all 658 translator tests,
  no skips. Two real translation runs passed the pinned graph: 29,637 generated,
  29,065 base and 4,102 Retro functions. That candidate is uncommitted on local
  submodule branch `codex/kartpad-bltl-lifting`; root pins are unchanged. Preserve
  it until native-build and gameplay acceptance determine whether to promote it.
- Closed #347 from its shipped interface-fingerprint and recorded acceptance
  evidence, and #235 from the same reporter reaching races. No comments or new
  reporter requests were posted. #313 retains Honor performance. #196 retains
  Retro warmup and endless matchmaking; #216 and other partial hardware reports
  remain open. The stale startup next actions in the machine-readable priority
  source were reconciled; already closed #215 leaves the active crash queue.
- Updated the builder and historical Mac installation guide, maintenance board,
  known-issue scope and current upstream ledger. Removed broken links to absent
  local evidence from the historical board; dated claims remain scoped. The review covers all 67 issues
  once, and all 18 commits since the common upstream base; ancestry gaps are not
  assumed to be missing code.

Private logs, manifests, generated sources and personal outputs stay ignored
under `private/focused-loop/` and `work/bltl-lifting-20261001/`. No release or
private input was published. The primary dirty checkout and other worktrees
remain preserved.

## Integration and next checks

- Builder/documentation changes are committed on `codex/focused-maintenance-loop`
  and published as [draft PR #372](https://github.com/chrissotraidis/kartpad/pull/372).
  Hosted receipts and regression checks both passed on `6b79eae7`.
- The actual Android CLI `doctor` and `build-pack` route passed against the
  published APK, reused the compatible pack and exported game data. Its pack is
  unchanged and all 2,043 exported file hashes match the RVZ extraction.
- The retained PowerVR candidate remains in its original isolated checkout.
  Its proposed lock points to `dawn-android-20261001.1`, which was not hosted when
  checked. Do not promote that lock or call #304 fixed until the verified archive
  is available and its identity is checked in the actual app package. Moto G54
  acceptance remains separate.
- Controller review confirms the shared mappings and L1 preset are implemented.
  A proposed physical-channel A fallback was withheld: installed Apple SDK
  documentation says `physicalInputProfile` is equivalent to the typed profile,
  so a split fake profile can manufacture a failure. #324 needs real Joy-Con
  routing evidence before rewiring input.
- Android and iPhone ghost messages now say that **all** Retro ghosts are outside
  the current transfer tool, including Wii courses played in Retro. The original
  “custom-track” wording contradicted #295's retained acceptance. Storage and
  import/export behavior are unchanged; Retro transfer remains open.
- One native Android cache-miss build with the local `bltl` candidate is running
  with four jobs and a separate private cache. Graph gates passed; retain its
  final compile/check/package result before promotion. No new game pack or
  source pin is included in PR #372.

Continue the PowerVR artifact/package gate, bounded missing upstream fixes,
Retro storage/course mapping and measured same-device performance. Preserve
explicit native, hardware and service gates; do not spin on reporter retests.
