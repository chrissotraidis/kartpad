# First code119 reporter evidence

Compared the live 47 open issues with the verified publication/reply snapshot. Two new reporter comments were found: [#198](https://github.com/chrissotraidis/kartpad/issues/198#issuecomment-5707551007) and [#104](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5707313589). Downloaded the #198 text attachment and preserved the #104 inline report locally. No private archive, game data or physical Android device was needed. This pass does not establish a bug fix or justify closing either issue.

## #198: CPU-heavy selected session, not an undifferentiated low-FPS report

Reporter: TECNO Spark 20C / Android13, described as Helio G85. The export identifies TECNO KJ5 / API33; native adapter is Mali-G52 MC2. Original profile, reporter-named Luigi Circuit, code119 confirmed in native session header. Selected PID4790; sixteen matching health samples and sixteen frame records. The earlier PID30771 and launcher exit history are distinct attempts.

Pipeline prewarming finishes after 103.8 seconds with 1,254 pipelines. Exclude the first zero-queue interval at present3301 because its CPU measurement spans part of prewarming. The five fully subsequent CPU intervals (presents3601–4801, 52.661 seconds and 1,500 presents) show:

- Recent-frame FPS windows: 25.805–30.271. These shorter windows are not identical to the 300-present CPU intervals.
- Main-thread CPU occupancy: 95.8–96.4% of one core; 30.171–36.165 ms CPU per present, weighted average33.699 ms.
- Nearby completed audio probe windows: approximately3.70% of one core for `AxDspHle::ProcessPBList` (not all audio work).
- Nearby render-worker probe windows: about5.24 ms CPU per call, approximately15.03% of one core. Worker/audio windows are independent and overlapping; do not sum them or subtract them from main-thread occupancy.
- Subsequent `present_total` phase means: 2.443–4.265 ms. This is host-side elapsed time, not GPU execution time.
- Selected-session thermal status stays0, power saving isfalse, battery temperature37–38C. This does not exclude every hardware frequency/power limit.
- Selected-session peak PSS is1,703.45 MiB. Earlier PID30771's higher memory and user-requested exit cannot be attributed to PID4790. No matching selected-process native crash/ANR trace is supplied.

Decision: prioritize main-thread game execution and CPU-side GX/FIFO production/drain costs. Persistent shader compilation, the measured audio function, and host presentation waiting do not account for the selected settled intervals. Do not claim GPU innocence or a particular translated function as the root cause. Renderer validation is enabled in this diagnostic build, so these timings are not a clean retail-build performance comparison.

Source inspection identifies an attribution gap: `KARTPAD_FUNCTION_SCOPE("aurora::end_frame_impl")` is in the synchronous path. `aurora::end_frame()` bypasses that function when the frame worker is enabled, waits for the prior worker and drains the FIFO on the producer. Thus the missing end-frame record is not a missing-export failure or zero-cost result. The next targeted instrumentation should split the active producer's wait and FIFO drain CPU/wall time, alongside main-thread sampling where available. Do not ask for another equivalent code119 log; retain this capture as evidence.

## #104: sampled checks clean, graphics cause still open

Samsung SM-S928B / API36; Vulkan Adreno750; Original profile; native code119 session PID23771. Instance, adapter, device, surface and guest entry succeed. Thirteen frame records include mostly near60 FPS after warm-up and one48.626 FPS window. Eight matching health samples show thermal status0 and power savingfalse. PSS peaks at3,069.12 MiB; this alone is not a leak diagnosis or evidence explaining character corruption. Historical low-memory entries concern older launcher/other PIDs, not this selected attempt.

There are31 emitted draw-check records and no emitted anomaly=true records. They show complete sampled vertex data, in-range PNMTX selections, and no non-finite sampled position/normal matrices. Two completed draw windows report2,048 inspections each, against387,584 and3,563,554 eligible draws respectively. A third window is only partially observed before the capture ends.

Limits are material: only PNMTXIDX-direct draws enter this check; normal output is deduplicated/budgeted; GPU output is not examined. The first2,048 every128th eligible samples consume a window's inspection budget at roughly262,017 eligible draws. A busy30-second window can therefore spend most of its remaining draws unobserved. No anomaly record does not clear all matrix inputs, upload/layout/interpolation, shader execution, or the driver.

Decision: keep the character corruption separate from startup failures and memory-kill hypotheses. Ask only whether characters remained corrupted in this code119 capture, with an existing same-attempt screenshot if available. No additional generic log is needed. The next renderer evidence should distribute the bounded sampling budget across time and identify the actual affected draw/output; simply printing more of the same initial samples will not resolve it.

## Correlation and retained evidence

Match sessions using native build marker, PID and Unix timestamps. Do not directly compare `[KartPadDiagnostic].monotonic_ms` with Android health/legacy `elapsed_ms`: this code uses distinct clock APIs, and the supplied reports show different absolute values. Match legacy phase/CPU lines by session and adjacent frame records, not by treating all monotonic counters as one epoch. Function windows are matched approximately by output order; they do not yet carry common session-clock fields.

Raw text is retained locally under `build/feedback-20260917/`, with a derived `analysis.json`; no raw reporter dump is republished in this document. #198 attachment SHA-256: `bd85149e6a3786c6095e55bb4f0eb89bc5384d80c568e95942c939cb8fcee686`. #104 comment-body SHA-256: `5280579d0e2eaa7872050da392da9524c57c6559e55c1129649fa8bca3afa1ec`.

No application code or release assets changed in this review. The useful result is a narrower CPU target, explicit graphics-sampling coverage limits, and confirmation that the new export paths are producing usable reporter evidence.

## Follow-up receipts

- [#198 reply](https://github.com/chrissotraidis/kartpad/issues/198#issuecomment-5707876669): posted and read back.
- [#104 reply](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5707876852): posted and read back.
