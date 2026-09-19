# iOS versus Android renderer delta audit

Compared maintained runtime source at Android `fcf8c08f6f2695681cec65cb8b3bd116fb4054c0` and iOS `3865aa300abb8c928568b88b165f50c9695c4aa8`, along with the actual cached mobile build configuration and #104/#193 issue dates. This establishes source differences, not matched-scene hardware equivalence. The owner's working iOS result is a useful reference, but no matched capture of that scene was acquired in this audit.

## What matches

The files `gx/shader_info.cpp` (including uniform matrix layout and uploads), `gx/frame_interpolation.cpp`, `gx/pipeline.cpp`, and `gfx/texture.cpp` are byte-identical between these source revisions. Normal position/normal matrix-indexing expressions in `gx/shader.cpp` match; Android adds an opt-in literal-index comparison variant. The Android flag uses a formerly zero padding bit. Both cached builds name Dawn `v20260603.191052`, with different platform-specific package archives. Matching tags do not establish identical backend implementations or package build options.

This is evidence against an obvious missing iOS matrix-layout fix in Android. It does not establish identical generated shaders for different scene/configuration inputs, identical uploaded buffers, or identical backend output. iOS selects Metal and Android Vulkan, so the compiler/backend path remains a major meaningful difference even with identical application source.

## Material differences

| Area | Difference | Interpretation |
| --- | --- | --- |
| Frame overlap | Android public builds force native frame overlap; iOS selects overlap when interpolation is active. | Changes scheduling and lifetime pressure. Samsung #211 logs confirm overlap encoding. A controlled scheduling comparison is meaningful, but not a proven cause. |
| Initial report chronology | #104 was opened September 7, before forced overlap was integrated by parent commit `6a2dffc` on September 10 UTC. | Forced overlap cannot explain the original #104 report by itself. It could still affect current symptoms or performance. |
| Frame-state ownership | Android seals depth mapping and debug marker state with the frame. | Supporting changes for concurrent encoding; removing them indiscriminately would undo safety work. |
| Shader experiment | Android has original/compatibility modes with merging disabled in both; iOS has no equivalent selector. | Compare default paths separately from experimental paths. Prewarm compilation is not use. |
| Graphics register initialization | Android invalidates the initial GEN_MODE cache tag so the first zero write decodes. | An Android-side correction, not an iOS fix missing from Android. No link to reported corruption established. |
| Display-list cache | Android adds a front lookup cache but retains identity/content validation. | A performance-path difference to audit/isolate if needed; not evidence of bad cache hits. |
| Guest floating point | Android avoids repeated TLS lookup and host NI-mode updates when the NI bit does not change. | Host/context invariants matter; identical renderer code does not guarantee identical upstream game data. No failing invariant demonstrated here. |
| Platform runtime | Android has its own fiber switch and surface lifecycle handling. | Necessary portability differences require semantic equivalence, not blindly copying Apple code. |
| Pipeline workers | Android API <=29 avoids worker compilation. | Not selected for the API33 Retroid or API36 Samsung captures. |

## Confirmed diagnostic mismatch, corrected

The iOS diagnostic launcher already sets `KARTPAD_RENDERER_VALIDATION=1`. Its Release Dawn setup nevertheless unconditionally enabled `skip_validation` and `disable_robustness`; it never read that setting. CPU-side draw checks could therefore run while GPU validation and robustness stayed disabled. Android's diagnostic setup honors the flag.

Updated iOS Dawn toggle construction to honor the same opt-in setting as Android. Normal Release behavior is preserved; diagnostic mode explicitly disables both skip toggles. This is a diagnostics correction, not a graphics fix. Published iOS build51 is unchanged and must not be described as having this correction.

The existing toggle contract test now exercises Vulkan and Metal, five environment values, and Debug/Release configurations against each platform's actual toggle construction. Both pass (40 backend/environment/build combinations across the two sources). The actual iPhoneOS arm64 Release compile/link also passes; prepared source verification passes. No physical execution or new package publication occurred.

## Next comparison should locate where the platforms diverge

Treat the correctly rendered iOS scene as a reference, with the same game mode, character, native frame rate, resolution/aspect and equivalent diagnostics. Separate the boundaries:

1. Guest-produced vertex/index/matrix data and renderer state. If these differ materially before backend translation, investigate guest/runtime/cache behavior first.
2. Shader recipe and uniform/vertex layout. If inputs match but these differ, investigate configuration/translation/limits rather than phone-specific workarounds.
3. Translated backend shader and encoded draw. If the upstream representation agrees, inspect Metal versus Vulkan translation and resource use. A successful Metal compile alone does not validate Vulkan behavior.
4. Actual pixel output. Correct command encoding cannot establish correctness here; a controlled shader/scheduling change or affected-device frame evidence must close that gap.

Comparisons must tolerate expected timing/animation differences; arbitrary full-frame hashes from unrelated runs would not be meaningful. Do not request or publish raw game assets in public reports. Do not change all Android-specific optimizations at once: that would obscure which difference mattered. This audit supports a shared cross-platform investigation rather than assuming one unrelated defect per phone.
