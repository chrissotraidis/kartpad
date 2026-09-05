#pragma once

namespace kartpad::android {

struct DisplaySettings {
  bool show_fps = true;
  int aspect_mode = 2;
  float resolution_scale = 1.0f;
};

// Android's UI thread publishes settings; the runtime/render thread consumes
// the newest complete snapshot at its normal per-frame settings boundary.
void PublishDisplaySettings(const DisplaySettings& settings) noexcept;
bool ConsumeDisplaySettings(DisplaySettings* settings) noexcept;

}  // namespace kartpad::android
