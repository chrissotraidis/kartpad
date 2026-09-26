#pragma once

#include <cstdint>

namespace kartpad::input {

// Controller auto-accelerate, matching the touch A button: holding accelerate
// for one second locks it on; the next press unlocks it. That unlocking press
// behaves as an ordinary hold and cannot lock again until A is released.
inline constexpr uint64_t kAutoAccelerateHoldMs = 1000;

class AutoAccelerateLatch {
 public:
  bool Apply(bool held, uint64_t nowMs, bool enabled) noexcept {
    if (!enabled) {
      Reset();
      return held;
    }
    if (held && !held_) {
      armed_ = !locked_;
      locked_ = false;
      pressStartMs_ = nowMs;
    } else if (!held) {
      armed_ = false;
    }
    held_ = held;
    if (armed_ && nowMs - pressStartMs_ >= kAutoAccelerateHoldMs) {
      locked_ = true;
      armed_ = false;
    }
    return held || locked_;
  }

  void Reset() noexcept { *this = AutoAccelerateLatch{}; }
  bool locked() const noexcept { return locked_; }

 private:
  bool held_ = false;
  bool armed_ = false;
  bool locked_ = false;
  uint64_t pressStartMs_ = 0;
};

}  // namespace kartpad::input
