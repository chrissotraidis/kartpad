# Android A3 pinned archive download

Date: 2026-09-04

## Scope

This source-only A3 slice adds acquisition of the sole profile-pinned Retro
Rewind archive. The Android owner accepts only HTTPS, follows at most five
HTTPS redirects, requests identity transfer encoding, applies 30-second connect
and read timeouts, and requires an HTTP 200 response. A declared content length,
when present, must match the generated archive byte count.

The response is streamed through a 1 MiB buffer into a uniquely created
app-cache partial file. The stream cannot exceed the pinned byte count and must
finish at that exact count with the pinned SHA-256. Cancellation is checked
between reads. Only a verified result is atomically moved to the stable cache
name; failures and cancellation never promote the partial file. An existing
regular, non-symlink archive is reused only after the same exact size/hash
verification.

The manifest now declares only `android.permission.INTERNET`. The package audit
was narrowed from “no permissions” to an exact one-permission allowlist, so any
additional Android permission still fails closed.

## Verification

- The pinned-JDK warning-as-error transfer harness passes exact content,
  persisted bytes, existing-file revalidation, short/long input, mismatched
  hash, cancellation, injected read/network loss, and symlink rejection.
- The earlier space, installed-content, and atomic storage/recovery matrices
  pass unchanged.
- Public debug assemble, release Kotlin/Java compilation, and lint pass at API
  28 compatibility. The first lint run correctly rejected Java `HexFormat`
  (Android API 34); the implementation now decodes the expected digest without
  that API and the rerun passes.
- Private game-runtime debug Kotlin/Java configuration compilation passes. No
  private APK was rebuilt or installed.
- All 30 builder/tvOS tests pass with one optional private-input skip, and the
  repository safety audit passes.
- The exact source-only APK is 33,675,275 bytes with SHA-256
  `88129b305de90f0588cbd93978ede89fc061010b2420f3beb344522607052b65`.
  ABI, alignment, native dependencies, assets, privacy, and the exact INTERNET-
  only permission allowlist pass the package audit.

Source SHA-256 values:

- downloader: `f40e0e98cb9f5ee3184721051c35526f338c83ea323d11961bb280fff52f5c30`
- transfer test: `40f83767851e4fbd993cbcaa2274439b9a7b76316c759c6543f51e6f3c931b95`
- test runner: `1b245dd476b477aa01b4882f5f715eed92ab07a53da196bdec3a69dcd9960197`
- manifest: `02b23d4dd38bede5180889b5e8f2137c47a3de56157894db4bd6072b924e4fc9`
- package audit: `35b6cb7a90a56f311b41f28c77327a2cff649adbfdf22e11db494a6f5d4cbe37`

## Classification

Pass for pinned HTTPS acquisition, bounded transfer verification, cancellation,
and atomic cache publication contracts. The 1.86 GB production archive was not
downloaded in this source-only test. No worker/UI invokes the downloader yet;
ZIP extraction, durable worker lifecycle/progress, process-death cleanup, and
Retro Rewind runtime acceptance remain open. No APK/AAB or private data was
published.
