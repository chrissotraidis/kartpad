# Android A3 free-space preflight

Date: 2026-09-04

## Scope

This source-only A3 slice adds deterministic storage-capacity accounting for a
future Android Retro Rewind download worker. `RetroRewindSpaceProbe` obtains
filesystem identity from `stat(2)` device IDs and capacity from Android's
app-private files and cache directories, then delegates policy to the pure Java
`RetroRewindSpacePreflight` evaluator.

The evaluator retains a 256 MiB reserve. When files and cache share a
filesystem, it requires the pinned archive size plus the maximum expanded size
plus one reserve. On separate filesystems, the files store must independently
hold the maximum expansion plus a reserve, and the cache store must hold the
archive plus a reserve. Checked addition fails closed on overflow.

For the generated 6.12.5 release contract, the same-filesystem requirement is
exactly 4,327,477,355 bytes:

- archive: 1,859,041,899 bytes
- maximum expanded content: 2,200,000,000 bytes
- reserve: 268,435,456 bytes

## Verification

- `./scripts/test-android-retro-rewind-space.sh` passes under the pinned JDK
  with Java warnings treated as errors. It covers exact capacity boundaries,
  one-byte shortages for shared/files/cache stores, invalid inputs, arithmetic
  overflow, probe failure, and the exact production requirement.
- `./scripts/test-android-retro-rewind-content.sh` passes.
- `./scripts/test-android-retro-rewind-storage.sh` passes.
- `PYTHONPATH=builder python3 -m unittest -q tests.test_kartpad_builder tests.test_tvos_contract`
  passes 30 tests with one optional private-input skip.
- Public debug assemble, release Kotlin/Java compilation, and debug lint pass
  against the prepared pinned Dawn distribution.
- `./scripts/audit-android-package.sh` passes for the source-only debug APK.
  It is 33,675,275 bytes with SHA-256
  `700b899ed7ee22ecb87837542100427dd99ed5829b8b8d0615a50c38a3df7994`.
- Repository safety, shell syntax, and `git diff --check` pass.

## Classification

Pass for the Android free-space policy and Android filesystem/capacity probe.
This is not download, extraction, worker-lifecycle, installed Retro Rewind, or
runtime acceptance evidence: no production caller invokes the probe yet. A2
and A3 remain open. No APK/AAB or private data was published.
