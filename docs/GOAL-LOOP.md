# KartPad goal-based autonomous execution loop

**Original engineering goal loop, written 28 August 2026.** Requirements live
in [PRD.md](PRD.md). This is the initial G0–G18 acceptance procedure; current
maintenance priorities and publication rules live in [MAINTENANCE.md](MAINTENANCE.md)
and the [maintenance board](MAINTENANCE-BOARD.md). Do not resume historical
machine state or treat the original delivery order as a current task assignment.

Read `docs/PRD.md` completely before entering this loop.

---

## 1. Mission rule

Work continuously toward the lowest unmet goal. A goal is met only when its required tests have run, the result was observed, and the evidence exists in `docs/` under the rules in the PRD.

A regression reopens the lowest affected goal. Never protect a higher-level feature by ignoring a lower-level failure.

Do not ask Chris for routine engineering approval. Standing local authorization is defined in PRD Section 8. Make the safest reversible choice, record dated evidence, test it, and continue. A human-only external dependency does not justify idling: record it precisely and advance every independent track.

---

## 2. Goal stack

### Foundation

- **G0 — Workspace and evidence system ready.** PRD/loop read; existing state inventoried; journal/status/research files created; stale processes and Simulators cleared.
- **G1 — Inputs and pins verified.** Disc identified/hashed/read-only; WiiCompiled and all required references pinned with licenses and push disabled; dependency lock recorded.
- **G2 — Baseline oracle captured.** Translator tests pass; reference boot/race/save/ghost evidence exists from Dolphin/Wii/upstream Windows where available; no unlabelled assumptions remain.

### Apple runtime correctness

- **G3 — Host portability layer compiles on macOS.** Utility/runtime tests link arm64 without Win32 libraries or x86-only flags; Windows baseline remains isolated/reproducible.
- **G4 — Guest memory is correct on macOS.** Selected Darwin memory path passes scalar, endian, alias, guard, fault, lifecycle, and stress tests; checked path remains an oracle.
- **G5 — Guest scheduler is correct on macOS.** Portable context/scheduler backend passes deterministic stress, lifecycle, register/FP preservation, and shutdown tests.
- **G6 — PPC/AArch64 semantics are exact.** Integer, scalar FP, paired-single, conversion, estimate, flag, and ABI suites have zero unexplained mismatches.

### macOS game

- **G7 — Native Metal frame.** Dawn Metal and Aurora present host and translated GX fixtures, then the first game frame.
- **G8 — macOS boots and accepts input.** Intro/title/menu render; audio is audible; keyboard/controller navigation works.
- **G9 — First complete macOS race and save.** Full race/results/menu transition, save, quit, relaunch, and staff-ghost fixture pass.
- **G10 — macOS offline compatibility complete.** All mandatory original tracks, cups, modes, Battle, Time Trial, ghosts, local multiplayer, controllers, audio, and save rows pass.
- **G11 — macOS performance and stability complete.** Mode-specific native cadence, frame pacing, first-run/warm-cache behavior, 8-hour soak, launch/race stress, and leak checks pass.
- **G12 — macOS online complete.** Local server state machine and impairment tests pass, followed by authorized normal external-service races when prerequisites permit.
- **G13 — macOS application complete.** Native app shell, data management, settings, diagnostics, update-in-place, original icon, package audit, and clean-clone self-build pass.

### Mobile

- **G14 — iPad/iPhone Simulator core complete.** One Simulator at a time; both device classes boot to complete race with Metal/audio/save/lifecycle.
- **G15 — Mobile shell complete.** Touch, optional gyro, layout editor, controller handoff, settings, diagnostics, game-data flow, and mobile icons pass.
- **G16 — Physical iPad/iPhone complete.** Device offline rows, performance, thermal/memory, audio, lifecycle, controller/touch, save, update, and 4-hour soaks pass.
- **G17 — Cross-device online complete.** macOS/mobile and mobile/mobile rooms, races, results, reconnect, path changes, and supported cross-client interoperability pass.

### Release

- **G18 — Full release-candidate matrix green.** Mandatory PRD matrix rows are Pass with exact-candidate evidence; no P0/P1 defects; source/self-build and safety/license audits pass.

Goals G4–G6 are hard correctness gates. G11 is a hard native-performance gate. G12/G17 are hard online gates. There is no fallback title, emulator wrapper, reduced correctness target, or offline-only completion state.

---

## 3. Session-start checklist

At every work-session start:

1. Read `docs/STATUS.md` and the last complete `docs/JOURNAL.md` entry.
2. Identify the lowest unmet/reopened goal.
3. Run `xcrun simctl list devices booted`; shut down every booted Simulator unless the current step explicitly needs the sole listed device.
4. Kill stale KartPad, WiiCompiled, Dolphin reference, helper, translation, test-server, and capture processes.
5. Confirm the disc hash spot-check and pinned reference revisions have not changed unexpectedly.
6. Confirm adequate disk space and that live private saves are backed up before a risky test.
7. Record the session goal, known-good commit/artifact, and smallest planned step in the journal.
8. Enter the main loop.

Never begin by rebuilding everything blindly. Inspect caches, manifests, and the last failure signature first.

---

## 4. The main loop

Repeat until G18 is met:

1. **Pick** the lowest unmet goal.
2. **Inspect current state.** Read status, last journal entries, build manifests, relevant source diff, open defect, and exact prior error. Determine what is already proven.
3. **Define one smallest reversible step.** It must have a clear immediate test and must not combine unrelated variables.
4. **Execute** the step using standing authorization.
5. **Test immediately.** Run the narrowest test that can falsify the change. A successful compile is not sufficient when the step affects runtime behavior.
6. **Compare against an oracle.** Use bit vectors, checked memory path, x86 harness, Dolphin/Wii reference, deterministic state hash, image comparison, recorded audio, or local network fixture as appropriate.
7. **Capture evidence.** Store log/test report/screenshot/profile/capture under `docs/artifacts/<date>/`; sanitize before placing anything in the publishable tree.
8. **Classify the result.** Pass, Fail, Regressed, Blocked—external prerequisite, or Inconclusive. Never round an inconclusive result up to Pass.
9. **Journal** the goal, step, commands, result, failure signature, evidence paths, code revision, and next step.
10. **Update `STATUS.md`** whenever a goal, known-good artifact, blocker, risk, or matrix row changes.
11. **Commit locally** only reviewed source/docs/patches that pass repository safety checks. Never commit private/generated inputs.
12. Continue with the next smallest step.

When a step fails, do not immediately repeat it unchanged. Read and classify the failure first.

---

## 5. Hard process rules

- **One Simulator at a time.** Shut down all existing Simulators before booting the next device.
- **One game instance at a time.** Do not run KartPad and a Dolphin/reference instance simultaneously when collecting performance, audio, input, screenshot, crash, or stability evidence.
- **One online client per intended slot.** Never accidentally duplicate a profile/session because stale clients remained alive.
- **Kill before relaunch.** Always terminate the previous app and orphan helpers first.
- **One variable at a time.** Especially FP flags, memory strategy, scheduler behavior, render backend, audio queue depth, and network parameters.
- **Two identical failures trigger escalation.** The same command failing with the same signature twice must not be run a third time unchanged.
- **Preserve inputs.** Disc images, reference checkouts, live saves, profiles, credentials, and private captures are never casually edited or deleted.
- **No silent fallback.** Every run logs architecture, memory path, scheduler, renderer, FP mode, product profile, enhancement state, and network target.
- **Correctness before speed.** Do not optimize an unproven semantic path.
- **Stable before experimental.** Interpolation, dynamic aspect, underclock, alternate scheduler, or fast paths remain default-off until their own tests pass.
- **No public-service stress.** Latency/loss/12-client/malformed-packet testing runs only against the local authorized server/harness.
- **No secret leakage.** Credentials, keys, tokens, full friend codes where sensitive, raw authentication payloads, and signing material never enter logs, screenshots, command history, Git, or shared diagnostics.
- **No false acceptance.** Source inspection, config, PID, clean process exit, and a screenshot cannot establish gameplay, timing, audio, touch feel, device stability, or online completion by themselves.
- **Hands-on rows stay hands-on.** Steering feel, touch ergonomics, audio quality, controller latency, thermal behavior, and normal online play require direct interaction.
- **Do not wait for permission on routine work.** Choose the least destructive valid action and continue.

---

## 6. Failure signature

Every failure gets a stable signature in the journal before another attempt:

```text
Goal:
Target/profile:
Commit/build manifest:
Command or interaction:
Expected:
Actual:
First failing subsystem:
Primary error code/message:
Guest PC/LR/function if applicable:
Host thread/backtrace if applicable:
Renderer/audio/network state if applicable:
Reproduction rate:
Evidence path:
Variables changed since last known good:
```

Two failures are “the same” when this signature is materially unchanged, even if timestamps or addresses differ.

---

## 7. Unblocking ladder

After a repeated or unclear failure, escalate in order and journal each rung used.

1. **Read the complete evidence.** Full build log, runtime log, crash report, guest dump, Metal validation output, audio counters, network state trace—not the last terminal line.
2. **Verify the test itself.** Confirm the expected result, input hash, profile, architecture, build manifest, app instance, server target, and oracle are correct.
3. **Check for stale state.** Old generated graph, pipeline cache, app container, save, Simulator, server, process, signing artifact, or dependency pin.
4. **Compare with the last known good.** Binary search the local change/pin range or restore the exact known-good artifact.
5. **Use the narrow oracle.** Checked guest-memory path, x86_64 harness, Dolphin/Wii trace, deterministic microfixture, software/host clear frame, silent audio sink, loopback network server.
6. **Read the implementation source.** Follow the exact call from translated function through ABI bridge, memory/scheduler/HLE, renderer/audio/network to the host API.
7. **Read the pinned reference and history.** WiiCompiled, Aurora, Dawn, Dolphin, Retro Rewind, server, Wheel Wizard, issues, pull requests, and commit history for the specific symptom.
8. **Minimize.** Reduce to one operation, guest function, memory region, thread transition, draw, sound block, input transition, or protocol state.
9. **Instrument, do not guess.** Add a bounded trace, state hash, signpost, packet-state log, or assert that distinguishes competing hypotheses.
10. **Route around one broken component.** Use a manual translated-function replacement, checked memory backend, alternate portable scheduler prototype, software/reference render fixture, local server endpoint, or isolated host adapter—while preserving a test proving equivalence.
11. **Reproduce under sanitizers/validation.** ASan/UBSan/TSan where compatible, Metal validation, Guard Malloc, network fault injection, or deterministic stress.
12. **Research one precise question.** Search primary source/docs/issues, return with a hypothesis, and act. Do not browse indefinitely.
13. **Park and advance independent work.** Record a complete open defect, mark the dependency, and take the largest available step that does not bypass a lower correctness gate. Return with fresh state.
14. **Human-only prerequisite.** If terms, account creation, CAPTCHA, credential, physical action, paid tool, signing team, or public-release authority is required, write the exact prerequisite once in STATUS/HANDOFF and continue all independent work.

Do not abandon the project because a risk is novel. Turn it into a smaller falsifiable experiment.

---

## 8. Specialized loop: host portability

For each Windows-only dependency:

1. Locate every compile/link/runtime use.
2. Define the host-neutral contract from observed behavior, not the Windows API shape.
3. Write contract tests first where practical.
4. Implement a Darwin backend in a separate source file.
5. Compile/run host-only tests on arm64 macOS.
6. Rebuild the Windows baseline or at minimum verify its isolated source graph was not unintentionally changed.
7. Record the replacement and remaining differences in `docs/PORTABILITY.md`.
8. Move to the next dependency only after the immediate test passes.

Port in dependency order: build flags → paths/logging → clocks/threads → memory → scheduler → renderer surface → audio → input → networking → packaging.

---

## 9. Specialized loop: PPC/AArch64 semantics

For each operation family:

1. Add curated edge vectors and randomized vectors.
2. Produce expected results from an authoritative oracle.
3. Run arm64 and x86/reference implementations with raw-bit output and flags.
4. Minimize the first mismatch.
5. Determine whether the cause is translator emission, helper semantics, compiler optimization, host FP environment, ABI, or scheduler state preservation.
6. Change one layer only.
7. Rerun the minimized case, full family, and global semantic suite.
8. Run a translated game microfixture.
9. After the micro-suite is green, rerun the relevant staff-ghost/state-hash fixture.
10. Record the resolution in `docs/SEMANTICS.md`.

Never solve a mismatch by adding an epsilon to a physics-affecting comparison or by ignoring NaN/signed-zero/rounding differences.

---

## 10. Specialized loop: memory and scheduler

For every memory/scheduler change:

1. Run unit/contract tests.
2. Run randomized stress with a fixed reproducible seed.
3. Run the translated microprogram.
4. Run one deterministic boot fixture.
5. Run one complete race fixture after G9 exists.
6. Inspect page mappings, thread/context counts, leaked resources, and shutdown.
7. Compare guest state hashes.
8. Only then measure performance.

The checked memory path is the correctness oracle. The optimized path may replace it only after equivalence tests pass.

---

## 11. Specialized loop: rendering

For each rendering issue:

1. Reproduce in the smallest known deterministic scene.
2. Capture KartPad, Dolphin/reference, and GPU/Metal diagnostics.
3. Classify: guest state, GX command generation, Aurora translation, Dawn behavior, Metal resource state, shader, presentation, or enhancement.
4. Disable optional enhancements.
5. Reduce to a GX fixture where possible.
6. Change one render state/path.
7. Compare image and gameplay state.
8. Run the affected track/mode plus a regression scene.
9. Record screenshots, pipeline/cache identity, and result.

Do not “fix” a visual defect by changing game state or physics unless reference evidence proves the game state was wrong.

---

## 12. Specialized loop: performance

1. Reproduce the exact scene with a deterministic fixture.
2. Warm or intentionally clear caches according to the test definition.
3. Capture baseline p95/p99/worst frame interval, CPU profile, GPU trace, audio counters, memory, and active mode.
4. Rank cost centers on the critical path.
5. Choose one change with a falsifiable expected effect.
6. Build the exact same configuration except that variable.
7. Re-run the same fixture and record before/after.
8. Run correctness, ghost/state, audio, and affected regression tests.
9. Keep only evidence-backed improvements; revert neutral/regressive changes.
10. Update `docs/PERF.md`.

Never optimize averages while p99/worst remains over the native deadline. Never count interpolated presentation frames as simulation performance.

---

## 13. Specialized loop: online

### 13.1 Local-server loop

For each protocol state:

1. Name the client state and expected server transition.
2. Capture an authorized reference trace or read the exact client/server source.
3. Add a local deterministic server fixture for success and representative failures.
4. Run one KartPad client through the state.
5. Compare state, timing, encoded fields, error mapping, and resource cleanup.
6. Add a second Apple client when peer/session behavior begins.
7. Inject latency/loss/jitter only locally.
8. Complete a full local race/results flow.
9. Add the state and evidence to `docs/ONLINE.md`.

### 13.2 External-service loop

Only after local state-machine coverage and external prerequisites are satisfied:

1. Verify service/client version and documented rules.
2. Use a normal human-scale session.
3. Capture only bounded sanitized state/error logs.
4. Complete the intended room/race/results action.
5. Stop on any sign of service degradation or policy conflict.
6. Record exact client/server versions and result.
7. Return to local fixtures for stress or malformed/failure testing.

Never automate matchmaking spam, rating manipulation, anti-cheat probing, or ban-evasion behavior.

---

## 14. Specialized loop: mobile

For each iPad/iPhone change:

1. Confirm no Simulator is booted; boot exactly one target.
2. Build the exact target and verify arm64/no-JIT/no downloaded code.
3. Terminate the previous app; install the new artifact; launch it.
4. Test the changed behavior immediately.
5. Test held-input clearing around any modal/lifecycle change.
6. Capture screenshot/log and update status.
7. Terminate and shut down the Simulator before switching device classes.
8. After Simulator acceptance, install in place on a physical device without deleting its container.
9. Repeat hands-on touch/controller/audio/lifecycle/thermal tests on device.

A Simulator PID or title screenshot never satisfies a physical-device row.

---

## 15. Specialized loop: icons and branding

1. Maintain an editable original vector master.
2. Run a trademark/IP sanity check: no Nintendo logo, character, kart, item, course, screenshot, or copied trade dress.
3. Export the 1024 master and platform sizes through a deterministic script.
4. Validate asset catalogs in macOS, iOS, and iPadOS builds.
5. Inspect 16 px, Dock, Spotlight, Home Screen, Settings, and App Library presentations.
6. Check alpha, clipping, contrast, dark/tinted variants, and visual consistency.
7. Capture icon evidence and record the exact master hash.

Do not use AI-generated or downloaded artwork without recording provenance and confirming it is original and license-safe.

---

## 16. Specialized loop: release candidate

For a candidate commit:

1. Freeze pins and generate the build manifest.
2. Start from a fresh directory and run clean macOS and mobile self-build workflows.
3. Run repository safety checks before and after generation.
4. Build the exact candidate artifacts.
5. Audit every package and binary dependency.
6. Install the exact artifacts, not a nearby development build.
7. Run the mandatory release-regression subset, long soaks, online normal-play rows, update-in-place, diagnostics privacy, and icon checks.
8. Record artifact hashes, signing state, devices/OS, durations, service versions, and all remaining defects.
9. Verify source, notices, privacy wording, and approved product description.
10. Reject the candidate on any P0/P1, unexplained semantic mismatch, package-boundary failure, or missing mandatory evidence.

A tag, checksum, or successful archive command does not make an artifact a release candidate.

---

## 17. Testing rhythm

- **After every code change:** narrow unit/contract/build test plus the smallest affected runtime fixture.
- **After every semantic/memory/scheduler change:** full affected family suite and deterministic translated fixture.
- **After every game-runtime change once G9 exists:** boot + complete-race smoke + save/relaunch.
- **After every renderer change:** deterministic image fixture and affected track/mode.
- **After every audio/input change:** full-race hands-on subset with counters and disconnect/lifecycle checks.
- **After every network change:** local deterministic state fixture; never use production as the first test.
- **Before ending a session:** run the highest known-good smoke path and make the final journal line state a reproducible known-good or exact blocker.
- **At each goal claim:** run every required gate for that goal and create an evidence index.
- **Periodically during active development:** replay the current cross-subsystem regression suite to catch drift before it compounds.
- **For a release candidate:** run the exact-candidate matrix subset defined in the PRD and release checklist.

---

## 18. Parallel-work rule

The lowest unmet goal controls acceptance, but not every independent task must stop behind it.

Allowed parallel examples:

- write host contract tests while a dependency builds;
- design original icons while a long soak runs;
- port diagnostics/settings code while a specific track defect is being minimized;
- build local network fixtures while external account/service access is blocked;
- prepare mobile CMake/toolchain scaffolding after the macOS semantic/memory/scheduler gates are green, even if macOS content QA continues.

Forbidden bypass examples:

- declaring mobile complete while macOS ARM semantics are still divergent;
- optimizing a flat memory backend before the checked oracle is correct;
- testing public online before the local state machine is understood;
- packaging a candidate before private/generated data audits exist.

Journal parallel tasks separately so their evidence does not blur goal state.

---

## 19. Stop and handoff conditions

Routine blockers are not stop conditions. Continue through the unblocking ladder and independent work.

Write a complete handoff and stop only when continuation would require one of the following:

- obtaining copyrighted game data not already supplied by the user;
- accepting terms, solving CAPTCHA, creating/verifying an identity, or providing a secret that only a human can lawfully provide;
- purchasing software/service or using an unavailable paid license;
- pushing/publishing/releasing without configured authorization;
- bypassing platform security, service security, anti-cheat, or a ban;
- risking destructive loss of the only copy of user data with no safe backup path;
- a required public upstream has disappeared and no legally usable source or mirror exists;
- a physical action is strictly required and no connected automation/device interface can perform it.

Even then:

1. state the exact goal and matrix row blocked;
2. provide the minimum human action required, once;
3. record every completed independent goal and last known-good artifact;
4. leave exact commands and expected result for resumption;
5. do not claim completion.

Everything else remains an engineering problem with a smaller experiment available.

---

## 20. Completion condition

The loop ends only when G18 is met:

- mandatory matrix green with exact evidence;
- no P0/P1 defects;
- ARM semantics and determinism proven;
- macOS and physical mobile targets accepted;
- required online flows accepted;
- source/self-build reproduces cleanly;
- original icons and app shells validated;
- package/legal/privacy boundaries pass;
- status, journal, handoff, performance, online, and release documents describe the exact truth.

Until then, pick the lowest unmet goal and continue.
