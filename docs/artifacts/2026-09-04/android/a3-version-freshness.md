# Android A3 Retro Rewind version freshness

Date: 2026-09-04

Branch: `codex/android-a3-version-freshness`

Baseline: `5105d99`

## Falsifiable subgoal

Before Android allocates installation space or requests any archive byte, fetch
the profile-owned official version manifest through a bounded HTTPS client.
Continue only when the feed is valid and no newer version exists; fail closed
with a specific KartPad-update message when the compiled profile is stale.

## Result

- Android's generated release contract now includes the same official version-
  manifest URL used by the Apple product, sourced from the sole checked-in
  profile rather than a second hand-maintained constant.
- The worker checks freshness after safe storage recovery and before capacity
  preflight/download. A newer valid version returns `version-update-required`
  plus only the validated version string. Invalid, unavailable, insecure, or
  oversized responses fail without touching archive state; the existing Retry
  UI remains available.
- The client permits HTTPS only, disables automatic redirects/content encoding,
  bounds redirects to five, applies 15-second connect/read timeouts, caps the
  body at 512 KiB even when length is unknown, requires strict UTF-8, and checks
  cancellation before and during streaming.
- Version parsing accepts two to four numeric components and compares arbitrary-
  precision components without integer overflow, within a 64-character result
  bound suitable for WorkManager data. Every nonempty feed line must be valid,
  matching the existing fail-closed Apple behavior.

## Verification

- The host contract covers current/newer/older and zero-padded versions,
  arbitrary-length numeric components, malformed lines, invalid UTF-8, declared
  and streamed oversize, HTTPS and insecure redirects, redirect exhaustion,
  HTTP/network failures, compression, and cancellation before/during read.
- Both the host JVM and a wiped API 36 / 4 KiB AVD reached
  `https://update.rwfc.net/RetroRewind/RetroRewindVersion.txt`; each reported
  official version `6.12.5`, equal to the compiled pin. The Android run waited
  for verified emulator DNS/network readiness before testing the platform TLS
  path. No archive URL was requested.
- The same wiped run retained the PR #55 UI result: bounded worker UUID
  `0b41fe6c-0508-4315-a41f-85e777ce577d` exposed an actionable foreground
  notification, accepted the real Cancel control, reached terminal `CANCELLED`,
  emitted no completion marker, and restored that state after force-stop/open.
- All eight source A3 contract runners, debug assemble, source-only release
  compile, API-28 lint, private game-runtime debug/release compile, strict APK
  audit, 22 builder tests (one expected private-payload skip), SunPad snapshot,
  repository safety, shell lint/syntax, and diff checks pass.
- Source verification validates all 446 patch hunks plus WiiCompiled, SunPad,
  and WheelWizard, then reaches the unchanged ignored local `rr-pulsar`
  mismatch (`b566a5d` present versus `29e76d4` pinned). This branch neither uses
  nor modifies that checkout.
- The exact source-only debug APK is 33,843,921 bytes with SHA-256
  `391f183e6fd4aebb540ad561c6fef436a4bf9cfe1857f205e7480e3e911389e2`.

## Classification

**Pass for profile-generated Android version metadata, bounded official-feed
transport/parsing, Android TLS execution, and stale-profile blocking before
archive acquisition.** The newer-version decision is fixture-tested, but its
rendered UI cannot be observed against today's current feed. Normal startup
still lacks the dual-mode chooser and installed-version fallback action.
Production archive/install
faults, Retro Rewind gameplay/mode switching, and physical hardware remain
open. No APK/AAB, archive, private data, device identifier, or raw log was
published.
