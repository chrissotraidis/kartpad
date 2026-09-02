# KartPad

<p align="center">
  <strong>Mario Kart Wii on Apple Silicon Mac, iPhone, iPad, and Apple TV; Retro Rewind on Mac, iPhone, and iPad.</strong><br>
  Native static recompilation through Metal, with touch controls, motion steering, controllers, and optional Retro Rewind content.
</p>

<p align="center">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple%20Silicon-arm64-0A84FF?logo=apple">
  <img alt="Metal renderer" src="https://img.shields.io/badge/renderer-Metal-5E5CE6">
  <img alt="Ahead-of-time static recompilation" src="https://img.shields.io/badge/PowerPC-static%20recompilation-FF9F0A">
  <img alt="macOS development target" src="https://img.shields.io/badge/macOS%20target-14%2B-0A84FF">
  <img alt="iPhone and iPad physical builds accepted" src="https://img.shields.io/badge/iPhone%20%2F%20iPad-physical%20builds%20accepted-30D158">
  <img alt="Retro Rewind supported" src="https://img.shields.io/badge/Retro%20Rewind-6.12.4-FF375F">
  <img alt="Game data not included" src="https://img.shields.io/badge/game%20data-not%20included-FF453A">
</p>

![KartPad running a race on DK Summit on iPad](docs/images/kartpad-dk-summit-ipad.png)

> [!IMPORTANT]
> **The latest preview includes KartPad's dual-mode Mario Kart Wii and Retro
> Rewind build for iPhone and iPad.** It must be re-signed before installation
> and requires your own legally obtained supported game image. Retro Rewind is
> optional and installs through KartPad from the official version-locked pack.
> Preview 5 makes signed-container imports converge on the working Files picker,
> keeps the macOS cursor visible, and retains Preview 4's experimental Mii
> import/management and macOS-only direct Wii Remote/Nunchuk path.
> The IPA includes ahead-of-time translated game logic but no disc image,
> extracted game assets, Retro Rewind pack, saves, signing identity, or
> provisioning profile. The public Retro WFC service is currently in
> maintenance, so live public online play is temporarily unavailable.

## What is available now?

| Question | Answer |
|---|---|
| Is this Dolphin or streaming? | No. WiiCompiled translates the game's PowerPC code ahead of time, then KartPad compiles it for ARM64 and presents it through Metal. |
| Is an IPA included in the GitHub release? | **Yes.** `v0.3.0-preview.5` includes an audited unsigned ARM64 IPA for iPhone and iPad. Re-sign it locally, then import your own supported game image on first launch. |
| Can the source create an IPA? | Yes. The Personal IPA Builder can also translate a supported user-owned game executable and create a separate private unsigned IPA on an Apple Silicon Mac. |
| Does it include Mario Kart Wii? | No. You must provide your own legally obtained supported PAL `RMCP01` revision 0 WBFS/ISO. |
| Does it support Retro Rewind? | **Yes.** Choose Original Mario Kart Wii or Retro Rewind when KartPad opens. KartPad can download, verify, and install the official Retro Rewind 6.12.4 pack. Physical iPad acceptance covers the complete install, launch, and playable single-player flow. |
| Does online play work? | The online-capable build passes login, matchmaking, a two-player race, results, ratings, and lobby return against a compatible isolated WFC server. As of 1 September 2026, the public Retro WFC service is in maintenance, so live public online play is temporarily unavailable. That external outage does not block Retro Rewind installation or offline play. |
| Do touch, tilt, and controllers work? | Touch, motion steering, and ordinary GameController-compatible pads are implemented, with general physical acceptance on iPhone and iPad. Direct Wii Remote/Nunchuk pairing is a separate experimental, macOS-only path that still needs external hardware testing. |
| Can I use a custom Mii? | **Experimentally.** On Mac, iPhone, or iPad, open **Game Data & Saves → Manage Miis…** and import a standard 74-byte `.mii` file. Restart KartPad, then select it in **License Settings → Change Mii**. KartPad does not yet create Miis. |
| Are Android and Apple TV supported? | Apple TV supports the base game as a local self-build for tvOS 17 or newer. Retro Rewind, online play, and a distributable tvOS artifact are not included. Android is not currently supported. |
| How much storage does it need? | The app is about 80 MiB and extracted Mario Kart Wii data uses about 2.5 GiB. Retro Rewind downloads an additional 1.72 GiB archive and needs temporary installation space. Keeping the WBFS/ISO on the device requires more space. |

## Original Mario Kart Wii or Retro Rewind

KartPad now treats Retro Rewind as a first-class optional game mode rather than
an unrelated setup path. The opening screen offers two choices:

- **Mario Kart Wii** starts the original game with its original tracks,
  characters, saves, local multiplayer, and KartPad controls.
- **Retro Rewind** adds its expanded tracks, characters, features, and Retro
  WFC integration while using the same native KartPad runtime and controls.

KartPad does not bundle either game's private data. After you import your own
supported Mario Kart Wii image, choosing Retro Rewind checks the official
version feed, downloads the matching official full pack, verifies its exact
size and SHA-256 identity, and installs it atomically. The accepted physical
iPad flow completed the full 6.12.4 download, verification, installation,
launch, and a playable single-player match.

Retro Rewind requires matching current content for online compatibility.
KartPad checks the official version before every Retro Rewind launch. If Retro
Rewind advances beyond the ahead-of-time profile included in KartPad, the app
asks for a compatible KartPad update instead of launching an outdated build.
After that KartPad update is installed, selecting Retro Rewind guides the user
through installing the newly matched official pack.

Retro WFC is Retro Rewind's online service. KartPad's online-capable graph
passes login, matchmaking, a complete two-player race, results, ratings, and
lobby return against a compatible isolated WFC service. The public Retro WFC
service is currently in maintenance, so live public online play cannot be used
until that external service returns. Original and Retro Rewind offline play are
not blocked by the outage.

KartPad packages a native Apple ARM64 app around a
[WiiCompiled](https://github.com/patchzyy/Wiicompiled)-generated Mario Kart Wii
module and its Aurora/Dawn compatibility runtime. PowerPC game code runs as
ahead-of-time translated arm64 code, Dawn presents through Metal, and a narrow
Apple host layer supplies audio, input, storage, timing, and lifecycle behavior.

This repository contains KartPad's Apple integration, reproducible patches,
tests, documentation, and original artwork. The source tree does **not** contain
Mario Kart Wii, a disc image, extracted Nintendo assets, generated game code,
saves, or signing material. The separately downloadable 0.3.0 preview IPA
contains the compiled ahead-of-time translation described in
[`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md), but none of the remaining
retail game data.

## Current status

| Area | Current result |
|---|---|
| macOS runtime | Native arm64 title, menus, races, saves, ghosts, Battle, and split-screen gameplay through Metal |
| Track coverage | All 32 retail tracks have exact native completion evidence |
| Correctness | Darwin memory, scheduler, ABI, integer, scalar-FP, and paired-single gates pass against their defined oracles |
| Input | Keyboard, touch, motion steering, and four independent Classic-controller slots; two-player full-race evidence passes. Direct macOS Wii Remote/Nunchuk pairing and its preset are experimental and await reporter hardware acceptance |
| Audio | Non-silent host playback, pause/resume, live output-device migration, and a two-hour representative continuity run pass their instrumented subcases; subjective listening and the eight-hour soak remain open |
| Performance | Warm, simple scenes can report 60 FPS; first-use shader compilation and some tracks can fall far below real time. Stable frame pacing is **not yet accepted** |
| Packaging | The K-circuit iPhone/iPad icon and branded package pass structural audit; installed-storage, configured gameplay, save-preservation, and normal-close evidence applies to the previously accepted app candidate, while the native first-run/settings/data-management shell remains open |
| iPhone/iPad | The full 29,065-function ARM64 retail app has been packaged as an unsigned IPA; locally signed builds have been installed and physically accepted on both iPhone and iPad, reaching live races, importing a supported private WBFS, and preserving saves |
| Game content | Version-locked dual-mode Original Mario Kart Wii / Retro Rewind 6.12.4 flow without bundling either game's private data; physical iPad install, launch, and initial single-player gameplay pass |
| Online multiplayer | Local Mac-to-iPad-Simulator login, matchmaking, room, race, native results, ratings, and lobby return pass; the public Retro WFC service is currently unavailable during maintenance, which does not block the accepted Retro Rewind install and offline-play flow |
| Distribution | `v0.3.0-preview.5` provides source plus a free unsigned community-preview IPA containing translated game logic. It contains no disc image, extracted game assets, Retro Rewind pack, saves, signing identity, or provisioning profile |

The evidence ledger, exact open rows, and known risks live in
[`docs/STATUS.md`](docs/STATUS.md). The 67-row release matrix is in
[`docs/PRD.md`](docs/PRD.md); a successful compile or screenshot is never
treated as gameplay acceptance by itself.

### Performance is active work

KartPad is playable on Apple Silicon, but it is not yet performance-ready.
The bundled initial pipeline cache reduces compilation work without eliminating
it. A cold title sequence has recovered from roughly 44 FPS to 60 FPS while
hundreds of shaders finished compiling; Moonview Highway has fallen to 1.3 FPS
on first use and later recovered only to roughly 46–54 FPS. Audio telemetry has
also recorded bounded drops during heavy compilation.

A matched title-path test makes that cache boundary concrete: from empty cache,
minimum effective FPS was 51.958 with an 83.783 ms maximum p99 and 20 dropped
audio blocks; the immediate warm relaunch held at least 59.963 effective FPS
with a 17.264 ms maximum p99 and zero drops. Track-level cold/warm profiling is
still required.

Those numbers are observations, not promises. The current performance gate is
a controlled cold-cache/warm-cache comparison with frame-time percentiles,
shader-cache accounting, audio-drop accounting, representative races, and a
long soak. Until it passes, expect startup hitches, track-dependent slowdown,
and poorer performance on iPhone than on Mac or iPad-class hardware.

## Game data

KartPad never downloads or bundles Nintendo data. Development uses a locally
owned PAL `RMCP01` revision 0 image that is verified, kept read-only, and
ignored by Git. Extracted files, translations, caches, saves, logs, and private
captures stay in ignored local directories.

On iPhone and iPad, first launch stops before emulation and accepts either the
supported private `RMCP01` WBFS/ISO image or an extracted `DATA` folder.
KartPad opens the image with a narrow native DiscIO importer, verifies the game
identity and revision, extracts the runtime files on-device, validates the
critical DOL, and atomically activates the protected private tree. Interrupted
imports recover or roll back; replacement never silently discards the last
valid copy. Removal is explicit, undoable until relaunch, and occurs before
emulation while preserving saves.

The translated ARM64 graph is compiled and signed on the Mac. The mobile app
imports non-executable game data only; it contains no PowerPC JIT, runtime
compiler, or executable-code download.

| Game ID | Region | Revision | Accepted input |
|---|---|---|---|
| `RMCP01` | PAL / Europe | 0 | One exact pinned WBFS container for the current development profile |

Other regions, revisions, dumps, and container hashes fail closed even when
their filename extension is recognized. The expected digest is recorded in
the build scripts for identification; no disc content is tracked or
distributed.

## Experimental Miis and Wii Remote controls

Preview 5 retains two opt-in features from Preview 4 for community testing. They are deliberately
marked **Experimental** until users with real exported Miis and original Wii
hardware complete the remaining acceptance checks.

### Import and manage Miis

On Mac, iPhone, or iPad, open **Game Data & Saves → Manage Miis…**. KartPad can
list the current Mii database, import a standard 74-byte `.mii` file, and remove
an unwanted entry. Changes are staged safely, the current database is backed
up, and the replacement is applied on the next launch. KartPad will not remove
the final remaining Mii.

KartPad cannot create a Mii because it does not include the Wii Menu or Mii
Channel. Create or export the Mii with a compatible tool, import the `.mii`
file, restart KartPad, and choose it from Mario Kart Wii's **License Settings →
Change Mii** screen. Do not attach a complete NAND, save, or app container to a
public issue.

### Pair a Wii Remote and Nunchuk on macOS

The macOS build has an opt-in **Controls → Experimental Wii Remote + Nunchuk**
path for an original `RVL-CNT-01` or Wii Remote Plus `RVL-CNT-01-TR`. It pairs
directly through the Mac's Bluetooth hardware without a DolphinBar, then hands
the controller to SDL and exposes a **Wii Remote + Nunchuk (Experimental)**
preset in Controller Settings.

This pairing path uses private macOS Bluetooth interfaces and is intended for
direct testing, not the Mac App Store. Actual pairing, Nunchuk input, reconnect,
and long-session behavior still require reporter hardware acceptance. iPhone
and iPad show the experimental control entry for clarity, but iOS/iPadOS do not
provide the required direct Wii Remote HID pairing path.

## Install or build

### Download the unsigned iPhone/iPad IPA

Download `KartPad-v0.3.0-preview.5-unsigned.ipa` and `SHA256SUMS` from the
[latest preview](https://github.com/chrissotraidis/kartpad/releases/tag/v0.3.0-preview.5).
Verify the checksum, re-sign the IPA with AltStore Classic plus AltServer or
another compatible personal-signing workflow, and select your own supported
PAL `RMCP01` revision 0 image on first launch. See
[`docs/INSTALL_IPA.md`](docs/INSTALL_IPA.md) for the complete boundary and
update-preservation guidance.

### Build a personal unsigned IPA

KartPad's public Builder can instead perform static recompilation on the user's
Apple Silicon Mac before signing:

```sh
./scripts/build-user-ipa.sh bootstrap
./scripts/build-user-ipa.sh inspect /path/to/Mario-Kart-Wii.wbfs
./scripts/build-user-ipa.sh build /path/to/Mario-Kart-Wii.wbfs
```

The resulting `artifacts/KartPad-personal-unsigned.ipa` is private and must not
be redistributed because it contains translated code generated from the
user's game executable. Compatibility is profile-driven: additional verified
WBFS/ISO containers can share a profile only when their extracted executables
are identical, while different regions or revisions use separate profiles.
See [`docs/BUILDER.md`](docs/BUILDER.md) for the cache, validation, extension,
and release contracts. Maintainers should also follow
[`docs/UPSTREAM_UPDATES.md`](docs/UPSTREAM_UPDATES.md) when advancing either
WiiCompiled or Retro Rewind.

### Development workflows

You need:

- an Apple Silicon Mac running macOS 14 or newer;
- Xcode and its command-line tools;
- CMake, Ninja, Git, ripgrep, Python 3, the .NET 8 SDK, and Rust/Cargo;
- `nodtool` 2.0.0-alpha.9; and
- your own legally obtained supported Mario Kart Wii `RMCP01` revision 0 image.

Install the pinned extractor if it is not already available:

```sh
cargo install nodtool --version 2.0.0-alpha.9 --locked
```

Verify the pinned public sources and private input boundary:

```sh
./scripts/verify-sources.sh
./scripts/check-repo-safety.sh
```

Run the portable correctness gates:

```sh
./scripts/test-host-portability.sh
./scripts/test-guest-memory.sh
./scripts/test-guest-scheduler.sh
./scripts/test-ppc-semantics.sh
```

Build from the pinned supported image in one fail-closed local workflow:

```sh
./scripts/self-build-macos.sh /path/to/your/Mario-Kart-Wii.wbfs
```

The workflow verifies the complete supported image hash, extracts it read-only
with pinned `nodtool`, validates `RMCP01` revision 0 plus the DOL/REL hashes,
translates the full private title graph with bounded parallelism, builds the
patched Apple runtime, and audits the signed local app. All extracted and
translated outputs stay under ignored `private/`; the app stays under ignored
`build/`. Existing valid extraction/translation work can be resumed.

The initial translation and native build are substantial. The workflow reuses
validated extraction and translation outputs after an interruption. It does
not yet clone every pinned reference automatically; the source references
checked by `verify-sources.sh` must already be present and clean.

Launch the audited local app:

```sh
open build/KartPad-self-built.app
```

The resulting app is a local development build. It is ignored by Git, may
contain a locally generated executable game module, and must not be
distributed.

To build from an already produced ignored translation graph, run the lower
level steps directly:

```sh
./scripts/prepare-g7-game-runtime.sh
./scripts/package-macos-runtime.sh \
  "$PWD/build/g7-game-runtime-build" \
  "$PWD/build/KartPad.app"
./scripts/audit-macos-package.sh "$PWD/build/KartPad.app"
```

Prepare and build the complete iOS Simulator runtime from the same private
translation graph:

```sh
./scripts/build-ios-discio-probe.sh \
  ref/upstream/dolphin \
  build/dolphin-ios-discio-iphonesimulator-source \
  build/dolphin-ios-discio-iphonesimulator-build \
  iphonesimulator
./scripts/prepare-ios-game-runtime.sh \
  private/g8-full-translation \
  build/ios-game-runtime-source \
  build/ios-game-runtime-build
./scripts/build-ios-game-app.sh \
  build/ios-game-runtime-source \
  build/ios-game-app-xcode \
  private/g8-full-translation
```

Prepare the corresponding unsigned physical-device package without signing or
installing it:

```sh
./scripts/build-ios-discio-probe.sh \
  ref/upstream/dolphin \
  build/dolphin-ios-discio-iphoneos-source \
  build/dolphin-ios-discio-iphoneos-build \
  iphoneos
./scripts/build-ios-device-game-app.sh \
  build/ios-game-runtime-source \
  build/ios-device-game-app-xcode \
  private/g8-full-translation
```

The build scripts verify the exact SunPad source snapshot and dependency pins,
compile only ARM64 code, and fail if private game data, saves, signing material,
or non-system dynamic dependencies enter the app bundle. Installation and
signing remain local development steps; this repository does not publish a
playable app artifact.

### Apple TV base-game self-build

The tvOS target is intentionally base-game only. It uses the existing private
RMCP01 translation and extracted `GameData`; neither is copied into the signed
app. Build the pinned Dawn archive for the target you need:

```sh
mkdir -p build/dependency-cache

./scripts/build-dawn-tvos.sh \
  appletvsimulator \
  /tmp/kartpad-dawn-tvos-simulator \
  /tmp/dawn-tvos-simulator-arm64-v20260603.191052.tar.gz
install -m 0644 \
  /tmp/dawn-tvos-simulator-arm64-v20260603.191052.tar.gz \
  build/dependency-cache/dawn-tvos-simulator-arm64-v20260603.191052.tar.gz

./scripts/build-dawn-tvos.sh \
  appletvos \
  /tmp/kartpad-dawn-tvos-device \
  /tmp/dawn-tvos-arm64-v20260603.191052.tar.gz
install -m 0644 \
  /tmp/dawn-tvos-arm64-v20260603.191052.tar.gz \
  build/dependency-cache/dawn-tvos-arm64-v20260603.191052.tar.gz
```

Build, install, stage, and launch the Simulator app:

```sh
TVOS_SIMULATOR_ID="<simulator-udid>"

./scripts/prepare-ios-game-runtime.sh \
  private/self-build/translation \
  /tmp/kartpad-tvos-simulator-source \
  /tmp/kartpad-tvos-simulator-build \
  base appletvsimulator
xcrun simctl install "${TVOS_SIMULATOR_ID}" \
  /tmp/kartpad-tvos-simulator-build/KartPadTV.app
./scripts/stage-tvos-game-data.sh \
  "${TVOS_SIMULATOR_ID}" \
  "$PWD/private/self-build/disc"
./scripts/audit-tvos-app.sh \
  /tmp/kartpad-tvos-simulator-build/KartPadTV.app \
  TVOSSIMULATOR
xcrun simctl launch "${TVOS_SIMULATOR_ID}" dev.kartpad.app
```

For a paired physical Apple TV, use Xcode 27 and your development team:

```sh
export DEVELOPER_DIR=/Applications/Xcode-27-beta-5.app/Contents/Developer
export DEVELOPMENT_TEAM="<apple-development-team-id>"
APPLE_TV_ID="<coredevice-id>"

./scripts/prepare-ios-game-runtime.sh \
  private/self-build/translation \
  /tmp/kartpad-tvos-device-source \
  /tmp/kartpad-tvos-device-build \
  base appletvos
./scripts/audit-tvos-app.sh \
  /tmp/kartpad-tvos-device-build/Release-appletvos/KartPadTV.app \
  TVOS
xcrun devicectl device install app \
  --device "${APPLE_TV_ID}" \
  /tmp/kartpad-tvos-device-build/Release-appletvos/KartPadTV.app
xcrun devicectl device process launch \
  --device "${APPLE_TV_ID}" dev.kartpad.app
sleep 2
xcrun devicectl device copy to \
  --device "${APPLE_TV_ID}" \
  --domain-type appDataContainer \
  --domain-identifier dev.kartpad.app \
  --source "$PWD/private/self-build/disc" \
  --destination Library/Caches/KartPad/GameData
xcrun devicectl device process launch \
  --device "${APPLE_TV_ID}" dev.kartpad.app
```

The first device launch creates the private app-data destination and exits
until the validated files are staged. The runtime writes saves only inside its
tvOS data container and keeps networking disabled.

See [`docs/GOAL-LOOP.md`](docs/GOAL-LOOP.md) for the execution rules and
[`docs/JOURNAL.md`](docs/JOURNAL.md) for reproducible commands and dated
results.

## First launch on Mac

The one-command build has already prepared the supported private data tree.
Open `KartPad-self-built.app`; if the app asks for game data, choose the
extracted `RMCP01` folder containing `sys/` and `files/`. KartPad validates the
identity before starting the runtime and preserves the previous valid setting
if a replacement is rejected.

The **KartPad** application menu provides **Choose Game Data…**, **Show Game
Data**, **Show Cache**, **Save Diagnostics Report…**, **Controller Settings…**,
**Controls…**, and the standard **Settings…** and **Quit** actions. Settings
exposes the supported display, audio, and FPS-counter controls. Durable saves
and configuration live in `~/Library/Application Support/KartPad`;
regenerable graphics data lives in `~/Library/Caches/KartPad`.

## Controls and mobile direction

The macOS keyboard bridge maps `WASD` to steering, `U`/Return to
A/accelerate/confirm, `M`/Delete to B/brake/reverse/back, `E` to R/drift,
Left Shift to L/item, arrows to the D-pad/tricks, Space to Start/pause, and Tab
to Select/minus. The native **Controls…** panel (`Command-/`) keeps the full
mapping visible in the app. Native controller discovery, remapping, and four
stable local slots are implemented separately from the keyboard fallback.

The iPhone/iPad app compiles a byte-identical pinned snapshot of SunPad's GPLv3
touch-control component and persistent **•••** menu directly. It preserves the
component's independently editable phone/tablet layouts, safe-area treatment,
multitouch, accessibility labels, settings, diagnostics, and controller-handoff
behavior. A separate tested adapter supplies Mario Kart Wii's Classic Controller
ABI without changing the copied baseline.

The landscape touch surface keeps every Wii Classic Controller action
available without a separate controller:

- **Left:** steering stick, D-pad, L, Start, and Select within thumb reach.
- **Right:** action buttons, R/ZL/ZR, and a second stick for menu-compatible
  input.
- **Mario Kart shoulders:** R is a compact digital control matching L rather
  than SunPad's Sunshine-specific analog-pressure trigger.
- **Held acceleration:** A stays asserted for the full touch. After one
  uninterrupted second it turns cyan and adds light haptic feedback, then
  returns to green and releases acceleration when the finger lifts.
- **Customize:** move and resize controls independently, save separate phone
  and tablet arrangements, or reset to the exact default layout.
- **Controller handoff:** the first extended controller takes Player 1, clears
  held touch input, and hides touch controls by default. Disconnecting it
  restores touch; additional controllers keep stable Player 2–4 slots.
- **Menu:** the persistent **•••** opens display, controls, game data,
  diagnostics, multiplayer access, and motion steering.
- **Experimental Miis:** **Game Data & Saves → Manage Miis…** imports and
  stages standard `.mii` records without replacing saves or game data.
- **Experimental Wii hardware:** direct Wii Remote/Nunchuk pairing is available
  only in the macOS build; the iPhone/iPad entry explains that platform limit.

KartPad's owning layer adds two actions ahead of SunPad's unchanged menu:

- **Multiplayer…** reports connected controllers, stable Player 1–4 assignment,
  and opens controller setup guidance. The first controller takes over Player
  1 from touch; Players 2–4 publish independent retail KPAD channels.
- **Motion Steering…** is default-off and provides recenter, inversion, and
  0.5×/1×/2× sensitivity. Touch can override it, physical controllers take
  priority, and backgrounding clears the live motion state.

The full retail graph boots on iPhone 17 Pro and iPad Pro 13-inch Simulator,
reaches title/menu/live Luigi Circuit, survives background/foreground, and
preserves exact save hashes across relaunch. The original icon catalog, privacy
manifest, opaque fitted-output bands, package boundary, and full 29,065-function
unsigned physical-device build pass. Locally signed builds from that IPA have
also been installed and accepted on physical iPhone and iPad hardware.
Simulator motion sensors are unavailable by design; additional motion tuning,
long-run performance, and audio characterization remain active work rather
than blockers to the completed device acceptance.

## First launch on iPhone or iPad

KartPad does not include Mario Kart Wii and cannot compile game code on-device.
For a locally built development app:

1. Build and locally sign KartPad on the Mac using your private translated
   `RMCP01` graph.
2. Put your supported `RMCP01` revision-0 WBFS/ISO in Files. An already
   extracted `DATA` folder remains supported as a fallback.
3. Launch KartPad and choose the disc image or extracted folder when prompted.
4. Leave the app open while it extracts or copies, validates, protects, stages,
   and activates the data. A successful first import continues into the game
   in the same session.
5. Later, use **••• → Game Data & Saves** to reimport or schedule removal.

The exact iPad-then-iPhone hands-on procedure is in
[`docs/PHYSICAL-ACCEPTANCE.md`](docs/PHYSICAL-ACCEPTANCE.md).

Saves live separately from the extracted game-data tree. Reimport and removal
retain them; uninstalling the app still removes its whole Apple container.

## Mobile screenshots

<table>
  <tr>
    <td width="50%"><img src="docs/artifacts/2026-08-30/g14-full-game-simulator/iphone-live-race-touch.jpeg" alt="KartPad live Luigi Circuit gameplay with the touch overlay on iPhone Simulator"></td>
    <td width="50%"><img src="docs/artifacts/2026-08-30/g14-full-game-simulator/ipad-live-race-touch.jpeg" alt="KartPad live Luigi Circuit gameplay with the touch overlay on iPad Simulator"></td>
  </tr>
  <tr>
    <td align="center"><strong>iPhone retail runtime</strong><br>Metal gameplay with KartPad's touch controls.</td>
    <td align="center"><strong>iPad retail runtime</strong><br>The independent tablet layout scales across the larger safe area.</td>
  </tr>
</table>

These are Simulator development-build captures using game data supplied
privately by the device owner. No game image, extracted data, save, or playable
binary is part of this repository.

## Diagnostics and privacy

On Mac, choose **KartPad → Save Diagnostics Report…** after a failure or slow
session. The schema-3 report contains bounded build/runtime identifiers,
selected safe settings, storage health, clean-versus-unclean shutdown state,
and capped current/previous log tails. User-directory prefixes and usernames
are redacted. It excludes the disc image, extracted files, generated game
module, saves, and file contents.

On iPhone or iPad, use **••• → Report a Problem…** to create KartPad's bounded
technical report and review it before sharing. Never attach game
data, generated modules, saves, signing material, or a complete app container
to a public report.

## Evidence-first development

KartPad keeps publishable, content-safe evidence under `docs/artifacts/` and
private traces under ignored paths. Every accepted step records the candidate,
procedure, observed result, hashes, limitations, and next gate. The project
does not infer timing, audio quality, touch feel, or stability from source
inspection alone.

Useful starting points:

- [`docs/STATUS.md`](docs/STATUS.md) — current accepted state and open risks.
- [`docs/PRD.md`](docs/PRD.md) — product requirements and release matrix.
- [`docs/PORTABILITY.md`](docs/PORTABILITY.md) — Windows-to-Apple host boundary.
- [`docs/SEMANTICS.md`](docs/SEMANTICS.md) — PPC/AArch64 correctness evidence.
- [`docs/RELEASE-CHECKLIST.md`](docs/RELEASE-CHECKLIST.md) — release gates.

## Frequently asked questions

### Can I download an IPA or playable app?

Yes. `v0.3.0-preview.5` provides an unsigned iPhone/iPad IPA that must be
re-signed before installation. It contains KartPad's compiled ARM64 translation
but no disc image or extracted game assets, so you must select your own legally
obtained supported image on first launch. The Personal IPA Builder remains
available as a separate local workflow. Follow
[`docs/INSTALL_IPA.md`](docs/INSTALL_IPA.md), and read
[`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md) for the community-release
boundary.

### Does online multiplayer work?

The development build now passes end-to-end login, matchmaking, room formation,
course voting, a two-player race, native results/ratings, and lobby return
between macOS and an iPad Simulator against a compatible isolated WFC server.
Public Retro WFC service compatibility, Wiimmfi, physical-device online play,
and external-client interoperability are still unaccepted while the service is
offline.

As of 1 September 2026, the official Retro Rewind documentation reports that
Retro WFC is in testing/maintenance mode following sustained attacks. The
official status page reports no live room data. KartPad's exact development
candidate reaches production NAS authentication, then receives error `61070`
when the Retro WFC GameSpy gameplay-login endpoint times out; a direct host
reachability check to that endpoint times out as well. Production matchmaking
and racing will be retested when Retro WFC is available again.

- [Retro Rewind service notice](https://mkwiiki.org/wiki/Retro_Rewind)
- [Retro WFC status](https://status.rwfc.net/)

### Does KartPad support Retro Rewind?

Yes. The 0.3.0 preview opens with an Original / Retro Rewind chooser and
installs a separately downloaded,
hash-verified Retro Rewind 6.12.4 pack. KartPad does not bundle Mario Kart Wii
or Retro Rewind content. Physical iPad build 7 completes the pack download,
verification, installation, Retro Rewind launch, and initial single-player
gameplay. Build 8 adds the final iPad multiplayer-guidance polish and installs
in place without removing app data. Production Retro WFC matchmaking and racing
remain temporarily unavailable during the external service outage, but this
does not block the current build. Before Retro Rewind starts, KartPad checks
the official version feed. If
Retro Rewind advances beyond the version compiled into the app, KartPad asks
for a compatible KartPad update instead of launching an outdated online pack.

### Can KartPad import or create a custom Mii?

Preview 5 can experimentally import and manage standard 74-byte `.mii` files
on Mac, iPhone, and iPad. Use **Game Data & Saves → Manage Miis…**, restart
KartPad, then select the imported Mii through Mario Kart Wii's License Settings.
KartPad cannot create a new Mii because it does not include the Wii Menu or Mii
Channel.

### Can I connect a Wii Remote and Nunchuk without a DolphinBar?

Experimentally, on macOS only. Enable **Controls → Experimental Wii Remote +
Nunchuk**, pair with the red SYNC button, attach the Nunchuk, and choose the
experimental preset in Controller Settings. This direct Bluetooth path still
needs wider testing with original Wii Remote hardware. It is not available on
iPhone or iPad.

### Are Android or Apple TV supported?

Apple TV supports a local base-game self-build on tvOS 17 or newer. The tvOS
target does not include Retro Rewind, online play, or a published app artifact.
Android is not currently supported.

### How much storage does KartPad use?

The current app package is about 80 MiB. Extracted game data uses about 2.5
GiB. Keeping the original WBFS/ISO in Files needs additional space, and the
full source build workspace is much larger than the installed app.

### Does this repository include Mario Kart Wii?

No. You must supply your own legally obtained supported disc image. Do not
open issues requesting game data, extracted files, generated modules, or
download links.

### Is KartPad a general Wii emulator?

No. KartPad is a game-specific static-recompilation integration for one pinned
Mario Kart Wii profile. It is not a loader for arbitrary Wii software.

### Is KartPad using Dolphin or streaming from a Mac?

No. It does not run the game through Dolphin and does not stream gameplay from
another computer. WiiCompiled translates the supported game's PowerPC code
ahead of time. KartPad compiles that translated code for ARM64 and supplies the
Apple app, Metal presentation, input, audio, storage, and lifecycle layers.

### Does KartPad use a PowerPC JIT on iPhone or iPad?

No. The mobile app executes a Mac-generated ARM64 translation and does not
download executable code or compile PowerPC code on-device.

### Why is the frame rate slow on first use?

Dawn and Metal still compile pipelines that are absent from the initial cache.
That work can stall guest progress and pressure the audio queue. Cache
coverage, bounded compilation, and sustained frame pacing are active release
gates; a displayed 60 FPS counter in one scene is not treated as acceptance.

### Why are the inherited experimental modes absent?

They targeted Sunshine-specific features: a 90% emulated CPU clock and a
GMSE01 60 FPS patch. Neither changes KartPad's ahead-of-time Mario Kart Wii
runtime, so the misleading no-op rows were removed. Use 1x render resolution
while diagnosing performance; KartPad's actual work is tracked through
frame-time telemetry, real guest-clock cadence, and CPU/GPU profiles.

### Do saves survive an app update or game-data replacement?

The tested in-place paths keep saves separate from game data, and reimport or
scheduled removal preserves them. A clean uninstall, bundle-identifier change,
or incompatible signing change can still remove or disconnect the app
container, so back up before crossing those boundaries.

### Is everything finished?

No. Native macOS gameplay is broad and the accepted mobile IPA runs real
races, but sustained performance, a complete three- and four-player result
path, the eight-hour soak, fresh-clone provisioning, production online
acceptance after Retro WFC returns, complete touch/motion race coverage, and
the full engineering-completion matrix remain open.
General physical-device acceptance is complete on both iPhone and iPad, while
narrower performance, audio, motion, and controller refinements can continue.

## Project map

| Path | Purpose |
|---|---|
| [`docs/INSTALL_IPA.md`](docs/INSTALL_IPA.md) | Download, checksum, re-signing, first-launch import, and update guidance for the public unsigned IPA |
| [`RIGHTS_AND_LICENSES.md`](RIGHTS_AND_LICENSES.md) | Free community-preview authorization and unresolved translated-code rights boundary |
| [`scripts/build-user-ipa.sh`](scripts/build-user-ipa.sh) | Identify a supported image and build a private unsigned IPA with the profile-driven Builder |
| [`scripts/package-public-unsigned-ipa.py`](scripts/package-public-unsigned-ipa.py) | Deterministically package the exact audited public community-preview IPA |
| [`scripts/audit-public-unsigned-ipa.py`](scripts/audit-public-unsigned-ipa.py) | Reject game data, signing residue, private paths, missing notices, malformed provenance, or an incorrect release build |
| [`builder/profiles/`](builder/profiles/) | Versioned container, executable, and static-translation compatibility profiles |
| [`docs/BUILDER.md`](docs/BUILDER.md) | Personal IPA workflow, cache design, compatibility extension, and public-release boundary |
| [`scripts/self-build-macos.sh`](scripts/self-build-macos.sh) | Verify, extract, translate, build, sign, and audit a local macOS app |
| [`scripts/prepare-disc.sh`](scripts/prepare-disc.sh) | Validate and privately extract the supported disc profile |
| [`scripts/translate-base.sh`](scripts/translate-base.sh) | Produce the ignored full ARM64 translation graph |
| [`scripts/build-ios-game-app.sh`](scripts/build-ios-game-app.sh) | Build the full iPhone/iPad Simulator game app |
| [`scripts/build-ios-device-game-app.sh`](scripts/build-ios-device-game-app.sh) | Build and audit the full unsigned physical-iPhone/iPad game app |
| [`scripts/check-ios-device-runtime-host.sh`](scripts/check-ios-device-runtime-host.sh) | Compile the exact UIKit runtime host for physical iOS and reject Simulator-only hooks |
| [`scripts/audit-macos-package.sh`](scripts/audit-macos-package.sh) | Reject malformed or privacy-unsafe Mac packages |
| [`scripts/audit-ios-game-app.sh`](scripts/audit-ios-game-app.sh) | Reject private data, unsafe linkage, and incomplete iOS bundles |
| [`apple/macos/`](apple/macos/) | Native Mac shell, settings, diagnostics, and runtime integration |
| [`apple/ios/`](apple/ios/) | iPhone/iPad lifecycle, import, multiplayer, and motion integration |
| [`apple/third_party/sunpad/`](apple/third_party/sunpad/) | Exact pinned SunPad touch/menu snapshot and provenance |
| [`patches/`](patches/) | Reproducible WiiCompiled/Aurora/Dawn integration changes |
| [`docs/STATUS.md`](docs/STATUS.md) | Accepted evidence, current risks, and honest open work |
| [`docs/PERF.md`](docs/PERF.md) | Performance measurement contract and acceptance gates |
| [`docs/KNOWN-ISSUES.md`](docs/KNOWN-ISSUES.md) | Known limitations and current workarounds |
| [`docs/IOS-THREE-DOT-MENU-FIX.md`](docs/IOS-THREE-DOT-MENU-FIX.md) | Reusable UIKit menu appearance, lifecycle repair, and validation checklist |
| [`docs/FUTURE-FEATURES.md`](docs/FUTURE-FEATURES.md) | Researched but deferred product features, beginning with RetroAchievements |
| [`docs/releases/NEXT.md`](docs/releases/NEXT.md) | Living Preview 5 validation and publication record |
| `ref/`, `private/`, `build/` | Ignored reference checkouts, private inputs, and local outputs |

## Research and credits

KartPad builds on WiiCompiled and its Aurora/Dawn runtime, Dolphin-derived
hardware research, SDL, and the wider static-recompilation community. SunPad
is the direct source—not merely a visual inspiration—for the mobile touch
surface and persistent three-dot menu. Exact pins and provenance live in the
repository verification scripts, the SunPad snapshot record, and the project
documentation.

## Legal and provenance

Mario Kart, Wii, Nintendo, and game imagery are owned by their respective
rights holders and are used here only to identify compatibility and document
runtime behavior. KartPad is not affiliated with or endorsed by Nintendo.

WiiCompiled is GPLv3 at the pinned revision. Aurora, Dawn, SDL, Dolphin-derived
code, Crypto++, Abseil, FreeType, libpng, and other dependencies retain their
own licenses and notice obligations. The imported SunPad mobile UI snapshot
retains its GPLv3 license, exact upstream revision, hashes, and attribution.
KartPad's original icon provenance is recorded in
[`branding/PROVENANCE.md`](branding/PROVENANCE.md).

## Contributing

The most useful contributions are reproducible reports against an open row in
[`docs/RELEASE-CHECKLIST.md`](docs/RELEASE-CHECKLIST.md), especially cold/warm
performance captures and physical-device touch, motion, controller, audio, and
lifecycle results. Include the exact commit, hardware, OS, settings, procedure,
and observed result. Never attach private game data, generated game code,
saves, credentials, or signing material to an issue or pull request.
