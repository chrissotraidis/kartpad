# Mobile diagnostic contract 2 — private Android 119 / iOS 51

Update: the owner subsequently authorized publishing diagnostics preview 2 and asking affected reporters to retry their normal failures. The earlier private-stage installation gate below is historical and does not block this preview. See [release instructions](../../releases/v0.4.25-diagnostics.2.md).
Reviewed 47 open GitHub issues on 2026-09-17. This is an evidence build, not a claim that the reported failures are fixed. Preserve the private 118/50 candidates. No installation, publication, or reporter outreach is part of this iteration.

## What changed and why

Both native runtimes now use a byte-identical event writer (canonical source: runtime/include/kartpad/diagnostics/events.h). JSON records include contract/schema 2, process ID, process-start timestamp, wall/monotonic timestamps, boundary, status, numeric API result, and bounded message. Runtime, guest entry, backend, Dawn instance, adapter, device, and surface checkpoints distinguish the first failure from its consequences. Each boundary has 32 records plus an exhaustion marker. Driver text is limited to 512 bytes, escaped and projected to ASCII; this is not a general secret redactor. Review exports before posting.

Dawn instance messages are now connected to the session transcript, alongside adapter/device result callbacks. This addresses a specific missing opportunity in #216: Vulkan adapter rejection preceded an unusable Null fallback and a later surface abort. Mobile Null is rejected before configuration; required surface usage is checked before configuration. These checks remove a misleading cascade, not establish Vulkan compatibility or fix the underlying adapter rejection. Some errors occur before the callback exists or are not emitted by Dawn; this does not promise every driver rejection reason.

Both platforms emit the same coarse frame window (every 300 presents, maximum 720 records), even without a visible FPS overlay. Includes FPS, p95/p99/worst frame duration, queued pipelines and resolution. These are presentation timings, not GPU timestamps, and shader queues do not establish GPU utilization. Existing opt-in inclusive thread CPU/wall timings cover selected functions, not arbitrary whole-program profiling. Existing sampled PNMTX draw diagnostics are retained, not a capture of every draw or every graphics defect.

Android health samples now include PID, Unix time, PSS and explicitly labelled Android thermal state. The bounded root health journal was collected but omitted from diagnostic exports; text and ZIP now include its last 256 KiB, marked as cross-session history. OS exit and trace rows include PID. Old history must still be matched by time/build/profile; PID can be reused. Missing memory data is null, not zero. iOS adds an independent 10-second memory/thermal/power sampler for up to 720 samples, with a final-sample marker. iOS physical footprint and Android PSS are different measures, deliberately separate fields. Thermal integer scales also differ and carry platform names. A blocked game thread need not stop the independent sampler, but OS suspension or process death will.

Both report contexts identify contract 2 and label context as export-time, not selected-session state. Capability fields describe supported capture paths, not proof that a particular capture is present. Existing source fingerprints, native BuildIDs/dSYM UUIDs, retained OS availability markers, process transcript headers, and OS crash probe remain essential. An empty OS trace does not mean there was no crash.

## Evidence decisions for all open issues

The table names the next useful decision, not a request to repeat a test immediately. Existing reporter evidence remains valid. Owner verification of installation, one normal export, and the explicitly confirmed crash probe comes before distribution.

| Issues | Evidence / next decision | Remaining limitation |
|---|---|---|
| #236, #235, #216, #215, #208, #205, #143 | Startup boundaries + native stack + build/model/OS. Separate import completion, adapter rejection, device/surface failure and guest entry. | #205 still needs import-versus-launch clarification; #216 has multiple devices, not one proven cause. OS may not retain a stack. |
| #200, #207, #131, #128 | Last native boundary, OS exit reason/stack, health timeline at the exit. Cup-end cases need the exact transition. | No automatic in-game course/ceremony identification; record the action and approximate time. #128 system bars are separate. |
| #296, #278, #275, #204, #198, #195, #169, #167, #103, #135 | Warmed frame windows, selected-function CPU/wall, pipeline queue, thermal/power/memory. Compare the same scene/build/settings. | Requires affected hardware. Full attribution still needs Simpleperf/Instruments sampling; no inference that a low FPS number alone means CPU or GPU bound. #135 startup is already confirmed fixed; remaining issue is performance. #169 save replacement is separate. |
| #211, #166, #137, #120, #104, #102 | Sampled PNMTX/layout/pipeline anomalies plus same-scene screenshot, device/driver/build. Retain working-device control in #166. | Sampling may miss the bad draw; no raw textures, shader dumps, guest memory or universal GPU capture. A clean sample does not establish correct rendering. |
| #199 | Frame progression + independent health + lifecycle/OS evidence during image freeze with audio. | Reporter reproduces without TV too. No assumption this is solely AirPlay. A hang stack may require OS tools. |
| #206 | Existing active network-wait evidence and controlled Wi-Fi/mobile/VPN distinction. | No packet payloads or identity dumps. This iteration does not make iOS network instrumentation identical to Android or prove carrier NAT. Do not request another generic log. |
| #257 | Define failing action/profile first, then use matching session/OS evidence. | Body does not describe a diagnosable symptom. |
| #273, #197 | Device/build + motion/controller state and short touch-versus-controller comparison. | No new continuous input stream; logging every input would add noise. Empty #273 body still needs details. |
| #202, #119, #101 | Existing surface/inset/display settings plus screenshot at the relevant lifecycle transition. | Frame timing cannot diagnose aspect/projection visually. #202 startup border is already distinguished from gameplay. |
| #194, #192 | Existing pack version/validation/install result and exact visible error. | #194 is macOS, outside these builds; #192 has a delivered transaction fix awaiting confirmation. Do not log archive contents. |
| #234 | Save/identity transfer semantics and backup type, without identifiers or save uploads. | Full identity/NAND migration is product work; logs cannot add missing support. |
| #248 | Exact guest failure address/build if the held-item transition still fails. | Translator continuation fix delivered; broad successful gameplay is not that transition's acceptance. |
| #297, #295 | Reporter acceptance of delivered mapping and Original ghost import/export. | No extra logs unless a specific failure occurs. Feature scope remains explicit. |
| #127, #5 | macOS same-scene rendering/controller evidence on relevant Mac build. | These mobile candidates do not cover macOS. |
| #203, #100, #91, #90 | Supported disc/identity/cheat, external display, DSU and Wiimmfi feature work. | Logging is not implementation. #100 needs display lifecycle work and physical wired/wireless testing. |

## Research and collection model

Use local structured breadcrumbs + OS-native crash collection + exact matching symbols + explicit user export. Avoid replacing native termination or trying to write complex diagnostics from a signal handler. Preserve independent timing/memory evidence while the game is alive, since a hard kill cannot finish a final report. Bound retained data and distinguish unavailable, truncated, unsupported and present. This extends the previous candidate's [research and acceptance plan](diagnostics-candidate.md).

[Dawn's instance implementation](https://dawn.googlesource.com/dawn/+/b922e0d44146f6d5242dde81e3c9e41793c20842/src/dawn/native/Instance.cpp) exposes instance logging separately from device callbacks; default messages can use platform logging. The compiled pinned SDK must accept the callback API before this is considered implemented. [Android ApplicationExitInfo](https://developer.android.com/reference/android/app/ApplicationExitInfo) provides process IDs and retained trace access; retention is limited and native traces require supported Android versions. Neither source guarantees this reporter's stack or driver explanation will be available.

## Acceptance

Host tests validate wire JSON, escaping/truncation, per-boundary budgets, cross-platform header parity, build identity refusal on mismatched symbols, report context semantics, missing-session export, retained health history and symlink/private-file exclusion. Real APK and physical-iOS SDK builds validate integration. None of those substitutes for owner crash/relaunch/export tests or affected-device gameplay. New artifacts and matching symbols belong in build/diagnostic-candidates-v2; receipts and exact identities are recorded there after packaging.
