#!/usr/bin/env bash
# Build and run the Mac PAD check: a controller on player 1 must be read while
# player 1 keyboard bindings are active. Needs Homebrew SDL3 and the abseil and
# fmt sources the runtime build fetches (pass their roots).
# Usage: tools/mac-input-check/run.sh ABSEIL_SRC FMT_SRC
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
aurora="$repo/vendor/runtimes/macos/aurora-main"
absl="$1"; fmt="$2"
work="$(mktemp -d)"; mkdir -p "$work/user"
flags=(-std=c++23 -DAURORA -DTARGET_PC -DFMT_HEADER_ONLY -I"$aurora/include" -I"$aurora/lib" -I"$absl" -I"$fmt/include" -I/opt/homebrew/include)
for src in "$aurora/lib/dolphin/pad/pad.cpp" "$aurora/lib/input.cpp" "$here/pad_keyboard_controller_check.cpp" "$here/stubs.cpp"; do
  clang++ "${flags[@]}" -c "$src" -o "$work/$(basename "$src").o"
done
for src in container/internal/raw_hash_set hash/internal/hash hash/internal/city hash/internal/low_level_hash base/internal/raw_logging; do
  clang++ -std=c++20 -I"$absl" -c "$absl/absl/$src.cc" -o "$work/$(basename "$src").absl.o"
done
clang++ "$work"/*.o -L/opt/homebrew/lib -lSDL3 -o "$work/check"
"$work/check" "$work/user"

