#pragma once
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <cstring>

namespace kartpad::diagnostics {
struct MatrixSelection {
  bool complete = false;
  uint32_t sampled = 0;
  uint32_t outside_palette = 0;
  uint32_t non_row_multiple = 0;
  uint32_t max_raw = 0;
  uint16_t used_mask = 0;
};
// PNMTXIDX is the first byte when directly present. No input bytes leave this function.
inline MatrixSelection inspect_matrix_selection(const uint8_t* bytes, size_t size,
                                                uint32_t count, uint32_t stride) {
  MatrixSelection result;
  if (!bytes || stride == 0 || count > size / stride) return result;
  result.complete = true;
  for (uint32_t i = 0; i < count; ++i) {
    const unsigned raw = bytes[size_t(i) * stride];
    const unsigned slot = raw / 3;
    ++result.sampled;
    if (raw > result.max_raw) result.max_raw = raw;
    if (raw % 3) ++result.non_row_multiple;
    if (slot >= 10) ++result.outside_palette;
    else result.used_mask |= uint16_t(1u << slot);
  }
  return result;
}
inline unsigned count_nonfinite(const void* bytes, size_t size) {
  unsigned count = 0;
  auto* data = static_cast<const uint8_t*>(bytes);
  for (size_t offset = 0; offset + sizeof(float) <= size; offset += sizeof(float)) {
    float value;
    std::memcpy(&value, data + offset, sizeof(value));
    if (!std::isfinite(value)) ++count;
  }
  return count;
}
// Spread the 2048 inspections across 32 time slices, rather than exhausting
// them at the beginning of a busy 30-second window. Unused slots are not banked.
class DrawSamplingBudget {
 public:
  bool take(uint64_t elapsedMs) {
    if (elapsedMs >= 30000) return false; // Caller resets each window.
    const unsigned slice = unsigned(elapsedMs * 32 / 30000);
    if (used_[slice] >= 64) return false;
    ++used_[slice];
    return true;
  }
 private:
  std::array<unsigned, 32> used_{};
};
// Caller serializes on the renderer's existing mutex. Separate budgets keep normal
// startup samples from consuming the anomaly allowance. No dynamic allocation.
class DrawReportBudget {
 public:
  bool take(uint64_t pipeline, bool anomaly) {
    if (anomaly) {
      if (anomalies_ == 64) return false;
      ++anomalies_;
      return true;
    }
    for (unsigned i = 0; i < pipelines_; ++i) if (seen_[i] == pipeline) return false;
    if (pipelines_ == seen_.size()) return false;
    seen_[pipelines_++] = pipeline;
    return true;
  }
 private:
  std::array<uint64_t, 32> seen_{};
  unsigned pipelines_ = 0;
  unsigned anomalies_ = 0;
};
}

namespace kartpad::diagnostics {
// One render-thread window per targeted pipeline. Report the first occurrence
// of each outcome, then every five seconds. Encoded means an API draw command,
// not GPU completion or correct pixels. No geometry or buffer contents logged.
struct DrawOutcomeWindow {
  uint64_t encoded = 0, skipped = 0, lastMs = 0;
  unsigned reports = 0;
  bool seenEncoded = false, seenSkipped = false;
  bool record(bool issued, uint64_t nowMs) {
    if (reports >= 120) return false;
    bool& seen = issued ? seenEncoded : seenSkipped;
    const bool first = !seen;
    seen = true;
    if (issued) ++encoded; else ++skipped;
    if (!first && (nowMs < lastMs || nowMs - lastMs < 5000)) return false;
    lastMs = nowMs;
    ++reports;
    return true;
  }
  void clearCounts() { encoded = skipped = 0; }
};
}
