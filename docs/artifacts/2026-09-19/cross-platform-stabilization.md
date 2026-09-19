# Cross-platform stabilization review — 19 September 2026

## Decision

Prepare a conservative local candidate, not a general Android-fix release.
The source changes in this pass repair the reproducible self-build input failure
and a nested macOS build-directory defect. The candidate also carries the
previously reviewed shared timer/renderer fixes and the Android optional-Vulkan-
debug-functions correction. It excludes the unaccepted depth experiment and
buffer-allocation prototype. No build was published, sent to a reporter or
installed on a phone during this pass. Saves and accepted artifacts are preserved.

The refreshed GitHub snapshot has 56 open issues. No new reporter result arrived
since the preceding intake. That intake acknowledged #302/#303/#304; another
round of equivalent requests would not add evidence. See the
[complete recent inventory](github-review-inventory.md) and
[diagnostic intake](recent-issues-and-build-evidence.md).

## Concrete changes and evidence

### Retro-WFC payload, issue #302

The Retro6.12.8 archive and Code.pul did not change. The mutable production payload
URL did: 28,968 bytes became 28,992. The old downloader correctly rejected it but
misidentified it as the Retro Rewind pack in its error message.

- New SHA-256: `099097a0f85a97c348123d91438438b24b112362f1fb23c94df6a343c5366471`.
- Live download passes exact size/hash, header/declared-size and production RSA
  signature validation. No validation was weakened.
- Old and new payloads were translated with the same maintained translator,
  same verified 6.12.8 Code.pul and same mod-aware base metadata. Both completed
  with zero C++ translation failures. New payload: 17 static byte patches,
  31 executable hooks, six static pointers, 4,102 emitted mod functions.
- The new winning overlay is `0x800D3648`, mapped to
  `DWCi_GPRecvBuddyMessageCallback`; the old payload leaves the base winner.
  No base address was added or removed from the dispatch table. The inspected
  base graph has no inlined-leaf copy of this function. This is an executable
  change, not merely a cosmetic pin refresh; online acceptance remains open.
- Regenerated shards retain 29,065 active base functions and 4,102 mod functions.
  The builder's exact profile gate was updated from 4,101 to 4,102 and exercised
  against the real graph. The Android release constants are regenerated from
  the same profile.
- Downloader errors now name the Retro-WFC payload. Tests cover oversized,
  short, wrong-hash and redirected responses: rejected bytes never replace the
  old cache and partial files are removed. Accepted identity replaces atomically.
- All 27 builder tests pass, including the real cached production-signature and
  tamper check. All 36 existing LR-relative translator tests pass; those do not
  establish correctness of the newer upstream continuation follow-up below.

The full self-build launcher was not run: it would write the owner's current
Mac configuration. Instead the input, translation, native build and package legs
are validated separately in private output directories. The prepared mod-root
contains the verified Code.pul; an installed complete pack and online gameplay
remain separate acceptance gates. No game data or generated retail source is
committed or uploaded.

### macOS generated-file location

`prepare-g7-game-runtime.sh` previously created `build/generated` even when its
runtime-source argument selected a nested directory. Runtime CMake resolves
`../generated` relative to that source, so the paths could disagree. It now uses
`dirname(runtime_source)/generated`, matching the existing iOS scripts and
retaining their restore-on-exit behavior. The actual nested build uses this
layout; the existing build-script contract includes macOS.

### Shared runtime scope

The candidate retains the reviewed timer reentry correction across all four
platform runtime sources and the vertex-upload, draw-format merge and index
bounds corrections. Those address concrete source defects; build121's negative
geometry results demonstrate that they are insufficient to resolve every report.
The Android candidate links the reviewed Dawn backport for missing optional debug
entry points. It does not bypass required Vulkan capabilities.

## Android device/driver decisions

| Mechanism | Evidence and devices | Candidate coverage / next gate |
| --- | --- | --- |
| Optional debug-utils loader rejection | MotoG85/Android16/code121 (#301), TabA9+ SM-X218U/Android16/code119 (new #216 case), RedmiNote11 2201117TG/code119 (#303) | Source-backed loader correction, local control/candidate regression. Affected-driver startup remains untested. The older Tab A report is separate. |
| Capability rejection | MotoG54, PowerVR BXM-8-256, driver `1.15@6133110 1.473.1398`, code121 (#304) | Not fixed. Exact symbols and exit/session correlation establish adapter rejection followed by fatal initialization, not RAM exhaustion. |
| Geometry despite corrected merging | HONOR YLE-W09 / Adreno829 / `512.842.36`, SM-S948B / Adreno840 / `512.842.19` (#166), Fold (#102), SM-S928B/DS Normal (#104), all negative on121 | Do not claim a driver-wide cause. Actual-game draw/shader output still needs reproduction. Depth lab stays separate. |
| Uniform capacity abort | #137, exact code119 symbols, comparison mode disables merging | Safe batch ownership/flush refactor remains needed; no Normal-mode crash has been established. Never flush blindly inside buffer resize while an offscreen pass is suspended. |
| Sustained CPU-side slowdown | HelioG85 #198; ambiguous PocoX3/Redmi9 model #275 with confirmed Retro/CoconutMall scene | No proven hot-function fix or FPS claim. Existing workers and empty shader queues do not support a generic multithreading/prewarm solution. |

For PowerVR, [upstream Dawn's opt-in relaxation](https://dawn.googlesource.com/dawn/+/99807f37d56c1dfe375807f108fe435d7ea303b5/src/dawn/native/vulkan/PhysicalDeviceVk.cpp)
is a lead, not a drop-in fix. It permits 14 inter-stage variables for a known
ImgTec limit case, but the adapter/device/default-limit path must agree with
that allowance. This reporter's numeric Vulkan component limits were not logged;
64 components is the upstream scenario, not a measured value from this phone.
Audit every shader interface and device request, prove pipeline creation, and
make unsupported startup return a clear error independently of supporting the GPU.

The [compatibility matrix](../../COMPATIBILITY-MATRIX.md) now records exact known
device/build/driver combinations, code121 negative results, the PowerVR failure,
A10X build51 findings and the presentation-only #199 update. Model names alone
must not select a workaround. There is no universal Android acceptance result.

## Apple issues and release boundaries

- #302 is the demonstrated self-build input defect fixed here; it is not a Mac
  GPU failure. The payload/profile fix applies to all platform self-builds.
- #127's split-screen interpolation correction already shipped. The reported
  M5 MacBook Air two-player scene still lacks acceptance; do not count that
  correction as newly implemented in this pass.
- #194's clearer mismatched-pack message is existing source. Automatic Mac pack
  updates remain separate work. A new translated Code.pul requires a new binary.
- #135's A10X startup fix is accepted. Build51 reports 40–45 FPS/dips35 on Original
  Luigi Circuit and 25–30 at course selection, warm queues empty, two memory
  warnings and a thermal rise. This is not a controlled before/after benchmark
  and does not identify a dominant expensive function.
- #196 remains reopened/unresolved on iPhone17ProMax/iOS27. Anonymous memory
  backing did not establish a fix for its separate missing-target crash.
- #199's phone/TV black image with continuing audio/input is presentation work;
  #100 external-display lifecycle and #101 stretched layout also remain open.
- No minimum-OS lowering is included for #300. No gameplay/online acceptance or
  store/release signing is inferred from an unsigned physical-SDK build.

## Source migration and newly checked upstream gaps

Maintained source is real: translator under `vendor/wiicompiled`, platform runtime
forks pinned by gitlinks. However the migration preserved upstream base
`1912292c804ff9b1b79938de89369ec4496f9fff`; it did not import later upstream changes.
The live [upstream head](https://github.com/patchzyy/Wiicompiled/commit/83463764b8acda394e058b0c689a10b8561fc380)
is 114 commits beyond that baseline. This is an ancestry count, not 114 absent
fixes: several relevant changes are already adapted in maintained source.

- Timer correction `c2289e4` is already in this candidate's four runtime pins.
- Depth change `452b478` is adapted only in the preserved depth lab; it is not
  included here, despite passing the earlier synthetic depth tests.
- Kamek skip-return correction `25c69ae` is present in the maintained translator.
  The later [scoping follow-up `8e0cc968`](https://github.com/patchzyy/Wiicompiled/commit/8e0cc9689887)
  is not: current source adds every Kamek branch-link hook to LR-continuation
  analysis, while upstream gates genuine skip-return hooks and traverses tails.
  Review this in a separate translator change, run its positive/negative tests,
  then compare real old/new graphs and Item Rain. No supplied reporter crash is
  attributed to this difference yet, and it is not silently bundled here.
- Upstream macOS stack correction `a67069a` expands its HostContext stack from
  64KiB to 1MiB. KartPad's Apple path uses a different ucontext implementation
  with 256KiB stacks. The Windows branch's 64KiB constant does not describe the
  Mac path. Stack pressure is a review target, not proof of a KartPad crash or
  justification for an unmeasured allocation increase on every platform.
- Recent upstream exit-prompt input changes use a different settings/input
  architecture; review behavior against KartPad's native overlays before porting.

`UPSTREAM_UPDATES.md` no longer tells maintainers to replay the retired runtime
patch stack. Its payload update procedure now covers exact graph counts as well
as signatures and pins.

## Local builds and verification

- Android code125: complete non-debuggable/profileable Release build and APK
  audit passed; signature verified. It uses the local Android Debug certificate,
  **not** the Community Release identity. No compatible in-place installation is
  implied. Packaged source revision is `815d44d` (clean at build capture); the later
  `d3e733b` changes only the builder's measured function-count expectation.
- macOS: dual-product native build, ad-hoc package signature and package audit
  passed, version 0.4.25-stabilization.3/build52. A separate portable native-runtime
  smoke run selected Original, initialized Metal, submitted over 3,000 frames and
  produced non-silent audio. Its queues finished prewarming. This was an intro
  startup run on the host M3 Max, not a race/FPS comparison. The app-control tool
  could not select the unbundled process, so there is no visual gameplay claim.
- iOS: unsigned physical-SDK arm64 build52 completed. Final package audit,
  UUID-matched symbols and IPA integrity are recorded below. No device
  installation occurred. Its embedded provenance records `d3e733b` with local
  tracked/documentation changes (`source_dirty=true`); exact prepared-runtime
  and translation hashes are retained. It is not advertised as a clean release
  checkout. Build52 is selected explicitly by Xcode build settings.
- Maintained-source verification passes for all three prepared runtime trees.
  The reviewed Dawn library hash matches the prototype; 15 controlled loader
  cases pass for each control/backport. Four renderer-boundary tests and the
  shared timer reentry test pass. Builder27, translator LR-relative36,
  maintenance65, matrix2 and generated-link1 tests pass.

The initial Mac wrapper ended with a shell-command error after native linking
because its script changed while that shell was executing. Packaging was rerun
as a separate leg with absolute paths and explicit version/build expectations;
its audit passed. The first incremental iOS build52 retry lacked the generated
symlink restored/removed by the earlier script; the correctly scoped private
link was re-established before retrying. These setup failures are retained in
local logs, not represented as successful whole-script runs.

All raw build logs, source comparison JSON, loader results and matching symbols
remain under ignored local `work/release-review-20260919` and
`build/stabilization-20260919`. Android and iOS use the same translation tree
fingerprint `85a15dc3353a8c27d6fcdd245ee498c9704783edec89a17b1f088c87d467c4e9`.
The candidate is not a freshly regenerated base translation: verified existing
mod-aware base output was copied privately; both mod legs and new shards were
regenerated and checked. The installed full-pack/online gate remains open.

## Candidate artifact identities

Artifacts are retained in the stabilization worktree under
`build/stabilization-20260919/artifacts/`.

| Artifact | Identity |
| --- | --- |
| Android `KartPad-0.4.25-stabilization.3-code125-local-debug-signer.apk` | SHA-256 `8dea36d534845f78df9861ec4841c3903c770aef796ee985c19cc26b2e560068`; native BuildID `ad6a74cd5ccb53fe95c891eed6b8cca793fa0d43` |
| Mac `KartPad-macOS-0.4.25-stabilization.3-build52-local.zip` | SHA-256 `5553ebe080838b29ffba7e1d38e21bdef87267de0efd7d3f7251c7ee6a5e5fde`; audited app content hash `9144ba74e346016145cb7ea5b7abaff3960967d486427b11e70e8de66e5b90d3` |
| iOS `KartPad-iOS-0.4.25-stabilization.3-build52-unsigned.ipa` | SHA-256 `4d7aa3ae138ca6b931b454ec7f684a22856c5ebfe49e11d30810c754241cf4fb`; binary/dSYM UUID `04297CA9-A1DF-3A4B-A297-D3D449CC0F3A` |

Android signer SHA-256 is
`61dfb51411efe50b2e7fb8d280fcfbba766792c275d1024013940760caa3afaf`.
It matches the earlier local prototype identity, not the public Community
Release identity. No uninstall/data-clear workaround is authorized or needed.

Code123 hash remains
`a18cb466f9a990b3cde83d1c0f65fe9e4907da33beb5d54b0ec24d3308b5a1de`;
code124 hash remains
`3a3afc7b8e72c34ed53d88f336e37e94cbe5f46101b235284b263b8be1e89334`.
The primary checkout's previous verified payload cache also retains its old hash.

## Preservation and integration

Work uses the existing stabilization worktree on
`codex/cross-platform-stabilization-20260919`, based on phone candidate `13a3e67`.
Original code123 and depth-lab code124 APKs, their source branches, matching
symbols and recovery bundles remain untouched. The dirty primary checkout was
not reset or used for native source edits. Reviewed documentation is reconciled
back to that checkout; candidate code stays on the named integration branch.
Do not merge away the experimental branch or publish these local binaries as a
broad fix without the stated owner/device gates.


## Owner phone deployment update

The owner-authorized in-place updates are now installed on iPhone 14 (build52)
and Pixel 9 Pro XL (code125). See the [deployment evidence](owner-phone-deployment.md)
for signing, preservation and launcher checks. Race stability, rendering and
performance acceptance remain open.
