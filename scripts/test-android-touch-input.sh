#!/usr/bin/env bash
set -euo pipefail

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/kartpad-android-touch.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT

"${CXX:-c++}" -std=c++20 -Wall -Wextra -Werror -pthread \
  -I"$repo_root/runtime/include" \
  "$repo_root/runtime/src/android/touch_input.cpp" \
  "$repo_root/tests/android_touch_input_contract.cpp" \
  -o "$test_dir/android-touch-input-contract"
"$test_dir/android-touch-input-contract"
