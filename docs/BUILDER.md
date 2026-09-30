# KartPad Personal IPA Builder

KartPad uses static recompilation. The Builder translates a supported game
executable on your own Mac, from your own disc image, before you sign the app.
Prebuilt KartPad downloads have been retired, so the Builder is currently the
way to get KartPad on iPhone and iPad. Mac and Android Builder targets are in
progress; this page describes only commands that exist today.

## Current preview

The Builder accepts your own PAL `RMCP01` revision 0 disc image as ISO, WBFS,
RVZ, WIA, GCZ or CISO. The pinned development WBFS is recognized by its hash;
any other dump is accepted provisionally and must extract to the profile's disc
identity and exact `main.dol` and `StaticR.rel` hashes, or the build stops
before translation. (Checked 29 Sep 2026 with ISO and RVZ converted from the
pinned image; a different game's disc is refused.) It produces an unsigned,
personalized IPA for local signing. The Builder and compatibility metadata are
public; disc data, extracted files, translated code, signing material, and the
resulting IPA remain ignored and private.

Requirements are an Apple Silicon Mac, Xcode, CMake, Ninja, Git, ripgrep,
Python 3, .NET 8, and `nodtool` 2.0.0-alpha.9. Fetch the profile's exact pinned
source checkouts and hash-verified physical-iOS Dawn archive once:

```sh
./scripts/build-user-ipa.sh bootstrap
./scripts/build-user-ipa.sh doctor
```

The bootstrap fetches only dependencies declared by the selected profile,
checks out exact commits, initializes their submodules, disables push URLs,
and fails rather than modifying an unexpected or dirty existing checkout.

Inspect an image without extracting it:

```sh
./scripts/build-user-ipa.sh inspect /path/to/Mario-Kart-Wii.wbfs
```

Build the private unsigned IPA:

```sh
./scripts/build-user-ipa.sh build /path/to/Mario-Kart-Wii.wbfs
```

The default output is ignored at
`artifacts/KartPad-personal-unsigned.ipa`. It contains translated code from the
user's game executable, whose redistribution rights KartPad does not clear.
The Builder records that game-content status separately from the GPLv3 software
license; it does not impose a blanket redistribution ban on GPL-covered code.
Keep the personal IPA private: do not share or upload it.

While it runs, the Builder appends stage events (`preflight`, `extract`,
`translate`, `dependencies`, `generate`, `compile`, `package`) as JSON lines
to `logs/progress.jsonl` under the work root. Frontends can show the current
stage and elapsed time from that file; compiler output stays in the normal log.
The repository's `padmint.json` describes the Builder's inputs, targets and
status for tools that drive it.

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

PadMint can make the iPhone/iPad game pack without a Mac. Apple's SDK may only
be used on Apple computers, so off a Mac the pack is compiled with LLVM 21.1.8
(clang and `ld64.lld`) against an SDK that `builder/kartpad_builder/ios_sdk.py`
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

Validated extraction is cached by profile and complete input-image hash, so
ordinary code changes do not extract the same disc again. Build and translation
workspaces use a stricter key containing the input-image hash, canonical
profile hash, Builder pipeline version, tracked source index, and current source
diff. A code or profile change therefore cannot silently reuse an older app
workspace. Extraction and translation stages validate their manifests before
reuse and stage new extraction atomically. IPA ZIP entries are sorted, have fixed
timestamps, and preserve executable permissions, so the same audited app and
provenance produce byte-identical packages.

The IPA embeds a content-safe `KartPadBuilderProvenance.json` containing hashes
and profile identifiers, never local source paths. Packaging rejects disc
images, saves, provisioning profiles, signatures, and explicitly supplied
private path prefixes.

## Release boundary

The following is the maintainer's publication policy, not an additional
restriction on GPL rights. You may modify and redistribute the GPL-covered
Builder, runtime, and integration under the GPL, including commercially and
without separate maintainer approval. See
[`RIGHTS_AND_LICENSES.md`](../RIGHTS_AND_LICENSES.md).

The maintainer may publish the exact audited community-preview IPA produced by
`scripts/package-public-unsigned-ipa.py`. That package has versioned
provenance, license notices, deterministic ZIP metadata, no private game data,
and no signing material. Its translated-game-code and uncleared game-content
rights status must be stated plainly as documented in `RIGHTS_AND_LICENSES.md`.

Do not publish a generated translation directory, raw app bundle, personalized
Builder IPA, extracted game tree, save, signing certificate, or provisioning
profile. A local Builder output is not interchangeable with the exact public
release candidate.

The private development product passes a local Mac-to-iPad-Simulator online
race/results flow. Public-service, physical-device online, and external-client
acceptance remain separate from Builder compatibility and are not claimed for
this preview.
