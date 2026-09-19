# Demonstrated mobile renderer defects and corrections

Four local regressions exposed defects in the maintained Android and iOS FIFO renderer. These are code corrections, not additional diagnostic modes. They do not yet establish which defect, if any, produces the particular Samsung screenshot.

| Defect | Reproduction and correction |
| --- | --- |
| Vertex invalidation did not break merging | The actual `CP_CMD_INVAL_VTX` branch cleared array upload caches but left `stateDirty=false`. The next eligible draw could merge and return before the fresh-upload path. Mark draw state dirty at invalidation, without unnecessarily invalidating pipeline configuration. |
| Merged indices could exceed 16 bits | The actual merge predicate accepted an appended draw whose offset indices exceeded 65535. Reject that merge and emit a new draw. Include the existing partial-quad template rounding in the bound and use wide addition to avoid overflow in the check itself. |
| Quad loop counter wrapped | The actual index generator used a 16-bit loop variable incremented by 4. Counts 65533–65535 wrapped the variable to zero; AddressSanitizer caught writes outside the vector. Widen the loop counter while retaining the existing partial-quad behavior. |
| Format changes did not break merging | `calculate_last_vtx_size` selected the new format but did not mark draw state dirty. Consecutive draws could therefore use the previous format's shader/layout. Break merging when recalculating the format, including when the byte stride is unchanged. |

The changes are confined to `aurora-main/lib/gx/command_processor.cpp` in each mobile runtime. No phone-specific branch, logging subsystem, renderer toggle, or global disabling of draw merging was added.

## Regression evidence

`tests/test_draw_merge_boundaries.py` compiles and executes the actual production invalidation branch, merge eligibility expression, index generator and format-size function. Small fixture types supply their dependencies; this is host-side behavioral coverage, not a full gameplay reproduction. The counter case runs under AddressSanitizer. Each newly identified failure was observed before applying its corresponding correction on both sources.

All four new regression tests pass after correction, along with the existing draw-input and native diagnostic contracts: 10 tests total. Local before/after logs are retained under `build/frame-capture/` and `build/merge-fix/`. No simulator acceptance is claimed.

Android maintained revision: `efb63c192b7c7fda013cba1e82225910d5ca0d43`.
iOS maintained revision: `b52612602187ebac1686bced5e010507623864ab`.
Parent build source: `a98e0c3`.

## Candidate intent

Android candidate code 121, `0.4.25-diagnostics.3-mergefix`, uses ordinary non-debuggable Release packaging with the existing diagnostic reporting enabled by its version label. Character Graphics Test should remain Normal when evaluating these corrections. The opt-in RenderDoc capture setting is off. Public code 119 is not overwritten or relabeled.

The defects are shared, which makes them valid fixes on both platforms but does not explain platform-specific occurrence by itself. Different draw sequences or batching may expose them differently; that remains a hypothesis. A same-scene comparison on an affected installation is still necessary before closing a reported graphics issue. Do not present these fixes as a remedy for all Android performance, installation or crash reports.

## Build result

The final Android code 121 APK passed the full compile/package and existing APK audit. It is non-debuggable, the game activity is not exported, and native/symbol BuildIDs match. The final iPhoneOS arm64 Release compile/link also passed. Artifact metadata is in `draw-merge-build.json`.

The local APK and matching symbols are retained in `build/merge-fix/`. It uses the existing local debug signing certificate; this is independent of the non-debuggable Release build type. A community-signed installation requires a matching-signer candidate. No installation, publication or reported-issue closure occurred.
