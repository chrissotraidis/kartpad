# Character rendering investigation, 29 October 2026

No further production fix demonstrated. The separate six-bit selector correction cannot explain the S24 draw samples with valid selectors. This investigation preserves actual renderer regressions and narrows the remaining failure boundary.

## Preserved implementation

Runtime branch `codex/character-renderer-probes`, commit `042b969a56e8065a63f564995327d152f9f6103e` (merged in [runtime PR #14](https://github.com/chrissotraidis/wiicompiled/pull/14)), atop Android candidate `6e3ce40fba8faab8adbddad7933af67018e3d78c`. Only `aurora-main/tests/gpu_readback_test.cpp` changes; no app/runtime production code. It adds five synthetic fixtures to the existing GPU readback executable and a diagnostic isolation check. No captured geometry, uniforms, textures, game data or pipeline blobs are committed.

The five fixtures cover direct F32 position/normal, indexed S16 position plus S8 normal with RGBA8/RGB565 color, and the diagnostic 7/10-byte layouts with indexed big-endian F32 positions, S16 XYZ normals (fraction14), RGBA8 colors, and S16/U16 UVs (fraction14/15). They exercise all ten position/normal slots. The 7/10-byte fixtures also exercise all ten texture-matrix slots, separate TEX1/TEX2 selectors, two normalized normal-derived 3x4 texgens, postmatrices, three texture stages, spotlight attenuation, and alpha cutoff/lighting. The complete 16x16 readbacks must equal independently constructed color bands, not merely match each other. Assertions confirm the source strides and full 20 position/texture + 10 normal matrix layout after FIFO state updates.

The diagnostic check records three identical depth-writing `LESS` draws through the real self-check module. Every run produced 1024 covered pixels per copy and zero differing pixels. The production module allocates and clears a separate depth/color target inside each variant iteration, resets DrawEncodeState per pass, and copies viewport/scissor. Shared-depth contamination was not demonstrated; no diagnostic fix is proposed.

## Actual modes and receipts

Final committed source passed all five fixtures and the existing full GPU suite in each of these five modes (25 fixture runs). Each log reports `API: Metal` on Apple M3 Max.

| Mode | Requested environment | Actual receipt |
|---|---|---|
| Raw | none | repack mode off; attribute=false; rows=false |
| Repack | VERTEX_REPACK=2 | mode all_draws, src_stride7/10→dst_stride48 |
| PN attribute | VERTEX_REPACK=2, VERTEX_PNMTX=1 | attribute=true, padded48-byte layout |
| Explicit matrix rows | VERTEX_REPACK=2, MATRIX_ROWS=1 | rows=true, attribute=false |
| Constant matrix lookup | VERTEX_REPACK=2, CONST_PNMTX=2 | eligible constant lookup with two texture indices |

All environment names above have prefix `KARTPAD_RENDERER_`. Final logs are retained privately as `kartpad-character-committed-{raw,repack,attr,rows,constant}.log`.

Native-uniform coverage is NOT established. `KARTPAD_RENDERER_NATIVE_UNIFORMS=1` is only acted on by the Vulkan/OpenGLES branch of `gpu.cpp`; the earlier Metal run explicitly logged `native_uniforms=false`. The valid fourth mode is explicit rows only. Existing host Dawn package has `DAWN_ENABLE_VULKAN=OFF`; no local Homebrew Vulkan/MoltenVK loader was found. No fallback is reported as Vulkan, and no backend rebuild was undertaken.

Reproduction uses the already documented Dawn provider package/system SDL dependencies in [the selector record](matrix-selector.md). Configure the same isolated runtime host test build, build target `gx_readback_tests`, then run `<build>/tests/gx_readback_tests <fresh-cache-dir>` under each environment above. This executable always reports the actual adapter/backend; check the mode receipts before interpreting a result.

## Exact reported pipeline experiment (private)

The tracked Classic seed cache contains exact version 19, 2768-byte records matching reported hashes `58866e32bada1f83`, `33c5ff18d5c180e0`, `a053a041ae0a872e`. All use XYZ normals, not NBT/NBT3. Their vertex strides are 7, 7, 10; they have three texgens, including TEX1/TEX2-selected normalized normal-source transforms. The first two have three/four TEV stages respectively; the last has three.

A private test variant reconstructed the entire PipelineConfig from each record, asserted byte-for-byte equality and its original seeded hash before drawing, and used synthetic vertices/matrices/lights/textures. All 15 runs (three records × five supported modes above) returned nonempty 1024-byte readbacks. Within each recipe the readback buffer hash matched in all five modes:

| Record | Nonzero bytes | Readback XXH3 |
|---|---:|---|
| 58866e32bada1f83 |1024|91a9afd3ad9eb82e|
| 33c5ff18d5c180e0 |1024|91a9afd3ad9eb82e|
| a053a041ae0a872e |768|a02c4b2e6471d755|

This exercises the full supplied TEV/pipeline configuration instead of only an approximate shader. It is still synthetic uniform/vertex/texture input on Metal, not a replay of the reporter's failing draw or a Vulkan result. Result JSON, per-recipe/mode logs, the experimental source/loader and descriptors are retained privately in the task’s ignored `private/triage-20261029/character-renderer-evidence/` archive with a verified SHA-256 manifest. They are not staged or published. Earlier preliminary exact-config logs used an incorrect pointer-hash overload; all named final full-hash logs and JSON were replaced by verified byte-buffer hashing with `xxh3_hash_s`.

## Reporter boundaries

- S24 (#104) [first sample](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5707313589) and [second sample](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5715227609): each 31 bounded draws with pn_max_raw<=24, pn_outside=0, pn_nonmultiple=0 and no nonfinite positions/normals. Separate selector fix does not explain these.
- S24 [later native-uniform/rows report](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-6136220776): selected 378-vertex draw produced 583 pixels in each of all three variants, no difference, while missing bodies remained. A selected-draw match is not whole-character acceptance.
- #301 [144-vertex mismatch](https://github.com/chrissotraidis/kartpad/issues/301#issuecomment-5989232524): raw 2472 covered pixels, repacked 0, constant 0, strongly_differing 2284. This is a real diagnostic difference; the current local probes do not reproduce it and isolated depth does not explain it.
- PowerVR #304 [latest supplied diagnostics](https://github.com/chrissotraidis/kartpad/issues/304#issuecomment-5996163884): 81-vertex draw had 149544 covered pixels in both layouts and 149544 strongly differing pixels; constant copy matched the main layout. Different from the #301 zero-coverage outcome.
- OnePlus #472 [latest log and near/far observation](https://github.com/chrissotraidis/kartpad/issues/472#issuecomment-6294375665): PN-attribute option active, missing bodies persisted; self-check 81/87-vertex attempts had zero coverage. The report lacks paired near/far draw identity. Current “Simpler computer karts” source switches CPU archive/animation at race load and leaves players/ghosts/online opponents alone; it is not a distance-based model switch. Do not equate this option with the reported near/far boundary.

Useful remaining discriminator: compare the same nonempty character draw's raw/repacked inputs and output on Vulkan, with its actual near/far draw identity if investigating distance. A self-check match establishes equivalence for its sampled draw, not correct rendering of all character parts; #104 reports a match while bodies remain missing. Another generic option toggle or unqualified “send more logs” would not establish that boundary. No affected device is available in this task, and no further device request is being made.
