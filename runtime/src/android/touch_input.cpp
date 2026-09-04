#include "kartpad/android/touch_input.h"

#include <algorithm>
#include <cmath>
#include <mutex>

namespace kartpad::android {
namespace {

std::mutex g_touch_mutex;
TouchInputState g_held;
std::uint32_t g_latched_buttons = 0;

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
    g_latched_buttons |= state.buttons & ~g_held.buttons;
    g_held = state;
}

TouchInputState ConsumeTouchInput() noexcept {
    std::scoped_lock lock(g_touch_mutex);
    TouchInputState result = g_held;
    result.buttons |= g_latched_buttons;
    g_latched_buttons = 0;
    return result;
}

bool IsTouchInputConnected() noexcept {
    std::scoped_lock lock(g_touch_mutex);
    return g_held.connected;
}

void ClearTouchInput() noexcept {
    std::scoped_lock lock(g_touch_mutex);
    g_held = {};
    g_latched_buttons = 0;
}

}  // namespace kartpad::android
