# KartPad renderer probe

A separate Android diagnostic app for [#102](https://github.com/chrissotraidis/kartpad/issues/102)
and [#104](https://github.com/chrissotraidis/kartpad/issues/104). It uses synthetic
inputs and extracts the packed-data WGSL functions from the pinned Aurora source.
It does not load KartPad, translated game code, game data, saves, network accounts,
or device identifiers. The app has no permissions and does not send results
until the user selects **Share Results** and a destination.

This is an investigation tool, not a graphics fix or a playable KartPad update.
Its package is `dev.kartpad.rendererprobe`; installing it does not replace
`dev.kartpad.android`. No reinstall or storage clearing of KartPad is needed.

## Run

Download the audited Android diagnostic APK (retired).

You do not need to run KartPad first. This separate app supplies all of its
own synthetic inputs.

Open **KartPad Renderer Check**, tap **Run GPU Check**, then **Share Results**.
Keep the app open during the test. Post the text to the relevant issue after
reviewing it. Include whether Original, Retro Rewind, or both show corruption.

In version 0.2.0, four compute variants and four indexed-draw variants
compare 4,096 values each against independent CPU expectations (32,768 total):

- Scalar uniform array, bounds protection disabled.
- Vector-packed uniform array, bounds protection disabled.
- Scalar uniform array, bounds protection enabled.
- Vector-packed uniform array, bounds protection enabled.

WebGPU validation remains enabled in every variant. Each robustness mode uses a
fresh adapter and device; the selected backend is Vulkan on Android and Metal on macOS.
Software adapters are rejected before device creation because the pinned Dawn
library aborts in its SwiftShader device-toggle setup. There is no fallback
to a different graphics backend. GPU callbacks have a
five-second timeout; shader compilation and driver calls can take longer.

Tests include every byte alignment, both byte orders, signed 16-bit fixed-point
vectors, 24-bit colors, finite 32-bit floats, scalar array indexing, and dynamic
indexing of 20 three-column matrices. Values are read back from a compute pass.
Field numbers in a mismatch report mean:

| Field | Operation |
| --- | --- |
| 0 | unsigned byte |
| 1–2 | little/big-endian unsigned 16-bit |
| 3–4 | little/big-endian unsigned 32-bit |
| 5–8 | four signed big-endian 16-bit values divided by 256 |
| 9–10 | little/big-endian 24-bit color |
| 11 | uniform array offset |
| 12–14 | matrix transform components |
| 15 | big-endian finite float |

The new draw variants issue indexed triangles through vertex and fragment stages.
They use separate packed vertex-index and attribute storage buffers, signed
big-endian positions, the current Aurora 80-byte uniform prefix, 20 indexed
position matrices, dynamic uniform offsets, RGBA8 textures, and four queued
updates of shared buffers/textures before readback. The CPU expects one
independently computed RGBA pixel per quad. Reports distinguish compute lines
from `draw` lines and include the failed phase/pixel/channel when applicable.

A pass validates only these synthetic cases. It does not validate actual GX
draw streams/generated game shaders, compressed textures, the renderer's
staging buffers or multithreaded lifetime, presentation, frame pacing, or
gameplay on that device. A mismatch is evidence
for a smaller follow-up case, not automatic proof of a driver bug. Error reports
are distinct from value mismatches.

## Build

Use KartPad's pinned Android bootstrap/dependencies, then:

```sh
scripts/build-android-renderer-probe.sh
```

The result is an unsigned release APK under
`tools/renderer-probe/android/build/outputs/apk/release/`. The script does not
install, sign, or publish it. Public candidates must be non-debuggable, signed
with a persistent release identity, audited, and anonymously downloaded back
before linking them to reporters. Do not publish a hardware debug-signed APK.

For a local macOS baseline, using the existing pinned Dawn installation:

```sh
cmake -S tools/renderer-probe -B build/renderer-probe -G Ninja \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=/absolute/path/to/dawn
cmake --build build/renderer-probe
build/renderer-probe/kartpad_renderer_probe
```

The CLI exits nonzero on a mismatch or error. The report includes a SHA-256 of
the exact extracted helpers. The generator reads only Aurora's `shader.cpp`.
KartPad probe code is GPL-3.0-only; extracted Aurora code retains its MIT license.
The APK includes root GPL, Aurora, Dawn, and NDK toolchain notices.

The `licenses/` copies come from Dawn source
`13abc3bc8ea2d3c2050f9e77a12d012108ceee24` and the existing pinned Abseil
source. They cover Dawn and the relevant bundled/header dependencies; no game
runtime or game content is linked. Android's static C++ runtime is covered by
the packaged NDK toolchain notices.

An excluded `kartpad_renderer_probe_cli` target is available for authorized
ADB development. It runs the same probe without a Java UI, so a locked screen
does not prevent the synthetic GPU check. Do not substitute CLI acceptance
for testing the APK's buttons and sharing flow.
