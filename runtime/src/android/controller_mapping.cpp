#include "kartpad/android/controller_mapping.hpp"

#include "kartpad/input/auto_accelerate.h"

#include <array>
#include <atomic>
#include <chrono>

namespace kartpad::android {
namespace {

constexpr uint64_t Pack(const ControllerButtonMapping& mapping) noexcept {
  uint64_t packed = 0;
  for (std::size_t index = 0; index < mapping.size(); ++index) {
    packed |= static_cast<uint64_t>(mapping[index]) << (index * 4);
  }
  return packed;
}

std::atomic<uint64_t> g_mapping{Pack(kDefaultControllerButtonMapping)};
std::atomic<bool> g_autoAccelerate{false};
std::array<kartpad::input::AutoAccelerateLatch, 4> g_autoAccelerateLatches{};

}  // namespace

void PublishControllerButtonMapping(
    const ControllerButtonMapping& mapping) noexcept {
  const auto valid = IsValidControllerButtonMapping(mapping)
      ? mapping : kDefaultControllerButtonMapping;
  g_mapping.store(Pack(valid), std::memory_order_release);
}

ControllerButtonMapping ReadControllerButtonMapping() noexcept {
  ControllerButtonMapping mapping{};
  const uint64_t packed = g_mapping.load(std::memory_order_acquire);
  for (std::size_t index = 0; index < mapping.size(); ++index) {
    mapping[index] = static_cast<uint8_t>((packed >> (index * 4)) & 0x0f);
  }
  return IsValidControllerButtonMapping(mapping)
      ? mapping : kDefaultControllerButtonMapping;
}

void PublishControllerAutoAccelerate(const bool enabled) noexcept {
  g_autoAccelerate.store(enabled, std::memory_order_release);
}

uint32_t ApplyControllerAutoAccelerate(const uint32_t chan,
                                       const uint32_t classicButtons,
                                       const bool connected) noexcept {
  if (chan >= g_autoAccelerateLatches.size()) return classicButtons;
  auto& latch = g_autoAccelerateLatches[chan];
  if (!connected) {
    latch.Reset();
    return classicButtons;
  }
  const auto now = std::chrono::duration_cast<std::chrono::milliseconds>(
      std::chrono::steady_clock::now().time_since_epoch()).count();
  const bool accelerate = latch.Apply(
      (classicButtons & kClassicA) != 0, static_cast<uint64_t>(now),
      g_autoAccelerate.load(std::memory_order_acquire));
  return accelerate ? (classicButtons | kClassicA) : (classicButtons & ~kClassicA);
}

}  // namespace kartpad::android
