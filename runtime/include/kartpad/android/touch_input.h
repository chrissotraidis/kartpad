#pragma once

#include <cstdint>

namespace kartpad::android {

inline constexpr std::uint32_t kTouchButtonUp = 0x00000001;
inline constexpr std::uint32_t kTouchButtonLeft = 0x00000002;
inline constexpr std::uint32_t kTouchButtonZr = 0x00000004;
inline constexpr std::uint32_t kTouchButtonX = 0x00000008;
inline constexpr std::uint32_t kTouchButtonA = 0x00000010;
inline constexpr std::uint32_t kTouchButtonY = 0x00000020;
inline constexpr std::uint32_t kTouchButtonB = 0x00000040;
inline constexpr std::uint32_t kTouchButtonZl = 0x00000080;
inline constexpr std::uint32_t kTouchButtonR = 0x00000200;
inline constexpr std::uint32_t kTouchButtonPlus = 0x00000400;
inline constexpr std::uint32_t kTouchButtonMinus = 0x00001000;
inline constexpr std::uint32_t kTouchButtonL = 0x00002000;
inline constexpr std::uint32_t kTouchButtonDown = 0x00004000;
inline constexpr std::uint32_t kTouchButtonRight = 0x00008000;
inline constexpr std::uint32_t kTouchButtonMask = 0x0000f6ff;

struct TouchInputState {
    float left_stick_x = 0.0f;
    float left_stick_y = 0.0f;
    float right_stick_x = 0.0f;
    float right_stick_y = 0.0f;
    std::uint32_t buttons = 0;
    bool connected = false;
};

// The Android UI thread publishes held state. Rising button edges are retained
// until the guest scheduler consumes them, so a short tap cannot disappear
// between KPAD samples.
void PublishTouchInput(TouchInputState state) noexcept;
[[nodiscard]] TouchInputState ConsumeTouchInput() noexcept;
[[nodiscard]] bool IsTouchInputConnected() noexcept;
void ClearTouchInput() noexcept;

}  // namespace kartpad::android
