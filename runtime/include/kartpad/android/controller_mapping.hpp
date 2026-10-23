#pragma once

#include <array>
#include <cstddef>
#include <cstdint>

#include "kartpad/android/gamepad_contract.h"

namespace kartpad::android {

using ControllerButtonMapping = std::array<uint8_t, 12>;

inline constexpr ControllerButtonMapping kDefaultControllerButtonMapping{
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
};

inline constexpr std::array<uint32_t, 14> kMappablePhysicalButtons{
    kGamepadSouth, kGamepadEast, kGamepadWest, kGamepadNorth,
    kGamepadLeftShoulder, kGamepadRightShoulder, kGamepadDpadUp,
    kGamepadDpadDown, kGamepadDpadLeft, kGamepadDpadRight,
    kGamepadLeftTrigger, kGamepadRightTrigger, kGamepadLeftStick, kGamepadRightStick,
};

inline bool IsValidControllerButtonMapping(
    const ControllerButtonMapping& mapping) noexcept {
  for (const uint8_t physical : mapping) {
    if (physical >= kMappablePhysicalButtons.size()) return false;
  }
  return true;
}

inline uint32_t ApplyControllerButtonMapping(
    const uint32_t buttons, ControllerButtonMapping mapping) noexcept {
  if (!IsValidControllerButtonMapping(mapping)) {
    mapping = kDefaultControllerButtonMapping;
  }
  constexpr uint32_t mappedMask = kGamepadSouth | kGamepadEast |
      kGamepadWest | kGamepadNorth | kGamepadLeftShoulder |
      kGamepadRightShoulder | kGamepadDpadUp | kGamepadDpadDown |
      kGamepadDpadLeft | kGamepadDpadRight | kGamepadLeftTrigger | kGamepadRightTrigger |
      kGamepadLeftStick | kGamepadRightStick;
  uint32_t result = buttons & ~mappedMask;
  for (std::size_t game = 0; game < mapping.size(); ++game) {
    if ((buttons & kMappablePhysicalButtons[mapping[game]]) != 0) {
      result |= kMappablePhysicalButtons[game];
    }
  }
  return result;
}

void PublishControllerButtonMapping(
    const ControllerButtonMapping& mapping) noexcept;
ControllerButtonMapping ReadControllerButtonMapping() noexcept;

// Controller auto-accelerate (off by default; the touch A button has its own).
// Apply runs on the guest input thread with the mapped Classic buttons.
void PublishControllerAutoAccelerate(bool enabled) noexcept;
uint32_t ApplyControllerAutoAccelerate(uint32_t chan, uint32_t classicButtons,
                                       bool connected) noexcept;

// Rumble (on by default). WPADControlMotor reads it on the guest thread.
void PublishControllerRumble(bool enabled, int strengthPercent = 100) noexcept;
bool ControllerRumbleEnabled() noexcept;
float ControllerRumbleStrength() noexcept;

// Starts or stops player one's device vibration. Defined by the Android app's
// JNI bridge, which forwards changes to KartPadDeviceRumble.
void SetDeviceRumble(bool active) noexcept;

}  // namespace kartpad::android
