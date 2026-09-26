#include "kartpad/memory/checked_guest_memory.h"

#include <algorithm>
#include <limits>
#include <sstream>

namespace kartpad::memory {
namespace {

constexpr std::uint64_t kGuestDomainSize = 0x1'0000'0000ULL;

std::string FaultMessage(const char* operation, const std::uint32_t address,
                         const std::size_t width, const std::string& detail) {
  std::ostringstream stream;
  stream << operation << " at guest 0x" << std::hex << address << std::dec << " width " << width
         << ": " << detail;
  return stream.str();
}

}  // namespace

GuestMemoryFault::GuestMemoryFault(const FaultKind kind, const std::uint32_t address,
                                   const std::size_t width, std::string message,
                                   std::optional<FaultContext> context)
    : std::runtime_error(std::move(message)),
      kind_(kind),
      address_(address),
      width_(width),
      context_(std::move(context)) {}

GuestMemoryFault CheckedGuestMemory::MakeFault(const FaultKind kind, const std::uint32_t address,
                                               const std::size_t width,
                                               std::string message) const {
  std::optional<FaultContext> context;
  if (fault_context_provider_) {
    context = fault_context_provider_();
    std::ostringstream stream;
    stream << message << " [function=" << context->translated_function << " pc=0x" << std::hex
           << context->guest_pc << " lr=0x" << context->guest_lr << std::dec
           << " registers=" << context->register_dump << ']';
    message = stream.str();
  }
  return GuestMemoryFault(kind, address, width, std::move(message), std::move(context));
}

std::uint64_t CheckedGuestMemory::CheckedEnd(const std::uint32_t address,
                                             const std::size_t width) const {
  if (width == 0 || width > 8) {
    throw std::invalid_argument("guest scalar width must be 1, 2, 4, or 8 bytes");
  }
  const std::uint64_t end = static_cast<std::uint64_t>(address) + width;
  if (end > kGuestDomainSize) {
    throw MakeFault(FaultKind::Unmapped, address, width,
                    FaultMessage("access", address, width, "crosses 32-bit domain end"));
  }
  return end;
}

void CheckedGuestMemory::Map(const Region& region) {
  if (region.size == 0 || static_cast<std::uint64_t>(region.guest_base) + region.size >
                              kGuestDomainSize) {
    throw GuestMemoryFault(FaultKind::InvalidMapping, region.guest_base, 0,
                           "mapping is empty or crosses the 32-bit guest domain");
  }
  if (region.backing_offset > std::numeric_limits<std::uint64_t>::max() - region.size) {
    throw GuestMemoryFault(FaultKind::InvalidMapping, region.guest_base, 0,
                           "mapping backing range overflows");
  }

  std::scoped_lock lock{mutex_};
  const std::uint64_t new_end = static_cast<std::uint64_t>(region.guest_base) + region.size;
  for (const Mapping& existing : mappings_) {
    const std::uint64_t existing_end = static_cast<std::uint64_t>(existing.guest_base) + existing.size;
    if (region.guest_base < existing_end && existing.guest_base < new_end) {
      throw GuestMemoryFault(FaultKind::InvalidMapping, region.guest_base, 0,
                             "guest mapping overlaps an existing region");
    }
  }

  const std::uint64_t backing_end = region.backing_offset + region.size;
  if (backing_end > std::numeric_limits<std::size_t>::max()) {
    throw GuestMemoryFault(FaultKind::InvalidMapping, region.guest_base, 0,
                           "backing does not fit the host size type");
  }
  backings_[region.backing].resize(static_cast<std::size_t>(backing_end), std::byte{0});
  mappings_.push_back({region.guest_base, region.size, region.backing, region.backing_offset});
  std::sort(mappings_.begin(), mappings_.end(),
            [](const Mapping& left, const Mapping& right) {
              return left.guest_base < right.guest_base;
            });
}

void CheckedGuestMemory::RegisterMmio(const std::uint32_t start, const std::uint32_t end,
                                      MmioRead read, MmioWrite write) {
  if (end <= start || !read || !write) {
    throw std::invalid_argument("MMIO range/callback is invalid");
  }
  std::scoped_lock lock{mutex_};
  mmio_.push_back({start, end, std::move(read), std::move(write)});
}

void CheckedGuestMemory::RegisterExecutable(const std::uint32_t start, const std::uint32_t end) {
  if (end <= start) {
    throw std::invalid_argument("executable range is invalid");
  }
  std::scoped_lock lock{mutex_};
  executable_.push_back({start, end});
}

void CheckedGuestMemory::SetFaultContextProvider(FaultContextProvider provider) {
  std::scoped_lock lock{mutex_};
  fault_context_provider_ = std::move(provider);
}

void CheckedGuestMemory::Reset() {
  std::scoped_lock lock{mutex_};
  mappings_.clear();
  backings_.clear();
  mmio_.clear();
  executable_.clear();
  fault_context_provider_ = {};
}

const CheckedGuestMemory::Mapping* CheckedGuestMemory::FindMapping(const std::uint32_t address) const {
  for (const Mapping& mapping : mappings_) {
    if (address >= mapping.guest_base &&
        static_cast<std::uint64_t>(address) <
            static_cast<std::uint64_t>(mapping.guest_base) + mapping.size) {
      return &mapping;
    }
  }
  return nullptr;
}

const CheckedGuestMemory::MmioRange* CheckedGuestMemory::FindMmio(const std::uint32_t address,
                                                                  const std::size_t width) const {
  const std::uint64_t end = static_cast<std::uint64_t>(address) + width;
  for (const MmioRange& range : mmio_) {
    if (address >= range.start && end <= range.end) {
      return &range;
    }
  }
  return nullptr;
}

bool CheckedGuestMemory::IntersectsExecutable(const std::uint32_t address,
                                               const std::size_t width) const {
  const std::uint64_t end = static_cast<std::uint64_t>(address) + width;
  return std::any_of(executable_.begin(), executable_.end(), [&](const AddressRange& range) {
    return address < range.end && range.start < end;
  });
}

std::uint64_t CheckedGuestMemory::LoadUnsigned(const std::uint32_t address,
                                               const std::size_t width) const {
  (void)CheckedEnd(address, width);
  if (width != 1 && width != 2 && width != 4 && width != 8) {
    throw std::invalid_argument("guest scalar width must be 1, 2, 4, or 8 bytes");
  }
  std::unique_lock lock{mutex_};
  if (const MmioRange* range = FindMmio(address, width); range != nullptr) {
    MmioRead read = range->read;
    lock.unlock();
    return read(address, width);
  }

  const Mapping* mapping = FindMapping(address);
  if (mapping == nullptr) {
    throw MakeFault(FaultKind::Unmapped, address, width,
                    FaultMessage("load", address, width, "unmapped byte"));
  }
  const std::uint64_t map_end = static_cast<std::uint64_t>(mapping->guest_base) + mapping->size;
  if (__builtin_expect(static_cast<std::uint64_t>(address) + width > map_end, 0)) {
    for (std::size_t index = 1; index < width; ++index) {
      const std::uint32_t current = address + static_cast<std::uint32_t>(index);
      const Mapping* next = FindMapping(current);
      if (next == nullptr) {
        throw MakeFault(FaultKind::Unmapped, address, width,
                        FaultMessage("load", address, width, "unmapped byte"));
      }
      if (next != mapping) {
        throw MakeFault(FaultKind::CrossRegion, address, width,
                        FaultMessage("load", address, width, "crosses a mapping boundary"));
      }
    }
  }

  const auto& backing = backings_.at(mapping->backing);
  const std::size_t base_offset = static_cast<std::size_t>(mapping->backing_offset + (address - mapping->guest_base));
  std::uint64_t value = 0;
  for (std::size_t index = 0; index < width; ++index) {
    value = (value << 8U) |
            std::to_integer<std::uint8_t>(backing.at(base_offset + index));
  }
  return value;
}

std::int64_t CheckedGuestMemory::LoadSigned(const std::uint32_t address,
                                            const std::size_t width) const {
  const std::uint64_t value = LoadUnsigned(address, width);
  if (width == 8) {
    return static_cast<std::int64_t>(value);
  }
  const unsigned bits = static_cast<unsigned>(width * 8);
  const std::uint64_t sign = std::uint64_t{1} << (bits - 1U);
  return static_cast<std::int64_t>((value ^ sign) - sign);
}

void CheckedGuestMemory::Store(const std::uint32_t address, const std::size_t width,
                               const std::uint64_t value) {
  (void)CheckedEnd(address, width);
  if (width != 1 && width != 2 && width != 4 && width != 8) {
    throw std::invalid_argument("guest scalar width must be 1, 2, 4, or 8 bytes");
  }
  std::unique_lock lock{mutex_};
  if (IntersectsExecutable(address, width)) {
    throw MakeFault(FaultKind::ExecutableWrite, address, width,
                    FaultMessage("store", address, width, "intersects executable range"));
  }
  if (const MmioRange* range = FindMmio(address, width); range != nullptr) {
    MmioWrite write = range->write;
    lock.unlock();
    write(address, width, value);
    return;
  }

  const Mapping* mapping = FindMapping(address);
  if (mapping == nullptr) {
    throw MakeFault(FaultKind::Unmapped, address, width,
                    FaultMessage("store", address, width, "unmapped byte"));
  }
  const std::uint64_t map_end = static_cast<std::uint64_t>(mapping->guest_base) + mapping->size;
  if (__builtin_expect(static_cast<std::uint64_t>(address) + width > map_end, 0)) {
    for (std::size_t index = 1; index < width; ++index) {
      const std::uint32_t current = address + static_cast<std::uint32_t>(index);
      const Mapping* next = FindMapping(current);
      if (next == nullptr) {
        throw MakeFault(FaultKind::Unmapped, address, width,
                        FaultMessage("store", address, width, "unmapped byte"));
      }
      if (next != mapping) {
        throw MakeFault(FaultKind::CrossRegion, address, width,
                        FaultMessage("store", address, width, "crosses a mapping boundary"));
      }
    }
  }

  auto& backing = backings_.at(mapping->backing);
  const std::size_t base_offset = static_cast<std::size_t>(mapping->backing_offset + (address - mapping->guest_base));
  for (std::size_t index = 0; index < width; ++index) {
    const unsigned shift = static_cast<unsigned>((width - 1U - index) * 8U);
    backing.at(base_offset + index) =
        static_cast<std::byte>((value >> shift) & 0xFFU);
  }
}

std::size_t CheckedGuestMemory::RegionCount() const {
  std::scoped_lock lock{mutex_};
  return mappings_.size();
}

std::uint64_t CheckedGuestMemory::BackingSize(const BackingId backing) const {
  std::scoped_lock lock{mutex_};
  const auto found = backings_.find(backing);
  return found == backings_.end() ? 0 : found->second.size();
}

}  // namespace kartpad::memory
