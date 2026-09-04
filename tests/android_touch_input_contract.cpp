#include "kartpad/android/touch_input.h"

#include <cassert>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <limits>

int main() {
    using namespace kartpad::android;

    ClearTouchInput();
    auto state = ConsumeTouchInput();
    assert(!state.connected);
    assert(state.buttons == 0);

    PublishTouchInput({
        2.0f,
        -2.0f,
        std::numeric_limits<float>::quiet_NaN(),
        0.25f,
        kTouchButtonA | kTouchButtonLeft | 0x40000000u,
        true,
    });
    state = ConsumeTouchInput();
    assert(state.connected);
    assert(state.buttons == (kTouchButtonA | kTouchButtonLeft));
    assert(state.left_stick_x == 1.0f);
    assert(state.left_stick_y == -1.0f);
    assert(state.right_stick_x == 0.0f);
    assert(state.right_stick_y == 0.25f);

    // A down/up pair between guest samples must survive exactly one consume.
    PublishTouchInput({0, 0, 0, 0, kTouchButtonB, true});
    PublishTouchInput({0, 0, 0, 0, 0, true});
    state = ConsumeTouchInput();
    assert(state.buttons == kTouchButtonB);
    state = ConsumeTouchInput();
    assert(state.buttons == 0);
    assert(state.connected);

    ClearTouchInput();
    state = ConsumeTouchInput();
    assert(!state.connected);
    assert(state.buttons == 0);
    assert(!IsTouchInputConnected());

    std::cout << "Android touch input contract passed\n";
    return 0;
}
