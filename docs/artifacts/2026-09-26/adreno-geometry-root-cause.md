# Adreno character geometry: most likely cause and candidate fix — 26 September 2026

Scope: Android character-model corruption on Qualcomm Adreno ("vertex explosion", missing or stretched bodies with eyes still drawn) in #104, #193, #211, #316, #308, #102, #137, #323 (and the Adreno 619 case in #216's thread). Mali (Pixel, Galaxy A32) and Apple GPUs render the same scenes correctly. This is a source, compiler and host analysis. Nothing was installed on a device, published, or pushed.

## 1. Most likely cause

The broken draws are exactly the draws whose vertices carry their own position-matrix index (`PNMTXIDX` sent directly per vertex): skinned character bodies. Rigid parts (eyes, karts, tracks) use one matrix per draw and are fine. In the failing recipe `58866e32bada1f83` (and `33c5ff18d5c180e0`) the generated vertex shader does this for every vertex:

```
let in_pnmtxidx = (raw_fetch_u8_1(&vbuf, ubuf.vtx_start + vidx * 7u + 0u) / 3u);
let in_pos = fetch_f32_3(&abuf, ubuf.array_start[0] + raw_fetch_u8_1(&vbuf, ubuf.vtx_start + vidx * 7u + 3u) * 12u, false);
let in_nrm = fetch_s16_3(&abuf, ubuf.array_start[1] + raw_fetch_u8_1(&vbuf, ubuf.vtx_start + vidx * 7u + 4u) * 6u, 14, false);
let mv_pos = vec4f(in_pos, 1.0) * ubuf.postex_mtx[in_pnmtxidx];
```

So each vertex reads single bytes out of 32-bit words at an odd stride (7) and an unaligned base, then uses those bytes as addresses for a second, dependent storage-buffer read, then uses a byte as a dynamic index into the uniform matrix array.

Source evidence (Android runtime, before this change):

- `aurora-main/lib/gx/shader.cpp:726` (`attr_load`): indexed attributes become `array_start + raw_fetch_u8/u16(&vbuf, …) * stride` into `abuf`; line 746 makes `PNMTXIDX` `raw_fetch_u8_1(...) / 3u`.
- `shader.cpp:992`: `mv_pos = … * ubuf.postex_mtx[in_pnmtxidx]`.
- `shader.cpp:1715` (`load_u8`), `1733` (`load_u16`, cross-word path when a 16-bit value straddles two words), `2092`/`2094` (`vbuf`/`abuf` are raw `array<u32>` storage buffers).
- `gfx/common.cpp:1671`: `push_verts` uses alignment 0, so `vtx_start` itself is usually not 4-byte aligned after any odd-sized draw.

Why the fetch path rather than the matrix lookup:

- The build 121 comparison already ran on affected phones. #193 logs show `KartPadPNMTX draw_binding … variant=literal` bound to both target pipelines, and the corruption was unchanged; #102 also reported no change. The literal variant replaced only the matrix lookup with a 20-case switch. The byte and dependent array reads were identical in both variants.
- `KartPadDrawCheck` samples in #137 (Adreno 840) show valid indices and finite matrices on the CPU side, so the inputs are correct before the GPU reads them.
- Renderer Check 0.1/0.2 passed on Adreno 750 (512.762.41) and 840, but used synthetic layouts, not this chain of odd-stride byte reads feeding a dependent storage read in a real game shader.
- Outside precedent: Bevy #24926 reports skinned meshes corrupted on Adreno 730 Vulkan only when skinning data came from a storage buffer read in the vertex shader. Dawn's default Qualcomm workarounds do not cover this pattern.
- #323 (Snapdragon 8 Gen 3) reports that some characters look right at first and disappear races later. That fits a driver problem sensitive to buffer placement (the unaligned `vtx_start` moves with everything drawn earlier in the frame) better than a fixed miscompile of one shader.

This remains an inference. No Adreno device reproduced it here, and the Adreno compiler could still be mishandling the matrix index itself (for example by folding the literal switch back into an indexed load). The candidate below removes every fetch-path difference while keeping the matrix lookup, so an on-device A/B separates the two.

## 2. Candidate fix (implemented, local only)

Android runtime `vendor/runtimes/android`, branch `codex/android-input-menu-20260926`, commit `a4befb7` (not pushed).

For triangle draws with `PNMTXIDX` direct, the CPU resolves every indexed attribute and uploads a repacked vertex in which everything is direct and 4-byte aligned:

| Attribute | Before (recipe 58866) | After |
|---|---|---|
| Matrix indices (PNMTX, TEX1/2 MTX) | 1 byte each, offsets 0-2 | same byte in a zero-padded 32-bit slot, offsets 0/4/8 |
| Position | 8-bit index into `abuf`, f32 | direct big-endian f32 at 12 |
| Normal | 8-bit index into `abuf`, s16 frac 14 | direct f32 at 24 |
| Color 0 | 8-bit index into `abuf`, RGBA8 | direct original bytes at 36 |
| Texcoord 0 | 8-bit index into `abuf`, s16 frac 14 | direct f32 at 40 |
| Stride / start | 7 bytes, unaligned start | 48 bytes, start aligned to 4 |

The vertex shader then does only aligned, independent reads from `vbuf`. The matrix lookup is unchanged. It uses existing generator paths: direct f32 and direct byte fetches. There is no new shader code.

Files:

- `lib/gx/kartpad_vertex_repack.{hpp,cpp}` (new): enable decision, layout rewrite, packer, rate-limited log.
- `lib/gx/gx.cpp/.hpp`: the vertex-layout loop of `populate_pipeline_config` is factored into `populate_vertex_layout`, so the pipeline and packer share one source layout. Behaviour is unchanged.
- `lib/gx/command_processor.cpp`: `resolve_pipeline_state` rewrites the layout for eligible draws. `handle_draw` and `submit_raw_draw` upload the repacked bytes with `push_verts_aligned`, and staging admission counts the repacked size plus 3 bytes of padding. CPU-side audit, interpolation and matrix-usage scans still read the original vertices.
- `lib/gfx/common.cpp/.hpp`: `push_verts_aligned`.
- `lib/webgpu/gpu.cpp/.hpp`: `g_adapterIsQualcomm` (vendor ID 0x5143, or "Adreno"/"Qualcomm" in the adapter strings).
- `cmake/aurora_gx.cmake`, `tests/`: build list, host tests, and one missing host stub (`pipeline_scene_generation`, a pre-existing link break).

Gate: on by default only for Qualcomm adapters, and read once per process. Overrides:

- `KARTPAD_RENDERER_VERTEX_REPACK=1` or `0` (environment, any platform)
- On Android, `adb shell setprop debug.kartpad.vertex_repack 1` or `0`, then restart the game process. This forces it on for Mali testing or off for an Adreno A/B without app changes.

Log lines (console.log, `aurora::gx::fifo`):

- Once per launch: `KartPadPNMTX repack mode=auto|forced_on|forced_off qualcomm=<bool> enabled=<bool>`.
- Once per repacked recipe, up to 24: `KartPadPNMTX repack active source=<original recipe hash> pipeline=<repacked hash> src_stride=7 dst_stride=48 report=n/24`.

Behaviour differences to keep in mind:

- **CPU cost.** It applies only to PNMTXIDX-direct draws, but is not yet measured. Measure it on the Pixel battle scene with the property forced on before shipping.
- **Array reads.** The packer reads attribute arrays from guest memory at draw time. The GPU path uses a snapshot taken at the first draw after a frame start or after `GXInvalidateVtxCache`. Both see the same data unless the game rewrites an array mid-frame without invalidating, and in that case the packer is closer to hardware.
- **Pipeline recipes.** Repacked recipes have new hashes, so pipelines recorded earlier on Adreno phones will compile on first use again until they are re-recorded.
- **Unchanged draws.** Lines/points and non-PNMTXIDX draws are untouched.
- **Existing diagnostic.** With `KARTPAD_RENDERER_CONST_PNMTX` also set, the old draw_binding lines no longer match their target hashes. Use the new `repack active source=` line instead.

## 3. Verification

Done here:

- **Android compile.** The seven changed or dependent translation units (`command_processor`, `kartpad_vertex_repack`, `gx`, `gpu`, `common`, `shader`, `shader_info`) compile without warnings, using the exact NDK 29 release flags from the android220 build's `compile_commands.json` (script: `work/adreno-geometry-20260926/compile_tus.py`). No APK was linked.
- **Host tests.** `gx_fifo_tests` against the submodule: 245 pass, 1 skipped, 4 fail. A baseline built from the submodule HEAD before this change (plus only the same link stub) shows the identical 4 failures and 243 passes: the copy/clear resolve tests and `DrawTopologyTemplatesPreserveExactGxIndexOrder`. The two new tests are the difference. They check the 58866 recipe layout, 16-bit indices, NBT3 normals, little-endian RGB565, and out-of-range indices against values computed by hand.
- **Shader.** The retained real 58866 WGSL, rewritten to the repacked fetches the generator emits, compiles with the host Tint from the pinned Dawn. The repacked vertex stage declares one storage buffer (`vbuf`) instead of two and does 10 storage loads instead of 13.

Without an Adreno device:

1. On the Pixel (Mali), `adb shell setprop debug.kartpad.vertex_repack 1`, restart KartPad, and capture character select plus a 12-racer starting grid. Then set the property to `0` and capture the same scenes. The two should match; CPU rounding differences are possible but should be far below a pixel. Record game CPU per present for both runs to measure cost.
2. On the Mac or iPad build, `KARTPAD_RENDERER_VERTEX_REPACK=1` gives the same comparison on Metal.
3. The log must show `repack mode=forced_on … enabled=true` and `repack active source=58866e32bada1f83 …`.

On an Adreno reporter's phone, a build with this change should log:

```
KartPadPNMTX repack mode=auto qualcomm=true enabled=true
KartPadPNMTX repack active source=58866e32bada1f83 pipeline=… src_stride=7 dst_stride=48 report=1/24
```

Together with correct character bodies in the same scene, that line confirms the fetch path as the cause. If bodies are still broken with that line present, the fetch path is excluded, and the remaining difference is the per-vertex dynamic uniform index. The next candidate would then be full CPU skinning: transform positions and normals on the CPU and draw with the current matrix. A `debug.kartpad.vertex_repack 0` run on the same Adreno phone gives the matched "before".

## 4. Not done

- **`gpu_fetch_check` (GPU readback of fetched values) was not implemented.** WebGPU vertex shaders cannot write storage buffers, and a compute-shader copy of the same fetch code would not exercise the vertex stage where the bug appears to live. The synthetic Renderer Check compute and draw tests already passed on Adreno 750/840. The on-device A/B above, using the two log lines, answers the same question without adding readback plumbing to the frame encoder.
- **No APK was built, and nothing was installed or pushed.** The root gitlink records the local commit only.
