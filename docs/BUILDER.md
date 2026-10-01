# KartPad Personal Builder

KartPad's public Android APK and iPhone/iPad IPA contain no game code.
[PadMint](https://github.com/chrissotraidis/padmint) builds the game part from
your own disc and supplies the build tools. For normal setup, follow
[Get KartPad](../README.md#get-kartpad). This page describes the repository
builder that PadMint runs and the separate development workflows.

## Current targets and inputs

| Target | Build computer | Private output |
| --- | --- | --- |
| Android game pack | Windows, macOS or Linux | `.so` game pack for the published APK, plus extracted game data |
| iPhone/iPad personal app | Apple Silicon Mac with Xcode | Published empty IPA with your `.dylib` game pack added, plus extracted game data |
| iPhone/iPad personal app (experimental) | Windows or Linux | Same personal IPA, using PadMint's LLVM and open-source headers; see the evidence below |
| Mac development app | Apple Silicon Mac | Local app through the [Mac self-build workflow](INSTALL_MACOS.md#build-it-yourself); no current public Mac app |

Android phone-only builds through PadMint and Termux remain experimental.
See PadMint's [phone guide](https://github.com/chrissotraidis/padmint#android-phone-only-experimental)
for its memory, storage and setup requirements.

The pack builder accepts your own PAL `RMCP01` revision 0 disc image as ISO,
WBFS, RVZ, WIA, GCZ or CISO. The pinned development WBFS is recognized by its
hash; another container is accepted provisionally and must extract to the
profile's disc identity and exact `main.dol` and `StaticR.rel` hashes before
translation. ISO and RVZ converted from the pinned image were checked on
29 Sep 2026; a different game's disc was refused. Listing a supported extension
or running `inspect` does not verify the extracted executables.

PadMint also saves a game data folder with `files/` and `sys/`. Importing that
folder on the device needs no common key. Android can alternatively import an
ISO/WBFS/RVZ with your own common key after you add the game pack. The iPhone
alternative disc importer accepts ISO/WBFS; use the exported folder for an RVZ.
See the [Android](INSTALL_ANDROID.md) and [iPhone/iPad](INSTALL_IPA.md) guides.

## Build a pack against the published app

Use the latest PadMint for tool installation and normal player builds. For a
manual build, install Python 3, Git, CMake, Ninja, .NET 8 and `nodtool`
2.0.0-alpha.9. Android also needs the pinned Android NDK; iPhone builds on a Mac
need Xcode. Windows/Linux iPhone builds need the LLVM and header sources that
PadMint supplies. Run these examples from the repository root in a shell with
the tools available; the `build-user-ipa.sh` wrapper uses Bash and Python 3.

Bootstrap and verify only the selected target's pinned dependencies:

```sh
./scripts/build-user-ipa.sh bootstrap --target android-pack
./scripts/build-user-ipa.sh doctor --target android-pack
```

Build the Android pack against the published APK, and export its game data:

```sh
./scripts/build-user-ipa.sh build-pack android /path/to/Mario-Kart-Wii.rvz \
  --app /path/to/KartPad-v0.7.3-android.apk \
  --output artifacts/KartPad-android-personal.so \
  --game-data artifacts/KartPad-game-data
```

For an iPhone/iPad personal IPA, use the `ios-pack` target and the published
empty IPA instead:

```sh
./scripts/build-user-ipa.sh bootstrap --target ios-pack
./scripts/build-user-ipa.sh doctor --target ios-pack
./scripts/build-user-ipa.sh build-pack ios /path/to/Mario-Kart-Wii.rvz \
  --app /path/to/KartPad-v0.7.3-ios-unsigned.ipa \
  --output artifacts/KartPad-ios-personal.ipa \
  --game-data artifacts/KartPad-ios-game-data
```

The output game data folder must not already exist. Choose a new output path
for another export. Keep the pack, personal IPA and game data private. Sign the
personal IPA with your existing sideloading identity and update in place to
preserve saves.

Bootstrap checks out exact pinned commits and initializes required submodules.
It fails rather than modifying an unexpected or dirty existing checkout. The
pack builder checks for duplicated app state and TLS wrappers against the
published app.
Compatible app updates can reuse a cached pack when its interface fingerprint
matches; the app asks for a new pack when that interface changes.

While it runs, the pack builder appends stage events (`preflight`, `extract`,
`translate`, `compile`, `check`, `package`) to `logs/progress.jsonl` under the
work root. Compiler output stays in the normal log. The repository's
`padmint.json` declares the inputs and target commands PadMint runs.

## Full iPhone development build on a Mac

The older `build` command builds the complete app locally instead of adding a
pack to a published empty app. It requires an Apple Silicon Mac, Xcode and the
[Apple build prerequisites](BUILDING.md#prerequisites):

```sh
./scripts/build-user-ipa.sh bootstrap
./scripts/build-user-ipa.sh doctor
./scripts/build-user-ipa.sh inspect /path/to/Mario-Kart-Wii.rvz
./scripts/build-user-ipa.sh build /path/to/Mario-Kart-Wii.rvz
```

The default output is ignored at `artifacts/KartPad-personal-unsigned.ipa`.
It contains translated game code and remains private. This development path
is separate from PadMint's `build-pack` workflow and the published empty IPA.

## Compatibility profiles

Profiles live in `builder/profiles/` and are versioned JSON. They keep these
concerns separate:

- accepted container formats and exact full-image hashes;
- disc ID, disc number, revision, and Wii magic;
- extracted DOL and REL identities;
- load addresses, memory layout, entry points, function map, injectors, and
  expected translation counts.

This design allows multiple verified WBFS/ISO container variants to point to
one static-recompilation profile when extraction proves they contain the same
DOL and REL. A different region or executable revision receives a separate
profile because addresses and generated code can change. Unknown inputs always
fail closed.

To add compatibility:

1. Verify the complete image and extract it read-only.
2. Record the container SHA-256 only after establishing legal provenance.
3. Compare the extracted DOL/REL hashes and disc header with an existing
   profile.
4. Add a container entry only if the executable identities are identical;
   otherwise create and validate a new profile.
5. Run `./scripts/test-kartpad-builder.sh` and a complete local build twice.

## iPhone game packs on Windows and Linux (experimental)

PadMint can make the iPhone/iPad game pack without a Mac or Apple's SDK.
Off a Mac the pack is compiled with LLVM 21.1.8 (clang and `ld64.lld`) against an SDK that `builder/kartpad_builder/ios_sdk.py`
assembles from open-source parts only. PadMint downloads each part pinned by
digest (its `tools.lock.json`; `libcxx` brings the others with it, and only
off a Mac):

| Part | Source | License |
| --- | --- | --- |
| clang, ld64.lld, llvm-nm, llvm-strip, llvm-install-name-tool | LLVM 21.1.8 release for the host | Apache-2.0 WITH LLVM-exception |
| C++ standard library headers | LLVM `libcxx-21.1.8.src`, configured as LLVM configures libc++ for Apple | Apache-2.0 WITH LLVM-exception |
| C library headers | Apple `Libc-1752.120.2` | APSL-2.0; six Berkeley headers BSD-4-Clause-UC, three Citrus headers BSD-2-Clause |
| Kernel type headers (`sys/`, `arm/`, `machine/`, `mach/`, `libkern/`) | Apple `xnu-12377.121.6` | APSL-2.0; `arm/endian.h`, `arm/limits.h`, `arm/types.h` BSD-4-Clause-UC |
| pthread, malloc, setjmp and cache-control headers | Apple `libpthread-539.100.4`, `libmalloc-812.100.31`, `libplatform-375.120.2` | APSL-2.0 |
| `Availability*.h` | Apple `AvailabilityVersions-157.2`, made by its own script | APSL-2.0 |
| `math.h`, `fenv.h`, `TargetConditionals.h` | written for KartPad (`builder/ios-sdk/`) from the C standard and arm64 facts | GPL-3.0-or-later |

Apple's headers are used as its iPhone install uses them: the names that
install defines (`XNU_PLATFORM_iPhoneOS`, Libc's iPhone features) are
resolved, and Libc's install-only blocks are removed. The assembled SDK's
`SOURCES.json` lists every file with its origin, SHA-256 and license. Nothing
from Apple's SDK or any Apple binary is used, and the assembled SDK stays in
the build folder; it is never published.

The pack is linked with a flat namespace: every name it imports is looked up
when the app loads it. A Mac-built pack already binds the app's own exports
that way (`-undefined dynamic_lookup`); here it also covers libSystem and
libc++, because `ld64.lld` cannot mark a looked-up app export as thread-local.
Generated text stubs name the app's thread-local exports, read from the
published app. After linking, the builder checks that every import the app
does not export is a C or C++ standard library name, then runs
`check-game-pack-state.py` as on a Mac. The pack interface fingerprint does not
include the compiler, so an LLVM-built pack is accepted by the same published
app. The translator writes its data blobs in the host's assembler syntax, so
off a Mac they are rewritten as Mach-O before compiling.

Checked 30 Sep 2026 with the published empty 0.7.2 IPA: `padmint make kartpad
ios` on Ubuntu 24.04 arm64 (Docker, 13.5 minutes) and on Windows 11 ARM64
with arm64 Python (29 minutes) each made a personal IPA with pack fingerprint
`35ccf81c...`. Each, installed in place on an iPhone 14 (iOS 26.6.2), reached
an active Grand Prix race with the existing saves. Linux x86_64 and Windows
x86_64 use the same code but have not been run end to end.

## Repeatable builds and cache safety

Validated extraction is cached by profile and input-image hash. Build and
translation workspaces use a stricter key containing the image hash, canonical
profile hash, Builder pipeline version, tracked source index and current source
diff. Extraction reuse validates the disc header and executable hashes;
translation reuse checks function counts, the shard graph and the REL guard.
New extraction is staged before it becomes the cached input.

PadMint keeps checked packs separately by platform, pack interface fingerprint
and disc hash. A compatible cached pack skips translation and compilation while
retaining the pinned Retro inputs and disc extraction checks. Before packaging,
the existing app-state/TLS symbol check runs again against the selected app.
Cache reuse does not establish new gameplay acceptance or a faster first build;
measure the stages for the actual build under review.

The full development IPA builder uses sorted ZIP entries, fixed timestamps and
executable permissions. It embeds content-safe `KartPadBuilderProvenance.json`
and rejects disc images, saves, provisioning profiles, signatures and supplied
private path prefixes. The pack workflow adds the player's library to the
published empty IPA; the result is a separate personal artifact.

## Release boundary

Public releases contain only the empty Android app (`scripts/build-android-app.sh`),
the empty iPhone app (`scripts/build-ios-app.sh`), the PadMint recipe and checksums.
Before release, the empty apps and all public artifacts must satisfy the audits
and device/emulator race gates in [AGENTS.md](../AGENTS.md).

Never publish a game pack, personal build, translated code, disc data, extracted
game tree, save, console key or signing material. Keep generated inputs and
personal outputs ignored and private. A local development or player build is
not the published empty app.

This is the maintainer's publication policy, not an additional restriction on
GPL-covered software. You may modify and redistribute the GPL-covered Builder,
runtime and integration under the GPL, including commercially. The Builder
records game-content rights separately from its software license. See
[rights and licenses](../RIGHTS_AND_LICENSES.md).
