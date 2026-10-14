# Issue 102 current-release follow-up

On 12 September 2026 the reporter supplied a current `v0.4.16-android.2`
Galaxy Z Fold 8 / Qualcomm Adreno 840 comparison at 2x, 4:3, with Renderer
Validation disabled. The in-game geometry/road-texture corruption remains. The
reporter additionally supplied a surface-loss warning, a road-texture render
pass pipeline stall / vertex-buffer mismatch, a pipeline compilation latency
spike, and a severe frame drop during draw-state recovery.

This is stronger current-release evidence for the existing renderer/geometry
lane, but it does not establish a shared Adreno-wide cause or a fix. The next
engineering gate remains a controlled affected-draw comparison on the exact
target. No reinstall, cache reset or full diagnostic archive was requested.

Public response: https://github.com/chrissotraidis/kartpad/issues/102#issuecomment-5647561179
