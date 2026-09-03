# KartPad status

Updated: 2026-09-03

## Native Android work

Android A0 passes on the authorized second Apple Silicon host. The explicit
bootstrap pins public ARM64 Temurin 17, SDK/Build Tools/NDK/CMake/emulator
components and two disposable ARM64 AVDs. The non-playable SDLActivity shell,
transparent KartPad-owned overlay, SDL/JNI entry, and Dawn Vulkan adapter
fixture build and pass package audit, then install and run on API 36 / 4 KiB
and Android 15 / 16 KiB cold-boot AVDs. The audited local debug APK SHA-256 is
`c28461e09f78ba2dc05ab70d137d1918d2e559c9ec2864ae645d26f3697e22ee`.
This does not prove a presented frame, lifecycle, guest memory, fibers,
gameplay, physical Android hardware, performance, or release readiness; no APK
or AAB was published. Evidence:
[`docs/artifacts/2026-09-03/android/a0-source-only-fixture.md`](artifacts/2026-09-03/android/a0-source-only-fixture.md).
The lowest incomplete goal is A2.

The first A1 renderer slice passes on both pinned page-size lanes. One Dawn
Vulkan device performs an exact 16-pixel GPU clear/readback, presents through
SDL's Android native window, and presents again after an automated
HOME/foreground surface recreation. It now also observes an exact physical
landscape-to-flipped-landscape sensor transition, reconfigures the retained
Dawn surface, and replaces/presents through three consecutive
background/foreground surface generations on both lanes. The ELF AArch64
fixture passes start/resume, yield, sleep/wake, join, cancel, two million
deterministic scheduler operations, and one million native context switches
with the complete callee-saved register set on both lanes. A separate A1
checkpoint reserves a dynamic sparse 4 GiB range and proves two shared
views, cross-alias visibility, and runtime-page-size-aware protection changes
on both 4 KiB and 16 KiB lanes without writable-executable memory. Evidence:
[`docs/artifacts/2026-09-03/android/a1-vulkan-readback-present.md`](artifacts/2026-09-03/android/a1-vulkan-readback-present.md)
and
[`docs/artifacts/2026-09-03/android/a1-lifecycle-stress.md`](artifacts/2026-09-03/android/a1-lifecycle-stress.md)
and
[`docs/artifacts/2026-09-03/android/a1-guest-memory.md`](artifacts/2026-09-03/android/a1-guest-memory.md)
and
[`docs/artifacts/2026-09-03/android/a1-elf-scheduler.md`](artifacts/2026-09-03/android/a1-elf-scheduler.md).

This closes A1's source-only native primitive and Vulkan-surface gate. It does
not prove production-runtime integration, gameplay, physical-device Vulkan,
or performance. The lowest incomplete goal is A2.

The first A2 build/link slice passes. A fresh ignored runtime copy consumes the
current common Apple patch stack plus narrow Android patches, compiles all
29,065 Original translated functions, and links them with the production
4 GiB guest-memory implementation, ELF AArch64 fibers, Aurora, pinned Dawn,
and the official SDL AAR as `libmain.so`. Gradle packages the complete runtime
through the normal app module while fixture mode remains the public default.
The resulting local ARM64 debug APK is 103,425,387 bytes with SHA-256
`5d96c31ef91ead5d7ada0977c1853d39b4fcc7f57ea8f4fe3439c1de89ac9e13`;
its stripped `libmain.so` is 83,529,560 bytes with SHA-256
`a1b15ee74f77fd891f7d885c6602bf23bd73c9b6e4cfcfc56ce1ee2279089165`.
The package passes ABI, dependency, RELRO, non-executable-stack, 16 KiB load,
JNI/SDL export, permission, native allowlist, and private-path/data audits.
This is build and package evidence only: no game data was included or staged,
and boot, gameplay, controller, audio, save/relaunch, lifecycle under the game,
and physical-device rows remain open. A2 remains the lowest incomplete goal.
Evidence:
[`docs/artifacts/2026-09-03/android/a2-original-runtime-link.md`](artifacts/2026-09-03/android/a2-original-runtime-link.md).

The next A2 storage/runtime slice also passes. Game-runtime builds package an
exact 14-file public asset allowlist and atomically install it before SDL loads
at `files/KartPad/RuntimeResources/a2-v1`. Context-derived app-private paths
now own configuration, logs, NAND, and mutable Dawn/Aurora caches without any
storage permission or private content in the APK. A cleared API 36 / 4 KiB
cold launch initializes the dynamic 4 GiB guest mapping, loads the translated
image, executes 43 main-DOL and 192 StaticR constructors, creates the Vulkan
renderer, seeds 1,199 public pipeline rows, and then fails closed at the exact
expected boundary because no DVD root is configured. The audited game APK is
103,429,792 bytes with SHA-256
`49526a79b60bdc0f1b3ca51202f4b95c12b2fef3329a552a125a63f1863011c2`.
This is app-private initialization evidence, not game boot or gameplay. A2
remains open for privately staged `RMCP01` data and the emulator/physical
gameplay matrix. Evidence:
[`docs/artifacts/2026-09-03/android/a2-app-private-runtime.md`](artifacts/2026-09-03/android/a2-app-private-runtime.md).

The first full Original emulator boot now also passes. Ignored validated
RMCP01 data is staged only under the app sandbox; the title, demo, saved
license, non-silent SDL stream, and live Luigi Circuit gameplay render through
the complete translated runtime. Six title/demo and three live-race
HOME/foreground cycles retained their process after a narrow stale-ImGui-frame
repair. Three cold processes restored the saved `KartPad` license. A debug-only
app-private RKG bridge reaches the existing native player fixture, but that
fixture diverges into the wall and does not finish; a separate clean Nintendo
staff replay rendered for more than twelve wall-clock minutes without a crash
but is not player/results/save evidence. A2 remains open for a complete player
race, results, post-race save/relaunch, real controller, and physical Android
hardware. Evidence:
[`docs/artifacts/2026-09-03/android/a2-emulator-boot-lifecycle.md`](artifacts/2026-09-03/android/a2-emulator-boot-lifecycle.md)
and
[`docs/artifacts/2026-09-03/android/a2-debug-input-replay.md`](artifacts/2026-09-03/android/a2-debug-input-replay.md).

An additional Android-only debug marker can now retain fixture acceleration
while routing steering through the existing keyboard stick. It accepts
steering but did not complete a race. Normal fixture steering also diverged on
exact GCN Mario Circuit metadata and on the exact SNES Mario Circuit 3 stream
previously proven through the native macOS player path. No forced finish was
used; the private all-cups test save was restored byte-for-byte afterward.
This is diagnostic capability only and does not narrow A2's remaining player,
controller, or physical-device gates. Evidence:
[`docs/artifacts/2026-09-03/android/a2-keyboard-steer-diagnostic.md`](artifacts/2026-09-03/android/a2-keyboard-steer-diagnostic.md).

## Native tvOS work

The maintainer-owned `codex/tvos-retro-rewind` branch contains the first
independent native tvOS implementation slice: a `KartPadDual` tvOS build graph,
focus-driven setup host, Extended Gamepad requirement, Mac-side private game
data staging, official hash-verified Retro Rewind installation, and a fail-closed
artifact audit. The complete dual Original/Retro Rewind graph now compiles and
links as an unsigned arm64 tvOS 17 app, and that app passes the native bundle,
platform, dependency, symbol, privacy, and private-data audit. No Apple TV is
paired with the current Mac, so signing, installation, execution, gameplay,
performance, and save recovery remain untested. Apple TV support is therefore
not accepted. The candidate includes an original three-layer tvOS icon and Top
Shelf image compiled into its audited asset catalog. It remains explicitly
experimental in the `v0.4.0` hardware-bring-up build. The next
gate is a small outside cohort using the exact audited candidate and tester
checklist. The
authoritative scope, build procedure, storage boundary, and external-testing
gate are in
[`docs/TVOS.md`](TVOS.md).

## Current goal

**0.4.0 is published as KartPad's second stable community release.** The
`v0.4.0` tag points to source commit
`369159153bef0d045edf5cc1cf3b1b444b36a284`. Its iPhone/iPad app 0.4.0 build
15 IPA has SHA-256
`af80c2bc6fcabdb4eee84aed05254eccef76d7e6bbf83f2c7f21101168c665c8`;
its experimental tvOS app 0.4.0 build 3 IPA has SHA-256
`9ee2a9b05bff56261d4d4986eca54840e98ade8ae0abd3ac623c1f2393dcf5cc`.
The physical iPhone passed Retro Rewind 6.12.5 launch, per-control hiding, and
the editor's Back path. Exact merged-source builds, double deterministic
packages, local and fresh hosted audits, hosted byte comparison, checksums,
and remote tag/main verification pass. Physical Apple TV acceptance remains
open, so that included artifact is still explicitly experimental.

**0.4.0 Preview 2 is published.** `v0.4.0-preview.2` points to source commit
`e9fa6058ee09fff0b16481ebe4a78d61cea69c87`. Its app 0.4.0 build 14
iPhone/iPad IPA has SHA-256
`a796cd0e29bfd47d78afc50989a959803f9eff434252a3a455af85308b380fe6`;
its app 0.4.0 build 2 tvOS IPA has SHA-256
`3f8f529a93cc3f1ddfe9e9b71171ba56ead5a49ae3598c449a42f00eed6c5a9a`.
It advances the pinned Retro Rewind input and translated graph to 6.12.5, adds
a daily upstream version watcher and deterministic profile updater, and repairs
the universal iPhone/iPad three-dot menu after inherited settings refreshes.
Exact merged-source builds, deterministic double packages, hosted byte
comparison, checksums, fresh hosted audits, and the daily workflow pass.
Physical 6.12.5 gameplay and tvOS acceptance remain separate gates.
The established physical 6.12.4 iPad result is not relabeled as 6.12.5 proof.

**0.4.0 Preview 1 is published.** `v0.4.0-preview.1` points to source commit
`4d32dfac683966ea1cb4f72963deffbe936404da`. Its app 0.4.0 build 13
iPhone/iPad IPA has SHA-256
`5b959d7a6abba43db3d557bbba3dc3a1ab913650f0717cdf8600afa06fcb32c1`;
its app 0.4.0 build 1 tvOS IPA has SHA-256
`78dcdf28c947330d480fcc789f0b81b95bafe94497c56f9c26bb6249c5362df1`.
Both exact merged-source builds, deterministic double packages, local audits,
hosted byte comparisons, checksums, and fresh hosted audits pass. The Apple TV
artifact remains a physically unaccepted tester build, not a supported-platform
claim; the external Apple TV matrix is still open.

**Preview 5 is published.** `v0.3.0-preview.5` points to source commit
`8e57ac49c161ff576d6eff198ade2ee9b21f575e`. Its unsigned app 0.3.0 build 12
IPA has SHA-256
`9b7b8c586ddd04b639dda5634e72e88dc91ccefb93762f1afde6e8006d274d14`.
The exact source passed fresh native macOS and physical-iOS builds. Both local
packages were byte-identical, and the freshly downloaded hosted IPA and
checksum matched and passed a new audit. Reporter acceptance remains open.

**Preview 4 is published.** `v0.3.0-preview.4` points to source commit
`3e43c002d60378bd4975c4637a8e3a149f2d733e`. Its unsigned app 0.3.0 build 11
IPA was packaged twice byte-identically; the local and freshly downloaded
hosted files match byte-for-byte and pass checksum, ZIP, app, privacy,
provenance, signing-residue, and private-data audits. The hosted IPA SHA-256 is
`6bd4a3bd6a8582dd193093dda7471cecee2cafd7450f51ea59454329a1529b9e`.

Preview 4 adds experimental Mii import/management on Mac, iPhone, and iPad plus
an experimental macOS-only direct Wii Remote/Nunchuk pairing path and
controller preset. The exact merged-main macOS build compiles, links, packages
with Bluetooth permission, and passes audit. A real exported Mii and physical
Wii hardware remain external acceptance gates. Issue #5 now contains the
bounded tester request and remains open for results.

The preceding in-place iPad candidate preserved the complete 5,745-file,
4.8-GB KartPad Application Support/NAND tree byte-for-byte, launched, and
remained running. Earlier hands-on testing accepted Retro Rewind, ordinary
controller input, the stable three-dot button and reorganized menu,
exit/reopen lifecycle, Original Mario Kart Wii, and the existing license.
Folder-scan diagnostics and a direct Files fallback were built and
contract-tested; Preview 5 removes the intervening failure alert. The exact
Feather-signed environment remains the final acceptance gate. The release rollup is in
[`docs/releases/NEXT.md`](releases/NEXT.md).

**The provider-compatible import hotfix is published.** `v0.3.0-preview.3`
points to source commit `452af2dde3d19508a5e6ced6c03deb0e24b8b509`. Its unsigned
0.3.0 build-10 IPA, checksum, embedded release notes, provenance, licenses,
privacy boundary, and freshly downloaded hosted artifact all pass. The hosted IPA
SHA-256 is
`e839c115a97867949b16fa1c4a2a3472dce4eb3da6c69fff6f40c3eca2abbdcf`.
The build asks iOS Files providers for a local picker copy, removes only that
temporary copy after import, and scans app-folder disc extensions before
provider package/directory metadata. Issue #1 remains open for confirmation on
the reporter's exact iPad; build and audit proof are not that confirmation.

**Local Apple-to-Apple online flow passes.** Native macOS and the exact iPad
Simulator completed login, matchmaking, room formation, Luigi Circuit race
traffic, the retail online finish/results path, rating updates, and return to
the shared lobby. The accepted run exchanged more than 3,500 UDP packets in
each direction per client and consumed the complete 5,001-frame fixture. The
test-only finish trigger is documented in `docs/ONLINE.md`; public-service,
physical-device online, impairment, and external-client rows remain open.

The exact released dual-mode build also reaches production Retro WFC NAS
authentication. It then receives `61070` because the public GameSpy
gameplay-login endpoint times out. Retro Rewind's official documentation lists
the service as in testing/maintenance mode, and its status page has no live
room data. Production online acceptance is waiting on Retro WFC recovery. That
external outage does not block the accepted Retro Rewind installation, launch,
or offline-gameplay support in the current KartPad build.

The same source produced a fresh signed KartPad `0.3.0` physical-iOS build. It
was installed over the existing app on the attached iPad without
an uninstall, launched successfully, and visibly reached the Original / Retro
Rewind chooser. That is physical build, install, launch, and chooser evidence;
it is not production Retro WFC matchmaking or gameplay evidence. The latter
remains queued behind service recovery.

Two physical-iPad attempts to download the official 6.12.4 full pack then
failed identically after transfer: both device crash reports show `Thread stack
size exceeded` in `KartPadSHA256ForLargeFile`. The verifier had placed a 1 MiB
streaming buffer on a dispatch worker's smaller stack. Current source moves that
buffer to heap storage, makes download and install percentages separate, checks
Retro Rewind's official version feed before launch, and fails closed when a
newer pack requires a new ahead-of-time KartPad build. Physical build 7
established the hardware acceptance gate: its full-width dual-mode chooser was
visually accepted on the iPad, then a fresh hands-on run downloaded the official
6.12.4 pack, completed verification and installation without a crash, launched
Retro Rewind, and reached a playable single-player match. Build 8 is installed
in place without removing KartPad's data and carries the final iPad
multiplayer-guidance polish, which is validated in the exact iPad Simulator
candidate. This closes physical pack installation, Retro Rewind launch, and
initial offline-gameplay acceptance. Production Retro WFC matchmaking and
online gameplay remain unaccepted while the external service is in maintenance,
but they are not a blocker for this build.

## Goal ledger

| Goal | Status | Evidence / next gate |
|---|---|---|
| G0 Workspace/evidence | Pass | Safety audit passed; checkpoint `2f3bf40` pushed |
| G1 Inputs/pins | Pass | Full source/disc verifier passed; checkpoint `94f6e79` is on GitHub |
| G2 Baseline oracle | Pass | Translator 570/570; isolated Dolphin boot/license/menu/race/staff-ghost oracle in `docs/artifacts/2026-08-28/dolphin-oracle/` |
| G3 Host portability | Pass | Native arm64 host library/contracts pass; Darwin graph contains no Win32/x86-only link token; manifest recorded |
| G4 Guest memory | Pass | Checked Darwin path passes conformance, lifecycle, randomized stress, microprogram, ASan/UBSan; safe Mach VM feasibility probe passes |
| G5 Guest scheduler | Pass | Explicit state machine passes lifecycle/priority/VI/register tests and two deterministic million-operation runs under Release and ASan/UBSan |
| G6 PPC/AArch64 semantics | Pass | 250,227-check arm64/x86 hashes match; Dolphin oracle, sanitizers, translator 582/582, translated scalar/paired state, scheduler/callback persistence, and all 10,836 title units pass |
| G7 Native Metal frame | Pass | Real PAL wrist-strap frame visible at 60 FPS; reproducible Apple runtime patch and capture evidence recorded |
| G8 macOS boots/input | Pass | Full DOL+StaticR intro/title/menu, audible output, A/directional/1 navigation; evidence under `docs/artifacts/2026-08-28/g8-title-menu/` |
| G9 first race/save | Pass | 100cc VS standings/result/menu cycle, changed save hash, clean quit/relaunch with `Player` intact, and `Nin★sato 01:29.670` replay; evidence under `docs/artifacts/2026-08-28/g9-race-save/` |
| G10 macOS offline compatibility | In progress | Row 22 passes all 32/32 retail tracks with every cup subset complete; ghost sync, save safety, vehicles/drift, items/AI/collisions, Time Trial row 26, Battle rows 27–28, two-player row 29, four full-range keyboard/controller slots, explicit GameCube-adapter limitation, privacy-safe obsolete-service fallback, and a two-hour representative audio-continuity run also pass their stated subcases. Continue honest Grand Prix progression, three/four-player standings cycles, and subjective/final audio acceptance |
| G11–G18 | Gated | Await G10 |

## Finish-line order

The project is no longer blocked on proving that the game can run or on
packaging a public Retro Rewind preview. The shortest credible path to full
engineering completion is to close the remaining evidence gaps in dependency
order:

1. **Close G10 honestly:** finish representative Grand Prix progression,
   complete three- and four-player race/standings cycles, and perform the
   remaining subjective audio acceptance. Do not spend more time re-proving
   already accepted tracks or modes.
2. **Make G11 measurable before optimizing:** add bounded frame/pipeline
   telemetry, establish reversible cold/warm fixtures, then attack the ranked
   bottleneck. Shader-cache guesses without p99/worst evidence are not a plan.
3. **Separate automation from hands-on gates:** run long stress, save, package,
   cache, diagnostics, and Simulator work autonomously; reserve subjective
   touch, motion, audio, thermal, and live-service checks for hardware.
4. **Close targeted hardware rows:** general iPad/iPhone execution and Retro
   Rewind installation pass. Continue sustained performance, thermals, motion,
   controller feel, and broader touch-race coverage against exact builds.
5. **Finish the application boundary:** automate clean-checkout provisioning
   and complete updater/notarization infrastructure without bundling private
   data. Native WBFS import and update-in-place preservation already pass.
6. **Retest public online when available:** the complete local Apple-to-Apple
   WFC flow passes. Resume production NAS, GameSpy, matchmaking, race, results,
   and reconnect only after Retro WFC service recovery.
7. **Cut one full candidate:** rerun the full 67-row matrix, package/privacy/
   license audits, source self-build, and zero-P0/P1 review against the same
   immutable commit and artifact hashes.

The practical change in approach is to stop treating broad successful gameplay
as the scarce resource. The scarce resource is now controlled evidence:
repeatable multiplayer completion, frame-time instrumentation, reversible cache
experiments, physical-device interaction, and a reproducible legal build path.

## Known-good state

- Repository checkpoint: exact branded macOS gameplay-package source `325d5f3` is on `origin/main`. Its ignored 80 MiB arm64 package passes installed-storage, configured title/menu/live-race input, save-preservation, and normal-close checks with bundle-content hash `12e827fdaf206df3689ab0fe0b73fa7ebe20fe3827b538d8fe7c21e8ac25e3db`. Source `5781b99` adds the native data/cache/diagnostics menu without changing the gameplay core. Source `bed127f` adds the native display/audio Settings panel. Source `a5ee9fe` adds the native first-run extracted-data gate, reconfiguration action, complete fallback application menu, and safe menu-Quit route. Source `ac89225` exposes the existing in-game controller-mapping UI from that native menu. Source `c6f94b7` adds bounded technical context to the privacy-safe diagnostics report. Source `df98779` adds persistent clean/unclean session classification and capped/redacted current/previous tails; its exact package passes export, privacy scan, clean relaunch, and audit with bundle-content hash `893095ac96d66d036c61cbfa8af79b58eac3bdbf9d24b5da4fa44066111afcb6`. Source `d6e3202` adds the one-command WBFS-to-macOS self-build; its fresh extraction, 29,637-function translation, 857-step build, exact package audit/title/audio/clean-quit exercise, and byte-identical function/shard comparisons pass with bundle-content hash `bc53f9e82e2e7656d86170e59426b9ab79b4553366946b684824739fd9f0fc92`.
- Performance checkpoint: source `2cfb7e1` adds bounded p50/p95/p99/worst presentation telemetry, effective-motion FPS, pipeline queue counts, and strict summary parsing. Its exact package reaches the title, emits valid records, audits, and quits cleanly with bundle-content hash `dc6ecdca64df7a031fde00ab63472f0130674e8705bd27196483d6a0005615de`. A reversible empty-cache/warm-cache title pair quantified the cold failure at minimum 51.958 effective FPS, 83.783 ms maximum p99, 85.094 ms worst, and 20 audio drops versus warm minimum 59.963 effective FPS, 17.264 ms maximum p99, 25.966 ms worst, and zero drops. A counterbalanced one-vs-six priority-worker sweep proved that application-cache emptiness does not control all machine-level Metal/Dawn state: both policies ranged from poor to essentially perfect as that state changed. Warm Moonview profiling now rules out steady GPU saturation (12.15% union occupancy, no drawable waits) and ranks exact scalar-FP exception bookkeeping on the main thread. Direct arm64 FPSR access passed correctness and a microbenchmark but failed a paired production CPU comparison, so it was reverted. Source `2282e2c` corrects hidden FPSCR effects in ABI/liveness analysis and passes the complete semantic surface; its exact package held 60 FPS with zero audio drops, but a paired attract-race profile was CPU-neutral (candidate/control total 10.432/10.813 seconds, main thread 7.527/7.402 seconds). Correctness is retained; no speedup is claimed, and safe FPSCR-state elimination remains the ranked CPU direction.
- The first exact `2282e2c` automated macOS soak was operator-stopped after
  4:10:10 and is not row-38 acceptance. Its partial trace strongly rejects
  monotonic memory/thread growth (257,120--1,125,792 KiB RSS, negative
  post-warmup slope, 23--28 threads) and preserved the exact save, but 480
  audio blocks / 184,320 bytes were dropped in scene-transition bursts. The
  fixed 120 ms queue ceiling is now the ranked pre-soak fix. The Simulator
  application shell had also remained visibly open despite zero booted
  devices; future launches require both zero booted devices and zero competing
  visible runtime applications. Evidence:
  `docs/artifacts/2026-08-30/g11-interrupted-macos-soak.md`.
- Simulator state: no Simulator is booted. The disposable iPhone 17 Pro devices used for clean-import/rollback and scheduled-removal testing were terminated, shut down, and deleted; the preserved iPhone container was not modified.
- Buildable KartPad targets: host, memory, scheduler, semantic contracts, native subsystem smoke, translated semantic fixture, and provisional translated-frame app.
- Input profile: WBFS containing clean PAL `RMCP01`, revision 0; original is read-only. Physical keyboard holds retain the full normalized Classic-stick range. Accessibility-generated GUI taps use a bounded 0.35 level for 250 ms; acceleration/reverse retain their 500 ms gameplay holds. Physical controllers and future touch input are unaffected.
- WiiCompiled baseline: required commit/tree verified in a detached, push-disabled partial clone.
- Translator baseline: immutable upstream remains 570/570; KartPad's reproducible FPSCR lowering patch passes 582/582 on native arm64 with .NET SDK 8.0.130. Stateful scalar/paired FP, comparison, FPSCR move, and exception-control helpers now expose their hidden FPSCR reads/writes to ABI and interprocedural liveness analysis instead of masquerading as pure calls.
- Gameplay baseline: hashed Dolphin 5.0-17995 arm64/Vulkan/HLE binary boots `RMCP01`, creates an isolated license/save, reaches Luigi Circuit and its official staff ghost, and recovers to 60 FPS/VPS after shader warmup.
- Portability baseline: `kartpad_host` and its contract suite compile/link/run natively for arm64 macOS; manifest is under `docs/artifacts/2026-08-28/`.
- Memory baseline: checked/table guest memory is the accepted correctness path; evidence is `docs/artifacts/2026-08-28/g4-guest-memory.md`.
- Scheduler baseline: explicit cooperative state machine, deterministic hash `0x7287563387fb1677`, plus translated CPU-context/NI/FPSCR persistence across yields and host callbacks; evidence is `docs/artifacts/2026-08-28/g5-guest-scheduler.md`.
- Native subsystem preparation: validated Metal/CoreAudio/GameController/storage/network smoke; useful for G7 and later gates.
- Semantic subset: arm64/x86_64 complete 250,227 checks with state hash `0xccd5757c4c0643d4`; the translated fixture additionally proves VE-enabled paired invalid arithmetic still writes both lanes while aggregating causes. Evidence is `docs/artifacts/2026-08-28/g6-ppc-semantics.md` and `docs/SEMANTICS.md`.
- Full title surface: user-owned PAL DOL and StaticR translate into 29,637 functions; the native runtime executes both constructor graphs through the title and license menu.
- Original icon: editable default/dark/tinted SVG masters and opaque exports exist; 1024 px and 16 px visual QA passed. The iPhone/iPad appearance variants now pass Simulator and physical-device asset-catalog builds.
- Full mobile game app: the freshly serialized controller integration compiles all 29,065 base translated functions into an Xcode-produced arm64 `IOSSIMULATOR` app. SDL owns the UIKit scene lifecycle; the real SDL/Metal window receives the byte-identical SunPad overlay. The first physical controller takes Player 1, clearing/hiding touch by default on hardware; Players 2–4 publish independent states into their matching retail KPAD channels and disconnect clears stale input. The resolved iPhone/iPad bundle, original compiled icon catalog, privacy/runtime resources, system-only linkage, twelve-file exact snapshot, and forbidden-private-data audit pass. The latest full FPSCR-effect-model Simulator candidate has executable SHA-256 `bdb805b933e9cbce3e921dba11063af18fd6b18eaebdb36c447bbae24f71f2d8`; its exact FPS, aspect-ratio, and render-resolution menu actions all update the runtime immediately without relaunch. A normal twelve-racer iPad Simulator Luigi Circuit scene held 57.003–60.082 effective FPS across 35 retained race records and advanced 10.615 guest seconds across a roughly ten-second wall-clock bracket, ruling out a repeated-frame-only 60 Hz result for that stationary scene. Sequential iPhone/iPad launches preserve exact saves; the iPhone regression reaches live gameplay, discovers the Simulator extended controller, exposes its assignment/setup through Multiplayer, contains fitted output with opaque-black bands, opens the real system folder picker, completes a validated 2.5 GiB private import/swap, restores the old copy byte-for-byte under an injected swap failure, and recovers a stranded rollback on its next launch. With no installed game data, a native gate now runs before emulator initialization and can import the supported WBFS or extracted fixture and continue directly into gameplay in the same process. Destructive removal is explicitly scheduled, undoable until relaunch, and applied before emulator startup; its full-size regression removed only game data while preserving the exact save. A fresh post-motion source preparation completed the full 853-step serialized graph from immutable pins; its standalone Simulator link is `06238bd24c37235524375b7a12fbb0ca522b156b51936bf5be97049f5da5e500`. A Simulator-only one-worker pipeline policy corrects the observed Metal compiler scheduler crash without changing device/macOS policy. KartPad-owned configurable CoreMotion steering now compiles for Simulator and device, passes its deterministic input contract, presents an accurate Simulator-unavailable fallback, and survives the final candidate's background/foreground cycle; physical motion play remains open. Evidence: `docs/artifacts/2026-08-30/g14-full-game-app.md`, `docs/artifacts/2026-08-30/g14-full-game-simulator/`, `docs/artifacts/2026-08-30/g14-controller-multiplayer/`, `docs/artifacts/2026-08-30/g14-opaque-letterbox/`, `docs/artifacts/2026-08-30/g14-game-data-import/`, `docs/artifacts/2026-08-30/g15-native-wbfs-import/`, and `docs/artifacts/2026-08-30/g15-motion-steering/`.
- Physical mobile build: the same integrated source and all 29,065 base
  translated functions now compile and link against the pinned physical-iOS
  Dawn archive as a complete unsigned arm64 `IOS` 16.0 app. The 75 MiB bundle
  passes the strict full-game package/private-data/system-dependency audit at
  executable SHA-256
  `b02c1c94dee58526169a08e73bbbe671e6f6ee31c1870517ef244e2651e9de92`.
  A new source and build directory exposed and corrected an undercounted
  serialized KPAD patch hunk, then rebuilt both the complete Simulator graph
  and the complete physical-device graph from the corrected patch stack. The
  source verifier rejects any declared/actual line-count mismatch across the
  complete tracked unified-diff stack before a costly build begins. The final
  audit additionally requires the native WBFS-import contract and rejects
  Dolphin JIT/cached-interpreter execution-core symbols.
  The reproducible `scripts/build-ios-device-game-app.sh` rerun is incremental
  on an existing build directory. This closes fresh-directory and incremental
  full device compilation, not signing,
  installation, execution, performance, thermal, audio, or touch-feel rows.
  Evidence: `docs/artifacts/2026-08-30/g16-full-device-build.md`.

## Active risks and blockers

- The 0.3.0 menu removes the inherited Sunshine-specific 90%-clock and GMSE01
  60 FPS no-op rows, replaces remaining product-facing SunPad wording with
  KartPad, keeps Report a Problem visible, fixes the transient blank ellipsis,
  and presents Multiplayer guidance with a visible Back action on iPad. The
  pinned upstream component remains byte-identical; these adaptations live in
  KartPad's owning layer.

- The current touch-control candidate keeps the pinned twelve-file SunPad
  snapshot byte-identical while adapting two behaviors in KartPad's owning
  overlay: Classic R is a compact digital pill matching L, and an uninterrupted
  one-second A touch changes to a cyan held-acceleration state until touch-up.
  The focused Classic adapter passes. A Simulator-only end-to-end probe now
  drives the real SunPad touch-down/up targets and observes the mapped Classic
  state inside the live app: held `0x00000010`, released `0x00000000`. The full
  Simulator app audits at
  executable SHA-256
  `7c3c6a4ddda8a2d89d42e4a867dfc6c1e43aadd4635c28a2870e302e525956be`.
  Sequential iPhone and iPad visual/accessibility regressions both pass: R
  matches L, A enters `Acceleration held`, and release restores its normal
  state while retail rendering continues underneath. Each device and the
  Simulator shell were shut down before the next launch; zero runtimes remain.
  The exact updated UIKit host also compiles as an arm64 `IOS` 16.0 object with
  SHA-256
  `58df58a0577dd6c3276ec67c93bbf67955c6e1531a3912323cbb5881b72d4a55`;
  the reproducible check proves every Simulator-only test contract is absent.
  The unsigned physical-device shell and original icon catalog independently
  rebuild and pass their `IOS` package audit.

- About 14 GiB of host storage remains after private disc extraction, the full translated runtime build, and native trace evidence. Large generated products remain ignored; capacity must be checked before additional build graphs.
- Direct mobile WBFS import passes its complete Simulator integration boundary.
  A fresh no-data launch opened the supported `RMCP01` revision-0 WBFS,
  extracted and atomically activated the full 2.5 GiB/2,043-file tree,
  reproduced the accepted DOL/REL hashes, continued into retail rendering in
  the same process, accepted touch input, and reached the title again after a
  warm relaunch. The app links the narrow import graph rather than Dolphin's
  execution core; the package audit rejects JIT/cached-interpreter symbols.
  A supported physical import has completed. Injected interruption under real
  device pressure and detailed import thermals remain narrower hardware gates.
  Evidence:
  `docs/artifacts/2026-08-30/g15-native-wbfs-import/`.
- No human-only prerequisite currently blocks G0 or the independent parts of G1.
- Public Retro WFC, external-client interoperability, account, and remaining
  hands-on performance/audio/motion rows remain open and are not claimed.
- WiiCompiled's bundled `MAP.txt` may be used as an ignored local reference, but independent provenance for republishing it is not established; do not copy it into public KartPad sources/artifacts.
- The exact 2008 Classic ABI is live and the game recognizes it. A/accelerate, analog steering, D-pad, and B/reverse are proven. Three-player gameplay switches to the retail 30 FPS cadence documented by the Dolphin oracle; a complete live-input three-player race remains open.
- Two content-private three-player automation attempts rendered all expected panes and exited normally but failed to complete because the synthetic driver left the course at both the accepted `0.35` and rejected `0.18` steering levels. The `0.18` experiment was reverted; these attempts are not runtime-defect or standings evidence.
- A normal three-player stationary-player experiment registered three independent channels and held the retail four-pane 30 Hz mode for about 310 live seconds, but CPU completion did not trigger FINISH/DNF/results while every local player remained unfinished. The shortcut is rejected: row 30 still needs at least one local finisher through sustained physical input or a separately proven normal input-driving method. The same run accumulated 29 dropped audio blocks / 11,136 bytes, so three-player audio remains an explicit fail signal. Evidence: `docs/artifacts/2026-08-30/g10-three-player-stationary-timeout.md`.
- A deterministic second-race crash after returning from a three-player race was traced to a reclaimed camera node retained by the global race-camera list. A broad slot-`0xff` guard was itself regressive because three-player retail mode uses a legitimate slot-`0xff` overview camera. The corrected generated-source guard additionally requires the observed `0x55440003` scene-heap poison; the exact formerly failing sequence now preserves all four panes and reaches live second-race gameplay in the same process. Full three-/four-player standings cycles remain open.
- The opt-in RKG player fixture matches native stream expansion and the exact 240-frame countdown cadence but later diverges through the live-player path. It remains a diagnostic harness, not evidence for staff-ghost synchronization or a completed track.
- Both private disc-derived staff sets pass a strict content-free preflight: 32 files, exactly one structurally consistent input for every retail course ID `0..31`, and matched per-stream frame counts. This establishes a complete oracle inventory only; native row 22 execution remains open.
- A guarded private all-cups fixture derived from the user's own backed-up save now exposes the remaining row-22 tracks. It validates magic/version/CRC and changes only GP-completion flags plus CRC. It is a test precondition, not row-23 progression evidence; representative Grand Prix and honest unlock progression remain open.
- Two-player split-screen PRD row 29 passes: P1 completed three live-keyboard laps, both panes reached the retail finish transition, and the full standings table retained distinct Mario/P1 and Luigi/P2 rows. The successful log contains zero fixture entries; evidence is under `docs/artifacts/2026-08-29/g10-two-player-race/`. Three/four-player full races remain open.
- Time Trial PRD row 26 passes: an exact `01:38.880` personal ghost was recorded, saved, loaded after relaunch, replayed completely, and then authentically replaced by a normal live-input `05:01.445` personal best. A second fresh process loaded the replacement; evidence is under `docs/artifacts/2026-08-29/g10-time-trial-record/`.
- The initial visual interpretation of an N64 Mario staff-ghost overrun was false: the observation crossed into an automatic replay loop. A changed frame-end trace proved identical `240..8319` race segments and zero mismatches across 137,360 watched words. Ghost timing must be accepted from guest state, not wall-clock screenshots.
- Balloon Battle PRD row 27 passes: all ten retail arenas boot, and a complete 6-v-6 Block Plaza match reaches results and Main Menu. Instantaneous capture-time labels ranged from 43.2–60.0 FPS; deterministic cadence measurement remains a G11 gate and is not inferred from screenshots.
- Coin Runners PRD row 28 passes: all ten retail arenas boot, and complete 6-v-6 Block Plaza matches reach per-player results, team outcome, and Main Menu.
- Forced-exit save safety PRD row 20 passes at the stable Main Menu boundary: pre-exit, post-`SIGKILL`, and post-relaunch saves are byte-identical, and the existing `Player` license remains selectable.
- Vehicles/characters/drift PRD row 24 passes representative native coverage: Baby Mario light bike Manual completes via the bit-exact staff replay, Mario medium kart Manual completes both Battle modes, and Bowser heavy bike Automatic completes a full Balloon Battle.
- Items/AI/collisions PRD row 25 passes across complete 12-racer VS, Balloon Battle, and Coin Runners fixtures with item effects, collisions, AI, scoring/standings, results, and clean exits.
- GameCube adapter PRD row 32 passes by explicit limitation: the Darwin product deliberately uses a no-device WUP-028 stub and does not advertise raw USB adapter support; ordinary controllers remain mandatory separately.
- Four controller slots PRD row 31 passes: P1–P4 independently register as Classic controllers, channel-specific disconnect raises the correct interruption state, reconnect restores assignment, and pending/previous held input is cleared.
- G2 audio evidence is limited to emulator execution; subjective audio quality is a future hands-on row and is not claimed.
- G8 playback is proven by both the runtime's non-silent host-stream telemetry and an independent system-output loopback level capture. Subjective audio quality and latency remain hands-on G10/G11 rows.
- Audio continuity instrumentation is bounded and cumulative. Its first uncontended diagnostic sample recorded 104,960 queue checks and 40,304,256 submitted bytes with zero post-start empty observations or drops. Replay pause/resume passes with zero empty observations and a bounded eight-block pause burst. Default-output migration also passes: two live route changes caused a bounded 101-block stale-data burst, then zero further drops through 98,304 checks; the original output was restored and gameplay remained live. A separate 2:00:18 representative run completed 22 exact replay segments with zero empty-before-push observations through 2,408,448 checks; 175 stale blocks (67,200 bytes, about 0.0073% of submitted bytes) were discarded without sustained starvation. Subjective listening remains open, and this two-hour run does not replace the G11 eight-hour soak. Evidence: `docs/artifacts/2026-08-30/g10-audio-two-hour.md`.
- The fresh-process Time Trial replacement check added a normal-load sample through 49,152 queue checks and 18,873,984 submitted bytes with zero post-start empty observations or drops. It strengthens ordinary menu/gameplay continuity but does not replace pause, default-device migration, or long-session acceptance.
- The portable development app intentionally stores writable `UserData` beside its executable and is not distributable. The exact branded arm64 package contains no writable/private state, links only Apple system libraries, declares macOS 14.0, and uses the original icon. The `325d5f3` gameplay candidate reaches configured live Grand Prix gameplay and keeps durable state in Application Support and rebuildable cache state in Caches; the save and bundle remain unchanged. The native shell provides Show Data, Show Cache, bounded Save Diagnostics, a standard display/audio Settings panel, and an entry into the existing F10 controller-mapping UI. Schema-3 diagnostics identify exact build/runtime, product/renderer/memory/scheduler strategies, selected safe settings, validated data, yes/no storage health, clean/unclean session state, and capped/redacted current/previous structured tails while excluding private content. An unconfigured launch validates a supported user-owned extracted RMCP01 folder before runtime initialization, writes and reloads `dvd_root`, and reaches the game in the same process; unsupported selections preserve the prior config, and both first-run and application-menu Quit routes exit without fatal teardown. Replacing an older signed app bundle with the current package preserves byte-identical external config/save state and boots retail rendering. The public Mac command-line workflow now accepts the pinned user WBFS, performs a fresh validated extraction, emits the complete private title graph, builds/audits the app, and reaches retail rendering/audio with clean input and shutdown; its function/shard trees are byte-identical to the prior graph. Automated fresh-clone reference provisioning, native image-generation progress/resume/cache management, and public updater/notarization infrastructure remain open. Evidence: `docs/artifacts/2026-08-30/g13-exact-macos-package.md`, `docs/artifacts/2026-08-30/g13-macos-native-menu.md`, `docs/artifacts/2026-08-30/g13-macos-settings/`, `docs/artifacts/2026-08-30/g13-macos-first-run/`, `docs/artifacts/2026-08-30/g13-macos-controller-menu.md`, `docs/artifacts/2026-08-30/g13-macos-diagnostics-v2.md`, `docs/artifacts/2026-08-30/g13-macos-update-in-place.md`, `docs/artifacts/2026-08-30/g13-macos-clean-rebuild.md`, `docs/artifacts/2026-08-30/g13-macos-session-diagnostics.md`, and `docs/artifacts/2026-08-30/g13-macos-wbfs-self-build.md`.
- Moonview Highway first use sampled at 1.3 FPS and recovered to roughly 46 FPS within 20 seconds, then remained around 46–54 FPS during focused checks. Exact guest completion passed, but G11/G36 must compare a controlled warm-cache rerun and resolve sustained frame pacing before performance acceptance.

## UI reference commitment

The local `ref/sunpad` checkout remains the direct implementation reference for
the mobile touch interface and persistent three-dot menu. Its pinned twelve-file
snapshot, including controller slots and mapping, remains byte-identical. A
KartPad-owned layer adds product-specific Multiplayer, motion, reporting, game
data, and display behavior without modifying that snapshot.

The current runtime applies aspect ratio, render resolution, FPS visibility,
touch-layout editing, reset behavior, held-input clearing, and four stable
controller slots in process. Original 4:3 and bounded 16:9 clear to opaque
black. The Game Data & Saves flow validates, stages, swaps, rolls back, and
removes private data without touching saves. Dynamic fill remains experimental
because it can expose the game's overscan or scratch area.

The app boots, races, backgrounds, resumes, and preserves saves on accepted
iPhone and iPad builds. Broader touch-driven race coverage, physical finger-drag
ergonomics, additional controller and motion calibration, sustained performance
and thermals, and subjective touch/audio acceptance remain open. Evidence:
`docs/artifacts/2026-08-30/g14-simulator-shell/`,
`docs/artifacts/2026-08-30/g14-full-runtime-link.md`,
`docs/artifacts/2026-08-30/g14-full-game-app.md`,
`docs/artifacts/2026-08-30/g14-full-game-simulator/`,
`docs/artifacts/2026-08-30/g14-controller-multiplayer/`,
`docs/artifacts/2026-08-30/g14-opaque-letterbox/`,
`docs/artifacts/2026-08-30/g14-game-data-import/`,
`docs/artifacts/2026-08-30/g14-ipad-current-race-profile.md`,
`docs/artifacts/2026-08-30/g15-native-wbfs-import/`,
`docs/artifacts/2026-08-30/g15-motion-steering/`,
`docs/artifacts/2026-08-30/g15-touch-modal-input-clear/`, and
`docs/artifacts/2026-08-30/g15-touch-layout-editor/`.
