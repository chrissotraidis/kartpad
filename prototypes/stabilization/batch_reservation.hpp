#pragma once

#include <array>
#include <cstdint>
#include <limits>
#include <span>
#include <vector>

// Experimental draw admission, deliberately not wired into Aurora yet.
// A reservation either commits every range or changes nothing. The producer
// owns flushing; allocation code must never wait on the renderer worker.
namespace kartpad::prototype {
enum class Buffer : unsigned { Vertex, Uniform, Index, Storage, Count };
using Sizes = std::array<uint64_t, unsigned(Buffer::Count)>;
struct Request { Buffer buffer; uint64_t bytes; uint64_t alignment; };
struct Range { Buffer buffer; uint64_t offset; uint64_t size; };
enum class Admission { Accepted, Flush, Oversized, Invalid };

class BatchReservation {
  Sizes capacity_, tail_, used_{};

  static bool add(uint64_t a, uint64_t b, uint64_t& result) {
    if (b > std::numeric_limits<uint64_t>::max() - a) return false;
    result = a + b;
    return true;
  }
  static bool padded(uint64_t bytes, uint64_t alignment, uint64_t& result) {
    // Matches Aurora map/push: zero-length aligned allocations occupy one
    // alignment unit; all other allocations append their own trailing padding.
    if (!bytes) { result = alignment; return true; }
    const auto remainder = alignment ? bytes % alignment : 0;
    return add(bytes, remainder ? alignment - remainder : 0, result);
  }
  bool fits(const Sizes& sizes) const {
    for (unsigned i=0; i<sizes.size(); ++i) {
      uint64_t sealed;
      if (!add(sizes[i], tail_[i], sealed)) return false;
      if (!sealed) continue;
      // CopyBufferToBuffer rounds the final length to four bytes.
      if (!padded(sealed, 4, sealed) || sealed > capacity_[i] || sealed > UINT32_MAX) return false;
    }
    return true;
  }
public:
  BatchReservation(Sizes capacity, Sizes tail) : capacity_(capacity), tail_(tail) {}
  const Sizes& used() const { return used_; }
  void reset_after_submission() { used_ = {}; }

  Admission reserve(std::span<const Request> requests, std::vector<Range>& ranges) {
    Sizes next = used_, empty{};
    std::vector<Range> pending;
    pending.reserve(requests.size());
    for (const auto& request : requests) {
      const auto i = unsigned(request.buffer);
      if (i >= next.size()) return Admission::Invalid;
      uint64_t size;
      if (!padded(request.bytes, request.alignment, size)) return Admission::Invalid;
      if (request.alignment && next[i] % request.alignment) return Admission::Invalid;
      pending.push_back({request.buffer, next[i], size});
      if (!add(next[i], size, next[i]) || !add(empty[i], size, empty[i])) return Admission::Invalid;
      // Existing renderer Range offsets/sizes are uint32_t.
      if (empty[i] > UINT32_MAX) return Admission::Oversized;
    }
    if (!fits(empty)) return Admission::Oversized;
    if (!fits(next)) return Admission::Flush;
    used_ = next;
    ranges = std::move(pending);
    return Admission::Accepted;
  }
};
} // namespace kartpad::prototype
