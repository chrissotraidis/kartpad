# KartPad native Android implementation plan

## Status and decision

- **Assessment updated:** 3 September 2026.
- **Assessment type:** repository review plus A0 source-only implementation and
  ARM64 emulator execution.
- **Runtime proof:** the local non-playable A0 APK builds, audits, installs, and
  runs its SDL/JNI/Dawn-Vulkan adapter fixture on the pinned API 36 / 4 KiB and
  Android 15 / 16 KiB ARM64 AVDs.
- **Decision:** A0 passes on the authorized second Apple Silicon host. Proceed
  to A1 native primitives and deterministic Vulkan presentation before
  user-interface or private full-game work.

KartPad can be ported to Android without changing its defining architecture.
The Android build should contain the same ahead-of-time translated Original
Mario Kart Wii and Retro Rewind profiles as the Apple `KartPadDual` product,
linked into one native `arm64-v8a` library. A small Android application owns
the window, lifecycle, storage pickers, downloads, settings, touch controls,
motion input, and diagnostics. Aurora and Dawn remain the renderer; SDL remains
the audio, controller, and application-entry layer.

This is not an Android frontend for Dolphin, a streamed version of the Apple
app, or a runtime PowerPC compiler. It is a native Android host for the existing
KartPad static-recompilation runtime.

The older SunPad Android feasibility study in the maintainer's local reference
checkout is useful background, but it describes SunPad's ModernGekko
architecture and is not part of KartPad's public tracked tree. It is not
KartPad's implementation plan. In particular, KartPad should use its existing
Aurora/Dawn renderer and dual-profile WiiCompiled graph rather than adopting
SunPad's module or GLES-first design.

## First supported Android scope

The first serious Android preview should have this deliberately narrow scope:

- 64-bit ARM Android devices only (`arm64-v8a`).
- Android 9 / API 28 minimum initially, subject to the first physical-device
  results and the pinned Dawn package's API 28 build baseline.
- Compile and target SDK 36 for the intended 2026 distribution environment.
- Original Mario Kart Wii and Retro Rewind 6.12.5 in the same APK, matching
  KartPad 0.4.0's current dual-profile graph.
- Offline play first; Retro WFC is an independent acceptance gate.
- User-provided PAL `RMCP01` revision-0 `.iso` or `.wbfs`, plus the existing
  extracted-folder fallback.
- The official, pinned Retro Rewind full pack downloaded and verified by the
  app. It is not bundled.
- Touch, ordinary Android/SDL controllers, and optional motion steering.
- Phone and tablet layouts matching the iPhone and iPad experience as closely
  as the platform permits.
- A locally signed/sideloaded preview before any store-release work.

The following are not first-preview requirements:

- x86 or x86-64 Android devices;
- Android TV, ChromeOS, foldable-specific layouts, or desktop windowing;
- direct Wii Remote pairing;
- production Retro WFC compatibility;
- Google Play publication;
- byte-identical game-renderer output between Metal and Vulkan;
- imitating Android system pickers or permission screens with custom UI.

Those exclusions constrain the first proof; they do not silently remove
current iOS functionality from the longer-term parity target.

## Architecture

```text
KartPadActivity : SDLActivity
|
+-- SDL SurfaceView
|   `-- Aurora -> Dawn -> Vulkan
|
+-- KartPadOverlayView
|   +-- gameplay touch controls
|   +-- mode chooser
|   +-- menus and settings
|   `-- import/install/status layers
|
+-- Android services
|   +-- Storage Access Framework import
|   +-- Retro Rewind download/install
|   +-- sensors and haptics
|   `-- diagnostics share intent
|
`-- JNI / stable mobile-host C ABI
    `-- libmain.so (arm64-v8a)
        +-- Original profile
        +-- Retro Rewind profile
        +-- WiiCompiled runtime and HLE
        +-- Android guest memory and fibers
        +-- SDL audio and controllers
        +-- Android TLS and BSD sockets
        `-- Aurora / Dawn Vulkan
```

The current
[`wiicompiled-dual-product-target.patch`](../patches/wiicompiled-dual-product-target.patch)
already establishes the correct product model. Android should extend it with a
shared-library product branch; it should not make Original and Retro Rewind
separate applications or downloadable code modules.

### Android application shell

Use a small Kotlin application built around SDL's existing `SDLActivity` and
`SDLSurface`. The activity can add a transparent project-owned `View` above the
game surface in SDL's `RelativeLayout`. This keeps SDL's mature JNI entry,
lifecycle, controller, and audio integration while allowing KartPad to own
every visible application screen.

Do not introduce a second engine framework or an elaborate Android navigation
stack. The shell needs only:

- `KartPadActivity`, derived from `SDLActivity`;
- `KartPadOverlayView`, a deterministic Canvas-based overlay;
- a small state coordinator for setup, menus, and native-runtime readiness;
- Storage Access Framework launchers;
- a foreground-capable Retro Rewind installation worker/service;
- sensor, haptic, and share adapters; and
- a narrow JNI bridge to the shared mobile runtime.

The SDL native thread may wait on a condition variable while the Android UI
performs first-run selection, import, or Retro Rewind installation. UI work
must always be posted to the Android main thread; the main thread must never
block waiting for native startup.

### Native product and build system

The Android build should produce `libmain.so` with all translated and runtime
object libraries compiled as position-independent code. It must export the
entry/JNI symbols expected by SDL and the KartPad shell while hiding unrelated
symbols.

Required changes include:

1. Replace the current Apple-only CMake platform gate with explicit
   Apple/Android ARM64 branches.
2. Treat Android as a mobile SDL target so `SDL_main` is available; the current
   non-iOS `SDL_MAIN_HANDLED` condition is too broad.
3. Remove Apple framework links and `-mcpu=apple-m2` from Android targets.
4. Select Android memory, fiber, path, TLS, and host sources rather than Apple
   or Windows implementations.
5. Link Android system libraries by logical name (`android`, `log`, `dl`) and
   resolve Vulkan through the NDK/Dawn package.
6. Keep the release graph and generated private sources outside the public
   repository and package audit boundary.

The exact pinned Dawn release already provides
`dawn-android-aarch64.tar.gz`. Its exported CMake target contains an absolute
Linux CI path to NDK 29's API-28 `liblog.so`; the preparation step must reject
or rewrite that path to the local Android `log` library. The Android artifact,
URL, size, and SHA-256 should then be added to `dependencies.lock.json` and
verified before configuration, following the Apple package pattern.

### Guest memory and scheduler

The highest-risk native work is below the user interface.

KartPad currently reserves a 4 GiB guest address space and creates aliased
views. Android should use a dynamic native base and a shareable file descriptor
backed by `ASharedMemory_create`, `memfd_create` when available, or a private
app-cache file as a controlled fallback. The implementation must:

- reserve without assuming a fixed high virtual address;
- preserve alias and protection behavior;
- use the runtime page size rather than assuming 4 KiB;
- pass on both 4 KiB and 16 KiB Android environments;
- never map executable translated code from app-writable storage; and
- retain the existing checked-memory fixtures before attempting gameplay.

The Apple AArch64 fiber switch already saves the important callee-saved general
and SIMD registers. Generalize that logic for Mach-O and ELF symbol/ABI rules
rather than maintaining an unrelated Android scheduler. First prove
start/yield/sleep/wake/join/cancel and register preservation in an Android
native fixture, then integrate the translated runtime.

### Rendering and presentation

Use Aurora and Dawn Vulkan. Aurora already contains an Android native-window
surface source based on SDL's Android window property, plus Android surface
readiness and lifecycle hooks. The first renderer proof should therefore be:

1. create the SDL Android surface;
2. create Dawn's Vulkan device and swap chain;
3. clear and present a deterministic color;
4. survive surface destruction/recreation and rotation;
5. present the existing translated renderer fixture; and
6. only then boot the complete game.

Run emulator renderer tests with both the automatic/host backend and a software
Vulkan backend. Agreement between them is useful for diagnosing host-emulator
translation errors. Neither result establishes physical Vulkan driver
correctness or performance.

### Audio

The current runtime opens an SDL3 audio stream, so Android should begin with
SDL rather than a new Oboe backend. Validate:

- correct sample format and channel mapping;
- stable music, voices, and effects;
- pause/resume and focus loss;
- wired, USB, Bluetooth, and built-in output changes;
- latency and underruns during a full cup; and
- no progressive desynchronization in a long session.

Emulator audio is appropriate for functional tests, not latency or route-change
acceptance.

### Input and motion

Preserve the existing normalized Classic Controller state and mixing rules.
Android touch, SDL controllers, and sensors should all feed the same shared
mobile input structure used by the Wii input adapter.

- Use SDL gamepad IDs for stable one-to-four-player controller assignment.
- Clear held input on pause, surface loss, modal presentation, disconnect, and
  profile changes.
- Keep the existing rule that a real controller can hide touch controls.
- Preserve the current larger-magnitude stick, maximum-trigger, button-OR, and
  rising-edge behavior.
- Implement motion steering with Android's rotation-vector/gravity sensors but
  reuse the current dead zone, sensitivity, inversion, and recenter curve.
- Treat emulated sensor input as a functional test only; handling feel requires
  a phone or tablet.

### Storage, resources, and saves

Use Android's Storage Access Framework rather than broad filesystem access:

- `ACTION_OPEN_DOCUMENT` for `.iso` and `.wbfs`;
- `ACTION_OPEN_DOCUMENT_TREE` for an extracted-folder fallback;
- stream the selected URI into app-private, same-volume staging;
- validate `RMCP01` revision 0 and required contents;
- atomically activate `GameData`; and
- preserve NAND, saves, settings, and diagnostics during imports and updates.

Content URIs are not filesystem paths and may be slow or revocable. Native
DiscIO should consume the private staged copy, not hold a provider URI open for
gameplay.

APK assets are also not ordinary adjacent files. Copy the Wii bootstrap, DSP
coefficient data, and initial pipeline cache into a versioned app-private
resource directory before native startup. A failed or interrupted extraction
must leave the previous complete resource set usable.

Suggested storage layout:

```text
files/KartPad/
  GameData/
  RetroRewind/RetroRewind6/
  User/NAND/
  Saves/
  Resources/<resource-version>/
  Diagnostics/

cache/KartPad/
  Imports/
  RetroRewindDownloads/
  RetroRewindStaging/
```

Only reconstructible downloads and incomplete staging belong in cache. Saves
must remain in app-private durable files and need an explicit export/backup
workflow before a preview can claim update safety.

### Networking and TLS

The existing BSD socket paths are a strong starting point. The native TLS
implementation is not: unsupported platforms currently fail rather than
providing a backend. Add a pinned native TLS implementation behind the existing
nonblocking session interface. A small mbedTLS integration is preferable to
routing synchronous guest calls through Java networking.

Android HTTPS used by the application shell for the version manifest and pack
download is separate from guest networking. Both layers must enforce HTTPS,
certificate validation, bounded redirects, timeouts, and cancellation.

Online acceptance proceeds in this order:

1. native DNS/TCP/TLS loopback fixtures;
2. host-Mac local server through the emulator's `10.0.2.2` alias;
3. one Android emulator client against the isolated local WFC environment;
4. macOS-to-Android-emulator local races;
5. one physical Android client on LAN;
6. Wi-Fi loss, cellular transition, reconnect, race, and results; and
7. production Retro WFC only when the service is available and testing is
   permitted.

Offline Retro Rewind completion must never be reported as online completion.

## Retro Rewind contract

The Android implementation must preserve the current iOS security and version
contract, not merely reproduce the happy-path download.

The selected profile currently pins:

- version `6.12.5`;
- official archive size `1,859,041,899` bytes;
- archive SHA-256
  `d8f7c61636ef76f8a451f4071ec5bbdcfea9d5f2500cfc6c245431f04580f9d9`;
- maximum expanded size `2,200,000,000` bytes; and
- exact `Code.pul`, Riivolution XML, and payload sizes/hashes.

The app binary contains the translated Retro Rewind profile. It downloads only
the official non-executable pack. If a new Retro Rewind release changes the
code/profile, KartPad needs a new translated application build just as it does
on iOS.

Extract the archive validation and atomic-install rules from
[`apple/ios/KartPadRetroRewindInstaller.mm`](../apple/ios/KartPadRetroRewindInstaller.mm)
into portable C++ where practical. Thin Apple and Android wrappers should own
only platform downloads, paths, progress, and UI. Shared logic should enforce:

- archive byte count and SHA-256;
- no absolute paths, backslashes, NULs, `.`/`..`, drive prefixes, or symlinks;
- no encrypted or duplicate entries;
- bounded entry count and total expansion;
- extraction of only the expected `RetroRewind6` root;
- exact version, `Code.pul`, XML, and payload validation;
- same-volume staging and atomic activation;
- retention of the previous complete installation until success; and
- cleanup/recovery after cancellation, process death, or storage exhaustion.

The 1.86 GB archive makes Android lifecycle behavior important. The public
quality implementation should use an app-scoped foreground-capable worker or
service with visible progress and cancellation, so rotating the device or
recreating the activity does not restart the transfer. The game must not launch
while installation is incomplete.

Run a free-space preflight. A first setup may temporarily require approximately
6.5 GiB for the app, original game data, archive, and expanded staging tree. An
update that retains the old pack for rollback may peak around 8--9 GiB. Measure
the real values before turning those estimates into user-facing requirements.

When the official version check reports a version newer than the compiled
profile, block online-capable launch and explain that a new KartPad build is
required. When the version service is unavailable but the installed pack is
fully valid, preserve the current iOS option to launch the installed version.

## Visual and behavioral parity

### Definition

"Pixel parity" means that KartPad-owned UI renders the same geometry, colors,
labels, control state, and safe-area-relative placement at an agreed logical
viewport. It does not mean that Android's document picker, permission UI, font
rasterizer, or Vulkan gameplay pixels will be byte-identical to their iOS and
Metal equivalents.

The gameplay overlay is a good candidate for near-exact parity because
[`SunPadGameOverlay.mm`](../apple/third_party/sunpad/SunPadGameOverlay.mm)
already defines normalized positions, colors, sizes, opacity, edit behavior,
and accessibility labels.

Use one small, checked-in declarative control specification as the source of
truth. Generate platform constants at build time rather than making both apps
parse a mutable runtime JSON file. Initially, generated iOS constants must be
verified against the existing implementation without visually rewiring it.

The Android gameplay overlay should be one custom Canvas view rather than a
large hierarchy of buttons. It must implement:

- deterministic draw order and anti-aliasing choices;
- stable pointer-ID-to-control ownership for true multitouch;
- sticks, A/B/X/Y/Z/Start/L/R, and the grouped D-pad;
- per-control editing, Hide/Show, and reset;
- global opacity and size;
- controller hide/restore behavior;
- modern C-stick horizontal behavior;
- the one-second A-button lock, locked color, and haptic feedback;
- the current untouched-iPhone compact defaults, existing-layout preservation,
  grouped D-pad editing, and the editor's direct **Back** path;
- pass-through outside active control regions; and
- virtual accessibility nodes for each control.

The first-launch mode chooser, three-dot menu, settings, game-data management,
Mii management, multiplayer information, and diagnostics should use the same
project-owned colors and vector assets. If exact text metrics are required,
bundle a redistributable common font on both platforms. Do not depend on Apple
system symbols or San Francisco being available on Android.

### Visual tests

Maintain two classes of screenshot test:

1. **Overlay-only golden images:** render the control view over a fixed
   transparent or solid surface at canonical phone and tablet sizes. Compare
   geometry and project-owned pixels exactly or with a very narrow raster
   tolerance.
2. **Composited application images:** render setup, menus, and gameplay frames.
   Compare with a perceptual threshold because platform fonts and Metal/Vulkan
   output can differ legitimately.

Also test hit regions and accessibility separately. A matching screenshot does
not prove that two simultaneous fingers, edge touches, or button locking work.

## What the Android Emulator can prove

Android calls this an **emulator**, not a Simulator. On an Apple Silicon Mac,
an ARM64 AVD can use Hypervisor.framework and execute ARM64 guest code without
cross-architecture CPU translation. This makes it substantially more useful
for KartPad than an x86 Android image would be.

The emulator is appropriate for:

- Gradle, manifest, JNI, shared-library loading, and symbol failures;
- Android ARM64 memory and fiber fixtures;
- 4 KiB and dedicated 16 KiB page-size tests;
- SDL activity/surface creation and lifecycle sequencing;
- first frame and basic Dawn/Vulkan correctness;
- application-owned phone/tablet UI and screenshot tests;
- touch hit regions and scripted multi-pointer input;
- rotation, insets, font scaling, dark mode, and activity recreation;
- document-provider imports and interrupted staging;
- Retro Rewind manifest, large-download, hashing, extraction, rollback, and
  process-death recovery using non-private fixtures;
- settings, save-directory, diagnostics, and upgrade-preservation fixtures;
- DNS/TCP/TLS tests and local-server routing through `10.0.2.2`;
- controlled network delay/loss experiments; and
- base/Retro profile-selection tests when the private generated graph and
  user-owned data are available on the build Mac.

The emulator cannot acceptably prove:

- real Adreno, Mali, or other vendor Vulkan-driver behavior;
- sustained frame pacing, thermal throttling, battery use, or memory pressure;
- audio latency, Bluetooth/USB routing, or long-session synchronization;
- touch latency, palm/edge behavior, haptic feel, or comfortable control
  placement;
- controller Bluetooth/USB latency and disconnect behavior across vendors;
- real rotation-vector steering quality;
- Wi-Fi-to-cellular transitions, OEM background restrictions, or process
  killing;
- storage-provider behavior across Samsung, Google, cloud, and removable
  providers;
- production network/NAT behavior; or
- public-release readiness.

Vulkan on the macOS Android Emulator may itself run through a host translation
or software layer. A renderer defect seen only in one emulator backend should
be investigated; a renderer success there must still be repeated on hardware.

### Recommended AVD set

Keep the emulator matrix small and purposeful:

| AVD | Purpose |
| --- | --- |
| ARM64 phone, API 34, 4 KiB | Existing fast development AVD and lower-version compatibility |
| ARM64 phone, API 36, 4 KiB | Target-SDK behavior, current phone UI, Vulkan and lifecycle |
| ARM64 tablet, API 36, 4 KiB | iPad-equivalent layout, safe areas, touch editor, large screen |
| ARM64 Android 15+ experimental 16 KiB image | Native library, guest memory, alignment, and resource tests |

Run one AVD at a time during full-game work. Use a cold-boot/no-snapshot lane in
automation so stale hidden state cannot turn a broken initialization path green.
Launch the emulator in its own window for manual multitouch; embedded emulator
windows have documented multitouch limitations.

## Authorized clean-machine bootstrap

The implementation machine's starting inventory is intentionally treated as
unknown. The Android agent is authorized to download and install the Android
and Java build tools required for this port, including the SDK command-line
tools, pinned JDK, SDK platforms, Build Tools, NDK, CMake/Ninja support,
Gradle dependencies, emulator, and the minimum ARM64 system images. It may also
download hash-pinned source or binary dependencies already authorized by this
repository. This authorization does not include game data, saves, credentials,
signing keys, or arbitrary executable game updates.

The first implementation milestone must provide `scripts/check-android-host.sh`
and a documented bootstrap command. Installation is an explicit operation in
the Android goal loop, not a hidden side effect of a normal build. Prefer
Android Studio's configured SDK or a user-local SDK root; do not rewrite global
shell profiles, replace unrelated system toolchains, or assume Homebrew exists.

Pin at least:

- Gradle wrapper and Android Gradle Plugin versions;
- JDK 17 selection;
- compile/target SDK 36;
- Build Tools 36.0.0;
- NDK `29.0.14206865`, matching the pinned Dawn Android package;
- CMake generator expectations; and
- phone, tablet, and 16 KiB ARM64 system-image identities used by automation.

Use `local.properties` only for the machine-local SDK path and keep it ignored.
Build scripts should accept `ANDROID_SDK_ROOT` and discover the NDK through the
SDK, while rejecting an unpinned version for release builds.

Do not install these tools as a side effect of an ordinary build. The dedicated
bootstrap command may install missing pinned components and accept paths through
arguments or environment variables; the validation command remains read-only.
If a download requires new legal terms, an account, a CAPTCHA, payment, or
credentials, stop at that boundary and request the human action once.

## Working on a different Mac

The Android output is not tied to the Mac that compiled it. A correctly built
APK can be installed on compatible Android ARM64 devices regardless of which
Apple Silicon Mac produced it. Development should therefore support two lanes.

### Public/source-only Mac

A clean clone on another Apple Silicon Mac must be able to:

- install the pinned JDK, SDK, NDK, CMake, and emulator images;
- build the Android shell and native fixture library;
- run unit, JNI, lifecycle, UI, 4 KiB, and 16 KiB emulator tests;
- build a non-playable audit APK without private generated sources; and
- verify deterministic dependency and package metadata.

This lane is suitable for contributors and CI. It must not require Nintendo
data, Retro Rewind data, generated translated shards, signing keys, or saves.

### Maintainer/full-game Mac

A full playable build additionally requires:

- the supported user-owned `RMCP01` input or validated extracted data;
- the private generated Original and Retro Rewind graph at the pinned profile;
- the same dependency lock and build configuration; and
- local debug/release signing configuration.

Prefer regenerating the private graph from the pinned inputs on the second Mac.
If it is transferred between maintainer-owned Macs, use a private channel and a
manifest of hashes; never place it in Git, CI artifacts, cloud build logs, or a
public cache. Game data and saves remain outside the application build tree.

Do not share a release keystore through the repository. Debug APKs may use each
Mac's local debug identity. A release candidate should be signed only on the
designated release Mac after the unsigned artifact has passed audit.

To make cross-Mac results comparable, every evidence record should include:

- KartPad commit and dirty-tree state;
- dependency-lock digest;
- generated-graph manifest digest, without publishing its contents;
- macOS/CPU, JDK, Gradle, AGP, SDK, NDK, CMake, Ninja, and emulator versions;
- AVD/device model, Android version, ABI, page size, and Vulkan driver;
- APK SHA-256 and signing-certificate digest; and
- selected Original/Retro profile and test result.

Absolute `/Users/...` paths must never enter generated build metadata or the
APK. Package audits should scan both strings and archive members for them.

## Implementation milestones and gates

Estimates are cumulative for one experienced engineer and are planning ranges,
not promises.

### A0 — Reproducible Android toolchain and source-only shell (week 1--2)

Deliver:

- `android/` Gradle application with pinned wrapper/plugin/toolchain;
- `KartPadActivity : SDLActivity` and an empty transparent overlay;
- `scripts/check-android-host.sh`;
- a source-only JNI fixture APK;
- phone API-36 and Android 15+ 16 KiB AVD definitions/instructions; and
- Android Dawn metadata added to the dependency lock.

Exit only when a clean second Apple Silicon Mac can build, install, launch, and
run the JNI fixture without undocumented local paths.

### A1 — Native runtime primitives and first Vulkan frame (week 2--4)

Deliver:

- Android CMake branch and PIC shared-library link;
- sanitized, hash-verified Dawn Android package;
- 4 KiB and 16 KiB guest-memory fixtures;
- Android AArch64 fiber/scheduler fixtures;
- SDL surface lifecycle and deterministic Vulkan clear/readback/present; and
- APK/native alignment and dependency audit.

Stop and reassess if the existing 4 GiB alias model cannot be made reliable on
both page sizes without executable writable mappings or device-specific hacks.

### A2 — Controller-driven Original game proof (week 4--7)

Deliver:

- full private dual graph linked into `libmain.so`;
- staged RMCP01 data and resource extraction;
- Original profile boot, title/menu navigation, complete race, results, save,
  relaunch, pause/resume, and surface recreation;
- SDL audio and one physical controller; and
- the same run on an emulator and the first physical Android device.

Do not begin pixel-parity work until this gate proves that the native runtime is
viable.

### A3 — Retro Rewind offline proof (week 7--12)

Deliver:

- portable archive validation/install core;
- Android manifest check, resumable/cancellable download, free-space preflight,
  staging, atomic activation, rollback, and recovery;
- exact 6.12.5 profile selection and no accidental Original fallback;
- complete offline Retro Rewind race, results, save, relaunch, and mode switch;
  and
- interruption tests for rotation, process death, network loss, corrupt ZIP,
  hash mismatch, full disk, and an existing valid install.

Pass this gate independently on emulator and physical hardware.

### A4 — Feature-complete mobile shell and touch parity (week 12--18)

Deliver:

- first-launch chooser matching iOS;
- `.iso`, `.wbfs`, and folder import/reimport;
- touch overlay, editor, A lock, haptics, and accessibility;
- one-to-four-player controller handling and touch hiding;
- motion steering;
- FPS, aspect-ratio, render-scale, touch, and controller settings;
- Mii import/manage/remove;
- game-data removal that preserves saves where promised; and
- bounded diagnostics sharing.

Pass golden-image and input hit-map tests on canonical phone and tablet
viewports, then complete touch-only races on a real phone and tablet.

### A5 — Online and device hardening (week 18--28)

Deliver:

- native TLS backend and fixtures;
- isolated local WFC runs on emulator and physical device;
- macOS/Android local cross-client races;
- reconnect, network impairment, and Wi-Fi/cellular transitions;
- Adreno and Mali Vulkan coverage;
- phone and tablet controller/audio/storage matrices;
- long-session memory, thermal, audio, and frame-pacing evidence; and
- upgrade-in-place and save export/restore rehearsal.

Production Retro WFC remains open until service availability and policy allow a
narrow real-service test.

### A6 — Sideloaded preview and possible store work (week 24--32)

Deliver:

- deterministic unsigned APK/AAB packaging where the toolchain permits;
- signed maintainer candidate with SHA-256 and signing-certificate record;
- package audit proving no game data, Retro Rewind pack, translated sources,
  saves, logs, local paths, or signing material leaked;
- 16 KiB ZIP/ELF alignment validation;
- install/update/rollback testing against the prior candidate; and
- a platform-specific rights and distribution decision.

A successful package audit is not by itself permission to publish a binary
containing translated retail logic.

## Emulator and physical acceptance matrix

| Capability | Host tests | ARM64 emulator | Physical Android |
| --- | :---: | :---: | :---: |
| Gradle/JNI/package loading | Secondary | Primary | Confirmation |
| AArch64 fibers and guest-memory fixtures | Secondary | Primary | Required |
| 4 KiB behavior | No | Required | Required on one device |
| 16 KiB behavior and alignment | Static | Required | Required before release |
| Vulkan first frame | No | Useful | Required |
| Correct complete gameplay | No | Useful | Required |
| Pixel/layout regression | Golden | Primary | Visual confirmation |
| Real multitouch and haptics | Scripted | Partial | Required |
| Controller mapping/reconnect | Unit | Partial | Required |
| Motion steering feel | Unit | Synthetic | Required |
| Audio correctness | Unit | Functional | Required |
| Audio latency/routes | No | No | Required |
| Retro Rewind installer recovery | Unit | Primary | Required |
| Local networking/TLS | Primary | Primary | Required |
| Production online/NAT | No | Incomplete | Required when permitted |
| Frame pacing/thermal/battery | No | Invalid | Required |
| OEM background/storage behavior | No | Invalid | Required |

The first hardware set should include:

1. a recent Pixel capable of 4 KiB/16 KiB testing where supported;
2. a Snapdragon/Adreno phone;
3. a Samsung or other Mali device; and
4. an Android tablet large enough to validate the iPad-style layout.

One device may cover multiple rows. Do not buy or recruit the full matrix before
the A2 physical race gate succeeds.

## Risk register

| Risk | Early detection | Response |
| --- | --- | --- |
| Dawn package has non-relocatable CMake metadata | Configure source-only shell on a clean path/Mac | Sanitize deterministically and pin the sanitized digest or rebuild Dawn from its pinned source |
| 4 GiB aliases fail or assume 4 KiB pages | A1 memory fixture on 4 KiB and 16 KiB AVDs | Fix the abstraction before running the game; do not add per-device address constants |
| Fiber state differs under Android ELF ABI | Million-iteration scheduler/register fixture | Share AArch64 logic with format-specific assembly wrappers |
| Huge dual `libmain.so` exceeds link/load limits | A0/A1 full private PIC link and cold-load timing | Use LLD, hidden symbols, split debug information, and measure before considering structural splits |
| Emulator Vulkan success hides vendor-driver bugs | First Adreno/Mali frame and race in A2/A5 | Keep software/host emulator lanes, but make hardware authoritative |
| Surface recreation causes device loss or stuck input | Rotate/background/lock loops before full boot | Make surface ownership explicit and clear all input on loss |
| Retro Rewind installation exhausts storage or dies mid-swap | Full-disk/process-death fault injection | Preflight space, stage on same volume, retain prior install, recover on launch |
| Android TLS is delayed because app HTTPS works | Native guest TLS fixture before online work | Track app downloads and guest networking as separate workstreams |
| Touch pixels match but behavior differs | Multi-pointer hit-map/replay tests | Share normalized state rules and test interactions independently of screenshots |
| System fonts/icons prevent exact screenshots | Cross-platform golden comparison early in A4 | Use project-owned vector assets and a redistributable bundled font where necessary |
| OEM background or provider behavior loses work | Physical process-kill and provider matrix | Keep durable state app-private; use foreground-capable long work and restartable transactions |
| Emulator performance creates false confidence | Label all emulator timing non-acceptance | Publish performance only from named physical hardware |
| Private inputs leak into APK or build logs | Audit every milestone artifact | Fail closed on known extensions, paths, hashes, translated shards, saves, logs, and signing data |

## Proposed repository layout

This is a target layout, not a requirement to create every file before its
milestone needs it.

```text
android/
  build.gradle.kts
  settings.gradle.kts
  gradlew
  gradle/wrapper/
  app/
    build.gradle.kts
    src/main/AndroidManifest.xml
    src/main/java/.../KartPadActivity.kt
    src/main/java/.../KartPadOverlayView.kt
    src/main/java/.../KartPadRetroRewindWork.kt
    src/main/cpp/CMakeLists.txt
    src/androidTest/

runtime/android/
  guest_flat_memory_android.cpp
  fiber_switch_android.S
  android_paths.cpp
  android_tls.cpp
  mobile_host_android.cpp

scripts/
  check-android-host.sh
  prepare-android-game-runtime.sh
  build-android-game-app.sh
  audit-android-package.sh
  run-android-emulator-tests.sh

tests/android/
  fixtures/
  golden/
```

Favor shared portable code under `runtime/` for input mixing, layout data,
archive validation, settings semantics, and profile selection. Keep Android UI,
JNI, URI, lifecycle, and service code under `android/`.

## Package and release audit

Before any tester receives an artifact, verify at minimum:

- only intended ABIs are present;
- every native `LOAD` segment and uncompressed native library is 16 KiB aligned;
- `zipalign -c -P 16 -v 4` succeeds;
- `libmain.so` has expected dependencies, RELRO, non-executable stack, hidden
  internal symbols, and no absolute build paths;
- expected JNI and SDL entry symbols are exported;
- package ID, version, minimum/target SDK, permissions, and network policy match
  the documented candidate;
- the APK/AAB contains no disc image, WBFS, extracted game data, Retro Rewind
  pack, generated translated source, save, NAND, log, signing key, credentials,
  provisioning data, or developer identifiers;
- licenses and source notices cover SDL, Dawn, Aurora, WiiCompiled, archive,
  cryptography, and other shipped native dependencies; and
- a freshly downloaded hosted artifact is byte-compared or checksum-compared
  with the audited local artifact.

## Immediate next action

Continue with A1. Extend the source-only fixture to create a Dawn Vulkan device,
clear/read back/present a deterministic frame, and survive SDL surface
destruction/recreation, rotation, and background/foreground transitions. Then
add page-size-aware guest-memory and Android ELF AArch64 scheduler/register
fixtures and run them on both pinned AVDs.

The A0 commands and sanitized result are recorded in
[`android/README.md`](../android/README.md) and
[`a0-source-only-fixture.md`](artifacts/2026-09-03/android/a0-source-only-fixture.md).
Do not begin the touch-UI port or private full-game link until A1 passes. The
first valuable user-facing proof after that is a controller-driven
Original-mode race on physical Android hardware; Retro Rewind installation and
touch parity follow from that stable runtime base.

## Platform references

- [Android Emulator acceleration](https://developer.android.com/studio/run/emulator-acceleration)
- [Android Emulator networking](https://developer.android.com/studio/run/emulator-networking-address)
- [Android Emulator known issues](https://developer.android.com/studio/run/emulator-troubleshooting)
- [16 KiB page-size support and emulator testing](https://developer.android.com/guide/practices/page-sizes)
- [Android Java/JDK build configuration](https://developer.android.com/build/jdks)
- [Storage Access Framework](https://developer.android.com/training/data-storage/shared/documents-files)
- [SDL Android integration](https://github.com/libsdl-org/SDL/blob/main/docs/README-android.md)
- [Pinned Dawn release](https://github.com/encounter/dawn-build/releases/tag/v20260603.191052)
