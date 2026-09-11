# Building KartPad on Apple platforms

Run commands from the repository root. For downloads and first launch, use the
[Mac](INSTALL_MACOS.md) or [iPhone/iPad](INSTALL_IPA.md) installation guide.
Android has a separate [source-build guide](../android/README.md).

For a personal unsigned IPA, the [Personal IPA Builder](BUILDER.md) handles
bootstrap, input validation and translation:

```sh
./scripts/build-user-ipa.sh bootstrap
./scripts/build-user-ipa.sh inspect /path/to/Mario-Kart-Wii.wbfs
./scripts/build-user-ipa.sh build /path/to/Mario-Kart-Wii.wbfs
```

The result remains a private local artifact and needs local signing. Keep game
inputs, generated code, saves and signing material out of Git.

## Prerequisites

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

## Source checks

Run the portable correctness gates:

```sh
./scripts/test-host-portability.sh
./scripts/test-guest-memory.sh
./scripts/test-guest-scheduler.sh
./scripts/test-ppc-semantics.sh
```

## Mac self-build

Build from the pinned supported image in one fail-closed local workflow:

```sh
./scripts/self-build-macos.sh /path/to/your/Mario-Kart-Wii.wbfs
```

The workflow bootstraps and verifies the pinned public sources plus the exact
Retro Rewind 6.12.7 pack, verifies the complete supported image hash, extracts
it read-only with pinned `nodtool`, validates `RMCP01` revision 0 plus the
DOL/REL hashes, translates the dual private title graph with bounded
parallelism, builds the patched Apple runtime, and audits the ad-hoc-signed
local app. All extracted and translated outputs stay under ignored `private/`;
the app stays under ignored `build/`. Existing valid work can be resumed.

The initial translation and native build are substantial. The workflow reuses
validated extraction and translation outputs after an interruption. Bootstrap
fetches missing pinned dependencies and fails closed if a source checkout,
Retro Rewind file, or Retro-WFC payload has the wrong identity.

Launch the audited local app:

```sh
open build/KartPad.app
```

The resulting app is a local development build. It is ignored by Git, may
contain a locally generated executable game module, and is not an audited release artifact. See the
[software and game-content rights](../RIGHTS_AND_LICENSES.md) before distribution.

To build from an already produced ignored translation graph, run the lower
level steps directly:

```sh
./scripts/prepare-g7-game-runtime.sh
./scripts/package-macos-runtime.sh \
  "$PWD/build/g7-game-runtime-build" \
  "$PWD/build/KartPad.app"
./scripts/audit-macos-package.sh "$PWD/build/KartPad.app"
```

## iOS Simulator and physical-device builds

Prepare and build the dual-game iOS Simulator runtime from the same private
translation graph. Bootstrap the pinned dependencies first, and use a fresh
prepared runtime after source or patch changes:

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
  private/g8-full-translation dual
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
  private/g8-full-translation dual
```

The build scripts verify the exact SunPad source snapshot and dependency pins,
compile only ARM64 code, and fail if private game data, saves, signing material,
or non-system dynamic dependencies enter the app bundle. Installation and signing remain local development steps. For published
packages, use the platform installation guides in the [documentation index](README.md).

See [engineering goal loop](GOAL-LOOP.md) for the execution rules and
[engineering journal](JOURNAL.md) for reproducible commands and dated
results.
