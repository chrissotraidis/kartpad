# Android A3 bounded archive extraction and activation pipeline

Date: 2026-09-04

Branch: `codex/android-a3-archive-extraction`

Baseline: `27eb5638c32709eea8bc3879ec56082f06d9a591`

## Falsifiable subgoal

Consume a verified Retro Rewind ZIP through the shared archive policy, extract
only the pinned root without following filesystem links, and join that result
to exact content validation and atomic activation on Android. Prove the JNI
path on both supported emulator page-size lanes without downloading or
publishing the production archive.

## Result

- Added official minizip-ng 4.0.8 commit
  `55db144e03027b43263e5ebcb599bf0878ba58de` to the Android dependency lock.
  Bootstrap fetches the 772,757-byte official archive at SHA-256
  `e0fa42896ad244261f100fd06fae7c64f6054ce02d143f4d0f55df5fced9f63d`,
  validates the extracted CMake source, and reports its path to Gradle/CMake.
- The native build disables unneeded archive formats, encryption, fetching,
  tests, and writers; it statically links only decompression and Android zlib
  into the existing `libmain.so`. No new packaged native library appears.
- Added a two-pass extraction core. Pass one applies the shared strict member
  path, exact-root, duplicate, symlink, encryption, entry-count, and expansion
  limits. Android additionally rejects invalid UTF-8. Pass two streams through
  a 1 MiB buffer and verifies each advertised uncompressed byte count and CRC.
- Output traversal uses directory file descriptors plus `mkdirat`/`openat`
  with `O_NOFOLLOW`, `O_EXCL`, and private permissions. A pre-existing output
  symlink or collision fails without writing outside staging.
- JNI provides cancellation checks between archive reads and bounded byte
  progress. The Java owner requires a regular non-symlink archive, a real
  staging directory, and an absent pinned root.
- The install pipeline revalidates the cached archive, creates exact scoped
  staging, extracts, validates version/`Code.pul`/XML, and atomically activates.
  Any cancellation, extraction, or validation failure discards only that exact
  staging directory and preserves the active install. Startup recovery remains
  the process-death cleanup boundary.
- The exact minizip-ng Zlib license is included in the APK. The package audit
  now enforces the exact asset set, exact native dependency allowlist including
  Android `libz.so`, and the exported extraction JNI symbol.

## Verification

- Host extraction matrix: pass. It covers valid content and progress, foreign-
  root exclusion, traversal, exact duplicates, file/directory aliases,
  symlinks, slash-named data, encryption, invalid UTF-8, missing root, entry and
  expansion limits, cancellation, CRC corruption, and a pre-existing output
  symlink with an untouched outside directory.
- Java pipeline fault matrix: pass. It proves successful activation, cancelled
  staging cleanup, invalid-content cleanup, invalid-archive refusal before
  extraction, and preservation of the prior active install.
- Both pre-existing shared archive-path/scan CTests and the pinned SunPad
  snapshot pass. An initial unscoped CTest command attempted sixteen unrelated
  targets not built in that selective directory; the correctly scoped archive
  invocation passed both available tests.
- Pinned Android host/bootstrap, public source-only assemble, release
  Kotlin/Java compilation, API-28 lint, and the package/privacy audit pass.
- The full private game-runtime native target rebuilt successfully with the
  new core/JNI/minizip graph, then an incremental rerun passed after final
  source changes. Its ignored 639,690,520-byte `libmain.so` has SHA-256
  `775101a01b04ab58233f8d28df314268e163b8b6ce4eb5613f796a3007aee1fa`
  and exports the extraction JNI symbol. No private APK was packaged or
  installed.
- Wiped API 36 4 KiB and API 35 16 KiB ARM64 AVD runs both observed
  `A3 JNI archive extraction passed entries=2 bytes=7` in addition to all
  existing memory, fiber, scheduler, controller, Vulkan, orientation, and
  lifecycle markers. Both emulators were shut down; no ADB target remains.
- All earlier Android A3 download, space, content, and storage tests pass. All
  30 builder/tvOS tests pass with one optional private-input skip. Shell syntax,
  shell lint, repository safety, and diff checks pass.
- The exact source-only debug APK is 33,834,881 bytes with SHA-256
  `dd891d78ffcd16fed258631ce9e92db95e343e2775e838ae97d3fe8d112ca3e2`.

Key source SHA-256 values:

- extraction header: `77a05e676b2f7e36d591346ef2ad6924ee893c0dc54eec47bdb0f9ca339d0f30`
- extraction implementation: `460ff62395a8ff405e2c93a00806e450f7fde7880edd292047c43f528900f047`
- JNI owner: `dc14d06658e278661b69b9bebc95b9d13fb8e734f33287df85ddd0d803a6d90b`
- Java extraction owner: `142ba8f2072567273fac5ac88b0324fe1e86576f44167792d6568905991f9c7e`
- install pipeline: `8d1867300b1d6f3027de0f125cdf4d7e116e0041c5020bc7a3e63f8de8981345`
- native test: `3eb25521b7a79f69b2ba016527f1f0fb25672b96452f1059e304ec555abe07c8`
- extraction runner: `06e00a50a051cf696bf21b0b4e4178ba7256349913486e4f784963d044879aab`
- pipeline runner: `bd35c76c27e13e3e8cbd85d679dd7fba6eadf9176e1295e6255d6032a04b9351`
- packaged license: `675181c03fc1302a1c8554c00f7be9bb420c5dbc9dcc2013433cec144413de03`

## Classification

**Pass for bounded Android ZIP extraction, JNI cancellation/progress, exact
staging cleanup, content-validation gating, and atomic activation contracts.**
This does not prove the 1.86 GB production archive, a durable download worker,
real process death during active work, complete Retro Rewind gameplay, or
physical hardware. A2 and A3 remain open. No APK/AAB, archive, private data,
device identifier, or raw capture was published.
