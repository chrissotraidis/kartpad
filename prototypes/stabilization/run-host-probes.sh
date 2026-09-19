#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
output="$repo_root/work/stabilization"
mkdir -p "$output"
compiler="${CXX:-/Library/Developer/CommandLineTools/usr/bin/clang++}"
sdk="${SDKROOT:-/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk}"
if [[ ! -x "$compiler" || ! -d "$sdk" ]]; then
  echo 'Set CXX to a compiler executable and SDKROOT to the macOS SDK.' >&2
  exit 1
fi
export CXX="$compiler -isysroot $sdk"
python3 -B -m unittest discover -s tests -p test_draw_merge_boundaries.py -v
python3 -B -m unittest discover -s tests -p test_sleep_timer_reentry.py -v
"$compiler" -isysroot "$sdk" -std=c++20 -Wall -Wextra -Werror -fsanitize=address,undefined \
  prototypes/stabilization/test_batch_reservation.cpp -o "$output/test-batch-reservation"
"$output/test-batch-reservation"
# This uses the pinned macOS Dawn package, not the Android-only Vulkan backport.
dawn="${KARTPAD_PROBE_DAWN_ROOT:-$output/dawn-metal}"
"$compiler" -isysroot "$sdk" -std=c++20 -O2 -Wall -Wextra -Werror \
  -I"$dawn/include" prototypes/stabilization/gpu_batch_probe.cpp "$dawn/lib/libwebgpu_dawn.a" \
  -framework CoreFoundation -framework Foundation -framework IOSurface -framework QuartzCore \
  -framework Cocoa -framework IOKit -framework Metal -o "$output/gpu-batch-probe"
"$output/gpu-batch-probe"
