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

    // A complete tap between samples must reach both SDK readers, in either
    // order, exactly once. Probing and repeated reads must not drain its peer.
    for (auto first : {TouchInputReader::Kpad, TouchInputReader::UnifiedWpad}) {
        const auto second = first == TouchInputReader::Kpad ?
            TouchInputReader::UnifiedWpad : TouchInputReader::Kpad;
        PublishTouchInput({0, 0, 0, 0, kTouchButtonA, true});
        PublishTouchInput({0, 0, 0, 0, 0, true});
        assert(IsTouchInputConnected());
        assert(ConsumeTouchInput(first).buttons == kTouchButtonA);
        assert(ConsumeTouchInput(first).buttons == 0);
        assert(ConsumeTouchInput(second).buttons == kTouchButtonA);
        assert(ConsumeTouchInput(second).buttons == 0);

        PublishTouchInput({0, 0, 0, 0, kTouchButtonB, true});
        for (auto reader : {first, second, first, second})
            assert(ConsumeTouchInput(reader).buttons == kTouchButtonB);
        ClearTouchInput(); // focus loss clears held state AND both pending taps.
        for (auto reader : {first, second}) {
            const auto cleared = ConsumeTouchInput(reader);
            assert(!cleared.connected && cleared.buttons == 0);
        }
    }

    std::cout << "Android touch input contract passed\n";
    return 0;
}
