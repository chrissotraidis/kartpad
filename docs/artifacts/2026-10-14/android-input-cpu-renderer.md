# Android input, CPU cost and character rendering — 14 October follow-up

Unreleased work in [KartPad #474](https://github.com/chrissotraidis/kartpad/pull/474)
and [WiiCompiled #7](https://github.com/chrissotraidis/wiicompiled/pull/7).
No physical iPad was used. Both PRs remain draft; 0.8.1/263 is still public.

## Short taps and first launch

`KPADRead` and `KPADGetUnifiedWpadStatus` consumed the same pending touch edge.
A press/release between polls could reach the first reader and disappear before
the other sampled it. Each reader now has its own pending-bit set. Held buttons
remain held; focus loss clears both sets. Tests cover either reader order,
repeated reads, held buttons and clearing, using the production touch source.

The earlier apparent title-screen stall also involved Android's fullscreen
tutorial and the game's idle demo. The original run recovered to license
selection in the same process after leaving the demo; no permanent focus
deadlock was established. Clearing the disposable emulator's NAND or shader
cache did not reproduce a persistent failure. Do not attribute all of those
observations to the short-tap defect.

The final private APK passed a normal extracted-folder import through Android's
Files picker on a clean API 34 app-data installation. After dismissing Android's
fullscreen tutorial, short taps reached new-license creation and a Luigi Circuit
Grand Prix race without restarting the native game process. Acceleration and
Home/resume worked in that same process. This replaces the earlier seeded-data
first-launch limitation with a normal-import smoke result, not complete-cup or
affected-handset acceptance. Final release-signed update/fresh checks still apply.

## CI

The Android fork inherited desktop workflows for targets it intentionally no
longer builds. Its workflow now retains translator build/tests and compiles and
links the complete maintained Android runtime through KartPad's pinned tools
and hash-verified dependencies, without private game inputs. Production behavior
contracts run with ASan/UBSan where supported. GNU/BSD byte-count portability and
the hosted runner's SDK-manager path were corrected during validation.

Both jobs pass on runtime `ac118be0d71c8c9d41ceab08c1a67ba661150a27`:
[run 38516183280](https://github.com/chrissotraidis/wiicompiled/actions/runs/38516183280).
This repairs the maintained Android lane; it does not fix or waive the old
desktop Dawn checksum mismatch. No dependency checksum or architecture guard
was bypassed. KartPad's boundary, receipt and regression checks also passed on
`83096695`.

## #470: cheaper vertex repacking

Both supplied Adreno 810 logs use all-draw repacking. The new loop visits one
attribute across the vertices, rather than testing every attribute for each
vertex. Formats, bounds handling and output bytes are unchanged. The known
Adreno 8xx rendering policy remains enabled.

`scripts/test-android-vertex-repack.py` extracts the production implementation,
runs its golden cases under ASan/UBSan, and offers an optimized microbenchmark.
Character, NBT3, 16-bit indexing, byte order, direct fixed-point input, out-of-range
attributes and identical-layout copying pass. Baseline and candidate output
hashes match in every benchmark case.

Quiet-host Apple Silicon CPU results, median of seven samples, nanoseconds per
call (synthetic data; **not Android FPS**):

| Vertices | Track before / after | Character before / after |
| ---: | ---: | ---: |
| 3 | 108.3 / 90.6 | 108.6 / 92.2 |
| 32 | 1,068 / 758 | 1,103 / 770 |
| 256 | 8,666 / 5,778 | 8,562 / 5,869 |
| 2,048 | 69,532 / 45,782 | 68,791 / 47,096 |

Reversing run order gave the same direction: roughly 27–34% less time for the
32–2,048-vertex cases, with matching bytes. This is a measured reduction in one
CPU routine, not a measured game speedup or identification of #470's regression.
Matched Adreno 810 race/profile/thermal evidence remains outstanding.

## Missing characters: separate native bone-index experiment

The new developer-only `KARTPAD_RENDERER_VERTEX_PNMTX=1` / Android
`debug.kartpad.vertex_pnmtx=1` path feeds the GX bone index through a native
`Uint32` vertex attribute. Eligible draws need a four-byte slot and stride;
odd-stride, expanded-line and constant-index draws retain their existing path.
The matrix arithmetic is unchanged. It is off by default and has no public
settings entry. It is separate from the matrix-rows option that failed on S24.

Renderer probe 0.3.0 now uses the game's current hash-verified Dawn archive.
Four compute and eight draw variants pass all **49,152** synthetic checks on
Android 14 ARM64 Vulkan SwiftShader, with WebGPU validation enabled and no
mismatches. Draws compare storage-pulled and native-attribute bone indices with
scalar/vector uniforms, robustness on/off, dynamic offsets and four queued
buffer/texture updates. The previous probe rejected software devices to avoid
an old Dawn assertion; the maintained dependency contains that correction and
the report now explicitly labels software adapters.

The runtime compiles and logs eligible native-attribute shaders in the real
game with all-draw repacking forced. With renderer validation and robustness
explicitly enabled, API 34 draws the full character in selection, reaches a
Luigi Circuit race, accepts acceleration and resumes after Home in the same
process, with no validation error or native abort in the captured logs. A synthetic pass cannot establish a fix on
Adreno 619/750 or the unidentified GPU in #472. Keep those reports open and do
not enable this by default without affected-device evidence.

Follow-up source review confirms that diagnostic draws call the same
`gx::render` function, including the native vertex-buffer binding. Persistent
pipeline records contain configurations that are rebuilt through
`gx::create_pipeline`; they do not reuse a shader compiled with a different
experiment setting. The setting is read once per process, so changing it requires
a restart. No additional shader-cache or self-check correction was needed.

## New Mac build report #475

The report fails a certificate check during PadMint preflight, before game
compilation. KartPad's Mac recipe called a shell wrapper that selected `python3`
from PATH, even if PadMint itself used Apple's Python. The recipe now passes
PadMint's own interpreter directly, as the iOS recipe already does.

A fixture places a failing `python3` first on PATH: the old wrapper chooses it,
while the updated manifest runs the supplied Apple interpreter with the correct
bootstrap arguments. Apple's Python also accepts the manifest through PadMint's
validator; 35 builder tests and 11 subtests pass. Certificate verification stays
enabled. This fixes a reproducible interpreter-selection defect, not a confirmed
cause of that player's TLS failure. Reporter confirmation and the normal clean
PadMint player check remain required before a release claim.

## Evidence and remaining gates

- Full repository suite: **354 tests and 221 subtests passed**. One expected
  duplicate-ZIP fixture warning. Touch, scheduler, keyboard expiry (73,728
  comparisons), vertex repack and shared-runtime parity checks pass.
- Final private debug APK: `build/followup-final-20261014/20261014-142117/out/`,
  SHA-256 `db2b0fe187f71631aeacd9400a1bfb64166cb0d5a78bb9917f750290144e1b5a`.
  Runtime staging verified against `ac118be`; matching game pack rebuilt for
  fingerprint `be0d8dbc904bf3725498d4d8691e6354c5baedb6b7cf2fce86e809f67e9910b4`.
  This APK contains private translated code and is not a public release artifact.
- Private logs/benchmarks are in `private/followup-20261014/`; screenshots in
  `build/perf/ui/`. No game data, saves or player/device identifiers are committed.
- Still needed: affected Adreno graphics/performance evidence, Thor confirmation,
  Retro Rewind coverage, final release artifact audits and update/fresh races,
  and PadMint's clean pre-tag and published player checks. No Apple release
  package or new version is produced by this pass.
