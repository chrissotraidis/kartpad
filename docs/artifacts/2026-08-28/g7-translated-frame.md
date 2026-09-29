# Provisional translated Metal frame evidence

This is useful G7 bring-up evidence, but **not G7 acceptance**: it uses a synthetic translated command fixture and direct Metal, not Dawn/Aurora, translated GX geometry, or a game frame.

- Pinned translator emitted the synthetic `func_80001000.cpp` exactly from a no-game-data DOL (now regenerated in tests and checked against `fixtures/g7/func_80001000.sha256`).
- The translated function now writes the shared checked-memory `KPGX` command at `0x80010000`.
- This older direct-Metal boundary fixture consumes its `102030FF` clear field into a 256×192 AppKit/CAMetalLayer drawable with Metal API Validation enabled.
- Every BGRA output pixel matched; updated captured PNG SHA-256 is `e81ee98d4af9b2e93a7d02cce493fb695caa4c36e639db24b5825a71673d8cf7`.
- Capture: `docs/artifacts/2026-08-28/g7-translated-frame.png`.

The first build failed under `-Werror` because a CoreGraphics enum was combined with an integer bitwise expression. Explicit `uint32_t` conversions resolved that compile-time type mismatch; the successful run followed after the code changed.
