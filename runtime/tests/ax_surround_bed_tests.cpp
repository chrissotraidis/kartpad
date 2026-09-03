#include "kartpad/audio/ax_surround_bed.h"
#include "kartpad/audio/tvos_audio_route.h"

#include <algorithm>
#include <array>
#include <cassert>
#include <cstdint>
#include <limits>
#include <span>

namespace {

constexpr std::int16_t ExpectedS16(std::int32_t accumulator,
                                   std::uint16_t volume_ramp) noexcept {
    const std::int64_t scaled =
        (static_cast<std::int64_t>(accumulator) *
         static_cast<std::int64_t>(volume_ramp)) >>
        15;
    return static_cast<std::int16_t>(std::clamp(
        scaled, static_cast<std::int64_t>(
                    std::numeric_limits<std::int16_t>::min()),
        static_cast<std::int64_t>(
            std::numeric_limits<std::int16_t>::max())));
}

void TestRoutingAndSentinels() {
    constexpr std::int16_t sentinel = 0x5A5A;
    std::array<std::int16_t, 8> storage;
    storage.fill(sentinel);
    const std::span<std::int16_t, 6> frame(storage.data() + 1, 6);

    constexpr std::int32_t main_l = 0x123456;
    constexpr std::int32_t main_r = -0x234567;
    constexpr std::int32_t main_s = 0x345678;
    constexpr std::int32_t aux_cl = -0x456789;
    constexpr std::uint16_t volume_ramp = 0x4000;
    kartpad::audio::ConvertAxSurroundBedFrameToS16(
        main_l, main_r, main_s, aux_cl, volume_ramp, frame);

    assert(storage[0] == sentinel);
    assert(storage[7] == sentinel);
    assert(frame[0] == ExpectedS16(main_l, volume_ramp));
    assert(frame[1] == ExpectedS16(main_r, volume_ramp));
    assert(frame[2] == 0);
    assert(frame[3] == 0);
    assert(frame[4] == ExpectedS16(main_s, volume_ramp));
    assert(frame[5] == ExpectedS16(aux_cl, volume_ramp));
}

void TestNegativeValuesAndSharedClampCalculation() {
    constexpr std::int32_t main_l = -123456789;
    constexpr std::int32_t main_r = 7654321;
    constexpr std::int32_t main_s = -32769;
    constexpr std::int32_t aux_cl = 32767;
    constexpr std::uint16_t volume_ramp = 0x6D3A;
    std::array<std::int16_t, 6> frame{};

    kartpad::audio::ConvertAxSurroundBedFrameToS16(
        main_l, main_r, main_s, aux_cl, volume_ramp, frame);

    assert(frame[0] == ExpectedS16(main_l, volume_ramp));
    assert(frame[1] == ExpectedS16(main_r, volume_ramp));
    assert(frame[4] == ExpectedS16(main_s, volume_ramp));
    assert(frame[5] == ExpectedS16(aux_cl, volume_ramp));
}

void TestSaturation() {
    constexpr auto max = std::numeric_limits<std::int32_t>::max();
    constexpr auto min = std::numeric_limits<std::int32_t>::min();
    std::array<std::int16_t, 6> frame{};

    kartpad::audio::ConvertAxSurroundBedFrameToS16(
        max, min, max, min, std::numeric_limits<std::uint16_t>::max(), frame);

    assert(frame[0] == std::numeric_limits<std::int16_t>::max());
    assert(frame[1] == std::numeric_limits<std::int16_t>::min());
    assert(frame[4] == std::numeric_limits<std::int16_t>::max());
    assert(frame[5] == std::numeric_limits<std::int16_t>::min());
}

void TestSilence() {
    std::array<std::int16_t, 6> frame{};
    kartpad::audio::ConvertAxSurroundBedFrameToS16(
        0x7FFFFFFF, -0x7FFFFFFF, 0x12345678, -0x12345678, 0, frame);
    assert(std::all_of(frame.begin(), frame.end(),
                       [](std::int16_t sample) { return sample == 0; }));

    frame.fill(0x1234);
    kartpad::audio::ConvertAxSurroundBedFrameToS16(0, 0, 0, 0, 0xFFFF, frame);
    assert(std::all_of(frame.begin(), frame.end(),
                       [](std::int16_t sample) { return sample == 0; }));
}

void TestAudioStreamReuseTracksRouteChanges() {
    using kartpad::audio::CanReuseTVAudioStream;

    assert(CanReuseTVAudioStream(6, 6, 6));
    assert(!CanReuseTVAudioStream(6, 6, 2));
    assert(CanReuseTVAudioStream(6, 2, 2));
    assert(!CanReuseTVAudioStream(6, 2, 6));
    assert(CanReuseTVAudioStream(2, 2, 6));
}

}  // namespace

int main() {
    TestRoutingAndSentinels();
    TestNegativeValuesAndSharedClampCalculation();
    TestSaturation();
    TestSilence();
    TestAudioStreamReuseTracksRouteChanges();
    return 0;
}
