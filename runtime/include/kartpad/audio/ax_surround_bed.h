#pragma once

#include <algorithm>
#include <cstdint>
#include <limits>
#include <span>

namespace kartpad::audio {

namespace detail {

inline constexpr std::int16_t ScaleAxSampleToS16(
    std::int32_t accumulator, std::uint16_t volume_ramp) noexcept {
    const std::int64_t scaled =
        (static_cast<std::int64_t>(accumulator) *
         static_cast<std::int64_t>(volume_ramp)) >>
        15;
    const std::int64_t clamped = std::clamp(
        scaled, static_cast<std::int64_t>(
                    std::numeric_limits<std::int16_t>::min()),
        static_cast<std::int64_t>(
            std::numeric_limits<std::int16_t>::max()));
    return static_cast<std::int16_t>(clamped);
}

}  // namespace detail

// The output span is one interleaved frame in FL, FR, FC, LFE, LS, RS order.
inline void ConvertAxSurroundBedFrameToS16(
    std::int32_t mainL, std::int32_t mainR, std::int32_t mainS,
    std::int32_t auxCL, std::uint16_t volume_ramp,
    std::span<std::int16_t, 6> output) noexcept {
    output[0] = detail::ScaleAxSampleToS16(mainL, volume_ramp);
    output[1] = detail::ScaleAxSampleToS16(mainR, volume_ramp);
    output[2] = 0;
    output[3] = 0;
    output[4] = detail::ScaleAxSampleToS16(mainS, volume_ramp);
    output[5] = detail::ScaleAxSampleToS16(auxCL, volume_ramp);
}

}  // namespace kartpad::audio
