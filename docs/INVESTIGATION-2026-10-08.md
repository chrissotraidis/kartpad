# Focused issue loop: 8 October 2026

## Intake and disposition

GitHub refresh: **8 October 2026 (JST)**, compared with the 7 October review.
There are **27 open issues and five open PRs**. Release remains 0.7.14/build 258;
#416 remains a draft. Its three checks passed at head `002a5695` before this
record was added. No new PR review was found. No new reporter comment or log
arrived on an existing bug after the prior review.

One new issue: [#437, change app icon feature](https://github.com/chrissotraidis/kartpad/issues/437),
filed 7 October 17:00 JST by Dhi20071. It is already assigned to Chris, who
[accepted it for the next build](https://github.com/chrissotraidis/kartpad/issues/437#issuecomment-6051134702)
on 8 October. Preserve that commitment in the queue. The request says customize
on iOS/Android but does not define bundled choices versus arbitrary user images.
First inspect existing platform/icon assets and define the smallest supported
choice/reset flow; do not promise arbitrary image support or rewire launcher
entries without install/update/navigation checks. No implementation or physical
acceptance is claimed by this review, and no redundant reply was added to #437.

The remaining open scope, with no new reporter evidence in this interval:

| Group | Open issues |
| --- | --- |
| Runtime and build performance | #339 |
| Graphics / presentation | #104, #301, #304, #431 (Android); #390 (Apple startup); #127 (Mac split-screen) |
| Controllers / screen area | #378 (ipega), #306 (Classic Pro), #324 (single Joy-Con), #202 (AYN insets) |
| Startup / import / cup ending | #332, #370, #380, #131 |
| Save and identity migration | #234 |
| Cellular online matching | #405 |
| Current feature / delivery work | #411 (Sound), #430 (shake), #377 (updates), #437 (icons) |
| Larger remaining requests | #90 (Wiimmfi), #91 (DSU), #100 (external display), #203 (regions/NAND/cheats), #295 (Retro ghosts), #300 (older OS) |

Issue links and retained evidence for the unchanged 26 cases are in the
[7 October inventory](GITHUB-REVIEW-2026-10-07.md). Correction to that inventory's
#104 row: its latest retained S24 diagnostic is **0.7.13**, not only 0.7.12;
this was already available before today's pass and is not a new response.
The empty comparisons remain inconclusive about the root cause.

## #339: measured build investigation

Continued the [priority board](MAINTENANCE-BOARD.md)'s next device-free experiment,
using the task's retained 6 October Android pack graph, NDK Clang 21 and four
build jobs. No physical device, installed game or player container was touched.
The original stage's source, native object/library and Ninja dependency/timing
databases were backed up, restored and verified by SHA-256 and mtime. Foreign
translation inputs were read only. Trace objects were written under this task's
ignored build directory, not over the candidate pack.

### What the checks establish

- **Three real no-op builds:** 0.078, 0.011 and 0.013 seconds. The existing Ninja
  graph correctly does no work for unchanged inputs.
- **Small-change invalidation:** a comment-only edit to `pack_info.cpp` rebuilt
  exactly its object and the library (two steps), in **1.515 seconds**. The
  resulting library was byte-identical. The next no-op was 0.012 seconds.
  This tests a metadata source edit, not a shared-header or translation change.
- **Retained full-build log:** 208 steps, **278.600 seconds** from first start to
  final completion. Its 72 `base_common` shards account for **576.406 of 1,105.204
  summed edge-seconds (52.2%)**. Ninja edge durations are elapsed time, **not
  measured CPU time**; overlapping jobs cannot be summed into wall time. The
  link was 0.557 seconds in that historical run. This is not a new controlled
  clean-build baseline or a before/after speedup.
- **Entry-point distinction:** `scripts/build-game-pack.sh` deliberately creates
  a new timestamped stage. The player builder in
  `builder/kartpad_builder/game_pack.py` instead keeps a keyed workspace and
  reuses a fingerprint-compatible pack, rechecking symbols against the app.
  Therefore the developer script does **not** prove every player update does a
  full compile. Preserve compatibility checks; do not introduce a generic cache
  rewrite from this observation.

### Where compiler time goes

Compiled three existing source shards serially with their production command,
redirecting object/dependency output into private scratch and adding Clang's
`-ftime-trace`/`-ftime-report`. “Largest” and “median” refer to the ordering in
the retained log, not a fresh census of all shards.

| Sample | Compiler total | Back end | Front end |
| --- | ---: | ---: | ---: |
| Largest retained common shard | 12.31 s | 11.36 s | 0.93 s |
| Median retained common shard | 9.51 s | 8.30 s | 1.19 s |
| Median retained Retro mod shard | 4.50 s | 3.68 s | 0.82 s |

The back end accounts for approximately **82–92%** of these three instrumented
compiler samples. Trace phases overlap/nest, so do not add individual optimizer
and code-generation subtotals. This is evidence to prioritize generated-code
optimization/code-generation cost over header parsing or linking for the next
experiment; it is not proof every shard has the same distribution.

**Next discriminating step:** use the retained pass reports to select one
common-shard code-generation or shard-partition candidate. Compare fixed-input
baseline/candidate compile time, object/code size and emitted code on a small
representative set before paying for full packs. Any change to generated guest
semantics needs equivalence and runtime measurement; retain exact rounding,
FPSCR and context behavior. A faster compiler run that worsens game CPU time
fails the purpose of #339. Do not simply lower optimization or relax FP rules.

The approximately 40% clean-compilation and 10% weak-device CPU/frame goals
remain **unmet by this pass**. No runtime optimization was implemented, no issue
was closed and no release was created. This pass establishes a narrower build
bottleneck and rejects the unsupported “all updates rebuild everything” lead.

## Evidence and verification

Private receipts: `build/intake-20261008/` contains paginated issue/comment
snapshots, the exact open issue list, incremental command logs and restoration
hashes, the retained Ninja summary, three compiler command/trace/pass reports,
and public-reply readback when posted. Generated game source, objects and raw
traces remain private. The summary above contains no game code or player data.

Validation: actual production Ninja no-op/two-step build and byte comparison;
three real NDK compiler profiles; retained-source/build restoration readback;
queue schema/coverage and focused maintenance tests. Refresh the live queue
before acting; the 7 October weekly counts remain a dated snapshot.
