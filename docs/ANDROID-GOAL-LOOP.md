# KartPad Android autonomous goal loop

## Objective

Build KartPad for Android as the same product, not a reduced companion app:
the existing ahead-of-time ARM64 Original Mario Kart Wii and Retro Rewind
runtime, Aurora/Dawn rendering, SDL audio/controllers, KartPad setup and data
management, and the accepted touch experience hosted natively on Android.

Proceed autonomously through the lowest incomplete goal. Continue until the
Android release-candidate gate passes or progress genuinely requires a human,
private game input that is not already available, physical Android hardware,
new legal terms, credentials, payment, or public-release authorization.

This is the original A0–A6 engineering acceptance ladder. Android has since
shipped; choose current work from [MAINTENANCE-BOARD.md](MAINTENANCE-BOARD.md)
under [MAINTENANCE.md](MAINTENANCE.md). [ANDROID.md](ANDROID.md) summarizes
architecture and acceptance. Unfinished rows still require evidence, but old
bring-up checkpoints do not supersede later release authorization.

## Required reading before changes

Read completely, in this order:

1. repository `AGENTS.md` instructions;
2. [`ANDROID.md`](ANDROID.md);
3. this goal loop;
4. [`STATUS.md`](STATUS.md), [`HANDOFF.md`](HANDOFF.md), and the current
   board row with its linked dated evidence;
5. [`PRD.md`](PRD.md), especially architecture, privacy, correctness, mobile,
   and release gates;
6. `dependencies.lock.json` and the current Retro Rewind profile in
   `builder/profiles/mkwii-rmcp01-rev0.json`;
7. the current iPhone/iPad owner layer, mobile input bridge, tvOS host, and
   pinned SunPad files named by `ANDROID.md`.

Do not implement from an older branch, preview tag, copied local checkout, or
the SunPad Android plan. Start from current `origin/main` and record its exact
commit.

## Standing authorization and boundaries

You are authorized to:

- inventory the machine and network-download the Android/Java build tools
  required by this work;
- install a user-local or Android-Studio-managed pinned JDK, SDK command-line
  tools, SDK platforms, Build Tools, Platform Tools, NDK, CMake/Ninja support,
  Gradle dependencies, Android Emulator, and ARM64 system images;
- download repository-authorized dependencies from their official sources,
  verify them, cache them locally, and add reproducible lock metadata;
- create AVDs, build/install/debug local APKs, run tests, and use available
  attached Android hardware within the project scope;
- create a `codex/` feature branch, commit coherent passing checkpoints, push
  it, and open focused pull requests.

You are not authorized to:

- download, publish, copy into Git, or expose Mario Kart Wii data, Nintendo
  assets, saves, NAND data, generated translated shards, signing keys, device
  identifiers, credentials, or private captures;
- accept new legal terms, create accounts, bypass CAPTCHA, purchase tools, or
  publish an APK/AAB without explicit human authorization;
- replace KartPad with Dolphin, streaming, a PowerPC interpreter/JIT, or
  executable code downloaded at runtime;
- rewrite unrelated Apple code or break the stable Apple build to make Android
  easier;
- assume an emulator proves physical performance, touch feel, audio latency,
  OEM lifecycle behavior, or release readiness.

If private generated code or user-owned game data is already present on the
machine, use it only from ignored private paths and record hashes without
printing or publishing contents. If it is absent, complete every source-only
and non-private goal available before asking for it.

## Product parity baseline

Reuse the portable runtime instead of cloning it. Keep one shared C/C++ product
core and thin platform owners:

- reuse the dual-profile product selection, translated graph, HLE, guest
  memory contracts, Classic Controller adapter, input state/mixing rules, SDL
  audio/controller layer, networking semantics, settings meanings, archive
  validation rules, and diagnostic redaction rules where portable;
- extract shared C++ only when an Android consumer and regression test justify
  it; do not perform a speculative cross-platform rewrite;
- keep Kotlin/JNI/Android Views, content URIs, activity/service lifecycle,
  sensors, haptics, and system intents under `android/`;
- treat Objective-C/UIKit as the behavioral oracle, not Android-compilable
  source. Express shared layout/style/state data once when that reduces drift.

The Android UI must preserve the accepted KartPad behavior:

- an Original Mario Kart Wii / Retro Rewind chooser;
- a menu titled **KartPad**, with the same consolidated Display, Controls,
  Touch Control Settings, Game Data & Saves, Multiplayer, Motion Steering, and
  diagnostics hierarchy; never show the SunPad title or obsolete experimental
  performance/60 FPS entries;
- Original 4:3 plus the same clearly labeled experimental aspect choices;
- A/B/X/Y/Z/Start/L/R, sticks, and grouped D-pad with the same Classic input
  mapping; the D-pad performs tricks and wheelies;
- multitouch, controller handoff, held-input clearing, global opacity/size,
  per-control move/resize/Hide/Show, layout reset, and **Back** returning from
  the editor to Touch Control Settings;
- the one-second A acceleration lock enabled by default for touch, cyan locked
  state, light haptic confirmation, and tap-to-unlock;
- the accepted compact defaults for untouched phones, while preserving
  existing customized layouts and using the existing tablet defaults;
- first-run import, Retro Rewind 6.12.7 install/version handling, Mii
  management, save-preserving data removal, and bounded diagnostics.

Where Android system UI differs, preserve the product action and outcome while
using the real platform picker, permission, sharing, and accessibility APIs.

## Goal ladder

Goals are cumulative. A compile is evidence for a build row only; it does not
complete runtime or hands-on rows.

### A0 — Reproducible toolchain and source-only shell

Deliver the minimal `android/` Gradle/SDLActivity project, pinned wrapper and
plugin versions, `scripts/check-android-host.sh`, an explicit bootstrap script,
one ARM64 phone AVD, one 16 KiB AVD where supported, a source-only JNI fixture,
and locked Dawn Android metadata.

Pass when a clean checkout can run one documented command to verify tools and
one documented command to build, install, launch, and exercise the JNI fixture
without private data or undocumented absolute paths.

### A1 — Android native primitives and Vulkan surface

Add the Android CMake shared-library product, PIC/ELF link, Android guest-memory
and AArch64 fiber implementations, SDL surface lifecycle, Dawn Vulkan device,
deterministic clear/readback/present fixture, 4 KiB and 16 KiB tests, and an APK
native-library audit.

Pass only after create/destroy/recreate, rotation, background/foreground, and a
long scheduler/register stress fixture succeed. Reassess before full-game work
if the 4 GiB alias model cannot be made safe without writable executable pages
or device-address hacks.

### A2 — Controller-driven Original game proof

Link the current private dual graph when authorized inputs exist, stage
validated `RMCP01` data privately, copy packaged runtime resources into
versioned private storage, and boot the Original profile.

Pass separately on an ARM64 emulator and physical Android hardware after
title/menu navigation, one complete race, results, save, quit/relaunch,
pause/resume, surface recreation, audible SDL output, and one controller all
succeed. Without physical hardware, record the emulator result and keep A2
open.

### A3 — Retro Rewind 6.12.7 offline proof

Use the current repository profile as the only version/hash authority. Port or
extract the bounded archive validation, download, free-space preflight,
staging, atomic activation, rollback, cancellation, and recovery contract.

Pass independently on emulator and physical hardware after a complete Retro
Rewind race, results, save/relaunch, Original/Retro mode switching, and fault
tests for corrupt input, mismatched hash, network loss, full disk, process
death, activity recreation, and an existing valid installation. Never accept
an accidental fallback to Original.

### A4 — KartPad shell and touch parity

Implement the current first-run flow, menu hierarchy, settings, imports,
touch overlay/editor, acceleration lock, haptics, controller handoff, motion
steering, Mii management, data/save actions, and diagnostics.

Pass automated phone/tablet golden images, hit maps, multi-pointer replay,
accessibility checks, state persistence, and modal/lifecycle input clearing.
Then require hands-on touch-only races on a physical phone and tablet; leave
those rows open if hardware is unavailable.

### A5 — Online and device hardening

Implement the native guest TLS backend, deterministic local network fixtures,
Android-emulator/local-WFC flow, and macOS/Android cross-client play. Add
Adreno/Mali, controller, audio-route, storage-provider, lifecycle, memory,
thermal, battery, frame-pacing, reconnect, and upgrade/save-recovery coverage.

Use production Retro WFC only when it is available and a normal test is
permitted. Never use public infrastructure for stress, malformed traffic, or
automation volume.

### A6 — Release candidate

Produce deterministic auditable unsigned APK/AAB outputs, verify only intended
ABIs and 16 KiB alignment, audit permissions/dependencies/symbols/paths/private
data/notices, sign a designated candidate only when authorized, and prove
update-in-place and save export/restore on physical devices.

Pass only when mandatory Android rows are green, no P0/P1 defects remain, the
exact candidate is tested, and hosted/publication authority is explicit. Do
not publish merely because packaging succeeds.

## The repeated work loop

Repeat until A6 passes or a genuine human-only boundary is reached:

1. **Sync and inspect.** Fetch `origin`, preserve any unrelated dirty work,
   read the latest Android/status/journal evidence, and select the lowest
   incomplete goal.
2. **State one falsifiable subgoal.** Choose the smallest reversible change
   with a concrete expected result and immediate test.
3. **Record the baseline.** Note commit, tree state, toolchain/lock digest,
   ABI, API/page size, AVD/device, renderer, and relevant artifact hashes.
4. **Implement narrowly.** Reuse existing KartPad/runtime code and add the
   smallest Android-specific owner. Do not mix unrelated UI, runtime, and
   performance changes.
5. **Test immediately.** Run the narrow unit/contract test, then the smallest
   JNI/app/runtime test capable of disproving the change.
6. **Run Apple regressions when shared code changes.** At minimum run affected
   tests, `scripts/verify-sunpad-overlay-snapshot.sh`, source verification, and
   the smallest applicable Apple build contract.
7. **Audit boundaries.** Check generated packages and logs for private data,
   translated shards, absolute user paths, signing material, credentials, and
   unintended ABIs/dependencies.
8. **Classify honestly.** Mark Pass, Fail, Regressed, Inconclusive, or Blocked
   by an external/human prerequisite. Never upgrade build or emulator proof to
   physical acceptance.
9. **Capture sanitized evidence.** Store compact logs/reports/screenshots under
   `docs/artifacts/<date>/android/` and keep raw/private captures ignored.
10. **Update the record.** Append the command, result, failure signature,
    evidence, commit, remaining gate, and next smallest step to `JOURNAL.md`;
    update `STATUS.md` and `ANDROID.md` when reality changes.
11. **Commit coherent checkpoints.** Run tests, `git diff --check`, repository
    safety, and source-pin verification. Commit only relevant reviewed files on
    a `codex/` branch and push/open a focused PR when the checkpoint is real.
12. **Continue.** Do not stop at scaffolding, a green compile, a blank activity,
    a clear frame, or first boot while a safe next step remains.

## Failure and anti-stall rules

- Read the complete error and record a stable signature before retrying.
- Two materially identical failures forbid a third unchanged attempt.
- Check stale Gradle daemons, CMake caches, AVD snapshots, installed APK/data,
  generated graphs, dependency archives, and environment paths before changing
  source.
- Reduce failures to one boundary: Gradle, JNI load, ELF/PIC, memory mapping,
  fiber switch, SDL lifecycle, Dawn/Vulkan, audio, input, URI/storage, archive,
  TLS, or guest behavior.
- Instrument to distinguish hypotheses; do not guess through broad rewrites.
- Prefer official Android, SDL, Dawn, CMake, and JDK documentation and pinned
  upstream source for technical decisions.
- If one goal is externally blocked, document it once and continue independent
  source-only work that does not bypass a correctness dependency.
- Never delete an app/container to fix an update or save bug without first
  backing it up and proving a restore path.

## Handoff standard

At any stop, leave:

- branch and exact commit;
- clean/dirty status and every intentional untracked path;
- completed goal/subgoal and what the evidence actually proves;
- exact commands and artifact hashes;
- toolchain versions, SDK/NDK roots, AVD/device/API/ABI/page size, and Vulkan
  backend;
- first unresolved failure signature or human prerequisite;
- private-data locations described only as sanitized placeholders; and
- one concrete next command or interaction.

A useful handoff lets the next agent continue without repeating discovery or
mistaking a build, emulator, or screenshot result for Android support.
