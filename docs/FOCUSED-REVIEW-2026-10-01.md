# KartPad focused maintenance plan, 1 October 2026

Make the current player build and import path dependable, finish bounded defects
and features, and maintain a deliberate two-way relationship with WiiCompiled.
Use local reproductions and retained evidence before asking players to test again.

## Evidence and scope

- Reviewed the live inventory of **67 open issues**, their descriptions and recent
  discussion, existing maintenance records, current main source, release notes,
  and upstream contribution history. The table below accounts for every issue.
- Main at review: `978a9f1c81325a2d829e0167e304b6855c4c682d`.
  Latest published KartPad: **0.7.3**. Published artifacts and main are separate
  baselines; record the exact recipe, source and dependency identities for builds.
- Latest published PadMint at review: **0.2.8**. Windows/Linux iPhone builds and
  Android phone-only builds remain experimental; recorded off-Mac iPhone racing
  covers ARM64 build machines, not every desktop architecture. There is no current
  published Mac KartPad application.
- The primary checkout is on old branch `codex/candidate-cpu-handoff-record`
  (`ca36e2be`) with extensive unrelated tracked and untracked work. Current source
  was reviewed through `origin/main`, which matched live GitHub main. Do not build
  that old checkout and describe the result as current-release validation.
- This document is planning and triage. No issue closures, replies, upstream PRs,
  dependency updates or game builds were performed for this review.
- Treat the spoken “Wii M5” request as the existing **Wiimmfi** request, #90.
  M5 Mac hardware also appears in #127, which is a different rendering case.

## Working rules

One change family per pass. Each pass records the trigger, baseline, narrow change,
exact validation, remaining device or service gate, and issue disposition.
Reuse the existing maintenance board, priorities and compatibility matrix; reconcile
their dated states rather than adding another automation or permanent tracker.

Keep reporter outreach quiet while engineering can progress. Existing unanswered
requests are sufficient. An internal reproduction or already supplied confirmation
can finish a bounded scope without another “try latest” cycle. Group issues for
engineering, but close duplicates only when the failure and retained scope match.
Do not close a handset bug from a Pixel result, synthetic limit fixture or silence.
When a thread mixes a finished bug with new requests, record the finished scope
and preserve the remaining request explicitly before closure.

Preserve saves, identity, private inputs and dirty work. Prefer the primary checkout
when safe; for implementation needing isolation, check ownership and reuse a
suitable worktree under `$CODEX_HOME/worktrees`. Do not reset the primary checkout
or create sibling clones in the GitHub folder. Publish only reviewed source and
audited public artifacts, never private game inputs or generated game packs.

## Pass 1: player compilation and RVZ import

Priority issues: #357, #366, #347, #192, #194. Track #357's separate S26 Ultra
Automatic graphics failure in the renderer pass.

1. Start from the exact current KartPad recipe and latest published PadMint.
   Inventory existing local build evidence, private format fixtures and output
   identities before deciding which full builds actually need repeating.
2. Validate one complete player path for each distinct supported build environment:
   Windows, macOS and Linux producing an Android pack; Apple Silicon macOS producing
   an iPhone/iPad IPA. Keep off-Mac iOS and Termux builds in their experimental
   lanes. Use a clean cache baseline and a second cached build; do not delete a
   player's real cache to simulate first use.
3. Use the existing private RMCP01 revision-0 RVZ fixture. Compare its extraction
   against the matching ISO/WBFS or extracted DATA fixture, then build the pack,
   import data through the real picker, and reach an Original race. Exercise Retro
   setup and mode switching separately. Record saves/settings before and after.
4. Validate Android RVZ data import with a compatible pack already installed.
   The app still accepts RVZ for data import; #357 does not establish an extraction
   regression. Distinguish the common-key requirement for encrypted disc data from
   the separate compilation step. The extracted `KartPad game data` folder is the
   documented path that avoids an in-app key requirement.
5. Exercise interrupted download/resume, cancelled import, insufficient space,
   a wrong-region/revision input and an incompatible pack using bounded fixtures.
   Fix the reproduced failing boundary. Measure peak workspace and output space
   before changing published storage or duration estimates.
6. Verify #347's released fingerprint behavior: app-only update reuses the pack;
   a relevant header or define change rejects it; Android migration preserves
   state and removes obsolete packs only after successful replacement. Confirm
   identical cached pack output and export checks. This is already implemented,
   so the work is reconciliation and regression validation, not a new design.

Done: reproducible end-to-end player builds and imports with exact outputs,
cache behavior, failures and platform limits recorded. Direct RVZ import alone
cannot supply the separately compiled game code missing from the public shell.
Simplify the two-step flow without promising restoration of the old bundled-game
distribution model.

Documentation: correct `docs/BUILDER.md`'s stale Mac-only/in-progress platform
description and community-preview packaging language. Align README, Android/iOS/
Mac guides, support instructions and PadMint terminology against shipped menus
and artifacts. Keep supported and experimental build routes explicit. Make pack
versus data, first setup versus update, and compatible versus stale pack clear.
Move the retired numbered download workflow in `docs/INSTALL_MACOS.md` into a
clearly historical section. Preserve the mobile distinction: RVZ works through
PadMint for iPhone/iPad; its alternative direct importer uses ISO/WBFS, while
Android's direct data importer also supports RVZ.

Two concrete code-review candidates need local discrimination before a fix:

- `game_pack.py` calls `_translated()` before checking `reusable_pack()` on both
  mobile paths. Translation uses a broader source identity, and PadMint separates
  workspaces by repository revision. Compare a compatible app-only update across
  two revisions and record extraction/translator/compiler invocations: cached
  pack reuse may still do avoidable preparation/translation first. Reorder only
  after verifying all input validation and export compatibility remain enforced.
- `cli.py`'s `inspect` result says `verified after extraction` for provisionally
  accepted disc images even though `inspect` does not extract them. A synthetic
  RVZ fixture can demonstrate the misleading status. Use wording such as
  `requires extraction verification`; preserve the real DOL/REL identity gate.

## Pass 2: completion and release reconciliation

First audit #347 against 0.7.0's implementation and recorded race/cache/mismatch
gates. Review #102, #196 and #235 for completion of their original defect scope:
each has affirmative reporter evidence already. #199 confirms the local frozen
image is gone, but does not establish every external-output combination. #297's
mapping features shipped; validate action coexistence and persistence locally.

Do not reopen implementation merely because an issue remains open. Conversely,
“ready locally” is not “shipped”: #304's tested PowerVR dependency was absent from
the 0.7.3 artifact. Verify integration, source pins, dependency identity and the
actual APK before announcing a candidate. Its handset acceptance remains separate.
#330 has a published timed resume check; use it as a local lifecycle regression,
while keeping the reported Samsung result distinct.

Reconcile `docs/MAINTENANCE-BOARD.md`, `docs/maintenance-priorities.json`,
`docs/KNOWN-ISSUES.md` and the compatibility matrix. They still carry dated states
such as #196 startup unresolved and #216 Retro untested despite newer results.
Replace generic waiting states with the next engineering action or exact external
dependency. Do not post 67 administrative comments to accomplish this.

## Pass 3: measured compilation and CPU work, #339

Patchy's targets are approximately **10% lower CPU frame time on weaker hardware**
and **40% shorter final compilation**, on the same machines. These are acceptance
targets, not demonstrated gains or promises.

- Record translation, shard generation, native compilation and link times
  separately, plus download/preparation/packaging outside those stages. Measure
  clean, no-op and representative incremental builds with identical tools, worker
  limits, power conditions and cache definitions. Repeat enough to distinguish
  noise; retain compile commands, shard sizes and the slowest compilation units.
- Inspect regenerated identical output, shard imbalance, repeated header parsing,
  dependency ordering, link cost and cache invalidation before tuning. The pack
  fingerprint already removes many unnecessary rebuilds. Audit whether it also
  invalidates for harmless inputs, without weakening ABI compatibility checks.
- Establish a diagnostic-off runtime baseline. Use the same device, track, mode,
  opponents, resolution, thermal state and warmed/cold state. Report mean CPU
  frame time, p95/p99, worst frame and sustained behavior; identify shader/cold
  hitches separately. Do not infer CPU cause solely from unchanged FPS at lower
  resolution, or claim a weak-phone gain from the M3 Max or Pixel.
- Retained #198/#275/#313 evidence provides concrete race workloads. #135 now
  points at GPU waiting and heat on the A10X, so keep it out of a generic CPU fix.
  GCN Cookie Land #204 is a battle workload, not a time trial.
- Profile guest execution, GX/draw work, dispatch, ABI crossings, memory access and
  waits. Select one measured hot path and test baseline/candidate/baseline. Stop
  or change the experiment when gains are within noise, stutter worsens, generated
  output grows excessively or semantics regress.

Done: stage-specific build results and an attributed, reproducible runtime change.
Publish measured results with limits even if the requested targets are not met.

## Pass 4: bounded stability and rendering fixes

Keep separate reproducers for cup-results-to-ceremony (#128/#131/#323), startup
and adapter rejection (#143/#200/#208/#216/#236/#301/#303/#304/#321/#332), and
Apple launch/freeze behavior (#309/#310/#322/#327/#370). Use retained matching
symbols and traces before adding instrumentation. #370 stays alive with all UI
gone; it is not yet a classified app crash. #327's remaining problem is launch
flicker, with the reporter saying other gameplay is flawless.

For graphics, preserve the Fold/OnePlus positive results separately from S24
failures and multi-player rendering. Review existing PR #369 before duplicating
its work: it exposes two S24 diagnostic combinations, not a proven graphics fix.
The next correction should be guided by an actual failing draw/model fixture.
Audit the S26 Ultra Automatic classification path from #357 using available GPU
identity evidence; do not assume an exact driver from a marketing model name.

Done: reproduced boundaries fixed locally and checked in the actual package,
with affected-driver or hardware gates named where access is unavailable.

## Pass 5: finish features in deliberate order

1. **Existing controls first:** #5/#306 Wii Remote plus Classic Controller Pro
   mapping/latency, #197 ipega mode/handoff, #297 shared actions/triggers and #324
   single Joy-Con input. Distinguish connection, event delivery, mapping, reconnect
   and measured latency. Preserve the current input architecture and menus.
2. **Retro ghost transfer, #295:** Original export is confirmed. Implement only
   the remaining Retro storage/course mapping, validate `.rkg` inputs, round-trip
   and preservation of unrelated ghosts/saves using fixtures.
3. **DSU, #91:** one phone supplying Player 1 buttons and calibrated tilt on tvOS,
   manual endpoint and experimental opt-in. Validate packet integrity/order,
   disconnect/stale input clearing, slot ownership and the tvOS launch gate before
   extending to multiple phones or motion-only sources. Protocol tests can be
   local; latency and Apple TV gameplay require hardware.
4. **Wiimmfi, #90:** first a feasibility decision against current upstream patch
   and authentication requirements. A patched ISO, MAC field or redirected server
   alone is insufficient for ahead-of-time translated game code. Require a matching
   translation path and private identity handling before implementation; login,
   matchmaking, a race, results and reconnect are distinct service gates.
5. **Broader compatibility:** RMCE01, full identity migration, cheats (#203/#234),
   older Apple OSes (#300), automatic Retro updates (#194), and separate external
   game output (#100). Keep these explicit scoped proposals behind build/stability
   work rather than combining them into a broad rewrite.

## WiiCompiled work in parallel

Current KartPad's recorded upstream base is `83463764b8ac`, not the historical
`1912292c804f` baseline. Inventory each translator/runtime gitlink and meaningful
backport before describing a missing commit count as missing fixes.
At review, current WiiCompiled is `75886669bcf3`: **18 commits after** KartPad's
recorded base. All five maintained source pins share that base. This is ancestry,
not a count of unimplemented fixes.

Patchy already imported KartPad fixes in upstream
[PR #244](https://github.com/patchzyy/Wiicompiled/pull/244).
Other controller/network fixes are in
[PR #251](https://github.com/patchzyy/Wiicompiled/pull/251), and anonymous Mach
memory is already proposed in
[PR #252](https://github.com/patchzyy/Wiicompiled/pull/252).
Avoid duplicate submissions. A source pin update and an upstream contribution
are separate changes with separate validation.

Make a compact contribution ledger inside `docs/UPSTREAM_UPDATES.md`: change,
KartPad source commit, upstream equivalent/PR, affected platforms, evidence,
current status, and next action. First compare upstream's newer commits against
the actual maintained source; then propose small genuinely missing shared fixes
with upstream-focused reproducers/tests. Keep app UI and personal game-pack
packaging downstream unless upstream has a concrete use for them.

| Incoming change | Current source finding | Focused acceptance |
|---|---|---|
| [`bltl` lifting, #254](https://github.com/patchzyy/Wiicompiled/pull/254) | Missing in pinned translator `9d563f98953c`. | Narrow instruction regression with LR set before either outcome; graph comparison and native correctness gates. |
| [Imported Wii certificates, #265](https://github.com/patchzyy/Wiicompiled/pull/265) | Mac `fa2f3d393385` and Android `18685d137e7d` still reject nonzero scalars at/above subgroup order rather than reducing them. Check iOS/tvOS pins separately. | Canonical, reducible and zero-key fixtures; no private identity uploads; authentication acceptance remains separate. |
| [Windows path characters, #266](https://github.com/patchzyy/Wiicompiled/pull/266) | Candidate; equivalence and KartPad consumer not yet established. | A real player build under spaces, apostrophes and ampersands; isolate quoting failures. |
| [Build reproducibility, #270](https://github.com/patchzyy/Wiicompiled/pull/270) | Native-prebuilt flags absent; actual KartPad build-path relevance still needs tracing. | Toolchain/cache/provenance checks against the path actually used, then stage timings. |

Upstream #267's paired-float Mac memory fallback is already semantically present
in the current macOS `Memory::Read64` path. Check the write path; do not list the
whole change as missing merely because its commit is absent from ancestry.

Review upstream's CONTRIBUTING instructions before submission. Prepare tested
code and concise technical evidence; the upstream maintainer's requirement for
the contributor's own descriptions and replies must be respected when publishing.
Do not make speculative PRs merely to increase contribution count.
The [upstream instructions](https://github.com/patchzyy/Wiicompiled/blob/main/CONTRIBUTING.md)
state: “PR descriptions and responses must be written by you, not generated.”
Prepare code, tests and review evidence; Chris writes the upstream submission text.

## Every open issue: disposition and next focused action

“Completion review” means existing evidence may finish a bounded scope; it is
not a closure already performed. “Validate shipped” means implementation exists
but the exact remaining contract still needs checking. Rows are engineering
assignments, not declarations that different devices share the same cause.

| Issue | Disposition | Next focused action |
|---|---|---|
| [#5](https://github.com/chrissotraidis/kartpad/issues/5) | Partial feature | Mii import/naming delivered; retain Wii Remote/Nunchuk connectivity and full-editor limits. Pair with #306 source review. |
| [#90](https://github.com/chrissotraidis/kartpad/issues/90) | Feature research | Wiimmfi translation/authentication feasibility and service acceptance plan. |
| [#91](https://github.com/chrissotraidis/kartpad/issues/91) | Feature | Bounded Player 1 DSU implementation; protocol/stale-input tests then tvOS hardware. |
| [#100](https://github.com/chrissotraidis/kartpad/issues/100) | Display defect/feature | Reproduce chooser-to-game mirroring; distinguish wired, AirPlay and separate TV view. |
| [#102](https://github.com/chrissotraidis/kartpad/issues/102) | Completion review | Fold reporter confirms manual all-draw fix in both modes; record workaround scope and cost, check default separately. |
| [#103](https://github.com/chrissotraidis/kartpad/issues/103) | Performance | Preserve S25+ pacing and Pocket 5 warm CPU cases separately in #339 workload set. |
| [#104](https://github.com/chrissotraidis/kartpad/issues/104) | Renderer defect | S24 textures/position and performance unresolved; review PR #369 and actual failing draws. |
| [#119](https://github.com/chrissotraidis/kartpad/issues/119) | Validate shipped | Check immersive-bar reapplication on entry, menu close and resume; avoid universal-device claims. |
| [#120](https://github.com/chrissotraidis/kartpad/issues/120) | Renderer defect | Retain OPD2514 stretched surfaces; use renderer evidence, not more game-image changes. |
| [#123](https://github.com/chrissotraidis/kartpad/issues/123) | Online/performance | Validate retained Pixel menu/music/network-wait case; don't infer all racing FPS fixed. |
| [#127](https://github.com/chrissotraidis/kartpad/issues/127) | Validate shipped | M5 Mac two-player alignment remains its own renderer regression gate. |
| [#128](https://github.com/chrissotraidis/kartpad/issues/128) | Cup exit/display | Reproduce Retro ceremony boundary; preserve AYN Thor system-bar subcase separately. |
| [#131](https://github.com/chrissotraidis/kartpad/issues/131) | Cup exit | Original final-results-to-ceremony reproduction; compare exact stack with #128/#323. |
| [#135](https://github.com/chrissotraidis/kartpad/issues/135) | GPU/performance | A10X current menu GPU waits/heat; compare build60/current graphics work, not disproven prewarm theory. |
| [#143](https://github.com/chrissotraidis/kartpad/issues/143) | Startup | Honor X7D remains unclassified; retained evidence before assigning GPU cause. |
| [#167](https://github.com/chrissotraidis/kartpad/issues/167) | Performance | G200 20–30 FPS insensitive to scale is profiling evidence, not proof of CPU attribution. |
| [#169](https://github.com/chrissotraidis/kartpad/issues/169) | Data/display/performance | Prioritize non-destructive save-boundary fixtures; modest FPS improvement does not close save loss. |
| [#192](https://github.com/chrissotraidis/kartpad/issues/192) | Retro install | Shipped recovery race versus unresolved Smart 8 download; use retained visible failure. |
| [#193](https://github.com/chrissotraidis/kartpad/issues/193) | Renderer defect | S24 negative result with option active; correlate skinned versus rigid model draws. |
| [#194](https://github.com/chrissotraidis/kartpad/issues/194) | Partial feature | Old version mismatch handled; safe automatic Retro updating remains unimplemented. |
| [#195](https://github.com/chrissotraidis/kartpad/issues/195) | Performance | S25 Ultra time-trial versus VS opponent/item workload. |
| [#196](https://github.com/chrissotraidis/kartpad/issues/196) | Completion review | Reporter confirms Original/Retro launch works; preserve warmup and online-search follow-ups separately. |
| [#197](https://github.com/chrissotraidis/kartpad/issues/197) | Controller defect | ipega default A/B mapping and menu handoff; local detach/held-input reproduction. |
| [#198](https://github.com/chrissotraidis/kartpad/issues/198) | Performance | G85 Luigi Circuit race unchanged in 0.5.4 despite smoother menus; use #339 profile. |
| [#199](https://github.com/chrissotraidis/kartpad/issues/199) | Partial completion review | Local frozen image confirmed gone; retain unproven HDMI/AirPlay scope under display work. |
| [#200](https://github.com/chrissotraidis/kartpad/issues/200) | Startup | vivo delayed exit distinct from installer recovery; exact-session classification. |
| [#202](https://github.com/chrissotraidis/kartpad/issues/202) | Window/insets | AYN Thor gameplay bars versus expected pre-title border; inspect actual surface area. |
| [#203](https://github.com/chrissotraidis/kartpad/issues/203) | Multiple features | Separate RMCE01 profile, NAND/identity transfer and cheats; no inferred support. |
| [#204](https://github.com/chrissotraidis/kartpad/issues/204) | Performance | Original Cookie Land battle and smooth time-trial control; profile opponents/draw workload. |
| [#206](https://github.com/chrissotraidis/kartpad/issues/206) | Online | Retain mobile-data 86420 versus Wi-Fi/VPN; inspect peer-session evidence without assuming NAT cause. |
| [#207](https://github.com/chrissotraidis/kartpad/issues/207) | Performance/exit | A05 slowdown and intermittent race entry exits are separate measurements. |
| [#208](https://github.com/chrissotraidis/kartpad/issues/208) | Startup | Canonical HONOR LGN-NX3 case; classify retained failure, preserve duplicate history. |
| [#211](https://github.com/chrissotraidis/kartpad/issues/211) | Renderer defect | Missing bodies/S24 family; current shader/model evidence, no more ROM imports. |
| [#216](https://github.com/chrissotraidis/kartpad/issues/216) | Partial completion | Tab A9+ confirms both modes launch; older Tab A original report still separate; bodies/lag remain. |
| [#234](https://github.com/chrissotraidis/kartpad/issues/234) | Identity feature | Full console/Mii/country migration differs from raw save/rating import; preserve backups. |
| [#235](https://github.com/chrissotraidis/kartpad/issues/235) | Completion review | Same Honor X7c reporter now races in #313; finish old launch scope while retaining FPS case. |
| [#236](https://github.com/chrissotraidis/kartpad/issues/236) | Startup | OPPO A40 launch failure remains distinct; retained exact-session evidence. |
| [#257](https://github.com/chrissotraidis/kartpad/issues/257) | Insufficient description | Keep one existing clarification pending; no safe defect assignment or repeat request. |
| [#273](https://github.com/chrissotraidis/kartpad/issues/273) | Insufficient description | Motion ticket lacks platform/build transition; existing question sufficient. |
| [#275](https://github.com/chrissotraidis/kartpad/issues/275) | Performance | Same-device Retro ~20 versus Original 30–40 FPS logs; controlled #339 workload. |
| [#278](https://github.com/chrissotraidis/kartpad/issues/278) | Performance | S22 sub-20 FPS; preserve device-specific limits while profiling established workloads. |
| [#295](https://github.com/chrissotraidis/kartpad/issues/295) | Partial feature | Original export accepted; implement Retro course/storage mapping and preservation. |
| [#296](https://github.com/chrissotraidis/kartpad/issues/296) | Performance | POCO X7 Pro Retro Wild Woods 1x; separate from generic Mali assumptions. |
| [#297](https://github.com/chrissotraidis/kartpad/issues/297) | Validate shipped | Shared D-pad actions, trigger mapping and L1 preset exist; local persistence/reconnect checks. |
| [#300](https://github.com/chrissotraidis/kartpad/issues/300) | Compatibility feature | iOS15.7/macOS12 API/dependency audit before lowering deployment targets. |
| [#301](https://github.com/chrissotraidis/kartpad/issues/301) | Partial fix | Moto G85 startup resolved; freeze/no-input and missing models remain distinct. |
| [#303](https://github.com/chrissotraidis/kartpad/issues/303) | Validate shipped | Redmi Note 11 optional debug-function fix exists; don't transfer Moto acceptance. |
| [#304](https://github.com/chrissotraidis/kartpad/issues/304) | Release integration | PowerVR dependency omitted from 0.7.3; package dependency and graceful rejection before device gate. |
| [#306](https://github.com/chrissotraidis/kartpad/issues/306) | Controller defect | Original Wii Remote + Classic Pro on M1; separate D-pad/remapping and latency checks. |
| [#308](https://github.com/chrissotraidis/kartpad/issues/308) | Renderer defect | Red Magic 11 Pro Original geometry; no exact positive result recorded. |
| [#309](https://github.com/chrissotraidis/kartpad/issues/309) | Apple startup | iPad9 initial graphics rejection versus cleanup crash; exact boundary validation. |
| [#310](https://github.com/chrissotraidis/kartpad/issues/310) | Apple race/menu exit | CPU-resource notice took no action; not crash evidence; retain actual termination scope. |
| [#313](https://github.com/chrissotraidis/kartpad/issues/313) | Performance | Honor X7c ~36–40 ms game thread and visible-opponent cost; useful profiling target. |
| [#316](https://github.com/chrissotraidis/kartpad/issues/316) | Partial fix/performance | OnePlus all-draw option fixes visuals at ~50 FPS; Automatic and track textures not accepted. |
| [#320](https://github.com/chrissotraidis/kartpad/issues/320) | Performance | Mali-G51 race cost versus menu/compiler stalls; preserve scene-specific limitations. |
| [#321](https://github.com/chrissotraidis/kartpad/issues/321) | Validate shipped | ROG Adreno debug-label crash removed in release builds; target launch acceptance separate. |
| [#322](https://github.com/chrissotraidis/kartpad/issues/322) | Apple freeze | Character select plus looping audio; prewarm success elsewhere does not prove fix. |
| [#323](https://github.com/chrissotraidis/kartpad/issues/323) | Cup exit/renderer | Solo Sonic stays visible; two-player loss and ceremony exit must be separate reproducers. |
| [#324](https://github.com/chrissotraidis/kartpad/issues/324) | Controller feature | iPhone15 Pro Joy-Con(L) connects without buttons; event routing before motion/multiplayer expansion. |
| [#327](https://github.com/chrissotraidis/kartpad/issues/327) | Partial fix | Current iPhone16 report says launch-only flicker; gameplay good. Inspect chooser/game surface transition. |
| [#330](https://github.com/chrissotraidis/kartpad/issues/330) | Validate shipped | 0.7.2 timed background resume passed locally; retain Samsung-specific acceptance. |
| [#332](https://github.com/chrissotraidis/kartpad/issues/332) | Startup | Moto G75 launch after splash; Adreno cause remains unproven. |
| [#339](https://github.com/chrissotraidis/kartpad/issues/339) | Measured optimization | Stage build timings and profile frame CPU before selecting one narrow change. |
| [#347](https://github.com/chrissotraidis/kartpad/issues/347) | Completion review | Fingerprint ABI3 shipped in 0.7.0 with race/cache/mismatch gates; reconcile open design issue. |
| [#357](https://github.com/chrissotraidis/kartpad/issues/357) | Setup/renderer | Prove RVZ build+data import; separately fix S26 Ultra Automatic classification, don't assume extraction broke. |
| [#366](https://github.com/chrissotraidis/kartpad/issues/366) | Setup constraint | Phone-only build space prevents this user proceeding; verify storage/help, no promised universal Termux support. |
| [#370](https://github.com/chrissotraidis/kartpad/issues/370) | Apple black surface | M2 iPad Air/iPadOS18.7.8 stays open after safety screen, all UI gone; inspect lifecycle/render surface. |

## First execution batch

Begin with current-build provenance, the RVZ/PadMint path and fingerprint
reconciliation. In parallel, finish the upstream equivalence ledger and select a
small set of useful incoming/outgoing changes. Next complete the PowerVR release
integration and CPU/build baselines. Then run bounded controls/ghost work and the
renderer/cup-startup reproductions. Larger service/platform features follow their
feasibility gates. Ship accepted changes together only when their regression and
artifact gates are complete; request outside testing only for a specific remaining
hardware or service question that local work cannot answer.
