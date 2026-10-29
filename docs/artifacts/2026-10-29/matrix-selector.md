# GX matrix selector correctness, 29 October 2026

The Classic renderer read all eight bits of direct position/normal and texture
matrix selector bytes. GX selectors use six bits. With either upper bit set,
the old shader could select a different or out-of-range matrix and change pixels.
The correction masks the selector before computing the matrix slot and applies
the same rule to interpolation's slot mask and topology signature.

Reference: Dolphin's
[`PosMtx_ReadDirect_UByte` and `TexMtx_ReadDirect_UByte`](https://github.com/dolphin-emu/dolphin/blob/4f8af23db516d8b6e9cd00e7b261a65b026514a8/Source/Core/VideoCommon/VertexLoader.cpp#L21)
both apply `& 0x3f`. Texture selectors were checked independently; the test uses
a translated texture matrix and a two-color synthetic texture, so selecting a
wrong texture matrix changes the expected pixels.

## Source and scope

The GPU experiment used Android Classic source at
`4be10fabb9d978cf908819d4f0516d10c78cdd30`, with the new ROM-free regression added
before changing production code. Candidate
`6e3ce40fba8faab8adbddad7933af67018e3d78c` contains that regression and the correction
([runtime draft PR #11](https://github.com/chrissotraidis/wiicompiled/pull/11)).
The test linked the actual FIFO decoder, shader generator and renderer, using
macOS Metal through pinned Dawn `v20260603.191052` and system SDL3 `3.4.14`.

The parent portable regression executes selector expressions emitted by each
maintained shader source and the actual interpolation reader functions. It
checks all 256 byte values, padded PNMTX vertex attributes on Android, strided
vertex reads, slot masks and equivalent topology identities under ASan/UBSan.
It complements GPU coverage; it does not substitute for rendering on Apple
platform source variants or Android hardware.

| Runtime | Immediate baseline | Corrected candidate |
| --- | --- | --- |
| [Android](https://github.com/chrissotraidis/wiicompiled/pull/11) | `4be10fabb9d978cf908819d4f0516d10c78cdd30` | `6e3ce40fba8faab8adbddad7933af67018e3d78c` |
| [iOS](https://github.com/chrissotraidis/wiicompiled/pull/12) | `b6a0c0b9a15b34b8b9486e8e174ec9145c55dd16` | `88f6e999ce79f47a3ad17fbe82fae072becdb9e8` |
| [macOS](https://github.com/chrissotraidis/wiicompiled/pull/10) | `4da764a0e25ed301ba8e2ba446e277be3b177f19` | `926814625140d640f9173272f3f6cf6ef69ddfe7` |
| [tvOS](https://github.com/chrissotraidis/wiicompiled/pull/13) | `7d525c5ae22bc259df7f90aa72dd1a7b0fbee6a6` | `c66293ab2240282ebfaadc7b67be4bf96a9d921b` |

The macOS baseline includes the independent controller correction on the same
draft branch; the previous KartPad macOS gitlink was
`7171f95776ada9545124946d315aec2894a85b99`. The matrix patch itself changes only
shader selector expressions and interpolation readers on each Apple branch.

The portable sanitizer probe passed for all four corrected candidates. As a
counterfactual, all four original source variants failed at selector decoding.
Keeping corrected shaders but restoring only the old interpolation readers also
failed the used-slot assertion on all four platforms, independently exercising
that part of the correction.

## GPU results

Each mode used its own cache directory. Position row selector 3 and texture row
selector 30 were each tested with upper bits `0`, `0x40`, `0x80` and `0xc0`.
Expected pixels were independently generated four-color bands.

| Actual renderer mode | Before: correct pixels / 8 cases | After: correct pixels / 8 cases |
| --- | ---: | ---: |
| Raw vertex reads | 2 | 8 |
| CPU vertex repack | 2 | 8 |
| Repack plus PNMTX vertex attribute | 2 | 8 |

All six unmodified-selector controls passed before the correction; all eighteen
upper-bit cases failed. Afterward all 24 cases passed. Each candidate run also
passed the existing complete GPU readback suite, including split submissions,
copy/readback, staging capacity, interpolation and frame worker cases, exit 0. A further full-suite run reused the
cache populated by the failing raw-vertex baseline and also passed; existing
recipe/cache replay did not require a schema change for the new shader source.

## Reproduction

Requirements are an Apple Silicon Mac with Xcode command-line tools, CMake,
Ninja, a Metal-capable session and installed SDL3 development files (at least
3.4.4; tested with 3.4.14). CMake found SDL3 on its default search path in this
run. If it is elsewhere, add `-DSDL3_DIR="$SDL3_CMAKE_DIR"`, where that variable
names the directory containing `SDL3Config.cmake`. The `package` Dawn provider
downloads and locates its pinned, SHA-256-checked macOS package itself; no custom
`Dawn_DIR` or `CMAKE_PREFIX_PATH` was used. Other small dependencies are resolved
by the runtime's normal CMake setup, requiring network access on a cold build.

Use a separate disposable runtime worktree at candidate `6e3ce40`, with no game
assets. Set `KARTPAD_SOURCE` to the KartPad checkout. From the runtime root, stage the existing KartPad Android trace header (the host
test supplies disabled trace hooks), then build:

```sh
cp "$KARTPAD_SOURCE/runtime/include/kartpad/android/trace_scope.h" \
  aurora-main/lib/kartpad_android_trace_scope.h
cmake -S aurora-main -B build/matrix-selector -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DAURORA_ENABLE_CARD=OFF \
  -DAURORA_BUILD_GPU_TESTS=ON -DAURORA_SDL3_PROVIDER=system \
  -DAURORA_DAWN_PROVIDER=package
cmake --build build/matrix-selector --target gx_readback_tests -j2
build/matrix-selector/tests/gx_readback_tests build/matrix-cache-raw
KARTPAD_RENDERER_VERTEX_REPACK=2 \
  build/matrix-selector/tests/gx_readback_tests build/matrix-cache-repack
KARTPAD_RENDERER_VERTEX_REPACK=2 KARTPAD_RENDERER_VERTEX_PNMTX=1 \
  build/matrix-selector/tests/gx_readback_tests build/matrix-cache-attribute
```

For the counterfactual, in that disposable worktree restore only
`aurora-main/lib/gx/shader.cpp` and `aurora-main/lib/gx/command_processor.cpp`
from `4be10fabb9d978cf908819d4f0516d10c78cdd30`, keeping the candidate test.
Rebuild and repeat with three new cache directories. Each run must fail with
`Matrix selector upper bits changed pixels`, exit 4.

From KartPad with its proposed runtime pins checked out:

```sh
python3 -B -m unittest discover -s tests -p test_gx_matrix_selectors.py -v
```

## What this establishes

This proves a GX selector correctness defect and its correction in the tested
renderer paths. It does not establish that any affected phone's game vertex
stream contains these upper bits. In fact, #104's existing
[first](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5707313589)
and [second](https://github.com/chrissotraidis/kartpad/issues/104#issuecomment-5715227609)
bounded draw-check logs each contain 31 samples with position selectors no higher
than 24, no outside-palette selectors and no nonfinite matrices. Those sampled
draws do not exercise this defect. Recurring missing-character reports, including
[#104](https://github.com/chrissotraidis/kartpad/issues/104) and
[#472](https://github.com/chrissotraidis/kartpad/issues/472), remain open for
verification. There is no claimed fix for those devices, no performance result,
no game/device acceptance and no change to pipeline-cache retention.
