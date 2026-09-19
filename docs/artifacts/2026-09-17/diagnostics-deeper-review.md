# Deeper review: missing evidence, not just more log volume

This follows the two September 17 reporter-feedback audits. The graphics root cause is still unproven. The deeper review found an unused controlled experiment, a misleading inference risk in existing logs, and a missing measurement at the draw-encoding boundary.

## 1. We already have a useful controlled comparison

The new #211 Samsung capture reaches pipeline `58866e32bada1f83`. The earlier #104 capture reaches that pipeline and `33c5ff18d5c180e0`. These are the same report-grounded recipes used by the existing character matrix-indexing experiment. Their occurrence does **not** identify a specific character/body draw.

The published code119 community APK was inspected directly. It contains the Character Graphics Test UI, both comparison labels, native environment control, and native draw-binding record. Its SHA-256 remains `6c8bb3806abafb32c49efb8a767eaff5b5ad781af867968159455a85c4dfb806`.

Issue #193 has instructions for that experiment but no subsequent comparison result. Asked only the #211 reporter for original → compatibility → original on the same character screen and settings, with `draw_binding` lines, using their already-installed APK. This is a specific hypothesis test, not another normal capture or reinstall. Both explicit modes disable draw merging; therefore compare those modes with each other, not simply Normal against compatibility. A visual change would narrow the affected code path, not by itself prove a driver defect. No change would only weigh against this targeted change if the expected recipes and variant were reached.

[Posted and verified follow-up](https://github.com/chrissotraidis/kartpad/issues/211#issuecomment-5709173869).

## 2. Shader creation, producer recording, API encoding and GPU output are distinct

The #104 capture contains `shader_variant=constant` during prewarm but dynamic pipeline hashes in its draw checks, and no matching `draw_binding` record. Prewarming cached recipes can generate compatibility shaders even when the run does not select them. These creation messages are **not** evidence that compatibility mode failed on the device.

Also, the existing `KartPadPNMTX draw_binding` message is emitted in the producer before GPU command encoding. In `gx::render`, `bind_pipeline` can subsequently return false and skip that draw. A zero aggregate pipeline queue at one telemetry instant does not prove every earlier targeted draw was issued.

Added `KartPadDrawOutcome` to both maintained mobile runtimes. The two target recipe identities survive frame sealing in DrawData; Android preserves the original identity when the compatibility pipeline hash changes. The renderer counts pipeline skips and calls to DrawIndexed, with bound pipeline hash, PID, Unix/steady times and the last event's interpolation/index/instance context. Counts include repeated interpolation encodes. First observation of each outcome is reported, then at most one periodic report per five seconds, capped at 120 reports per target per render thread. Counts are reset after reporting; the final unsent partial interval may be absent. Renderer validation gates collection. The field is in transient DrawData, **not** PipelineConfig, so cache identity and shader recipes remain unchanged. iOS observes the two normal recipe hashes; it does not gain Android's comparison UI or literal shader variant.

An encoded call is not GPU completion, framebuffer readback, or proof of correct pixels. The instrumentation is deliberately named for the boundary it observes. No raw geometry, textures or buffer contents are emitted.

## 3. Current clean draw checks cover a very narrow hypothesis

`kartpad_audit_draw` checks direct PNMTX indices and finiteness of selected position/normal matrix palettes before submission. It does not validate indexed vertex position/normal fetches, projection results, the uploaded GPU buffer contents, material alpha/depth/cull decisions, or shader output. It excludes draws without direct PNMTX. Reporting also deduplicates ordinary records by pipeline, and periodic sampling can miss a consistently positioned draw in a repeating stream. Spreading the inspection budget over time helps coverage but does not eliminate those limitations.

Do not interpret `anomaly=false` as “the character inputs are all correct.” Do not expand this to every state field before the controlled comparison has a result. If both modes fail while the target draws are demonstrably encoded, the next discriminating evidence is the suspect draw's fetched attributes / staged uniform layout or an affected-device GPU frame capture, rather than another broad log bundle. A sampled pipeline alone does not identify the missing body.

Android's [frame profiling documentation](https://developer.android.com/agi/frame-trace/frame-profiler) describes analysis of a specific GPU frame; its [setup requirements](https://developer.android.com/agi/start) require compatible hardware and tooling. That is an optional later reporter/developer path, not a prerequisite placed on the owner or a reason to withhold the current experiment.

## 4. Retroid has more useful timing evidence than FPS alone

Rechecked the last 30 retained phase summaries in #103: CPU-side worker overlap encoding averages range 2.216–3.930 ms (median 3.424); presentation CPU-side wall averages 1.046–1.355 ms (median 1.2375). Three retained producer-ready wait summaries average 0.993–1.152 ms (median 1.131). These are averages per recorded phase sample, not maxima, GPU durations, or synchronized per-frame costs. They overlap and must not be added together.

Compared with recent main-thread CPU cost of 14.034–20.231 ms per present and 83.7–89.7% of a core, this supports investigating producer/game CPU work rather than treating the renderer worker or present-call averages as the whole explanation. It does not identify an arbitrary guest function. The active producer wait/drain probes added in the preceding review are the next useful split: if producer drain dominates, inspect draw/state/cache work; otherwise profile game/HLE work. Existing audio and worker function probes are separate threads/windows and cannot be subtracted blindly from the main-thread number. Diagnostic overhead remains unmeasured on that device.

## 5. Collection can discard the evidence we generated

Android's normal text export retains a 16 KiB header plus a recent tail within a 256 KiB per-file cap. The Retroid log explicitly says its middle was omitted. Function and draw diagnostics have finite reporting budgets. A long session can consequently export neither the middle event nor late diagnostic coverage. Raw-log retention and collection time matter as much as adding fields. No new generic longer-session request was sent. The focused character comparison asks for immediate per-session binding evidence; a missing line is a coverage/selection result, not a successful test.

## Validation and boundaries

Six focused tests pass, including sanitizer-backed counter transitions, first success after skips, interval rollover, backward-clock safety and the 120-report cap. Existing CPU timing, crash-handler and symbol identity contracts still pass. Both actual Android arm64 native and iOS arm64 Release builds compile/link successfully after correcting integration errors found by those builds. Maintained/prepared runtime source verification passes for both platforms.

Evidence is retained under ignored `build/feedback-20260917-deeper/`: test/build logs, published-APK feature checks, phase aggregates and the verified reporter reply. No new release was packaged or published, no physical acceptance is claimed, and no issue was closed. The immediate external dependency is the controlled reporter comparison, not an owner-supplied Android phone or a forced crash.
