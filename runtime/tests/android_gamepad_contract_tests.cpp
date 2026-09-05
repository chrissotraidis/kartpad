#include "kartpad/android/gamepad_contract.h"
#include "kartpad/android/controller_mapping.hpp"

#include <cmath>
#include <cstdint>
#include <iostream>

namespace {

bool Near(float actual, float expected) {
  return std::fabs(actual - expected) < 0.0001f;
}

bool Require(bool condition, const char* message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << '\n';
  }
  return condition;
}

}  // namespace

int main() {
  using namespace kartpad::android;
  bool passed = true;

  const auto disconnected = MapGamepadToClassic({});
  passed &= Require(!disconnected.connected && disconnected.buttons == 0 &&
                        Near(disconnected.left_stick_x, 0.0f) &&
                        Near(disconnected.left_stick_y, 0.0f),
                    "disconnected controllers must be neutral");

  RawGamepadState buttons;
  buttons.connected = true;
  buttons.buttons = kGamepadSouth | kGamepadEast | kGamepadWest |
                    kGamepadNorth | kGamepadBack | kGamepadStart |
                    kGamepadLeftShoulder | kGamepadRightShoulder |
                    kGamepadDpadUp | kGamepadDpadDown |
                    kGamepadDpadLeft | kGamepadDpadRight;
  buttons.left_trigger = kTriggerThreshold;
  buttons.right_trigger = kTriggerThreshold;
  const auto mapped_buttons = MapGamepadToClassic(buttons);
  constexpr uint32_t kAllExpected =
      kClassicA | kClassicB | kClassicX | kClassicY | kClassicMinus |
      kClassicPlus | kClassicL | kClassicR | kClassicUp | kClassicDown |
      kClassicLeft | kClassicRight | kClassicZr;
  passed &= Require(mapped_buttons.connected &&
                        mapped_buttons.buttons == kAllExpected,
                    "standard SDL buttons must map to Classic buttons");

  const ControllerButtonMapping swapped{1, 0, 2, 3, 4};
  passed &= Require(IsValidControllerButtonMapping(swapped),
                    "A/B swap must be a valid permutation");
  passed &= Require(
      ApplyControllerButtonMapping(kGamepadSouth, swapped) == kGamepadEast &&
          ApplyControllerButtonMapping(kGamepadEast, swapped) == kGamepadSouth,
      "assigning a used physical button must swap game assignments");
  const ControllerButtonMapping invalid{0, 0, 2, 3, 4};
  passed &= Require(!IsValidControllerButtonMapping(invalid) &&
                        ApplyControllerButtonMapping(kGamepadSouth, invalid) ==
                            kGamepadSouth,
                    "invalid mappings must fail closed to default");

  RawGamepadState direct;
  direct.connected = true;
  direct.buttons = kGamepadLeftShoulder | kGamepadRightShoulder;
  direct.left_trigger = kTriggerThreshold;
  direct.right_trigger = kTriggerThreshold;
  const auto directMapped = MapGamepadToClassic(direct);
  passed &= Require(
      (directMapped.buttons & kClassicZr) != 0 &&
          (directMapped.buttons & kClassicL) != 0 &&
          (directMapped.buttons & kClassicR) != 0 &&
          (directMapped.buttons & kClassicZl) == 0,
      "KartPad shoulders and triggers must match the iOS direct mapping");

  buttons.left_trigger = kTriggerThreshold - 1;
  buttons.right_trigger = kTriggerThreshold - 1;
  buttons.buttons = 0;
  passed &= Require(MapGamepadToClassic(buttons).buttons == 0,
                    "triggers must remain released below the threshold");

  passed &= Require(!WpadMotorCommandEnablesRumble(kWpadMotorStop) &&
                        WpadMotorCommandEnablesRumble(kWpadMotorRumble) &&
                        !WpadMotorCommandEnablesRumble(2),
                    "only the WPAD rumble command may enable controller output");

  RawGamepadState axes;
  axes.connected = true;
  axes.left_x = 32767;
  axes.left_y = -32768;
  auto mapped_axes = MapGamepadToClassic(axes);
  passed &= Require(Near(mapped_axes.left_stick_x, 1.0f) &&
                        Near(mapped_axes.left_stick_y, 1.0f),
                    "positive X and SDL-up must map to positive Classic axes");
  axes.left_x = -32768;
  axes.left_y = 32767;
  mapped_axes = MapGamepadToClassic(axes);
  passed &= Require(Near(mapped_axes.left_stick_x, -1.0f) &&
                        Near(mapped_axes.left_stick_y, -1.0f),
                    "negative X and SDL-down must map to negative Classic axes");
  axes.left_x = kStickDeadzone;
  axes.left_y = -kStickDeadzone;
  mapped_axes = MapGamepadToClassic(axes);
  passed &= Require(Near(mapped_axes.left_stick_x, 0.0f) &&
                        Near(mapped_axes.left_stick_y, 0.0f),
                    "the inclusive deadzone must map to neutral");

  if (passed) {
    std::cout << "Android SDL gamepad contract passed\n";
  }
  return passed ? 0 : 1;
}
