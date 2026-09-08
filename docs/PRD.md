# KartPad PRD: Mario Kart Wii, native on Apple platforms

**Scope:** Original Apple engineering requirements, written 28 August 2026.
The acceptance matrix remains a reference; initial machine state, delivery
order and pre-release assessments below are historical. For current work use
[STATUS.md](STATUS.md) and [MAINTENANCE.md](MAINTENANCE.md). Android's separate
scope is in [ANDROID.md](ANDROID.md).
**Audience:** An autonomous engineering agent with full control of an Apple Silicon macOS development machine.
**Companion document:** `docs/GOAL-LOOP.md`. Read both files before changing code or downloading dependencies.
**Product name:** **KartPad** (`kartpad`). Use it consistently unless a deliberate rename is recorded.

---

## 1. Executive decision

Proceed.

Mario Kart Wii now has a real static-recompilation substrate worth porting: `patchzyy/Wiicompiled`. It translates the supported retail executable and required mod code ahead of time, links the result to a native runtime, and currently produces playable Windows x86-64 builds. This makes KartPad an Apple host/runtime and semantic-correctness port—not a new decompilation project and not a request to write a Wii emulator from scratch.

However, **the current upstream is not an Apple port**. At the pinned source revision in Section 6, the runtime build explicitly requires 64-bit Windows, LLVM-MinGW Clang, and x86-64. Important runtime paths still use Windows fibers, `VirtualAlloc2`/`MapViewOfFile3`, vectored exception handlers, WinSock/Windows libraries, and `-march=x86-64-v3`. The project has improved PowerPC floating-point handling and contains portable-looking subsystems, but a successful Windows build does not establish AArch64 semantic parity, Darwin memory behavior, Metal presentation, CoreAudio, UIKit lifecycle correctness, or online interoperability.

The Native Apple Ports research in Notion reached the same underlying conclusion before the latest upstream changes:

- backend suitability is favorable, but confidence is medium;
- PowerPC floating-point exactness is the critical architecture risk;
- Apple guest-memory and fiber semantics should be validated before spending heavily on UI;
- online support is a separate, high-burden workstream;
- macOS must be established first, with iOS/iPadOS deferred until the host runtime is proven.

Current source research raises feasibility because the Windows port is substantially more complete than the initial Notion snapshot, but it does **not** remove those gates. Therefore:

> Build KartPad as an evidence-gated autonomous engineering program: establish exact AArch64 behavior and a complete macOS port first; then carry the same static core to iPadOS and iOS; then prove cross-device online play. Continue iterating until the measurable acceptance criteria in this PRD are met.

A compile is not a port. A first frame is not a playable game. A completed race is not complete compatibility. A local socket connection is not online gameplay. Every claim must be backed by recorded execution evidence.

---

## 2. Product objective and delivery order

Build **KartPad**, an unofficial native ARM64 static-recompilation port of Mario Kart Wii for Apple platforms, based on WiiCompiled's translator/runtime architecture and the user's legally obtained disc image.

Delivery order is strict:

1. **Source and behavioral baseline**
   - Pin exact upstream revisions.
   - Identify and hash the supplied disc image.
   - Reproduce translator tests and capture an authoritative behavior oracle.
2. **Native Apple Silicon macOS core**
   - Port host abstractions, guest memory, fibers/scheduling, PowerPC semantics, rendering, audio, input, storage, and networking to Darwin/AArch64.
3. **Complete macOS game compatibility**
   - Boot, menus, every offline mode, every original track, saves, ghosts, multiplayer, stable frame pacing, and long-session reliability.
4. **macOS online gameplay**
   - First against a local test server/harness, then against the supported Retro Rewind/WiiLink-compatible environment where service policy permits.
5. **Polished macOS application**
   - Native `.app`, first-run game-data workflow, settings, diagnostics, update-preserving storage, and original icon.
6. **iPadOS and iOS Simulator core**
   - Same statically translated core, no runtime JIT or downloaded executable code, one Simulator at a time.
7. **Native iPadOS/iOS shell**
   - Touch, optional gyro steering, controller support, lifecycle handling, diagnostics, settings, game-data management, and original mobile icon assets.
8. **Physical iPad and iPhone acceptance**
   - Performance, audio, input latency, thermal behavior, memory pressure, background/foreground, network changes, saves, and long sessions.
9. **Cross-platform online acceptance**
   - macOS, iPadOS, and iOS clients racing together; interoperability with other supported clients only where the service and protocol permit it.
10. **Reproducible release candidate**
   - Source/self-build workflow, package audits, notices, checksums, exact evidence, and no unverified claims.

Do not start mobile UI work merely because the macOS target compiles. Mobile begins after the macOS core has passed the semantic, memory, scheduler, first-frame, boot, and complete-race gates.

---

## 3. What “done” means

### 3.1 Engineering-complete definition

KartPad is engineering-complete only when all of the following are true and backed by evidence:

- **D1 — Exact input recognized.** The supplied image is identified by format, disc ID, region, revision, size, SHA-1, and SHA-256. The original file is never modified.
- **D2 — Reproducible translation.** The pinned translator deterministically produces the expected base-game source graph and, when enabled, the Retro Rewind profile graph from the supported input.
- **D3 — AArch64 semantic parity.** The integer, memory, condition-register, scalar floating-point, paired-single, conversion, rounding, NaN, signed-zero, estimate, and exception-state conformance suites have zero unexplained architecture-dependent mismatches.
- **D4 — macOS boots natively.** A signed or ad-hoc-signed Apple Silicon `.app` reaches the title screen with Metal rendering, CoreAudio output, and working input without Rosetta in the shipping path.
- **D5 — macOS offline compatibility.** Licenses, menus, Grand Prix, Time Trial, VS, Battle, unlocks, credits, records, ghosts, saves, and local multiplayer work through the matrix in Section 23.
- **D6 — Every original course works.** All 32 retail tracks complete under representative classes, vehicles, characters, weather/effect conditions, and item load.
- **D7 — Determinism is demonstrated.** Built-in or reference ghosts remain synchronized under the documented test method; architecture-specific state hashes remain stable for deterministic fixtures.
- **D8 — Native timing is preserved.** Modes that run at 60 Hz on original hardware sustain a 16.67 ms frame budget with correct pacing. Modes that intentionally use another cadence preserve the verified original cadence. Optional interpolation is never used to conceal missed simulation deadlines.
- **D9 — Audio is complete.** Music, voices, effects, DSP behavior, volume, pause/resume, device changes, and long-session output work without sustained underruns, clipping, runaway latency, or desynchronization.
- **D10 — Input is complete.** Keyboard, ordinary SDL controllers, GameCube-style mappings, four local controller slots on macOS, disconnect/reconnect, and held-input clearing pass. Touch and optional gyro pass on mobile.
- **D11 — Saves are durable.** License data, settings, unlocks, records, ghosts, and other writable state persist across clean quit, forced termination, update-in-place, and relaunch without corrupting unrelated data.
- **D12 — macOS online works.** Authentication or profile initialization, matchmaking, room formation, course voting, race start, live race state, results, ratings where applicable, reconnect/error handling, and graceful service outage pass against an authorized target.
- **D13 — Apple clients race together.** At least one macOS client and one physical iPad/iPhone client complete normal online races together through the supported service or local compatibility server.
- **D14 — iPadOS/iOS are native.** Simulator and physical-device builds are ARM64, use Metal, contain no JIT, and do not download executable code.
- **D15 — Mobile UX is usable.** Every gameplay action can be performed with touch; gyro is optional and configurable; hardware controllers hide/restore gameplay controls correctly; safe areas and lifecycle transitions do not create stuck input.
- **D16 — Application identity is complete.** Original, non-infringing macOS, iOS, and iPadOS icon assets pass asset-catalog validation and remain legible at every required size.
- **D17 — Diagnostics are useful and bounded.** The app records actionable startup, renderer, scheduler, memory, audio, input, lifecycle, save, and network breadcrumbs while excluding game data, translated code, credentials, private keys, and save contents from shared reports.
- **D18 — Long sessions pass.** An 8-hour macOS soak and 4-hour physical-device soaks complete without crash, progressive slowdown, unbounded memory growth, audio degradation, save corruption, or network-resource leakage.
- **D19 — Full test matrix is green.** Every mandatory row in Section 23 has dated evidence. Any skipped external-service row names the exact external prerequisite and is not marked Pass.
- **D20 — Clean reproduction works.** A clean checkout plus the pinned public dependencies and the user's own supported image can reproduce the source build and intended artifacts through scripts alone.
- **D21 — Package boundary passes.** No ISO, extracted Nintendo asset, save, log, signing secret, credential, translated source shard, or other prohibited private input is committed or accidentally packaged.
- **D22 — Defect threshold is met.** There are no reproducible P0 or P1 defects. P2 defects must have a narrowly documented workaround, evidence that core progression is unaffected, and an explicit release decision.

### 3.2 Public-distribution distinction

Engineering completion does not automatically establish that a prebuilt executable containing statically translated retail game code may be publicly distributed. WiiCompiled deliberately performs translation on the user's machine rather than shipping translated binaries. KartPad must preserve that caution.

The default release model is:

- public source, scripts, shell, original artwork, patches, and documentation;
- user-supplied supported disc image;
- local translation and compilation on the user's Mac;
- local signing/self-signing for macOS or iPhone/iPad;
- no game image, extracted assets, translated source, or playable translated binary in the repository.

A public prebuilt `.app` or `.ipa` is a separate legal and provenance gate. Do not describe one as releasable merely because a package audit finds no ISO file.

**Current community-release decision:** the maintainer separately authorized
the free unsigned `v0.4.4` iPhone/iPad community IPA and experimental tvOS IPA
under the narrow, unresolved-rights boundary in
`RIGHTS_AND_LICENSES.md`. The tvOS artifact remains an experimental
hardware-bring-up build pending exact-artifact reporter acceptance. This
decision does not mark the full PRD matrix complete or authorize paid or
official-store distribution.

### 3.3 Native tvOS extension

Native tvOS is now an approved implementation target, with
[`docs/TVOS.md`](TVOS.md) as its platform-specific contract. tvOS must reuse the
same ahead-of-time `KartPadDual` base/Retro Rewind graph and may not introduce a
runtime PPC interpreter or JIT. Its acceptance is separate from iPhone/iPad:
an Apple TV build must prove controller-only gameplay, purge recovery, save
backup/restore, Original mode, and Retro Rewind mode on physical hardware.

A successful tvOS compile is not physical acceptance. Because the maintainer
does not have Apple TV hardware, the first narrowly distributed build may be a
hardware bring-up candidate for a small tester cohort. Distribute only the exact
audited candidate with a narrow checklist, warn testers that no physical launch
has passed yet, and keep support claims closed until their evidence completes
the matrix. Offline Retro Rewind acceptance does not establish Retro WFC
service compatibility.

---

## 4. Non-goals and prohibited shortcuts

The following are not acceptable substitutes for this project:

- embedding or wrapping Dolphin as the shipping application;
- using Rosetta as the final macOS execution path;
- using a PowerPC interpreter or runtime JIT in the final app;
- using MoltenVK as the final renderer merely to avoid completing Dawn's Metal path, when native Dawn/Metal is available;
- disabling accurate floating-point behavior to gain performance;
- forcing a blanket 60/120 Hz simulation mode that changes original game behavior;
- calling interpolation “performance” when the simulation misses its native deadline;
- replacing unsupported online behavior with local-only multiplayer and claiming online completion;
- bypassing account creation, terms, anti-cheat, bans, version checks, certificate validation, or service security controls;
- load-testing a public community service with automated clients;
- distributing Nintendo-owned data, extracted assets, translated game code, or
  private server keys without the explicit maintainer release decision and
  documented boundary required by Section 3.2;
- modifying the original supplied ISO in place;
- silently changing the supported game revision;
- marking a row complete from source inspection, configuration, process launch, or a screenshot that does not show the claimed behavior.

Dolphin, a Wii, upstream Windows builds, packet captures from authorized test environments, and reference ghosts are allowed as ground truth and diagnostic oracles. They are not the shipping execution path.

---

## 5. High-level architecture

```text
User-owned Mario Kart Wii image (ISO/GCM/GCZ/CISO/WBFS/WIA/RVZ)
                         |
                         v
            normalize identity + verify RMCP01/revision
                         |
                         v
          private extraction: main.dol + StaticR.rel + data map
                         |
             +-----------+----------------+
             |                            |
             v                            v
      WiiCompiled translator       optional Retro Rewind
      (wwwii / manifest / shards)   Kamek/Pulsar translation
             |                            |
             +-------------+--------------+
                           v
          private generated ARM64 C++/assembly build graph
                           |
                           v
      KartPad native runtime and Apple portability layer
      - guest memory / aliases / guards
      - guest OS scheduling / fibers / timing
      - PPC integer / FP / paired-single semantics
      - Wii OS, VI, SI, PAD, DSP, DVD, NAND/HLE bridges
      - networking, SSL, DNS, DWC/NHTTP behavior
                           |
            +--------------+----------------+
            |              |                |
            v              v                v
       Aurora GX       CoreAudio/AVAudio   SDL3/GameController
       Dawn WebGPU     save/storage        touch/gyro bridge
       native Metal    diagnostics         controller slots
            |              |                |
            +--------------+----------------+
                           v
            macOS .app / iPadOS app / iOS app
```

Key architectural rules:

1. The PowerPC executable is translated **ahead of time**. The shipping process contains no PPC interpreter and no PPC JIT.
2. The game-specific translated graph and original game data are private local build inputs.
3. The Apple portability layer must be cleanly separated from Windows code so upstream improvements remain mergeable.
4. The base game and Retro Rewind are separate static products/profiles that may share profile-neutral translated shards.
5. The renderer is Aurora GX through Dawn's native Metal backend on Apple targets.
6. The runtime may use Dolphin-derived reference/HLE code where the upstream license permits it. Approved wording is “static recompilation with a Dolphin-derived hardware/HLE runtime,” not “no emulation technology anywhere.”
7. iOS/iPadOS builds contain only precompiled ARM64 code. They do not compile, JIT, or download code at runtime.
8. Networking is a first-class runtime subsystem, not a UI feature added after release.

---

## 6. Source baseline and repositories

### 6.1 WiiCompiled baseline

Begin from the exact known source state before considering newer commits:

- Repository: `https://github.com/patchzyy/Wiicompiled`
- Baseline branch: `main`
- Baseline commit: `1912292c804ff9b1b79938de89369ec4496f9fff`
- Baseline tree: `34f9deda094915e12f47316059911b28c6812964`
- Baseline date: 27 August 2026

Record the actual fetched commit. Clone into `ref/upstream/Wiicompiled`, detach at the pin, disable push URLs, and preserve a clean baseline worktree. Create a separate local integration branch/worktree for KartPad changes.

The pinned tree currently proves or exposes:

- clean PAL `RMCP01` input support;
- static translation with no runtime PPC interpreter/JIT;
- base and Retro Rewind product graphs;
- Aurora/Dawn graphics;
- SDL controller support, including recent four-port GameCube-controller work;
- PowerPC semantic helper files and conservative FP compile flags;
- game-data-private local translation;
- Windows-only x86-64 build assumptions that must be removed or abstracted.

Do not move the pin during initial bring-up. After a known-good KartPad checkpoint exists, evaluate newer upstream revisions one at a time, replay the patch stack, and run the full relevant regression subset before accepting the move.

### 6.2 Required reference repositories

Fetch exact commits into `ref/upstream/`, record them in `dependencies.lock.json`, and disable push URLs:

| Repository | Role | Use boundary |
|---|---|---|
| `patchzyy/Wiicompiled` | Translator, runtime, base and Retro Rewind product graph | Primary implementation base |
| `TeamWheelWizard/WheelWizard` | Current installer/update flow and WiiCompiled integration | Reference for acquisition/update UX; do not blindly port Windows UI |
| `Retro-Rewind-Team/rr-pulsar` | Retro Rewind/Pulsar code, profile behavior, supported server domains and testing model | Build/online reference subject to its licenses and service rules |
| `Retro-Rewind-Team/wfc-server` or the exact documented fork | Local authorized WFC-compatible test server | Local integration and failure testing; never expose default credentials publicly |
| `Retro-Rewind-Team/wfc-patcher-wii` / documented WiiLink source | Client protocol/security patch reference | Reference or licensed integration only |
| the exact Aurora and Dawn revisions vendored/pinned by WiiCompiled | GX compatibility and WebGPU/Metal renderer | Prefer upstream's known-good graph first |
| Dolphin source at a pinned revision | Behavioral oracle for Wii OS, DSP, SI, networking and edge cases | Reference and differential testing; not the shipping CPU core |
| a Mario Kart Wii symbol/map source explicitly permitted for use | Crash symbolization and targeted debugging | Verify license before vendoring any code |

Use the dependencies already vendored by WiiCompiled where possible. Do not mix arbitrary current Dawn, SDL, Crypto++, or Dolphin revisions into the first Apple spike.

### 6.3 Source-derived versus research-derived conclusions

Maintain `docs/RESEARCH.md` with two labeled subsections:

- **Notion/source baseline:** Findings already documented in the Native Apple Ports workspace, including the original “doable with caveats” judgment, critical FP risk, memory-model gate, and online burden.
- **Current upstream research:** Facts reproduced from exact source revisions, build files, commit history, issues, releases, and locally executed tests.

Never silently replace an earlier source conclusion. Record what changed and why the new evidence raises or lowers confidence.

---

## 7. Input disc image and private data boundary

The agent starts with a Mario Kart Wii image in `ref/`.

### 7.1 Identification procedure

Before translation:

1. Locate candidate `.iso`, `.gcm`, `.gcz`, `.ciso`, `.wbfs`, `.wia`, or `.rvz` files without renaming or altering them.
2. Record filename, size, modification time, SHA-1, and SHA-256.
3. Parse the disc header and record game ID, maker, region, and revision.
4. Verify whether it is the currently supported clean PAL `RMCP01` revision.
5. Copy or extract only into ignored private workspaces. The original remains read-only.

### 7.2 Revision policy

Current upstream supports only the clean PAL `RMCP01` image. If the supplied image is a different region, revision, or modified distribution:

- do not patch or convert it silently;
- do not pretend a hash mismatch is harmless;
- record the exact identity;
- determine whether the correct supported image is also present;
- if only another legitimate revision is available, add an explicitly named revision profile with its own maps, hashes, translated manifest, tests, and evidence;
- never translate one revision against another revision's manifest.

An unsupported dump is a blocker for that profile, not permission to obtain copyrighted data from the internet.

### 7.3 Private paths

Use a structure equivalent to:

```text
ref/
  PRD.md
  GOAL-LOOP.md
  <user-owned-disc-image>          read-only, ignored
  upstream/                        pinned read-only reference checkouts
private/
  disc/                            normalized/extracted private data
  saves/                           private reference saves and ghosts
  captures/                        private network/game captures requiring review
generated/
  base/                            translated private source/shards
  retro-rewind/                    translated mod/profile source/shards
build-macos-*/
build-ios-simulator/
build-ios-device/
artifacts/                         packages; ignored until audited
branding/                          original KartPad artwork and source masters
docs/                              journal, status, evidence, performance, online notes
```

The publishable source tree must exclude the disc image, extracted assets, translated source, generated object libraries, saves, private network captures, credentials, signing materials, and local app containers.

---

## 8. Autonomous execution authority and boundaries

### 8.1 Standing authorization

The agent is authorized to perform routine local engineering work without asking Chris for permission, including:

- install or update Homebrew packages and required open-source developer tools;
- install Xcode components and Simulator runtimes available to the signed-in developer environment;
- clone, fetch, inspect, and pin public repositories;
- create local branches, worktrees, patches, build directories, test data, and diagnostics;
- edit project source and locally checked-out dependency source;
- configure, compile, sign ad hoc, install, launch, terminate, and remove disposable test builds;
- boot and shut down Simulators under the one-Simulator rule;
- run local test servers and loopback clients;
- generate original icons and other original application artwork;
- profile with Instruments and other local diagnostics;
- run long tests, fuzzers, conformance suites, and automated input scripts;
- choose the safest reversible implementation when multiple reasonable local approaches exist.

Do not stop for routine approval. Record material choices and evidence in the journal, then continue.

### 8.2 Actions not covered by standing authorization

The agent must not:

- accept service terms on Chris's behalf;
- create or verify online identities that require human attestation, CAPTCHA, email, phone, payment, or identity verification;
- request, expose, guess, or bypass passwords, private keys, friend codes, signing secrets, certificates, or account tokens;
- evade bans, anti-cheat, abuse controls, version checks, or service security;
- upload the disc, extracted data, translated game code, saves, or private captures;
- push to a remote, publish a release, or submit an upstream pull request unless the remote and permission are already explicitly configured;
- load-test or spam a public community server;
- disable platform security, code-signing safeguards, TLS validation, or sandbox protections merely to make a test pass;
- uninstall or overwrite a non-disposable app/container without first preserving approved user data;
- purchase software or services.

When a human-only external prerequisite appears, document the exact prerequisite in `docs/STATUS.md`, continue every independent engineering track, and return to the blocked row when the prerequisite is supplied. Do not sit idle and do not repeatedly ask the same question.

---

## 9. Global engineering rules

These rules apply to every phase:

1. **One Simulator at a time.** Shut down every booted Simulator before starting another device class.
2. **One KartPad/game instance at a time.** Kill stale macOS, Simulator, device, server-test, and helper processes before relaunch.
3. **Kill before relaunch.** Never layer a new run on a hung process.
4. **One variable per diagnosis.** Especially for FP, timing, rendering, and network behavior.
5. **The same unchanged failure gets two attempts, not three.** After the second identical failure, enter the unblocking ladder in `GOAL-LOOP.md`.
6. **Correctness precedes optimization.** Never hide a semantic mismatch with a tolerance or fast-math flag.
7. **Stable path first.** Experimental interpolation, aspect expansion, texture replacement, underclock, or scheduler changes are default-off and clearly logged.
8. **Preserve inputs and user data.** The original disc image and reference checkouts are read-only; live save containers are backed up before risky operations.
9. **Test immediately after the smallest meaningful change.** Do not accumulate untested platform changes.
10. **Evidence is part of the implementation.** A goal without its evidence is unmet.
11. **Hands-on rows remain hands-on.** Automation can navigate menus and reproduce states, but it cannot substitute for touch feel, steering feel, audio listening, or sustained online play.
12. **No false equivalence.** Simulator success is not device success; local server success is not public-service success; a frame counter is not frame-pacing proof.
13. **No silent fallback.** Log renderer, architecture, product profile, build type, memory strategy, scheduler strategy, FP mode, network target, and whether any diagnostic fallback is active.
14. **Keep upstream mergeability.** Apple work belongs behind narrow interfaces and target-specific files, not scattered `#ifdef __APPLE__` edits when a platform abstraction is practical.

---

## 10. Phase 0 — baseline, provenance, and behavioral oracle

### 10.1 Read before coding

Read, in order:

1. `docs/PRD.md` and `docs/GOAL-LOOP.md`.
2. WiiCompiled `README.md`, `CONTRIBUTING.md`, `LICENSE`, `THIRD-PARTY-NOTICES.md`.
3. Translator README, project configs, manifests, generated-shard format, and translator tests.
4. Runtime CMake graph, `PublicProducts.cmake`, `main.cpp`, memory files, fiber manager, PPC/FPU helpers, audio backend, controller code, networking/HLE, product profiles, logging, and crash handling.
5. Aurora and Dawn build graphs and Apple support status at their pinned revisions.
6. Retro Rewind's source, license files, server-domain switches, local-server instructions, and exact update/profile inputs.
7. Wheel Wizard's WiiCompiled/Retro Rewind install and update logic.
8. Dolphin's relevant Wii memory, OS, DSP, SI, SSL/NHTTP/DWC, NAND, and Mario Kart Wii behavior.
9. Every open upstream issue or pull request that mentions macOS, ARM64, AArch64, floating point, memory, fibers, Metal, networking, or Mario Kart Wii correctness.

Summarize the result in `docs/RESEARCH.md`; do not rely on memory after the initial read.

### 10.2 Establish a reference behavior oracle

Use one or more of the following, in descending preference for each test:

- original Wii hardware owned/available to the tester;
- pinned Dolphin on the same Mac using the same disc image;
- the pinned official WiiCompiled Windows release/build in an authorized local Windows environment;
- architecture-neutral unit vectors with known PowerPC outcomes;
- upstream recorded ghost-sync fixtures and logs whose exact provenance is known.

For architecture differential testing, build the semantic harness for both arm64 macOS and x86_64 macOS. Run the x86_64 harness under Rosetta when available. This provides a same-OS x86-versus-ARM comparison without making a Windows VM a project prerequisite.

Capture baseline evidence for:

- boot/title/menu flow;
- one Time Trial on Luigi Circuit;
- one staff-ghost race;
- one Grand Prix race with items and AI;
- one two-player local race if available;
- title/menu/race audio;
- a save/relaunch;
- renderer and timing behavior;
- a normal authorized online flow if an account/test profile already exists.

Do not block all macOS development merely because a Windows oracle is unavailable. Use Dolphin/Wii and deterministic test vectors, and document the missing comparison source.

---

## 11. Phase 1 — make the runtime host-neutral

The first code goal is not “launch on macOS.” It is a clean portability boundary that can compile host-only tests on both Windows and Apple.

### 11.1 Build-system separation

Replace the current hard-coded Windows/x86-64 assumptions with explicit target capabilities:

- `MKW_HOST_WINDOWS`, `MKW_HOST_DARWIN`;
- `MKW_HOST_X86_64`, `MKW_HOST_ARM64`;
- `MKW_RENDER_D3D12`, `MKW_RENDER_VULKAN`, `MKW_RENDER_METAL`;
- `MKW_PRODUCT_BASE`, `MKW_PRODUCT_RETRO_REWIND`;
- `MKW_BUILD_MACOS`, `MKW_BUILD_IOS_SIMULATOR`, `MKW_BUILD_IOS_DEVICE`;
- `MKW_GUEST_MEMORY_FLAT`, `MKW_GUEST_MEMORY_CHECKED`;
- `MKW_GUEST_SCHEDULER_*` for the chosen scheduler backend.

Requirements:

- Windows builds remain buildable from the same source unless a documented upstream conflict makes that temporarily impossible.
- Windows libraries such as `shell32`, `windowsapp`, `dbghelp`, `user32`, `winmm`, `ws2_32`, `iphlpapi`, `secur32`, `crypt32`, `setupapi`, and `winusb` are linked only by Windows targets.
- `-march=x86-64-v3` is never applied to arm64 targets.
- PowerPC semantic compile flags remain separate from ordinary host-runtime optimization flags.
- Apple targets select Dawn Metal and disable D3D/Vulkan code not needed by the artifact.
- Third-party warnings and project warnings remain separated.
- Generated translated shards are compiled with bounded parallelism and deterministic flags.
- Every target records a machine-readable build manifest: source commits, compiler, SDK, deployment target, architecture, product profile, flags, and generated graph hash.

### 11.2 Host platform interfaces

Create narrow interfaces for:

- virtual memory reservation/mapping/protection/faults;
- stackful guest execution or scheduler context switching;
- monotonic clocks, sleeps, high-resolution timers, and thread naming/priority;
- sockets, DNS, interface enumeration, TLS certificate stores, and network-change events;
- file paths, atomic writes, directory watching, and app support/cache/temp directories;
- crash capture, symbolization, message presentation, and process exit;
- audio device enumeration/output;
- controller discovery and raw adapter access;
- media/session integration and music ducking;
- window/surface creation and DPI/Retina sizing.

Host-independent code must not include Windows or Apple headers directly.

### 11.3 Phase gate

Phase 1 passes when:

- the translator's no-game-data tests are green;
- host utility libraries compile for arm64 macOS;
- platform-contract tests run on macOS;
- the current Windows target or at least its compile graph remains reproducible in the baseline worktree;
- no game code has yet been blamed for a host abstraction failure;
- `docs/PORTABILITY.md` lists every remaining Windows-only source file and its owner/plan.

---

## 12. Phase 2 — Apple guest-memory model

Current WiiCompiled uses a Windows-specific flat guest-memory implementation with a fixed 4 GiB address-space reservation, placeholder replacement, shared backing views, page protection, and vectored exception handling. Apple needs equivalent semantics, not a superficial `mmap` substitution.

### 12.1 Required guest-memory behavior

The implementation must preserve:

- the complete 32-bit guest address domain expected by translated code;
- MEM1/MEM2 aliases and any owned regions;
- byte-order-correct reads/writes;
- unaligned access behavior used by the title;
- MMIO, EFB/FIFO, and guarded executable-region dispatch;
- zero-fill and deterministic initial state;
- shared backing where guest aliases refer to the same physical storage;
- page protection and detection of writes to translated/executable ranges;
- clear failure for truly invalid access rather than silent host corruption;
- access to the active translated function, guest PC/LR, and CPU register dump in fault diagnostics;
- safe teardown and repeated process launches.

### 12.2 Darwin implementation candidates

Evaluate in this order and record evidence:

1. A Darwin flat reservation using `mach_vm_allocate`/`mach_vm_map` and VM protections at a fixed, verified host base.
2. A reservation plus file-backed/shared mappings for aliases, with Mach exception or signal handling that can safely classify and resume supported guest faults.
3. A generated base-relative flat path if the translator can make the host base configurable without changing guest-visible addresses.
4. A checked/table-based address path as a correctness fallback and likely iOS path if fixed mappings are not reliable or permitted in the mobile sandbox.

Never use a destructive fixed mapping flag without first proving the range is reserved and owned by KartPad. Never catch a fault and continue unless the handler can identify the exact supported guest operation safely.

### 12.3 Memory conformance suite

Automate at least:

- all scalar widths and signedness;
- every alignment modulo the access width;
- big-endian load/store round trips;
- cross-page and end-of-region boundaries;
- MEM1/MEM2 alias coherence;
- overlapping/mirrored regions;
- guard-page faults and recoverable MMIO/EFB dispatch;
- executable-write detection;
- concurrent scheduler access under expected guest ordering;
- initialization, shutdown, and second launch;
- stress with randomized legal maps and accesses;
- ASan/UBSan host builds where compatible with the mapping strategy.

### 12.4 Memory gate

Do not proceed to full game bring-up until the selected macOS memory path passes the suite with zero unexplained mismatches and can run a translated microprogram that reads, writes, branches, calls a host API, and exits cleanly.

The checked path may be slower, but it must remain available as a diagnostic oracle until the optimized flat path has equivalent evidence.

---

## 13. Phase 3 — portable guest scheduling and fibers

Current guest scheduling depends on Windows fibers. Darwin and iOS need a supported ARM64 strategy that preserves guest ordering and CPU context.

### 13.1 Strategy selection

Evaluate:

1. **Explicit portable guest scheduler/state machine.** Preferred when the translated call boundary can yield without preserving arbitrary host stack frames.
2. **Portable stackful context library.** Acceptable if its license, arm64 macOS/iOS support, stack protection, sanitizer behavior, and lifecycle are proven.
3. **Small audited Darwin ARM64 context-switch implementation.** Acceptable if isolated, tested, and ABI-correct.
4. **Thread-per-guest correctness prototype.** Diagnostic only unless profiling proves it preserves determinism and meets performance/lifecycle requirements.

Do not rely on deprecated APIs that are absent or unsupported on the deployment target. Do not invent a context switch without verifying all callee-saved GPRs, SIMD/FP registers, stack alignment, TLS expectations, exception unwinding boundary, and floating-point environment.

### 13.2 Scheduler requirements

- deterministic guest priority and run-queue behavior;
- correct sleep/wake, message queues, alarms, VI retrace, and rescheduling;
- complete save/restore of guest `CpuContext`;
- no host lock held across a guest switch;
- safe guest thread exit and deferred stack/context destruction;
- clean shutdown without switching into freed state;
- stable background/foreground suspension on iOS;
- per-thread logging and watchdog diagnostics;
- no busy-spin when all guest threads are waiting;
- consistent FP environment across switches.

### 13.3 Scheduler tests

Create deterministic tests for:

- creation, start, yield, resume, sleep, alarm wake, join, cancel, and exit;
- priority ordering and preemption points;
- nested host callbacks;
- repeated create/delete cycles;
- simultaneous wakeups;
- VI retrace cadence;
- deadlock watchdog;
- shutdown during waiting, running, and terminated states;
- FP and SIMD register preservation;
- background/foreground on Simulator and device later.

### 13.4 Scheduler gate

A translated scheduler fixture must run identically for at least one million deterministic scheduling operations under arm64 macOS, without deadlock, leaked stacks/contexts, priority inversion, or state-hash divergence.

---

## 14. Phase 4 — PowerPC-to-AArch64 semantic fidelity

This is the central architecture gate. A native build that renders but changes physics is a failed port.

### 14.1 Preserve current correctness work

The pinned upstream already treats translated PowerPC rounding points specially and applies conservative options such as no fast-math and disabled FP contraction to semantic code. Preserve and test this behavior. Do not globally re-enable fast math on translated shards or semantic helper files.

### 14.2 Required integer/CPU coverage

- 32- and 64-bit add/subtract, carry, borrow, overflow, and XER state;
- rotates, masks, shifts, sign extension, count-leading-zero;
- condition-register fields and branch predicates;
- multiply/divide edge cases;
- byte-reversed and indexed memory operations;
- update-form loads/stores;
- reservation/atomic behavior used by the title;
- function ABI, stack frames, LR/CTR, varargs, and host-call bridges;
- instruction sequences generated for DOL and REL code;
- profile-sensitive base versus Retro Rewind callers.

### 14.3 Required floating-point coverage

Test bit-for-bit where PowerPC semantics define an exact result, including:

- f32 and f64 arithmetic;
- explicit single-precision rounding points;
- fused versus non-fused multiply/add behavior;
- all guest rounding modes;
- float-to-int and int-to-float conversions at boundaries;
- ordered/unordered comparisons and condition-register updates;
- positive and negative zero;
- infinities;
- quiet and signaling NaNs, payload propagation where load-bearing;
- denormals/subnormals and host flush-to-zero state;
- overflow, underflow, inexact, invalid, and divide-by-zero flags used by the runtime;
- reciprocal and reciprocal-square-root estimate instructions;
- paired-single arithmetic, merge, compare, quantized load/store, and GQR behavior;
- state preservation across guest thread switches and host callbacks.

### 14.4 Differential harness

Build a standalone no-game-data conformance executable that can run the same vectors under:

- arm64 macOS;
- x86_64 macOS under Rosetta;
- upstream Windows/x86-64 when available;
- Dolphin's interpreter or another exact PowerPC oracle for disputed cases.

Every mismatch record contains:

- operation and operands as raw bits;
- guest FPSCR/rounding state;
- expected raw result and flags;
- actual raw result and flags;
- host architecture/compiler/flags;
- minimized reproducer;
- resolution or accepted documented hardware ambiguity.

Randomized/property testing supplements, but never replaces, curated boundary vectors.

### 14.5 End-to-end determinism

After the micro-suite passes:

- race against built-in staff ghosts on every retail track;
- record whether the ghost remains synchronized and whether lap/finish outcomes match the reference;
- run deterministic input fixtures and compare selected guest state hashes at fixed frame numbers between the reference and KartPad;
- repeat across clean launches and Release builds;
- test base and Retro Rewind profiles separately.

### 14.6 Semantic gate

No “close enough” tolerance is allowed for physics-affecting state. The gate passes only with zero unexplained conformance mismatches and no reproducible ghost/state divergence attributable to ARM64 semantics.

---

## 15. Phase 5 — Dawn/Metal and Aurora bring-up

### 15.1 Build configuration

On Apple targets:

- enable Dawn's native Metal backend;
- disable D3D12 and Windows UI paths;
- disable unnecessary Vulkan/OpenGL backends in release artifacts unless retained as diagnostic build options;
- build Aurora and its dependencies for arm64 macOS first;
- use a CAMetalLayer-compatible window/surface with Retina pixel sizing;
- ensure shader tools execute on the host during cross-builds and generated artifacts are appropriate for the target;
- keep transferable pipeline recipes separate from device-specific runtime caches.

### 15.2 Rendering correctness ladder

1. Dawn device and queue initialize.
2. Aurora creates a Metal-backed surface.
3. A host-only clear frame presents.
4. A translated GX microfixture presents known geometry.
5. WiiCompiled reaches its first game frame.
6. Intro/title screen renders correctly.
7. Menus and text render.
8. A complete race renders.
9. All 32 retail tracks render.
10. Split-screen, Battle, mirrors, weather/effects, shadows, particles, EFB-dependent effects, and post-processing pass.

### 15.3 Areas requiring explicit comparison

- EFB/XFB copies and readbacks;
- depth range and precision;
- texture formats, palettes, mipmapping, and filtering;
- TEV combiner behavior;
- bounding box/occlusion behavior if used;
- projection and viewport conventions;
- scissor and copy rectangles;
- alpha test/blending;
- render-target transitions;
- shader/pipeline cache invalidation;
- first-run shader compilation stutter;
- Retina drawable resizing and live aspect changes;
- background/foreground surface recreation on mobile.

Capture side-by-side reference images from identical deterministic states. Visual similarity alone does not override a gameplay-state mismatch.

### 15.4 Enhancements policy

Internal resolution, dynamic aspect ratio, unlocked presentation rate, and frame interpolation are secondary features:

- original aspect and native simulation rate are the stable default;
- enhancements are independently switchable and default-off until tested;
- interpolation must not modify simulation, input sampling, networking, ghost timing, or audio cadence;
- artifact-prone interpolation remains labeled experimental;
- every diagnostics report names the active enhancement state.

---

## 16. Phase 6 — audio

Port the audio stack to Apple without changing guest timing.

Requirements:

- preserve the exact bundled/free DSP coefficient-ROM provenance and checksum rules from upstream;
- route output through CoreAudio/cubeb where the pinned dependency supports Apple, or through a narrow AVAudioEngine/CoreAudio backend;
- use a bounded ring buffer with measured producer/consumer latency;
- preserve guest sample rate, channel order, mixing, and timing;
- handle device changes, Bluetooth latency changes, interruptions, mute, volume, and app suspension;
- do not couple audio queue depth to render interpolation;
- ensure network stalls do not starve audio indefinitely;
- keep music ducking optional and implement it only through public Apple APIs with no private surveillance of unrelated applications.

Acceptance includes title/menu/race music, voices, engine sounds, item effects, split-screen, pause/resume, foreground/background, output-device changes, and long sessions. Record underrun count, queue depth, measured latency, and drift.

---

## 17. Phase 7 — input and controller architecture

### 17.1 macOS

Support:

- keyboard bring-up mapping;
- SDL-compatible Xbox, PlayStation, Nintendo, and generic controllers;
- positional face-button naming rather than hard-coded Xbox labels;
- GameCube-style in-game mapping;
- all four local ports;
- a supported USB GameCube adapter path where the OS and driver permit it;
- controller assignment, remapping, dead zones, trigger thresholds, and reset;
- hot plug, disconnect, reconnect, sleep/wake, and no stuck inputs;
- Rumble/haptics where supported and non-blocking;
- per-device persistent identity without exposing sensitive hardware IDs in shared diagnostics.

The base stable mapping may present controllers to the game as GameCube controllers, matching current WiiCompiled. A Wii Remote emulation layer is not required for initial gameplay, but optional motion-derived commands must map cleanly to the title's supported inputs.

### 17.2 Mobile touch layout

The landscape touch interface must expose every required action:

- steering control with a fixed or floating analog option;
- accelerate;
- brake/reverse;
- drift/hop;
- item use;
- rear view;
- pause;
- D-pad/trick/wheelie directions;
- any menu-confirm/cancel actions not covered above.

Requirements:

- true multitouch: steer, accelerate, drift, and use an item simultaneously;
- editable position, size, opacity, visibility, and reset;
- independent iPhone and iPad layouts;
- safe-area and aspect adaptation;
- no touch target under the system home indicator or camera cutout;
- clear held state when menus, alerts, pickers, share sheets, backgrounding, or controller handoff occurs;
- menu button remains accessible when gameplay controls hide;
- controls auto-hide on hardware-controller connection and restore according to the user's setting;
- VoiceOver labels for native settings and menu actions; gameplay overlay limitations documented honestly.

### 17.3 Optional gyro/gesture steering

Provide optional Core Motion input:

- tilt steering with calibration, sensitivity, dead zone, inversion, recenter, and disable;
- gesture or dedicated-button options for tricks/wheelies;
- no forced gyro requirement;
- deterministic combination rules between touch, gyro, and controller sources;
- motion data remains on device and is not logged raw.

Test touch-only, gyro-only steering plus touch buttons, and controller-only play.

---

## 18. Phase 8 — storage, game data, saves, and app containers

### 18.1 macOS first-run workflow

A native shell guides the user to the supplied supported image or an existing locally translated workspace. It must:

- accept documented formats;
- identify disc ID/revision and reject unsupported input clearly;
- show hashes without implying they are download hints;
- perform extraction/translation locally;
- keep game data outside the `.app` bundle;
- support resume/recovery after interrupted generation;
- show progress based on real stages, not a fake timer;
- preserve a content-addressed generated cache keyed by disc hash, translator pin, profile, compiler, architecture, and flags;
- expose “Manage Game Data” to replace/remove private data safely.

### 18.2 iOS/iPadOS build reality

An iPhone/iPad cannot compile the translated C++ graph at runtime and may not download executable code. Therefore:

- the development/self-build pipeline runs translation and compilation on the Mac before signing the device app;
- the device app may import private non-executable game data it needs at first launch, subject to validation and storage limits;
- translated ARM64 code is part of the locally built signed app;
- no on-device JIT, dynamic compiler, or executable-code download exists;
- the public workflow is source/self-build unless a separately reviewed distribution model is approved.

### 18.3 Save/data requirements

- use Application Support for durable private data and Caches for regenerable caches;
- use atomic write + backup/rollback for critical saves;
- protect iOS files with appropriate data protection;
- avoid backing up huge regenerable extracted data to iCloud;
- expose exact export/import only for user-approved save/ghost files where safe;
- never uninstall as an update mechanism;
- verify update-in-place preserves the container;
- make all destructive actions explicit and reversible when practical;
- never include save contents in diagnostics.

Test new license, multiple licenses, unlocks, records, settings, ghosts, corrupted/truncated save recovery, full disk, read-only/error paths, forced termination during write, and relaunch.

---

## 19. Phase 9 — macOS game bring-up ladder

Advance one rung at a time, preserving evidence for every rung:

1. Host-only tests compile and run arm64.
2. Translated microprogram runs and exits.
3. Full translated base product links.
4. Process starts without immediate host assertion.
5. Guest memory initializes.
6. Scheduler reaches stable VI retrace.
7. Dawn/Metal presents a game frame.
8. Intro/title renders.
9. Audio is audible and continuous.
10. Keyboard/controller navigates license/menu flow.
11. Time Trial enters Luigi Circuit.
12. Kart responds to steering, acceleration, brake, drift, item/trick controls as applicable.
13. One lap completes.
14. A full three-lap race completes.
15. Results/menu transition completes.
16. Save writes and survives a clean relaunch.
17. A staff ghost remains synchronized.
18. A Grand Prix cup completes.
19. Every retail track boots and completes.
20. Every mandatory offline matrix row passes.

Do not jump directly to online because the title reaches a menu. Network debugging on an unstable scheduler, FP core, or save system wastes evidence and can produce misleading service failures.

---

## 20. Phase 10 — macOS compatibility and “essentially perfect” quality bar

“Essentially perfect” is operationalized as the following reproducible coverage, not a subjective impression.

### 20.1 Modes and content

Verify:

- license creation/selection and Mii/profile presentation;
- 50cc, 100cc, 150cc, and Mirror where unlocked/supported;
- karts and bikes;
- manual and automatic drift;
- all available characters and representative weight classes;
- all 32 retail tracks;
- Mushroom, Flower, Star, Special, Shell, Banana, Leaf, and Lightning cups;
- Time Trial, staff ghosts, saved ghosts, and records;
- VS race with configurable rules;
- Balloon Battle and Coin Runners on every retail arena;
- one-player and 2/3/4-player local configurations supported by the game;
- items, AI, off-road, boost, tricks, wheelies, collisions, respawn, lap/checkpoint logic, finish order, and results;
- unlock progression and credits;
- settings, controller config, and error paths;
- obsolete Nintendo network/channel features fail gracefully rather than hanging or corrupting state.

### 20.2 Defect priorities

- **P0:** data loss, security issue, copyright boundary failure, repeated crash at launch, or system-wide instability.
- **P1:** progression blocker, common track/mode crash, deterministic physics divergence, broken saves, nonfunctional required online flow, or sustained native-frame failure on target hardware.
- **P2:** serious visual/audio/input defect with a narrow workaround; uncommon content-specific crash; major accessibility/lifecycle issue.
- **P3:** cosmetic defect or optional enhancement issue.

No P0/P1 defect may remain at release-candidate status.

### 20.3 Regression fixture set

Create reusable private fixtures for:

- new license;
- all-cups-unlocked test license where lawfully produced from the user's own save;
- representative Time Trial/staff ghost states;
- pre-race, mid-race, results, Battle, and online room states;
- one save near capacity;
- controller slot combinations;
- network latency/loss profiles.

Keep fixtures and saves private/ignored. Document how they were created without publishing their contents.

---

## 21. Phase 11 — performance, frame pacing, and stability

### 21.1 Correct cadence

Do not assume every mode has the same original cadence. Measure reference hardware/Dolphin behavior for one-player, two-player, three-player, and four-player modes. Then require:

- 16.67 ms simulation/presentation cadence for original 60 Hz modes;
- the verified original cadence for modes that intentionally run at 30 Hz or another rate;
- no interpolation dependency for meeting the simulation deadline;
- no speedup/slowdown from host refresh rate;
- input sampling aligned with guest simulation rather than interpolated frames.

### 21.2 Measurements

Record, by scene and device:

- average, p95, p99, and worst frame interval;
- CPU time by translated code, runtime/HLE, renderer, shader compile, audio, and network;
- GPU time and present latency;
- first-run versus warm-cache behavior;
- audio underruns and queue latency;
- memory resident size, peak, and growth over time;
- input-to-photon measurement method and result where equipment permits;
- battery drain and thermal state on mobile;
- network RTT/jitter/loss separately from render time.

Use Instruments Time Profiler, Metal System Trace, signposts, and runtime counters. A displayed “60 FPS” number does not prove frame pacing.

### 21.3 Optimization order

1. Correct accidental debug/checked-path use in Release.
2. Remove architecture-inappropriate x86 assumptions and unnecessary copies.
3. Profile translated hot functions by symbol.
4. Optimize memory access and host-call bridges without changing semantics.
5. Optimize scheduler transitions and timer churn.
6. Eliminate avoidable shader/pipeline creation during gameplay.
7. Optimize Aurora/Dawn resource transitions and EFB paths.
8. Optimize audio queueing.
9. Specialize known translated hot paths only with differential tests.
10. Consider optional interpolation after native cadence is already stable.

Change one variable, capture before/after, and revert changes without evidence.

### 21.4 Stability

Before macOS is considered complete:

- 8-hour automated/hands-on mixed-mode soak;
- repeated 100-launch boot/quit cycle;
- repeated 100-race load/finish/menu cycle;
- controller connect/disconnect stress;
- save/relaunch stress;
- window resize/fullscreen/Retina/display-change stress;
- network enable/disable stress against a local server;
- no unbounded thread, handle, socket, descriptor, memory, or pipeline growth.

---

## 22. Phase 12 — online gameplay

Online is mandatory and has its own acceptance program.

### 22.1 Supported product target

Primary online target:

- the **Retro Rewind** static product/profile already represented in WiiCompiled;
- the exact Retro Rewind WiiLink-compatible server stack and version documented by the pinned Retro Rewind sources.

Secondary diagnostic target:

- a locally hosted compatible WFC server using the documented development domain/key flow;
- base-game networking where the pinned sources and service legally support it.

Do not claim Wiimmfi compatibility, production Retro Rewind compatibility, or Wii interoperability until that exact path has been run and observed. A compile-time `RetroRewind` target is not evidence that online works.

### 22.2 Local-first online development

Use a local authorized server/harness before a public service. It should support or simulate:

- DNS resolution and service discovery;
- HTTP/HTTPS endpoints used by the title/profile;
- certificate and signature flows;
- profile/account bootstrap using test-only identities;
- login/auth result states;
- matchmaking/search;
- room creation/join/leave;
- friend-room flow where feasible;
- course voting;
- peer/session negotiation and NAT behavior;
- real-time race packets;
- finish/results/rating submission;
- reconnect, timeout, duplicate, out-of-order, malformed, and lost packets;
- version mismatch and maintenance responses;
- server outage and partial endpoint failure.

Never ship local test keys or server secrets in the app.

### 22.3 Network portability work

Port and test:

- WinSock assumptions to BSD sockets/Network.framework-compatible behavior;
- nonblocking I/O and event notification;
- DNS and interface enumeration;
- IPv4/IPv6 behavior as required by the service;
- TLS trust using Apple's trust store or the exact licensed guest behavior;
- clock/certificate validity;
- HTTP redirects, chunking, compression, and cancellation;
- background/foreground and network path changes;
- Wi-Fi to cellular transition on iPhone/iPad;
- socket cleanup on race exit and app termination;
- privacy-bounded network logging.

No private Apple networking API is permitted.

### 22.4 Public-service testing discipline

When service rules and any required human account setup are satisfied:

- behave like a normal human client;
- do not automate repeated matchmaking joins/leaves on production;
- do not exceed normal race/session volume;
- use the documented test server for version-check-free development where permitted;
- use the local server for packet loss, jitter, scale, malformed traffic, and failure injection;
- immediately stop any test that degrades service or affects other players;
- never test cheats, rating manipulation, ban evasion, or anti-cheat bypass.

### 22.5 Online acceptance

Required evidence includes:

- local server: 12-client session/race simulation or the highest supported deterministic fixture;
- Apple-to-Apple: macOS + iPad/iPhone matchmaking/room/race/results;
- repeated normal races with no reproducible desync attributable to KartPad;
- friend/private room flow where the profile supports it;
- 50/100/200 ms latency profiles, jitter, 1/3/5% packet loss, and temporary disconnect against the local harness;
- graceful service maintenance/outage;
- clean cancellation and no leaked sockets/threads;
- production/test-server normal races only after policy prerequisites are met;
- cross-client interoperability with supported Wii/Dolphin/Windows clients only where authorized.

Maintain `docs/ONLINE.md` with the protocol/state-machine map, target versions, server pins, account prerequisites, test identities, evidence, and known service dependencies. Never place credentials in it.

---

## 23. Phase 13 — macOS application shell and branding

### 23.1 macOS application

Create a native Apple Silicon `.app` with:

- first-run game-image selection and local generation flow;
- clear unsupported-image errors;
- launch/resume into base or Retro Rewind profile;
- native menu/settings window or in-game overlay integrated cleanly with the runtime;
- internal resolution and original-aspect defaults;
- controller assignment/remapping;
- audio volume/mute;
- diagnostics export;
- game data, generated cache, saves, and profile management;
- renderer, product profile, and enhancement state shown in diagnostics;
- clean quit and save flush;
- no console window or Windows-path assumptions;
- sandbox-compatible path separation even if the initial macOS app is not sandboxed;
- hardened-runtime/notarization research recorded separately from local ad-hoc builds.

### 23.2 Original icon requirements

Create original branding with no Nintendo logo, Mario Kart logo, character, kart, course, item, texture, screenshot, trademarked trade dress, or traced game artwork.

Recommended visual direction: an abstract wheel/ring, forward motion marks, and an Apple-native geometric “K” or track curve. The icon must be recognizable without text.

Required source/output:

- editable vector master under `branding/`;
- 1024×1024 high-resolution source PNG;
- macOS AppIcon assets at 16, 32, 128, 256, and 512 points with required 1x/2x representations;
- iOS/iPadOS 1024 marketing icon and the asset-catalog variants required by the chosen Xcode target;
- dark and tinted appearance masters where supported by the target SDK;
- no pre-applied system corner mask where Apple expects the OS to mask;
- no unintended alpha or transparent fringe;
- visual QA at 16 px, Spotlight/Dock sizes, Home Screen, Settings, and App Library sizes;
- asset-catalog validation in the exact release build.

Use the same core identity across Mac, iPhone, and iPad, with platform-appropriate optical adjustments rather than unrelated icons.

---

## 24. Phase 14 — iPadOS/iOS Simulator core

### 24.1 Prerequisite gates

Do not begin this phase until macOS has:

- passing ARM64 semantic, memory, and scheduler suites;
- native Metal first frame;
- title/menu and complete race;
- durable save/relaunch;
- acceptable native frame pacing in the chosen baseline scene.

### 24.2 Simulator build

Build the same translated product for arm64 Simulator with:

- no JIT or interpreter;
- an iOS-compatible guest-memory strategy;
- an iOS-compatible guest scheduler/context switch;
- Dawn Metal targeting the Simulator SDK;
- UIKit-owned `CAMetalLayer` lifecycle;
- iOS-safe audio and file paths;
- no AppKit, Win32, raw USB adapter, or unavailable desktop API linked into the target;
- no runtime download or loading of unsigned executable modules.

Primary target is an iPad Simulator, followed by an iPhone Simulator. Fully terminate and shut down one before booting the other.

### 24.3 Simulator acceptance

- first-run shell launches;
- private game-data validation/import path works as designed;
- title/menu/race boot;
- audible audio;
- touch overlay drives a complete race;
- settings and diagnostics work;
- save/relaunch works;
- rotation policy, safe areas, background/foreground, memory warning, and surface recreation work;
- controller connect/disconnect works;
- online local-server flow reaches at least a room and race where the Simulator network stack permits it.

Simulator performance is diagnostic, not physical-device acceptance.

---

## 25. Phase 15 — physical iPad/iPhone

### 25.1 Device build

- arm64 device target;
- local Apple Development signing supplied by the environment;
- no signing identity or provisioning profile committed;
- install in place to preserve private data;
- app and package audited before install;
- exact commit/build manifest recorded.

### 25.2 Device-specific requirements

- Metal surface and Retina sizing;
- touch latency and ergonomics;
- optional gyro calibration and stability;
- controller mapping, haptics, and handoff;
- AVAudioSession interruptions, route changes, Bluetooth output;
- memory pressure and jetsam diagnostics;
- thermal throttling and battery drain;
- background/foreground and lock/unlock;
- Wi-Fi/cellular/path changes;
- save flush before suspension where possible;
- update-in-place preserving game data and saves;
- long online and offline sessions.

### 25.3 Device performance

Profile at minimum:

- a recent iPad Pro/Air-class device available to the project;
- a recent iPhone available to the project;
- one lower-memory/older supported device if available before claiming a broad minimum.

Set the minimum OS/device only after measured API, memory, and performance evidence. Initial development may target the current SDK; do not advertise a lower deployment target merely because it compiles.

---

## 26. Full test matrix

Every mandatory row needs: date, target/device, OS, architecture, product profile, source commit, build manifest, input disc hash, commands, logs, screenshot/capture where useful, result, and remaining defect.

| # | Test row | Target | Mandatory pass condition |
|---:|---|---|---|
| 1 | Source pins and notices | repo | Exact commits, licenses, patches, and push-disabled checkouts recorded |
| 2 | Disc identification | build host | Supported image identity/hashes recorded; original unchanged |
| 3 | Translator unit tests | host | All no-game-data tests green |
| 4 | Deterministic source graph | host | Repeated translation produces identical manifest/shard hashes |
| 5 | Base and RR graph separation | host | Base profile excludes RR code; RR profile includes expected translated mod graph |
| 6 | Host portability tests | macOS arm64 | Platform interfaces compile/run with no Win32 link dependency |
| 7 | Guest memory scalar/endian | macOS arm64 | Full memory conformance subset green |
| 8 | Guest aliases/guards/faults | macOS arm64 | Alias coherence and supported fault recovery green |
| 9 | Scheduler/fiber stress | macOS arm64 | Deterministic million-operation fixture green |
| 10 | PPC integer semantics | arm64 + x86 oracle | Zero unexplained mismatches |
| 11 | PPC scalar FP semantics | arm64 + oracle | Zero unexplained raw-result/flag mismatches |
| 12 | Paired-single/GQR semantics | arm64 + oracle | Zero unexplained mismatches |
| 13 | Host API ABI bridge | macOS arm64 | Translated fixture calls host APIs and returns correctly |
| 14 | Dawn Metal clear frame | macOS | Native Metal surface presents correctly |
| 15 | Translated GX fixture | macOS | Known geometry matches reference |
| 16 | Boot to title | macOS | Title renders, audio present, input accepted |
| 17 | License/menu flow | macOS | Create/select license and reach mode selection |
| 18 | First complete race | macOS | Three laps, finish, results, return to menu |
| 19 | Save/relaunch | macOS | License/settings/record persist after clean quit |
| 20 | Forced-exit save safety | macOS | No unrelated save corruption; recovery is clear |
| 21 | Staff ghost sync | macOS | Defined ghost fixture remains synchronized |
| 22 | All 32 retail tracks | macOS | Every track completes without P0/P1 defect |
| 23 | All retail cups/classes | macOS | Representative full Grand Prix coverage passes |
| 24 | Vehicles/characters/drift | macOS | Representative karts, bikes, weights, manual/auto pass |
| 25 | Items/AI/collisions | macOS | Heavy item/12-racer fixtures complete correctly |
| 26 | Time Trial/ghost records | macOS | Record, save, load, replay, delete/replace behavior passes |
| 27 | Balloon Battle | macOS | Every arena boots; representative full match completes |
| 28 | Coin Runners | macOS | Every arena boots; representative full match completes |
| 29 | Two-player split screen | macOS | Full race, correct inputs/audio/cadence |
| 30 | Three/four-player split screen | macOS | Full race; verified original cadence preserved |
| 31 | Four controller slots | macOS | P1–P4 assignment, reconnect, no stuck inputs |
| 32 | GameCube adapter | macOS | Supported adapter path passes or limitation is explicit |
| 33 | Audio continuity | macOS | Menu/race/pause/device-change/long session, no sustained underrun |
| 34 | Renderer comparison | macOS | Representative scenes pass image/behavior review |
| 35 | Native frame pacing | macOS | p99/worst meet mode-specific budget in required scenes |
| 36 | First-run shader/cache | macOS | No unbounded compile stall; cache works and invalidates correctly |
| 37 | Window/display lifecycle | macOS | resize/fullscreen/Retina/display change pass |
| 38 | 8-hour soak | macOS | No crash, leak, progressive degradation, or save corruption |
| 39 | macOS app shell | macOS | first run, settings, manage data, diagnostics, clean quit |
| 40 | macOS icon audit | macOS | all sizes/catalog validation/visual QA pass |
| 41 | Local online bootstrap | macOS + local server | DNS/TLS/profile/login state reaches expected result |
| 42 | Local matchmaking/room | macOS + local server | create/search/join/leave/course vote pass |
| 43 | Local online race/results | macOS + local server | complete race, results, cleanup pass |
| 44 | Network impairments | macOS + local server | latency/jitter/loss/temp disconnect handled as specified |
| 45 | Service outage/version mismatch | macOS | clear bounded error, no hang or corrupted save |
| 46 | Authorized external normal race | macOS | supported test/production service race completes under normal use |
| 47 | iPad Simulator boot/race | iPad Sim | title through complete touch-driven race |
| 48 | iPhone Simulator boot/race | iPhone Sim | title through complete touch-driven race |
| 49 | Touch completeness | iPad + iPhone Sim | every action, simultaneous input, edit/reset, no stuck state |
| 50 | Gyro option | iPad + iPhone Sim | calibrate/recenter/disable and full race pass |
| 51 | Controller handoff | iPad + iPhone Sim | overlay hides/restores, P1 retained, held state cleared |
| 52 | Simulator lifecycle | iPad + iPhone Sim | background/foreground, picker/share, memory warning, surface rebuild |
| 53 | iOS/iPadOS icons | build | mobile asset catalog and appearance variants validate |
| 54 | Physical iPad offline | device | complete race, touch/controller, audio, save, lifecycle pass |
| 55 | Physical iPhone offline | device | complete race, touch/controller, audio, save, lifecycle pass |
| 56 | Physical thermal/memory soak | devices | 4-hour session without thermal collapse, jetsam, leak, or audio drift |
| 57 | Apple-to-Apple online | macOS + device | room, race, results complete together |
| 58 | Two mobile clients online | iPad + iPhone | room, race, results complete together where service permits |
| 59 | Cross-client interoperability | Apple + supported external client | normal race completes with no KartPad-specific desync |
| 60 | Network path change | device | Wi-Fi interruption/recovery and permitted path changes fail/recover cleanly |
| 61 | Clean-clone macOS self-build | fresh dir | scripts reproduce app from pin + user's disc |
| 62 | Clean mobile self-build | fresh dir | scripts reproduce locally signable device artifact |
| 63 | Update-in-place | macOS + devices | app update preserves private game data, saves, settings |
| 64 | Diagnostics privacy | all | useful report; no game data, save contents, secrets, or raw credentials |
| 65 | Repository/package safety | repo + exact artifacts | automated audits pass; notices and manifests present |
| 66 | Accessibility/settings | all shells | native actions labeled, focusable, and usable; limitations documented |
| 67 | Release regression | all intended targets | complete mandatory matrix subset rerun on exact candidate |

Rows requiring a public service cannot be marked Pass without the exact authorized service result. They may be `Blocked—external prerequisite`, while all independent rows continue.

---

## 27. Evidence, journal, and status files

Maintain:

- `docs/JOURNAL.md` — append-only, dated. Every work session records goal, state inspected, commands, change, immediate test, result, evidence paths, failure signature, and next step.
- `docs/STATUS.md` — current lowest unmet goal, buildable targets, last known-good commits/artifacts, matrix status, blockers, and active experiments.
- `docs/RESEARCH.md` — Notion baseline versus current source/web research, with exact revisions and links.
- `docs/PORTABILITY.md` — Windows assumptions, Apple replacement, owner, status, tests, and remaining risk.
- `docs/SEMANTICS.md` — PPC/AArch64 test inventory and every resolved/unresolved mismatch.
- `docs/PERF.md` — every measurement with target, scene, build manifest, before/after, profile path, and conclusion.
- `docs/ONLINE.md` — protocol/state map, server/client pins, authorized targets, test accounts prerequisites, network fixtures, evidence, and service dependencies; never credentials.
- `docs/KNOWN-ISSUES.md` — reproducible defects, severity, reproduction, evidence, workaround, and owner.
- `docs/RELEASE-CHECKLIST.md` — source, macOS, Simulator, device, online, package, privacy, license, and artifact gates.
- `docs/HANDOFF.md` — exact current state and next executable step, kept usable even during uninterrupted autonomous work.
- `docs/artifacts/<date>/` — screenshots, videos, traces, sanitized logs, profiles, test reports, state hashes, and manifests.

Evidence naming should include date, target, profile, and purpose. Keep private captures under `private/` until reviewed and sanitized.

The agent must be able to resume from `STATUS.md` plus the final journal entry without rediscovering the project.

---

## 28. Diagnostics and observability

Wire observability early, before mobile UI:

- session/build manifest at startup;
- product profile and disc hash prefix;
- guest-memory strategy/base/map summary;
- scheduler backend, guest thread lifecycle, wait reason, watchdog;
- translated function/guest PC/LR for fatal faults;
- renderer adapter/backend, drawable size, scale, pipeline-cache identity;
- frame timing and missed native deadlines;
- audio queue depth/underruns/device route;
- controller slots and connect/disconnect, excluding sensitive raw identifiers;
- save open/read/write/flush/rollback result without contents;
- network target, state transitions, error categories, latency/loss counters, socket cleanup, excluding credentials and packet payloads by default;
- lifecycle, memory warnings, thermal state, background/foreground;
- clean/unclean session marker.

Shared diagnostics must:

- cap current/previous log tails;
- replace known personal paths;
- include a warning that arbitrary runtime text may still require review;
- exclude the disc image, extracted files, translated source, save contents, screenshots, raw packet captures, tokens, passwords, private keys, certificates, friend-code secrets, device IDs, and signing material;
- require user review before sharing.

Every fatal error should explain the subsystem and include the local log path rather than only aborting.

---

## 29. Build and automation deliverables

Create scripts equivalent to:

- `scripts/check-prerequisites.sh`
- `scripts/clone-sources.sh`
- `scripts/verify-sources.sh`
- `scripts/prepare-disc.sh`
- `scripts/build-translator.sh`
- `scripts/translate-base.sh`
- `scripts/translate-retro-rewind.sh`
- `scripts/build-macos-app.sh`
- `scripts/run-macos-test.sh`
- `scripts/build-ios-simulator.sh`
- `scripts/run-ios-simulator-test.sh`
- `scripts/build-ios-device.sh`
- `scripts/package-local-unsigned-ipa.sh` if technically/legal-boundary appropriate
- `scripts/run-conformance.sh`
- `scripts/run-ghost-determinism.sh`
- `scripts/run-local-online-server.sh`
- `scripts/run-online-fixture.sh`
- `scripts/check-repo-safety.sh`
- `scripts/audit-macos-package.sh`
- `scripts/audit-ios-package.sh`
- `scripts/create-build-manifest.sh`

Requirements:

- `set -euo pipefail` or equivalent strict failure behavior;
- no hard-coded personal paths;
- no secrets in arguments/logs where process listings expose them;
- idempotent fetch/patch behavior;
- exact pin verification;
- generated/private paths ignored;
- clear distinction between clean generation and incremental build;
- bounded parallel compilation based on available memory;
- deterministic outputs where feasible;
- safe termination/cleanup of prior instances and Simulators;
- commands printed or recorded so failures are reproducible.

---

## 30. Legal, licensing, provenance, and approved wording

### 30.1 Licensing

- WiiCompiled is GPLv3 at the audited revision. Preserve its license and third-party notices.
- Aurora, Dawn, SDL, Dolphin-derived components, Crypto++, Retro Rewind/Pulsar, WiiLink/WFC code, and every transitive dependency retain their own license and notice obligations.
- Do not describe the combined tree as having one license without verifying every component.
- Verify the exact license of symbol maps, assets, icons, fonts, server code, and any context library before importing them.
- KartPad's original shell, scripts, docs, and artwork do not relicense third-party or Nintendo-owned material.

### 30.2 Nintendo data boundary

Do not commit, upload, attach to CI, or distribute:

- the disc image;
- extracted Nintendo code/data/assets/audio/models/textures;
- translated game source or generated playable object/library output;
- saves or ghosts containing private user data;
- public download hints for copyrighted input.

The user supplies a legally obtained supported image locally.

### 30.3 Network/service boundary

- Community server operators set their own terms, version rules, anti-cheat policy, and account prerequisites.
- Open-source client/server code does not itself grant permission to use a production service.
- Test locally first and use public test/production services only as documented and authorized.
- Never bundle production server secrets or private signing keys.

### 30.4 Approved product wording

Use wording equivalent to:

> KartPad is an independent, unofficial native Apple port of Mario Kart Wii built through ahead-of-time static recompilation of a user-supplied supported disc image. The translated ARM64 code runs with an open-source Wii hardware/HLE compatibility runtime and Aurora/Dawn Metal rendering. KartPad contains no game image or original game assets and is not affiliated with or endorsed by Nintendo, WiiCompiled, Retro Rewind, WiiLink, Dolphin, or their contributors.

Do not claim official status, App Store availability, public online-service endorsement, or prebuilt-binary distribution until each exact claim is true.

---

## 31. Risk register

| Risk | Current standing | Required response |
|---|---|---|
| Runtime is Windows/x86-64 only | Confirmed in pinned CMake and link graph | Phase 1 host abstraction; retain Windows baseline |
| Fixed 4 GiB guest map uses Windows placeholders/VEH | Confirmed in source | Bounded Darwin memory spike, checked fallback, exhaustive memory tests |
| Guest scheduling uses Windows fibers | Confirmed in source | Portable scheduler/context backend with deterministic stress tests |
| PPC FP/paired-single differs on AArch64 | Critical architecture risk; partial upstream correctness work exists | Bit-level differential suite plus staff-ghost/state-hash acceptance |
| x86-only optimization flags/intrinsics | Confirmed | Target-scoped architecture flags and portable semantic helpers |
| Dawn/Aurora Apple path differs from current D3D/Vulkan build | Feasible but unproven for this runtime | Native Metal clear frame, GX fixture, full visual matrix |
| First-run shader stutter/cache mismatch | Likely | transferable recipe + device cache design; first-run measurements |
| Audio backend/guest DSP timing | Windows path exists; Apple unproven | CoreAudio port, queue metrics, long audio rows |
| GameCube adapter raw USB on macOS/iOS | Platform/permission dependent | Optional macOS backend; ordinary controllers remain mandatory; no device requirement on iOS |
| Mobile fixed-memory strategy | macOS result may not transfer to iOS sandbox | Separate iOS memory gate; checked/base-relative fallback |
| Mobile memory footprint/build size | Large translated graph and renderer | Measure, dead-strip, shard, strip symbols, device memory tests |
| Public prebuilt legal boundary | Unresolved; upstream avoids translated binaries | Source/self-build default; separate legal gate |
| Online service compatibility | Retro Rewind product graph exists; end-to-end Apple support unproven | Local server first, exact state-machine evidence, normal authorized external tests |
| Service accounts/terms | Human/external dependency | Record prerequisite, continue independent work, never bypass |
| Anti-cheat/community trust | High scrutiny | Determinism receipts, no cheats/bypass, transparent build identity |
| Retro Rewind version drift | Active external project | Pin client/server/profile, add compatibility matrix and update test |
| Network private keys/certs | Sensitive | secure local storage, no logs/repo, documented provisioning boundary |
| 60 Hz physics and frame pacing | Load-bearing | Correctness-first profiling; interpolation cannot mask misses |
| 3/4-player cadence differs | Must match reference | Measure and preserve mode-specific cadence |
| Save corruption during crashes/updates | High impact | atomic writes, backups, fault injection, in-place update tests |
| Thermal throttling on mobile | Unknown | physical-device profiles and 4-hour soaks before support claims |
| Upstream merge churn | Young project | pin first; isolated Apple layer; replay patches and regression subsets |
| Original icon accidentally implies official status | Avoidable | abstract original artwork and legal/visual review |

A risk is not a reason to abandon the goal. It is a requirement for a concrete experiment, fallback, test, and evidence trail.

---

## 32. Initial execution sequence

The autonomous agent's first sequence is:

1. Read `docs/PRD.md` and `docs/GOAL-LOOP.md` completely.
2. Create `docs/JOURNAL.md`, `docs/STATUS.md`, `docs/RESEARCH.md`, and `docs/PORTABILITY.md` if absent.
3. Inventory the repository and preserve any existing work.
4. Find, identify, hash, and make read-only the supplied disc image.
5. Clone/pin WiiCompiled at `1912292c804ff9b1b79938de89369ec4496f9fff` into `ref/upstream/` and disable push.
6. Pin the exact other reference sources and write `dependencies.lock.json`.
7. Run all no-game-data translator/runtime tests available on macOS.
8. Inspect and catalog every Windows-only build/source dependency.
9. Build the arm64/x86_64 semantic harness skeleton and run baseline vectors.
10. Implement the smallest host-neutral CMake/platform split that compiles utility tests on macOS without weakening Windows behavior.
11. Execute the Darwin guest-memory experiment and record the selected strategy.
12. Implement/test the portable scheduler backend.
13. Reach zero unexplained semantic-suite mismatches.
14. Configure Dawn native Metal and present the host clear frame.
15. Advance through the macOS bring-up ladder one evidenced rung at a time.
16. Do not begin iOS/iPadOS shell work until the mobile prerequisite gates in Section 24 are satisfied.

After each step, follow `docs/GOAL-LOOP.md`. Continue until the full mandatory matrix is green or a documented human-only external prerequisite is the sole remaining blocker.
