# Android A3 resumable archive download

Date: 2026-09-04

Branch: `codex/android-a3-resumable-download`

Baseline: `6a7db19833cbe0eb1e5588994a128db8a368169e`

## Falsifiable subgoal

Preserve a bounded, version-scoped partial Retro Rewind archive across network
loss or application process death, resume it only from an exactly validated
HTTP byte range, and still accept the final archive only after its complete
size and SHA-256 match the profile. Do not fetch or publish the production
archive.

## Result

- Replaced random throwaway transfer files with the exact app-private
  `.RetroRewind-6.12.5.part` path. A regular partial shorter than the pinned
  archive is reusable; oversized, complete-but-corrupt, symlinked, or
  non-regular state is reset without following links.
- A resumed request sends `Range: bytes=<verified-size>-`. A `206` response
  is accepted only when `Content-Range` exactly covers that offset through
  byte 1,859,041,898 of the pinned 1,859,041,899-byte representation. Decimal
  overflow, an unexpected start/end/total, non-identity encoding, or a
  contradictory declared length fails closed.
- If a conforming server ignores `Range` and returns the full representation
  with `200`, the partial is truncated and safely restarted at byte zero.
  Redirects remain HTTPS-only and bounded.
- Resume hashes the existing prefix before appending new bytes. Network loss
  and cancellation preserve the partial; permanent HTTP/integrity failures
  discard it. Final publication still requires a complete streamed SHA-256 and
  byte-count check followed by an atomic move.
- A valid already-published archive removes any redundant stale partial.

## Verification

- The warning-as-error host harness proves fresh transfer, prefix append,
  progress beginning at the cached offset, a second resume after injected
  network loss, wrong-offset refusal without mutation, exact and malformed
  `Content-Range`, decimal overflow, valid-complete reuse, oversized/corrupt
  reset, and symlink replacement with an untouched target.
- Fake HTTPS connections prove the exact outgoing `Range` header, a valid
  `206` remainder, safe `200` restart/truncation, and rejection of a
  mismatched range without changing partial bytes.
- A debug Android fixture resumed a 22-byte file from a seven-byte prefix and
  verified the final digest on wiped API 36 / 4 KiB and API 35 / 16 KiB ARM64
  AVDs. Both runs also passed all existing worker, extraction, memory,
  scheduler/fiber, controller, Vulkan, orientation, and lifecycle markers.
- A stronger wiped API 36 fault run used the actual append path inside the
  durable worker. It persisted seven bytes, force-stopped KartPad, confirmed
  the process was absent, then restarted the same UUID at attempt 1 from byte
  7 and completed the verified 92-byte fixture.
- A body-free HTTPS `HEAD` request to the exact profile URL returned 200,
  `Content-Length: 1859041899`, `Content-Type: application/zip`, and
  `Accept-Ranges: bytes`. This confirms current metadata only; it does not
  prove a ranged GET or download any archive content.
- All seven Android A3 contract runners, public assemble/release compilation,
  API-28 lint, private game-runtime Kotlin/Java configuration compilation,
  strict package/privacy audit, the 22-test builder suite, SunPad snapshot,
  repository safety, shell syntax/lint, and diff checks pass. No ADB target
  remains.
- The exact source-only debug APK is 33,843,921 bytes with SHA-256
  `f5b001c206abb5dd05bc0c58f8f6e6f2b5c684361ccaaa0f079f259e9f173364`.

## Classification

**Pass for safe partial persistence, exact HTTP range negotiation, prefix
rehashing/appending, fallback restart, and verified resume after real app
process death on the emulator.** This does not prove the official server's
range behavior, the 1.86 GB production transfer, UI cancellation, complete
production interruption/full-disk tests, Retro Rewind gameplay/mode switching,
or physical hardware. A2 and A3 remain open. No APK/AAB, production archive,
private data, device identifier, or raw log was published.
