#pragma once

#include "game_graphics_options.h"
#include "runtime_config.h"

namespace kartpad::graphics {

inline bool BloomDisabled() noexcept {
  return (RuntimeGameGraphicsOptions::DisabledPostProcessingPaths() & 0x10u) != 0;
}

// Match the Mac setting: preserve unrelated settings, save before applying, and
// let the game pick up the bloom mask when it constructs the next scene.
inline bool SetBloomDisabled(bool disabled) {
  const uint32_t previous = RuntimeConfigFile::LoadConfigFile()
                                .disabledPostProcessingPaths.value_or(0);
  const uint32_t mask = disabled ? previous | 0x10u : previous & ~0x10u;
  if (!RuntimeConfigFile::WriteSetting("video", "disabled_post_processing_paths",
                                    std::to_string(mask))) {
    return false;
  }
  RuntimeConfigFile::Mutable().disabledPostProcessingPaths = mask;
  RuntimeGameGraphicsOptions::SetDisabledPostProcessingPaths(mask);
  return true;
}

}  // namespace kartpad::graphics
