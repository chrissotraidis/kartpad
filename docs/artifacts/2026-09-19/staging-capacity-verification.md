# Staging capacity admission and automatic submission

The maintained Android, iOS/iPadOS, macOS, and tvOS renderers now admit complete
GPU operations before modifying their staging buffers. A full batch is submitted
and the unconsumed draw is retried once. This addresses the handoff's R8 boundary
without reallocating mapped GPU memory or increasing the fixed buffer sizes.
The exact revisions and evidence hashes are in
[`staging-capacity-verification.json`](staging-capacity-verification.json).

## Ownership and bounds

- Draw admission includes vertices, expanded indices, uncached indexed arrays,
  aligned uniforms, and up to three interpolation copies. Merged draws reserve
  only their additional vertices and indices and retain the existing fast path.
- Every admission leaves the 3,840-byte uniform binding tail and enough aligned
  uniform space for all 32 asynchronous readback slots. Arithmetic checks final
  four-byte copy alignment, the physical capacity, and 32-bit range limits.
- FIFO decoding returns the first unconsumed command and releases the renderer
  mutex before waiting for the worker's DONE phase. The split does not recursively
  drain the FIFO. The raw-draw bridge likewise unlocks before submitting.
- A split during an offscreen bake loads its existing color/depth targets and
  requires its prefix pipelines to be ready. The suspended EFB pass remains
  suspended: its referenced staging prefix is copied into temporary owned memory
  and restored at the same offsets in the next slot. It is not rendered early,
  cleared, or discarded. The temporary copy exists only during the split.
- Array upload caches are invalidated after submission. Interpolation tasks are
  dropped before unmapping; that logical frame uses duplicate presentation rather
  than replaying a suffix against mutable EFB resources.
- Pending synchronous EFB copies keep their textures but restage native-blit
  uniforms when the staging generation changes. CPU-demanded preparation follows
  FIFO decoding, so it cannot retain a uniform retired by decoding's own split.
- An operation that cannot fit together with retained suspended-pass data and
  required headroom throws `StagingCapacityError` before allocating the draw.
  Primitive subdivision is not implemented. This is a bounded failure path,
  not a claim that arbitrarily large operations now render successfully.

## Validation

The ROM-free probe links the real maintained Aurora renderer and pinned Dawn.
It compares scaled, tiled GX readbacks with independently constructed expected
pixels and checks destination canaries. The internal test seam only lowers
admission limits; the physical buffer allocation stays unchanged.

| Forced boundary | Result |
| --- | --- |
| Vertex capacity 128 bytes | Automatic split; exact quad pixels |
| Index capacity 24 bytes | Automatic split; exact quad pixels |
| Uniform capacity plus reserved seal headroom | Three automatic splits; exact clear/resolve/snapshot pixels |
| Storage capacity 512 bytes | Automatic split; updated same-address indexed arrays render correctly |
| Raw direct-draw bridge | Automatic split; exact quad pixels |
| Offscreen bake and pending readback | 24 automatic splits across all three mapped slots; both bake and suspended EFB preserved |
| Perspective interpolation | Matching draws established, native output preserved after split, replay disabled |
| Asynchronous frame worker | 16 perspective frames with automatic splits and correct readbacks; no deadlock |
| Single oversized quad | Typed rejection before any staging allocation; rendering succeeds after explicit test cleanup |

Actual per-batch high-water usage remained within the forced limits. The probe
also retains the prior unsplit, explicit-split, asynchronous-readback,
clear/snapshot, offscreen, direct-FIFO, and indexed-invalidation controls.

Twelve focused host regressions pass across all four maintained pins, including
ASan/UBSan arithmetic, retry, topology, map-lifecycle, readback-lifecycle, startup,
and sleep-timer checks. The previous maintained readback source independently
fails the new generation test on all four platforms; its six earlier lifecycle
modes still pass. This distinguishes the newly exercised lifetime boundary.

The broader local suite also passes: 283 tests with `PYTHONPATH=builder`. The
initial invocation omitted that import path and exposed stale report/menu/release
fixtures. Those fixtures now cover the existing report collector hook, current
menu routing, maintained-source rejection, and accepted release identities. No
product source was changed for those fixture corrections.

The renderer libraries compile for Android ARM64 with the NDK and iPhoneOS ARM64
with the device SDK. The macOS ARM64 probe links and runs. A complete tvOS SDK
build has not been performed in this cycle.

## Release boundary

This source change is newer than the audited Android code 131 and Apple build 55
packages. Those artifacts have not been relabeled or replaced. Whole-application
relinks, new package provenance, gameplay validation, and the coordinated public
release remain pending. These tests establish bounded rendering correctness;
they do not establish a gameplay FPS gain, lower handset memory use, or complete
physical-device compatibility.
