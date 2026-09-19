# Original Android versus iOS: investigation loop

## Result

The investigation narrowed the fault boundaries but did not demonstrate a graphics root cause. The strongest new result is that **all 1,193 bundled pipeline recipes produce byte-identical normal WGSL from the maintained iOS and Android generators when given the same recipe bytes**. This rules out a platform-specific source-generation mismatch for that corpus. It does not rule out a shared shader bug, different live recipes, corrupted inputs, resource lifetime faults, or different backend execution.

No speculative runtime fix or new public binary was made in this iteration. The earlier confirmed iOS diagnostic-validation correction remains separate from a graphics fix. Public Android build 119 and iOS build 51 are unchanged.

## Iterations and decisions

| Hypothesis | Check | Result and decision |
| --- | --- | --- |
| The first Android port omitted the established iOS patch stack. | Read `scripts/prepare-android-game-runtime.sh` at first release `v0.4.10-android.1` and the original Android runtime patch. | Preparation explicitly calls `prepare-ios-game-runtime.sh` with `KARTPAD_PREPARE_ONLY=1`, then layers Android changes. Reject the broad missing-patch-stack explanation; individual portability differences still need scrutiny. |
| New forced overlap or scalar exception bookkeeping caused the original corruption. | Compare #104's September 7 opening with integration commits. | `6a2dffc` forced overlap arrived September 10 UTC; `a850ada` scalar exception optimization arrived September 8. Neither explains the initial September 7 failure by itself. They could still influence current behavior. |
| Equivalent graphics recipes produce different shaders on Android. | Compile the actual maintained generators and feed both the same 1,193 version 19, 2768-byte bundled configurations. | 1,193 equal, zero different. The two recipes reached by the Samsung reports also match individually. Pursue upstream state and downstream backend boundaries, rather than inventing a missing generator fix. |
| The implicated shader forms are rejected by the shared compiler. | Build Tint from the pinned Dawn source; translate both target recipes, dynamic/literal indexing, vertex/fragment stages, robustness on/off, to SPIR-V and MSL. | All 32 checks pass. SPIR-V validation succeeds; additional eight explicit Metal validation runs succeed. This excludes these host compiler failures, not runtime miscompilation or invalid draw inputs. |
| The indexing experiment compiles back to an indistinguishable shader. | Inspect emitted SPIR-V. | Literal variants retain position/normal switches; the examined position cases call matrix loaders with literal offsets. Dynamic variants do not contain those switches. The experiment changes the host-generated program, but final vendor optimization remains unobserved. |
| Dawn treats Metal and Qualcomm Vulkan identically after accepting WGSL. | Read the pinned Vulkan physical-device and shader-module implementation. | False. Qualcomm-specific behavior includes passing matrices by pointer, scalarizing max/min/clamp and other workarounds. Existing workaround coverage is evidence of distinct paths, not evidence that any particular workaround fixes KartPad. |
| The original Android fiber port obviously loses floating-point state. | Review register layout, FPCR/FPSR save/restore, NI-mode handling and resume entry points. | No demonstrated faulty guest execution. Android explicitly saves/restores FPCR/FPSR; NI-mode reapplication and new-fiber context setup must be considered before alleging a bug. Retain as an upstream invariant to measure, not a justified patch. |

## Compiler provenance and limits

Dawn source archive SHA-256 is `713bea5b92d4f6c5175752fd7cbf1c3c5ce36598ff5dd98685d8a1216614ebba`, matching the build script's pin for `13abc3bc8ea2d3c2050f9e77a12d012108ceee24`. All 2,934 archive files under `src/tint/` and `src/dawn/native/` matched the source used here. A fresh local Tint build completed successfully.

The source-generation harness uses actual `gx/shader.cpp` and `gx/shader_info.cpp`; it replaces final GPU module submission with writing WGSL. It provides a fixed 256-byte alignment stub and uses host dependencies. It does not execute guest code or upload a real frame. The corpus is the current bundled cache, not every possible live-game recipe or a reconstructed original APK.

Tint CLI defaults do not reproduce every Dawn device option, binding remap, enabled extension or final vendor optimization. In particular, the Qualcomm matrix-by-pointer setting is selected inside Dawn's Vulkan shader-module path. The switch-to-if workaround found nearby applies to proprietary Imagination GPUs, not automatically to Qualcomm. These tests must not be described as the exact SPIR-V executed on the reporter's Adreno GPU.

Normal target WGSL SHA-256:

- `58866e32bada1f83`: `bad017e6a53cb06304af0aa9ee0285d8d2b9107c26e5c5fabc3155f1d2e554b2`.
- `33c5ff18d5c180e0`: `0c682289bfd23b08c9badea9109595f08e17728e9db3730cedf697dada560737`.

Machine-readable results and source revisions are in `platform-investigation-evidence.json`. Local harnesses, translated shaders and configurations remain under ignored `build/platform-investigation/`; raw game-derived configuration/shader material is not included in the committed report.

## Remaining fault boundaries and next decisions

Follow-up: `graphics-test-blind-spots.md` establishes that the compatibility variant retains dynamic texture-matrix indexing, one target uses alpha discard, and native backend validation is disabled. The comparison below isolates position/normal indexing only; a negative result does not clear all matrix indexing or prove either recipe belongs to the missing body.

1. **Guest data and encoded draw inputs.** Equal generators do not imply equal vertices, indices, matrices, projection, viewport or resource contents. Current finite-matrix/index checks cover only part of that boundary. A matched scene comparison should check semantic ranges and layout first; animation/timing means unrelated whole-frame hashes would be misleading.
2. **Merge/state/resource lifetime.** Both existing indexing comparison modes disable draw merging. If both restore the body relative to Normal, inspect merge/state behavior before attributing the result to matrix indexing. If only compatibility restores it, inspect the indexing/backend path. Reversing the comparison checks whether the improvement persists for unrelated reasons.
3. **Actual backend output.** If inputs agree and the indexing comparison differentiates output, capture the narrowly targeted translated shader/device options and a failing draw. Host compilation cannot close that boundary. Do not infer a driver defect merely from vendor-specific code in Dawn.
4. **Performance remains a separate family until evidence connects it.** Retroid #103 shows high main-thread activity with drained pipeline queues; Samsung #211 can show corruption while maintaining roughly 60 FPS. Neither supports treating all open issues as one shader-compilation bottleneck.

The targeted #211 comparison request remains unanswered at this check: https://github.com/chrissotraidis/kartpad/issues/211#issuecomment-5709173869. It uses the APK already installed and asks for actual `draw_binding` evidence, because prewarm messages do not prove which variant drew the scene. No duplicate request was posted. An affected reporter can supply this comparison; access to an owner's Android phone or an induced physical crash is not required.

The next iteration should act on that discriminating result or an upstream invariant failure. More undirected logs, another generic renderer probe, or changing all Android optimizations together would not resolve the remaining ambiguity.
