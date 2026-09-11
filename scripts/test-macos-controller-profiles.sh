#!/usr/bin/env bash
set -euo pipefail
repo_root="$(git rev-parse --show-toplevel)"
build="${1:-${repo_root}/build/self-build-macos-build}"
source="${2:-${repo_root}/build/self-build-macos-source}"
clang++ -std=c++20 -fobjc-arc -DTARGET_PC -Wall -Wextra \
  -I "${repo_root}/apple/macos" -I "${source}/include" -I "${source}/third_party/toml11" \
  -I "${source}/aurora-main/include" -I "${build}/_deps/sdl-src/include" \
  "${repo_root}/tests/macos/controller_profiles.mm" "${build}/_deps/sdl-build/libSDL3.a" \
  -framework Cocoa -framework Carbon -framework CoreVideo -framework IOKit \
  -framework ForceFeedback -framework CoreAudio -framework AudioToolbox \
  -framework GameController -framework CoreHaptics -framework Metal \
  -framework AVFoundation -framework CoreMedia -framework UniformTypeIdentifiers \
  -framework QuartzCore -o "${build}/controller-profile-tests"
"${build}/controller-profile-tests"
