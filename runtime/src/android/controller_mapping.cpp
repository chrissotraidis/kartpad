#include "kartpad/android/controller_mapping.hpp"

#include <atomic>

namespace kartpad::android {
namespace {

constexpr uint32_t Pack(const ControllerButtonMapping& mapping) noexcept {
  uint32_t packed = 0;
  for (std::size_t index = 0; index < mapping.size(); ++index) {
    packed |= static_cast<uint32_t>(mapping[index]) << (index * 4);
  }
  return packed;
}

std::atomic<uint32_t> g_mapping{Pack(kDefaultControllerButtonMapping)};

}  // namespace

void PublishControllerButtonMapping(
    const ControllerButtonMapping& mapping) noexcept {
  const auto valid = IsValidControllerButtonMapping(mapping)
      ? mapping : kDefaultControllerButtonMapping;
  g_mapping.store(Pack(valid), std::memory_order_release);
}

ControllerButtonMapping ReadControllerButtonMapping() noexcept {
  ControllerButtonMapping mapping{};
  const uint32_t packed = g_mapping.load(std::memory_order_acquire);
  for (std::size_t index = 0; index < mapping.size(); ++index) {
    mapping[index] = static_cast<uint8_t>((packed >> (index * 4)) & 0x0f);
  }
  return IsValidControllerButtonMapping(mapping)
      ? mapping : kDefaultControllerButtonMapping;
}

}  // namespace kartpad::android
