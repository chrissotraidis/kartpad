# KartPad 0.5.1 — macOS package (build 85)

Date: 2026-09-26. Release source revision: `de3a99c9054042f07e2840066b1bd06f4012659b`
("Pin macOS runtime for 0.5.1"), built with a clean tree.

## Result

The Apple Silicon Mac app for 0.5.1 build 85 was built from de3a99c and passed the
package audit, the public ZIP audit, a signature check after extraction and a
byte-reproducibility repack. The public app also launched on this Mac with existing
game data and ran the original game at a steady 60 fps after the one-time graphics
warm-up. No race, Retro Rewind, online or controller check was done.

| Item | Value |
| --- | --- |
| Asset | `build/macos85/release/KartPad-v0.5.1-macos-arm64.zip` (release worktree, ignored) |
| Bytes | 63,111,483 |
| SHA-256 | `a4348b8df37d9aa8925f86f9f02bc03b0ecd39715da4cf6a2e84660382fad399` |
| App version / build | 0.5.1 / 85, `dev.kartpad.app`, macOS 14+, arm64, ad-hoc signed |
| `Contents/MacOS/KartPad` SHA-256 | `27547b98398f9f1f3dc6da57e9ab6e73891955c9bb3006c21ae6ba2a6b5141b8` |
| Unsigned runtime SHA-256 (build fingerprint) | `8ce53269d7db8dcac579684ec2387de9bfcc51e17f3cf32912c84c0a99138ed1` |
| Bundled `initial_pipeline_cache.db` SHA-256 | `63b4889adf2b91160cee2eac00e30dabd0f7ff150143310f8e0dba32312618f4` (same as iOS) |

The Mac app has no `KartPadDiagnosticsCandidate` key; that diagnostic mode is iOS-only,
so "diagnostics NO" is the only possible Mac state.

## macOS runtime

`vendor/runtimes/macos` moved from `10360ad` to `69cdba9` on branch
`codex/macos-051-20260926` (pushed to chrissotraidis/wiicompiled). It ports the 12 iOS
commits from `codex/ios-menu-stall-20260925` in order:

| iOS | macOS | Change |
| --- | --- | --- |
| a4b49de | 915d5f0 | Capture long presentation gaps and bounded pipeline waits |
| 9d4cde3 | 4d97070 | Replay recorded pipelines when menu archives load |
| b2e51eb | 37e618e | Prewarm the first 512 recorded pipelines |
| 232484c | 9b345a4 | Count only first-use pipelines toward the synchronous build cap |
| f5a5002 | 3037dd7 | Prewarm every recorded pipeline on 6 GB+ Apple devices |
| f2d66d9 | 5ba5a98 | Launch graphics preparation progress; scale background workers |
| ea325f2 | ed11be1 | Retain 512 prewarmed pipelines; warm the rest once per OS build |
| 08a5d72 | fa5fa2c | Seed 133 more recorded pipeline recipes |
| 056a7f5 | 5f3dd85 | Key the OS warm-up marker to the bundled seed version |
| 3ce544d | 2c25302 | Let recurring race copies skip unready draws after race start |
| 5a0732f | b2ffa4e | Log 30-250 ms presentation jobs; recurring-copy window of four frames |
| cbe43de | 69cdba9 | Park blocking stream receives on the guest thread |

Adaptations: the macOS pipeline cache gained the `TargetConditionals.h`/`sys/sysctl.h`
include block that iOS already had; one log line uses `g_maxBackgroundPipelineWorkers`;
and the macOS receive path omits the iOS-only `KARTPAD_WFC_TRACE` developer trace
(noted in 69cdba9's message). No build-number or iOS-guard changes were needed. Every
touched file matches the iOS copy except for lines that already differed before the
port. `scripts/test-shared-runtime-parity.py` passes (5 files across four pins).

## Translation input

The Mac build uses the same translated game graph as the iOS 0.5.1 build,
`private/ios-gx-direct-20260925/translation` in the stabilization worktree (the GX
display-list burst graph). It was copied to ignored `work/macos-051/private/translation`
because `prepare-g7-game-runtime.sh` adds Mach-O `_k` symbol aliases to
`data_sections_init_blobs.S` in place, and the iOS build was reading the original at
the time. The copy differs only in absolute paths inside `shards.cmake` and
`data_sections_init_blobs.S` and in those aliases. The function and shard sources
(29,637 function files) hash identically to the iOS graph:
`26883242cf76e6370111f5f54476d918f1e062e9c4f9caa681511e08ac1a8dbf` (SHA-256 over the
sorted per-file SHA-256 list of `functions/` and `build_shards/` minus `shards.cmake`).
The Retro Rewind module comes from
`private/android-context-control-20260923/mod`, as referenced by the graph.
Earlier Mac builds used `private/upstream-20260922/translation`, which differs from
this graph in seven GX functions.

## Build and audit commands

From the release worktree at de3a99c:

```sh
scripts/prepare-g7-game-runtime.sh <translation copy> build/macos85/source build/macos85/runtime-build dual
KARTPAD_VERSION=0.5.1 KARTPAD_BUILD_NUMBER=85 KARTPAD_DIAGNOSTIC_CANDIDATE=NO \
  scripts/package-macos-runtime.sh build/macos85/runtime-build build/macos85/KartPad.app KartPadDual
KARTPAD_EXPECTED_VERSION=0.5.1 KARTPAD_EXPECTED_BUILD=85 \
  scripts/audit-macos-package.sh build/macos85/KartPad.app dual
```

The ZIP was made with `scripts/package-public-macos.py` and checked with
`scripts/audit-public-macos.py`. Both scripts hardcode v0.4.22-macos.1 / build 43, so
they were run through `work/macos-051/run_public.py`, which executes the repo scripts
unchanged apart from the release tag (`v0.5.1`), version, build and the release-notes
path (`docs/releases/v0.5.1.md`). Updating those constants in the repo would remove the
wrapper for the next release.

Results:

- The 997-step Ninja build compiled and linked with no errors.
- The app package audit passed: signature valid on disk and satisfying its designated
  requirement, Bluetooth entitlement present, version 0.5.1 (85), dual launcher.
- `build-fingerprint.json` records source commit de3a99c and the unsigned runtime hash above.
- The public ZIP audit passed: 55 entries, required notices and third-party licenses
  present, no game data, saves, signing material or writable runtime state, provenance
  `releaseTag=v0.5.1`, `sourceCommit=de3a99c…`, `appVersion=0.5.1`, `appBuild=85`, and
  the executable hash matches provenance.
- After `ditto -x -k`, `codesign --verify --deep --strict` passed, and the extracted
  app's path-relative content hash matches the built app. The audit's printed "bundle
  content hash" includes absolute paths, so it differs between locations by design.
- Packaging again into a second path produced the same ZIP SHA-256.

## Launch check

The extracted public app was opened on this M3 Max with the existing
`~/Library/Application Support/KartPad` setup (backed up first under
`work/macos-051/appsupport-backup`). It loaded the original game from the configured
disc folder, seeded the pipeline cache from the bundled DB, and ran the one-time
warm-up: 3,111 pipelines in 78.8 s, during which frame pacing was uneven (18-47 fps
windows, one 867 ms worst frame). After that it held 59.8-60.6 fps with zero queued
pipelines for the rest of the roughly two-minute session. Three Simulators from other
tasks were booted, so these numbers are a smoke check, not a performance measurement.
The app was closed with an AppleScript quit, which bypasses the shell's own quit path, so
the session log was left marked unclean; that marker only affects the next launch's
`previousSessionClean` log line. The session added logs and
`NAND/title/00000001/00000002/data/setting.txt`; no existing save or config file changed.

## Not verified

- Menus, character select, races, Retro Rewind, online/WFC, controllers and audio on the Mac.
- The receive-parking change (69cdba9) on Mac networking.
- Gatekeeper behavior of a downloaded (quarantined) copy, and any other Mac.
- Publication, anonymous download and hash readback of a hosted asset.
