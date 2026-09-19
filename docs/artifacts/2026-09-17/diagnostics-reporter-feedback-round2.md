# Reporter feedback: second September 17 review

Refreshed all 47 open issues and compared their comments with the preceding review. Four new reporter replies warranted follow-up. Two included new diagnostic logs. All four received individual replies, read back through GitHub after posting. Raw logs remain in ignored local build storage; this report contains only relevant aggregate evidence.

## Retroid Pocket 5: #103

[Incoming log and description](https://github.com/chrissotraidis/kartpad/issues/103#issuecomment-5707854622) identify Original at 1x on Moorechip Retroid Pocket 5, Android API 33 / Adreno 650. Export and native metadata agree on code 119. Selected PID 26124, session base_1789613381. This is a separate device case from the Samsung reports earlier in the issue.

The last 30 retained frame summaries range from 40.351–60.490 FPS (median 50.278), with zero queued pipelines throughout those summaries. The last 30 main-thread CPU intervals report 83.7–89.7% of one core (median 87.5%), or 14.034–20.231 ms CPU per present. These are separate telemetry windows, not a per-frame paired trace. Android reports thermal status 0 and power saving off in the matching health samples. Maximum retained PSS is 2,828,871 KiB. The export omits its middle, so it does not establish every transition or prewarm completion time.

This supports investigating sustained main-thread pressure. It does not identify the expensive function, exclude GPU work, or establish release-build performance: draw validation adds overhead. The 94 emitted draw records contain no flagged anomaly; sampled checks cannot establish that all rendering is correct.

Log SHA-256: `cf96bfb598359f009f8373363e6ab8d412e316583d429c6527416614e1c4e180`.

[Reply](https://github.com/chrissotraidis/kartpad/issues/103#issuecomment-5709058249): acknowledged useful evidence and the timing gap; no repeat capture requested on the same build.

## Samsung missing character body: #211 and #104

[#211 incoming log and screenshot](https://github.com/chrissotraidis/kartpad/issues/211#issuecomment-5708300962): screenshot inspected directly. Vehicle selection renders the menu, Standard Kart S and wheels while almost all of the driver body is absent; floating eyes/a small upper-head fragment remain visible. This is direct evidence of the visual defect, despite clean sampled input checks.

Code 119, Samsung SM-S928B / Android API 36 / Adreno 750. Selected PID 21183, session base_1789617100. This capture uses **Original**, 4x resolution and Fill Screen, despite the issue's earlier Retro history. Power saving is enabled in all six matching health samples; thermal status is 0. Neither observation establishes the graphics cause. Maximum retained PSS is 1,865,397 KiB.

Prewarm finishes in 11.8 seconds for 1,656 pipelines. The 900-present summary reports 59.041 FPS with zero queued pipelines; the 1200-present summary reports 36.031, also with zero queued pipelines. Subsequent summaries are mostly near 60. An explicit suspend/resume precedes the final interval: roughly 484 seconds of wall-clock passage versus 42.565 seconds on the steady clock. Exclude its 7.9% CPU reading from steady gameplay comparisons; it is not evidence of a continuous freeze.

There are 25 emitted draw checks, none flagged anomalous. Two completed windows inspect 2,048 draws out of 267,490 and 281,000 eligible draws. Those counts differ substantially from #104's much larger draw counts. Early sampling exhaustion is a coverage weakness, but cannot be claimed as the explanation for every missed defect. Input checks do not identify the character draw or prove correct shader output.

Log SHA-256: `765ca81f19ae6c5705fe3b64146836b0cafe9dfe06c0a8556be0d02dc373b641`.

[#104 confirmation](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5707984957) explicitly says the character remains corrupted. No replacement screenshot is needed to interpret the prior capture. Both reports belong to the SM-S928B / Adreno 750 cohort, but settings, sessions and reporter identity remain separate; a common root cause is unproven.

Replies in Portuguese: [#211](https://github.com/chrissotraidis/kartpad/issues/211#issuecomment-5709058509), [#104](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5709058884). Acknowledged continued failure and avoided requesting redundant logs.

## #198 acknowledgment

[Reporter response](https://github.com/chrissotraidis/kartpad/issues/198#issuecomment-5707940955) supplied no new capture. [Reply](https://github.com/chrissotraidis/kartpad/issues/198#issuecomment-5709059217) confirms the existing capture is sufficient for the current investigation and explains the active-path timing work without promising a release date or a fix.

## Bounded instrumentation changes on both mobile runtimes

- Time the active `aurora::end_frame`, previous-frame wait, and producer command drain including its mutex wait. Existing synchronous-path probes remain. Inclusive timings overlap and must not be added together. Wall time versus thread CPU distinguishes waiting from CPU work; neither is GPU timing.
- Add PID, Unix and steady timestamps to function summaries for session/time correlation.
- Retain the 2,048-check / 30-second draw budget and every-128th-draw filter, but distribute checks across 32 time slices, up to 64 checks each. Unused slots do not accumulate. This prevents an early burst from consuming every check and keeps the maximum inspection count unchanged.
- Include sample elapsed time and aggregate anomalous-inspection counts even when individual anomaly records reach their reporting cap. Existing finite window/report limits remain.

These changes improve the next diagnostic candidate. They do not fix the reported rendering or performance defects, and no issues were closed. No new APK/IPA was packaged or published in this review; existing code 119/build 51 downloads are unchanged.

Validation: six focused tests pass, including sanitizer-backed draw bounds and time-slice exhaustion/reset tests, mobile header parity, native crash-handler preservation, exact BuildID symbol matching, CPU-versus-wait behavior, and emitted timing correlation fields. Actual Android arm64 native target and iOS arm64 Release target compile/link checks are recorded locally in `build/feedback-20260917-round2/`. Physical reporter acceptance remains pending for any future candidate.
