# What the current graphics tests miss

This follow-up audits the tests rather than assuming that more successful shader compilations establish correctness. It finds concrete coverage gaps, not a proven cause of the missing character body.

## Confirmed gaps

### 1. The indexing comparison does not remove all dynamic matrix indexing

Both reported recipes, `58866e32bada1f83` and `33c5ff18d5c180e0`, retain **two dynamic texture-matrix reads** in both generated variants:

`ubuf.postex_mtx[in_texmtxidx1 / 3u]` and `ubuf.postex_mtx[in_texmtxidx2 / 3u]`.

The compatibility switch replaces position/normal indexing only. Texture-coordinate generation also normalizes each of those transformed vectors. The existing draw audit checks direct PNMTX selection and selected position/normal matrix finiteness; it does not inspect these texture indices, resulting coordinates, indexed vertex/normal data, or post-transform positions.

**Correct interpretation:** a negative compatibility result does not clear dynamic matrix indexing generally. A positive result narrows the position/normal path but still needs confirmation that the changed draw belongs to the missing object. The test remains useful within that narrower scope.

### 2. Invisible does not establish malformed geometry

Recipe `58866e32bada1f83` discards fragments when rounded final alpha is below 128. In its generated fragment stage, final alpha follows the base texture sample through the TEV operations. A wrong texture/binding/sample could therefore remove pixels even with valid position matrices. This is a causal possibility, not evidence of a bad texture in the reporter's session.

Recipe `33c5ff18d5c180e0` has no explicit shader discard. Both bundled configurations enable back-face culling, GX_LEQUAL depth comparison, depth writes and color writes; blending is GX_BM_NONE. A compiled shader and encoded draw do not prove that fragments survive clipping, culling, depth testing and material evaluation.

Neither recipe has been positively identified as the missing body draw. Reaching a recipe in a session is not that identification. The alpha-tested recipe could be another part of the character or scene.

### 3. WebGPU validation is not native Vulkan validation

Both maintained mobile `webgpu/gpu.cpp` files explicitly set Dawn's `backendValidationLevel` to `Disabled`. The existing diagnostic switch controls WebGPU validation and shader robustness. These are separate layers. A log saying `validation-and-robustness` must not be read as proof that Vulkan synchronization, native resource use or GPU-assisted validation ran.

Android also excludes `use_user_defined_labels_in_backend` from its normal toggle list. That makes future native capture attribution harder; the reason for that historical choice should be checked before enabling it broadly.

The Android diagnostics build enables WebGPU validation independently of the Character Graphics Test selector. Original and compatibility do not secretly toggle that validation setting differently; that possible confound was checked and rejected.

## Obvious platform mistakes checked without finding a defect

- **Missing host-memory flush:** Aurora uses Dawn mapped staging buffers, unmaps them, and records buffer copies. It does not directly own these Vulkan mappings. A generic recommendation to add `vkFlushMappedMemoryRanges` to Aurora is not justified. Queue ordering and frame/resource lifetime still require actual failing-frame evidence.
- **Forgotten Vulkan Y convention:** Dawn's Vulkan command encoding negates viewport height and adjusts its origin. There is no evidence here for adding another blanket Y flip to the application. Culling remains a draw-specific check.
- **A single alpha-test explanation for both recipes:** rejected; only one contains explicit discard. Do not replace the matrix assumption with an equally unproven texture assumption.

## Research-backed change in method

[RenderDoc's mesh workflow](https://github.com/baldurk/renderdoc/blob/v1.x/docs/python_api/examples/renderdoc/decode_mesh.rst) exposes geometry before and after the vertex stage. Combined with the draw's state and textures, an actual failing-frame capture can separate missing submission, bad input, bad transform and later rejection. This is materially different from another compiler test or ordinary log dump.

[RenderDoc's Android instructions](https://github.com/baldurk/renderdoc/blob/v1.x/docs/how/how_android_capture.rst) require a debuggable package and host tooling. It is a developer/technical-volunteer route, not an honest one-button workflow for every reporter. Do not request public frame captures: they can contain game assets. The owner's lack of an Android phone does not prevent a willing affected reporter from supplying this evidence privately.

[Android's native validation documentation](https://developer.android.com/ndk/guides/graphics/validation-layer) describes packaging the Khronos validation layer or loading an external layer. Simply changing the Dawn enum does not establish that a compatible layer is installed or running. A dedicated capture build needs explicit layer availability/activation evidence before its output is called native validation.

[Vulkan's depth documentation](https://docs.vulkan.org/guide/latest/depth.html) and [synchronization examples](https://docs.vulkan.org/guide/latest/synchronization_examples.html) support checking rejection and resource visibility separately from shader compilation. They do not establish a KartPad bug.

## Next evidence must answer one complete question

For one visibly failing frame, identify the missing object's draw and determine where it disappears:

1. Was the draw actually issued, with the intended vertices, indices and bindings?
2. Do post-vertex positions form the expected object inside the view volume?
3. If so, does culling/depth reject it, or does material/texture evaluation make it invisible?

Prefer a native frame capture with a willing technical reporter. If that is impractical, an in-app bounded capture must reproduce these same distinctions, correlate them to a screenshot/frame and retain only the necessary evidence. A series of unrelated startup probes does not substitute for this. This document does not claim such a capture feature has been implemented.

Do not send additional generic log requests or treat a failed position/normal indexing comparison as an exhausted investigation. The immediate correction is to narrow the interpretation of existing tests and stop using their success to exclude boundaries they never observed.

## Local evidence

`build/platform-investigation/test-blind-spots.json` contains decoded pipeline state and generated-source counts from both variants. `inspect-recipe.cpp` reads configurations through the actual maintained `PipelineConfig` definition and its validation routine, rather than guessing struct offsets. Raw configurations and generated shaders remain local. Committed metadata is in `graphics-test-blind-spots.json`.
