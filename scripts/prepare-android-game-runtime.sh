#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
absolute_from_repo() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s/%s\n' "$repo_root" "$1" ;;
  esac
}

translation_root="$(absolute_from_repo "${1:-private/g8-full-translation}")"
runtime_source="$(absolute_from_repo "${2:-build/android-game-runtime-source}")"
runtime_build="$(absolute_from_repo "${3:-build/android-game-runtime-build}")"
product="${4:-base}"

case "$product" in
  base|retro-rewind|dual) ;;
  *) echo "ERROR: product must be base, retro-rewind, or dual" >&2; exit 64 ;;
esac
if [[ ! -f "$translation_root/build_shards/shards.cmake" ]]; then
  echo "ERROR: missing private translated graph: $translation_root" >&2
  exit 1
fi
if [[ -e "$runtime_source" || -e "$runtime_build" ]]; then
  echo "ERROR: output already exists; choose fresh output paths" >&2
  exit 1
fi

# The existing Apple preparation command owns the common, ordered runtime
# patch stack. KARTPAD_PREPARE_ONLY stops before any platform configure/build;
# this Android command then layers only the ELF/NDK delta onto that fresh copy.
KARTPAD_PREPARE_ONLY=1 "$repo_root/scripts/prepare-ios-game-runtime.sh" \
  "$translation_root" "$runtime_source" "$runtime_build" "$product"
patch --batch -p1 -d "$runtime_source/aurora-main" < \
  "$repo_root/patches/aurora-android-public-sdl-surface-lock.patch"
patch --batch -p1 -d "$runtime_source/aurora-main" < \
  "$repo_root/patches/aurora-android-api29-serialized-vulkan.patch"
patch --batch -p1 -d "$runtime_source/aurora-main" < \
  "$repo_root/patches/aurora-android-gamepad-snapshot.patch"
patch --batch -p1 -d "$runtime_source/aurora-main" < \
  "$repo_root/patches/aurora-android-gamepad-rumble.patch"
patch --batch -p1 -d "$runtime_source/aurora-main" < \
  "$repo_root/patches/aurora-android-gamepad-lifecycle.patch"
patch --batch -p1 -d "$runtime_source/aurora-main" < \
  "$repo_root/patches/aurora-android-gamepad-event-cache.patch"
patch --batch -p1 -d "$runtime_source/aurora-main" < \
  "$repo_root/patches/aurora-android-gamepad-assignment.patch"
patch --batch -p1 -d "$runtime_source/aurora-main" < \
  "$repo_root/patches/aurora-idempotent-imgui-shutdown.patch"
patch --batch -p1 -d "$runtime_source/aurora-main" < \
  "$repo_root/patches/aurora-imgui-snapshot-bounds.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-runtime.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-private-paths.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-nand-open.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-surface-resume.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-keyboard-steer.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-sdl-controller.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-sdl-rumble.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-sdl-fiber-poll.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-touch-input.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-controller-probe.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-controller-mapping.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-runtime-settings.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-performance-telemetry.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-performance-breakdown.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-exportable-metrics.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/aurora-android-phase-metrics.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/aurora-opt-in-renderer-validation.patch"
cp "$repo_root/runtime/include/kartpad/diagnostics/draw_inputs.h" \
  "$runtime_source/aurora-main/lib/gx/kartpad_draw_inputs.hpp"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/aurora-draw-input-diagnostics.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-scalar-ni-transition.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-network-tls.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-tls-ioctlv-fixture.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-dns-ioctl-fixture.patch"

patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-network-stall.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/wiicompiled-android-alarm-reschedule-guard.patch"

cp "$repo_root/runtime/include/kartpad/android/trace_scope.h" \
  "$runtime_source/aurora-main/lib/kartpad_android_trace_scope.h"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/android-frame-critical-path-trace.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/android-frame-overlap-state-guards.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/android-native-frame-overlap-experiment.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/android-sealed-debug-frame.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/android-sealed-depth-mapping.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/aurora-first-genmode-write.patch"
patch --batch -p1 -d "$runtime_source" < \
  "$repo_root/patches/aurora-geometry-contract-tests.patch"

generated_link="$(dirname "$runtime_source")/generated"
if [[ -e "$generated_link" && ! -L "$generated_link" ]]; then
  echo "ERROR: generated path exists and is not a symlink: $generated_link" >&2
  exit 1
fi
ln -sfn "$translation_root" "$generated_link"

echo "Prepared integrated Android runtime source: $runtime_source"
