#include "kartpad/android/gamepad_contract.h"
#include "kartpad/android/controller_mapping.hpp"
#include "kartpad/input/auto_accelerate.h"

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

  const ControllerButtonMapping swapped{1, 0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
  passed &= Require(IsValidControllerButtonMapping(swapped),
                    "A/B swap must be a valid permutation");
  passed &= Require(
      ApplyControllerButtonMapping(kGamepadSouth, swapped) == kGamepadEast &&
          ApplyControllerButtonMapping(kGamepadEast, swapped) == kGamepadSouth,
      "assigning a used physical button must swap game assignments");
  const ControllerButtonMapping invalid{12, 0, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
  passed &= Require(!IsValidControllerButtonMapping(invalid) &&
                        ApplyControllerButtonMapping(kGamepadSouth, invalid) ==
                            kGamepadSouth,
                    "invalid mappings must fail closed to default");

  const ControllerButtonMapping wheelieOnRightShoulder{0, 1, 2, 3, 4, 6, 5, 7, 8, 9, 10, 11};
  passed &= Require(IsValidControllerButtonMapping(wheelieOnRightShoulder),
                    "right shoulder and D-pad Up reassignment must be a valid swap");
  passed &= Require(
      ApplyControllerButtonMapping(kGamepadRightShoulder,
                                   wheelieOnRightShoulder) == kGamepadDpadUp &&
          ApplyControllerButtonMapping(kGamepadDpadUp,
                                       wheelieOnRightShoulder) == kGamepadRightShoulder,
      "right shoulder to D-pad Up must swap the existing R action");

  passed &= Require(
      ApplyControllerButtonMapping(0, wheelieOnRightShoulder) == 0 &&
          ApplyControllerButtonMapping(kGamepadRightShoulder | kGamepadDpadUp,
                                       wheelieOnRightShoulder) ==
              (kGamepadRightShoulder | kGamepadDpadUp),
      "release clears mapped actions and simultaneous inputs preserve both actions");
  constexpr uint32_t directButtons = kGamepadDpadDown | kGamepadDpadLeft |
      kGamepadDpadRight | kGamepadStart;
  passed &= Require(
      ApplyControllerButtonMapping(directButtons | kGamepadRightShoulder,
                                   wheelieOnRightShoulder) ==
          (directButtons | kGamepadDpadUp),
      "other D-pad directions and Start remain direct during remapped input");

  const ControllerButtonMapping shared{0, 1, 2, 3, 4, 5, 5, 7, 8, 9, 10, 11};
  const auto sharedBits = ApplyControllerButtonMapping(kGamepadRightShoulder, shared);
  passed &= Require(IsValidControllerButtonMapping(shared) &&
      sharedBits == (kGamepadRightShoulder | kGamepadDpadUp) &&
      ApplyControllerButtonMapping(0, shared) == 0,
      "shared shoulder must emit and release both drift and trick actions");


  auto triggerShared = kDefaultControllerButtonMapping;
  triggerShared[8] = 10; // D-pad Left and item from the left trigger.
  const auto triggerBits = ApplyControllerButtonMapping(kGamepadLeftTrigger, triggerShared);
  RawGamepadState triggerState; triggerState.connected=true; triggerState.buttons=triggerBits;
  passed &= Require(MapGamepadToClassic(triggerState).buttons == (kClassicL | kClassicLeft),
      "trigger must support shared item and D-pad actions");

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
  {
    // Sideways Joy-Con: upright stick and buttons rotate to the rail-up grip.
    RawGamepadState upright{};
    upright.connected = true;
    upright.left_y = 30000;  // Toward the lower end of an upright left Joy-Con.
    upright.buttons = kGamepadDpadLeft | kGamepadBack;
    const auto leftJoyCon = RotateSidewaysJoyCon(upright, kNintendoVendorId, kJoyConLeftProductId);
    passed &= Require(leftJoyCon.left_x == 30000 && leftJoyCon.left_y == 0,
                      "left Joy-Con lower end steers right");
    passed &= Require(leftJoyCon.buttons == (kGamepadSouth | kGamepadStart),
                      "left Joy-Con thumb button accelerates and Minus pauses");
    upright.left_y = -32768;
    upright.buttons = kGamepadEast;
    const auto rightJoyCon = RotateSidewaysJoyCon(upright, kNintendoVendorId, kJoyConRightProductId);
    passed &= Require(rightJoyCon.left_x == 32767 && rightJoyCon.buttons == kGamepadSouth,
                      "right Joy-Con top steers right and A accelerates");
    const auto pair = RotateSidewaysJoyCon(upright, kNintendoVendorId, 0x2008);
    passed &= Require(pair.left_y == -32768 && pair.buttons == kGamepadEast,
                      "other controllers are unchanged");
  }
  {
    kartpad::input::AutoAccelerateLatch latch;
    passed &= Require(!latch.Apply(true, 0, false) || !latch.locked(),
                      "disabled auto-accelerate never locks");
    passed &= Require(!latch.Apply(false, 5000, false),
                      "disabled auto-accelerate follows release");
    latch.Apply(true, 1000, true);
    passed &= Require(!latch.locked() && latch.Apply(true, 1999, true) && !latch.locked(),
                      "auto-accelerate waits one second");
    passed &= Require(latch.Apply(true, 2000, true) && latch.locked(),
                      "one-second hold locks accelerate");
    passed &= Require(latch.Apply(false, 2100, true),
                      "locked accelerate survives release");
    passed &= Require(latch.Apply(true, 3000, true) && !latch.locked(),
                      "next press unlocks while held");
    passed &= Require(latch.Apply(true, 9000, true) && !latch.locked(),
                      "unlocking press cannot relock");
    passed &= Require(!latch.Apply(false, 9100, true),
                      "release after unlock stops accelerate");
    latch.Apply(true, 10000, true);
    latch.Apply(false, 10500, true);
    passed &= Require(!latch.Apply(false, 12000, true) && !latch.locked(),
                      "short press does not lock");
    latch.Apply(true, 13000, true);
    latch.Apply(true, 14000, true);
    passed &= Require(!latch.Apply(false, 14100, false),
                      "disabling clears a lock");
  }

  return passed ? 0 : 1;
}
