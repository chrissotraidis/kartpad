#include "kartpad/android/runtime_settings.hpp"

#include <mutex>

namespace kartpad::android {
namespace {

std::mutex g_mutex;
DisplaySettings g_settings;
bool g_pending = false;

}  // namespace

void PublishDisplaySettings(const DisplaySettings& settings) noexcept {
  const std::lock_guard lock(g_mutex);
  g_settings = settings;
  g_pending = true;
}

bool ConsumeDisplaySettings(DisplaySettings* settings) noexcept {
  if (settings == nullptr) return false;
  const std::lock_guard lock(g_mutex);
  if (!g_pending) return false;
  *settings = g_settings;
  g_pending = false;
  return true;
}

}  // namespace kartpad::android
