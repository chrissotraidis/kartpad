# EFB readback: actual renderer reproduction and lifetime corrections

The ROM-free `aurora_batch_probe.cpp` links the maintained Aurora renderer and
its pinned Dawn Metal backend. It records four horizontal color bands, resolves
a persistent EFB copy with a partial clear, downsamples it, and reads GX RGBA8
tiled bytes back into a guarded destination. Expected bytes are calculated
independently. Nine further frames split after one, two or three bands and
compare against the unsplit result, repeatedly reusing the three staging slots.

## Independently reproduced rendering defect

The initial real-renderer run failed: all four bands read back red. The shared
conversion shader clamps the vertical source coordinate to `flags.z/w`, but
`ensure_native_texture` supplied zero for both bounds. Setting the upper bound
to one preserves the full source height. This fixes scaled CPU-visible EFB
copies, including the native downsample path used by small asynchronous copies.
It does not establish a cause for a particular reported geometry failure.

After correction, all four colors match the independently expected GX tiles.
All nine split comparisons pass, destination canaries remain intact, and the
actual Metal renderer reports no error or validation failure. Nine additional
4x4 asynchronous copies also match the expected tiled bytes while reusing a
pooled destination. The test observes the production guest-write notification
with release/acquire synchronization before inspecting those bytes. The same run
passes after the callback lifetime corrections below. This is Aurora's real
clear/resolve/snapshot/downsample/readback path; later extensions also exercise FIFO uploads and suspended offscreen work,
as recorded below. Interpolation and automatic capacity admission remain open. Manual batch splits are not a completed R8 repair.

## Callback lifetime defects

`tests/test_efb_readback_lifecycle.py` compiles the actual maintained functions
with controlled WebGPU callback delivery. Baseline copies were saved before
editing. On all four runtime pins, the prior source exhibits each failure below,
while all corrected cases pass ARM64 AddressSanitizer and UndefinedBehaviorSanitizer.

| Case | Baseline | Correction |
| --- | --- | --- |
| Callback arrives after a timed-out synchronous wait returns | ASan stack-use-after-return | Callback owns a shared result until delivery finishes |
| Error text expires when its callback returns | ASan heap-use-after-free when logging | Copy bounded diagnostic text during callback delivery |
| Old asynchronous callback arrives after shutdown and destination reuse | Changes the new slot and in-flight count | Reject callbacks from a retired renderer generation |
| Buffer destruction delivers a cancellation callback during shutdown | Deadlocks on the callback mutex; bounded fixture times out | Retire the generation under lock, release old buffers outside it |
| Successful current readback | Passes | Still writes once; guard bytes unchanged |

These tests deliberately control callback order to expose the source contracts.
They do not claim that Dawn delivered each failure in an observed game session.
The existing five-second synchronous wait and current device-loss policy remain.

## Reproduction

With an already configured Mac Ninja build whose prepared source matches the
maintained Mac pin:

```sh
python3 tests/test_efb_readback_lifecycle.py
python3 prototypes/stabilization/build-aurora-probe.py \
  build/stabilization-20260919/macos-build \
  work/aurora-capacity-20260919/aurora-batch-probe
work/aurora-capacity-20260919/aurora-batch-probe \
  "$PWD/work/aurora-capacity-20260919/user-data"
```

The builder verifies prepared-source parity, builds renderer libraries, excludes
translated game archives from linking, and records the runtime revision and
probe hash. The probe writes only its designated test cache/user directory.
Private baseline sources, sanitizer reports and GPU transcripts are retained
under `work/aurora-capacity-20260919`.

Code130/build54 packages predate these changes. They must not be presented as
containing this correction. The changed Android renderer library and full iOS device-SDK build compile
successfully. Updated full Android/Mac builds and clean package provenance
are still required before release.

## Latest controller report

The September 19 reply on [issue #197](https://github.com/chrissotraidis/kartpad/issues/197#issuecomment-5741467134)
reports working touch menus after disconnecting the ipega, continuing incorrect
default-mode inputs, and uncertainty about the online menu failure. Preserve
that distinction: it narrows local mapping/handoff work but neither proves the
online failure fixed nor justifies asking for the same comparison again.

## Actual FIFO and offscreen extensions

Four additional real Metal cases (unsplit and three split intervals) suspend a
partially recorded EFB, bake an independently checked magenta texture offscreen,
resume the EFB, and submit at legal boundaries after returning from offscreen
work. Both outputs and their destination guards remain correct. This proves
preservation around those boundaries; it does not permit a flush while an
offscreen pass is active.

Four direct GX cases use GXInit/GXBegin/GXEnd, the actual FIFO decoder, quad
index generation, shader/uniform construction, vertex upload and GPU encoding.
Their four color bands match the independently expected tiled pixels. Four
indexed cases keep the same position-array address and format, change its bytes
between draws, and issue actual GX vertex-cache invalidations. Their outputs
also match with and without batch splits, extending the R1 source test to
actual storage uploads and rendering. No translated game code is linked.

All earlier synchronous/asynchronous readback and clear/snapshot cases still
pass in the extended executable. The current test does not implement automatic
admission, force each staging capacity, or exercise interpolation/worker overlap.
