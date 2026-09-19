# Pixel code125: failed owner stability test

The owner reported a crash followed by slowdowns and a noticeable pause on the
Pixel 9 Pro XL. Code125 is **not accepted for Android stability or release**.
iOS build52 has only the earlier install/launcher evidence; the owner has not
tested its gameplay. No replacement was installed during this investigation.

## Confirmed crash and current-run evidence

- Android's exit record identifies a native crash at 10:45 JST, 19 September,
  approximately 38 seconds after process start. Signal was SIGABRT. The abort
  message was `Scudo ERROR: internal map failure (error desc=Out of memory)`.
  This is an allocator abort, not an inferred low-memory-killer termination.
- Tombstone BuildID `ad6a74cd5ccb53fe95c891eed6b8cca793fa0d43` matches retained
  code125 symbols. Checked symbolization resolves the allocation through Tint
  uniformity graph construction, Dawn shader-module creation,
  `aurora::gx::cached_shader_module`, `create_pipeline`,
  `compile_pending_pipeline`, and `pipeline_worker`. The failing allocation is
  in a background compilation worker. Its location does not prove Tint alone
  consumed the memory or identify the cause of system mapping exhaustion.
- The already restarted Original/base process uses Vulkan on Mali-G715 at 2x
  resolution. It rebuilt 3,587 pipelines. At 10:45:24 and 10:45:34, sampled FPS
  was 30.88 and 27.87 with 2,472 and 1,340 pipelines still queued. The queue
  drained around 10:45:56; subsequent retained samples reached approximately
  60 FPS. This is correlated startup compilation pressure, not a matched race
  benchmark or proof that warmed gameplay is satisfactory.
  A physical screen capture at 10:52 shows the Luigi Circuit pause menu;
  contemporaneous near-60 samples are therefore paused-scene evidence, not
  recovered racing performance.
- A retained frame window reported 162.65 ms worst frame time. Presentation
  phase maxima reached 161.319 ms and 153.661 ms in nearby windows. The owner's
  approximately one-second perceived pause is not fully captured by those
  sampled windows and remains a separate unresolved observation.
- During the restarted run, `dumpsys meminfo` reported approximately 1.87 GiB
  graphics memory, TOTAL PSS around 3.3 GiB, and later approximately 1.23 GiB
  swap PSS. These are Android's accounting fields, not additive independent
  totals. A later system snapshot had about 1.0 GiB MemAvailable and 0.83 GiB
  SwapFree. These post-crash samples cannot reconstruct the crash's peak.

## Regression comparison and limits

The preserved installed code116 APK embeds runtime base `6ea5dce` with dirty
source and prepared-runtime hash
`8d65c505ad01e2017709aff778ad58943662781824b6d3897902c062a5698650`.
Code125 embeds clean runtime `ff36a77` and prepared-runtime hash
`5a20b0939445286fdc50c5590c172ad5f25e75d2c25d6954197b074a6483dcf2`.
The commit comparison shows no change to pipeline worker scheduling or shader
module retention between those two runtime commits. Code116's dirty build
prevents treating that comparison as an exact binary-source reconstruction.
No old/new physical performance comparison has been performed.

The current scheduler reserves two logical processors, allows the full worker
pool to perform background recipe prewarming, and retains compiled pipelines
and shader modules. It does not adapt background work to memory pressure.
This is an evidence-backed investigation target even though those policies
precede the latest stabilization commits. Recent timer, renderer, diagnostic,
translation and dependency changes must remain in the regression comparison;
the evidence does not exonerate or uniquely implicate any one change yet.

## Next discriminating work

1. Preserve this failed APK, old APK, exact symbols, logs and state backups.
   Keep the active owner session undisturbed. Monitoring is bounded to one hour
   ending 11:47 JST, with private app logs and periodic memory/exit samples.
2. Separate startup compilation from the warmed pause. Correlate the owner's
   transition/track if supplied; use existing timing and presentation phases.
   A later near-60 sample does not invalidate a prior hitch.
3. Prepare a controlled comparison of background prewarm admission and memory
   retention with identical game data, resolution, recipe cache and dependency
   inputs. Limit background work independently of first-use work, ensuring
   priority pipelines can progress without deadlock or starvation. Measure peak
   resident/swap/graphics memory, queue duration and frame tails; fewer workers
   alone do not solve unbounded retention.
4. Reconstruct code116's exact retained inputs where possible before claiming a
   regression cause; isolate the changed timer/renderer/dependency paths if
   warmed stalls remain after compilation. Do not erase the user's caches or
   switch builds during active play to manufacture a comparison.
5. Require data-preserving Original and Retro race/relaunch/endurance acceptance
   before promoting any follow-up. This Pixel failure does not establish the
   same cause for Adreno geometry, PowerVR limits, or other reporters' exits.

Raw evidence and symbolization are private under
`private/android-live-monitor/20260919-104601/` in the stabilization worktree.
The local capture process and thread heartbeat are active; they do not change
the app or its settings. The first crash's full pre-crash timing history was
not retained in the accessible log ring, so peak-memory attribution remains
open. No additional reporter builds or messages were sent.


## Correction prepared

[Code126](pixel-regression-correction.md) corrects the discovered Dawn cache-version
regression, bounds speculative pipeline replay, and fixes demand-work wakeups.
Host and package checks pass; physical acceptance remains open.

## Monitoring follow-up: 11:20 background launcher exit

The 19 September monitor recorded a new exit at 11:20:13.654 JST for the
separate `:launcher` process: Android reason `LOW_MEMORY`, background importance
400, recorded RSS 77 MB. Private exit records correlate the launcher PID across
samples in the installed code125 session. This is distinct from the 10:45 native
game crash; the restarted game PID remains unchanged and continues producing
logs through 11:29. No second native game crash appears in the latest crash
buffer or exit records.

At 11:29:48, game memory accounting reports Graphics 1,983,412 KiB, TOTAL PSS
3,438,646 KiB, TOTAL RSS 2,203,760 KiB and TOTAL SWAP PSS 1,336,512 KiB. These
fields must not be added together. Shader work is already drained (queue zero,
3,587 created). The launcher reclamation adds evidence of memory pressure after
startup compilation; it does not establish the game as its sole cause or prove
that code126 fixes sustained memory use. Recent near-60 FPS samples are not
controlled gameplay acceptance.

The existing capture remains healthy and bounded to 11:47 JST. Evidence is
retained privately in the existing capture directory (`112927-exits.txt`,
`112948-memory.txt`, live app log and latest crash buffer). Code125 remains
installed; code126 has not been installed or physically accepted.
