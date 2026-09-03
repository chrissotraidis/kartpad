#pragma once

#include <cstdint>

namespace kartpad::audio {

inline constexpr bool CanReuseTVAudioStream(
    std::uint32_t requested_channels, std::uint32_t opened_channels,
    std::uint32_t actual_channels) noexcept {
  if (requested_channels < 6) {
    return opened_channels == 2;
  }
  return opened_channels == (actual_channels >= 6 ? 6u : 2u);
}

}  // namespace kartpad::audio

extern "C" std::uint32_t KartPadTVPrepareAudioRoute(
    std::uint32_t requested_channels);
extern "C" std::uint32_t KartPadTVActualAudioOutputChannels();
