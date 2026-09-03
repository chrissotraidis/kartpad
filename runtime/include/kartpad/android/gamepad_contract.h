#pragma once

#include <algorithm>
#include <cstdint>

namespace kartpad::android {

enum GamepadButton : uint32_t {
  kGamepadSouth = 1u << 0,
  kGamepadEast = 1u << 1,
  kGamepadWest = 1u << 2,
  kGamepadNorth = 1u << 3,
  kGamepadBack = 1u << 4,
  kGamepadStart = 1u << 5,
  kGamepadLeftShoulder = 1u << 6,
  kGamepadRightShoulder = 1u << 7,
  kGamepadDpadUp = 1u << 8,
  kGamepadDpadDown = 1u << 9,
  kGamepadDpadLeft = 1u << 10,
  kGamepadDpadRight = 1u << 11,
};

enum ClassicButton : uint32_t {
  kClassicUp = 0x00000001,
  kClassicLeft = 0x00000002,
  kClassicZr = 0x00000004,
  kClassicX = 0x00000008,
  kClassicA = 0x00000010,
  kClassicY = 0x00000020,
  kClassicB = 0x00000040,
  kClassicZl = 0x00000080,
  kClassicR = 0x00000200,
  kClassicPlus = 0x00000400,
  kClassicMinus = 0x00001000,
  kClassicL = 0x00002000,
  kClassicDown = 0x00004000,
  kClassicRight = 0x00008000,
};

struct RawGamepadState {
  bool connected = false;
  uint32_t buttons = 0;
  int16_t left_x = 0;
  int16_t left_y = 0;
  int16_t left_trigger = 0;
  int16_t right_trigger = 0;
};

struct ClassicInputState {
  bool connected = false;
  uint32_t buttons = 0;
  float left_stick_x = 0.0f;
  float left_stick_y = 0.0f;
};

inline constexpr int32_t kStickDeadzone = 8000;
inline constexpr int32_t kTriggerThreshold = 16000;

inline float NormalizeStickAxis(int16_t raw) {
  const int32_t value = raw;
  if (value >= -kStickDeadzone && value <= kStickDeadzone) {
    return 0.0f;
  }
  if (value > 0) {
    return static_cast<float>(value - kStickDeadzone) /
           static_cast<float>(32767 - kStickDeadzone);
  }
  return static_cast<float>(value + kStickDeadzone) /
         static_cast<float>(32768 - kStickDeadzone);
}

inline ClassicInputState MapGamepadToClassic(const RawGamepadState& input) {
  ClassicInputState output;
  output.connected = input.connected;
  if (!input.connected) {
    return output;
  }

  const auto map = [&](GamepadButton source, ClassicButton destination) {
    if ((input.buttons & static_cast<uint32_t>(source)) != 0) {
      output.buttons |= static_cast<uint32_t>(destination);
    }
  };
  map(kGamepadSouth, kClassicA);
  map(kGamepadEast, kClassicB);
  map(kGamepadWest, kClassicX);
  map(kGamepadNorth, kClassicY);
  map(kGamepadBack, kClassicMinus);
  map(kGamepadStart, kClassicPlus);
  map(kGamepadLeftShoulder, kClassicL);
  map(kGamepadRightShoulder, kClassicR);
  map(kGamepadDpadUp, kClassicUp);
  map(kGamepadDpadDown, kClassicDown);
  map(kGamepadDpadLeft, kClassicLeft);
  map(kGamepadDpadRight, kClassicRight);
  if (input.left_trigger >= kTriggerThreshold) {
    output.buttons |= kClassicZl;
  }
  if (input.right_trigger >= kTriggerThreshold) {
    output.buttons |= kClassicZr;
  }

  output.left_stick_x =
      std::clamp(NormalizeStickAxis(input.left_x), -1.0f, 1.0f);
  output.left_stick_y =
      std::clamp(-NormalizeStickAxis(input.left_y), -1.0f, 1.0f);
  return output;
}

}  // namespace kartpad::android
