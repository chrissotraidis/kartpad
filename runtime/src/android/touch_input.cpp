#include "kartpad/android/touch_input.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <mutex>

namespace kartpad::android {
namespace {

std::mutex g_touch_mutex;
TouchInputState g_held;
std::array<std::uint32_t, 2> g_latched_buttons{};

float SanitizeAxis(float value) noexcept {
    if (!std::isfinite(value)) {
        return 0.0f;
    }
    return std::clamp(value, -1.0f, 1.0f);
}

}  // namespace

void PublishTouchInput(TouchInputState state) noexcept {
    state.left_stick_x = SanitizeAxis(state.left_stick_x);
    state.left_stick_y = SanitizeAxis(state.left_stick_y);
    state.right_stick_x = SanitizeAxis(state.right_stick_x);
    state.right_stick_y = SanitizeAxis(state.right_stick_y);
    state.buttons &= kTouchButtonMask;

    std::scoped_lock lock(g_touch_mutex);
    for (auto& pending : g_latched_buttons) pending |= state.buttons & ~g_held.buttons;
    g_held = state;
}

TouchInputState ConsumeTouchInput(TouchInputReader reader) noexcept {
    std::scoped_lock lock(g_touch_mutex);
    TouchInputState result = g_held;
    auto& pending = g_latched_buttons[reader == TouchInputReader::Kpad ? 0 : 1];
    result.buttons |= pending;
    pending = 0;
    return result;
}

bool IsTouchInputConnected() noexcept {
    std::scoped_lock lock(g_touch_mutex);
    return g_held.connected;
}

void ClearTouchInput() noexcept {
    std::scoped_lock lock(g_touch_mutex);
    g_held = {};
    g_latched_buttons.fill(0);
}

}  // namespace kartpad::android
