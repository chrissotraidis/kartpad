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
  kGamepadLeftTrigger = 1u << 12,
  kGamepadRightTrigger = 1u << 13,
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
inline constexpr uint32_t kWpadMotorStop = 0;
inline constexpr uint32_t kWpadMotorRumble = 1;

inline constexpr bool WpadMotorCommandEnablesRumble(uint32_t command) {
  return command == kWpadMotorRumble;
}

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
  map(kGamepadLeftShoulder, kClassicZr);
  map(kGamepadRightShoulder, kClassicR);
  map(kGamepadDpadUp, kClassicUp);
  map(kGamepadDpadDown, kClassicDown);
  map(kGamepadDpadLeft, kClassicLeft);
  map(kGamepadDpadRight, kClassicRight);
  map(kGamepadLeftTrigger, kClassicL);
  map(kGamepadRightTrigger, kClassicR);
  if (input.left_trigger >= kTriggerThreshold) {
    output.buttons |= kClassicL;
  }
  if (input.right_trigger >= kTriggerThreshold) {
    output.buttons |= kClassicR;
  }

  output.left_stick_x =
      std::clamp(NormalizeStickAxis(input.left_x), -1.0f, 1.0f);
  output.left_stick_y =
      std::clamp(-NormalizeStickAxis(input.left_y), -1.0f, 1.0f);
  return output;
}

// A single Joy-Con reaches Android through the kernel driver in its upright
// layout; SDL only rotates Joy-Cons it opens through HIDAPI, which Android
// Bluetooth does not provide. Rotate a lone left or right Joy-Con to the
// sideways (rail up) grip: the stick steers, and the four buttons under the
// right thumb become the face buttons. Pairs and other controllers pass through.
inline constexpr uint16_t kNintendoVendorId = 0x057e;
inline constexpr uint16_t kJoyConLeftProductId = 0x2006;
inline constexpr uint16_t kJoyConRightProductId = 0x2007;

inline int16_t NegateAxis(int16_t value) {
  return static_cast<int16_t>(std::clamp(-static_cast<int32_t>(value), -32767, 32767));
}

inline RawGamepadState RotateSidewaysJoyCon(RawGamepadState input,
                                            uint16_t vendor, uint16_t product) {
  if (vendor != kNintendoVendorId ||
      (product != kJoyConLeftProductId && product != kJoyConRightProductId)) {
    return input;
  }
  const bool left = product == kJoyConLeftProductId;
  const int16_t x = input.left_x;
  const int16_t y = input.left_y;
  input.left_x = left ? y : NegateAxis(y);
  input.left_y = left ? NegateAxis(x) : x;

  const uint32_t buttons = input.buttons;
  const auto moved = [buttons](uint32_t from, uint32_t to) {
    return (buttons & from) != 0 ? to : 0u;
  };
  constexpr uint32_t faceAndDpad = kGamepadSouth | kGamepadEast | kGamepadWest |
      kGamepadNorth | kGamepadDpadUp | kGamepadDpadDown | kGamepadDpadLeft |
      kGamepadDpadRight;
  uint32_t rotated = buttons & ~faceAndDpad;
  if (left) {
    rotated |= moved(kGamepadDpadLeft, kGamepadSouth) |
               moved(kGamepadDpadDown, kGamepadEast) |
               moved(kGamepadDpadUp, kGamepadWest) |
               moved(kGamepadDpadRight, kGamepadNorth);
    // The left Joy-Con has Minus but no Plus; use it to pause.
    if ((buttons & kGamepadBack) != 0) rotated = (rotated & ~kGamepadBack) | kGamepadStart;
  } else {
    rotated |= moved(kGamepadEast, kGamepadSouth) |
               moved(kGamepadNorth, kGamepadEast) |
               moved(kGamepadSouth, kGamepadWest) |
               moved(kGamepadWest, kGamepadNorth);
  }
  input.buttons = rotated;
  return input;
}

}  // namespace kartpad::android
