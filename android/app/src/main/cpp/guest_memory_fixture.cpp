#include "guest_memory_fixture.h"

#include <android/log.h>
#include <android/sharedmem.h>
#include <sys/mman.h>
#include <unistd.h>

#include <cerrno>
#include <cstddef>
#include <cstdint>

namespace {

constexpr char kLogTag[] = "KartPadFixture";
constexpr size_t kGuestReservationBytes = uint64_t{1} << 32;

bool Fail(const char* step) {
  __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                      "A1 guest memory failed step=%s errno=%d", step, errno);
  return false;
}

bool FailCheck(const char* step) {
  __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                      "A1 guest memory failed step=%s", step);
  return false;
}

}  // namespace

bool RunGuestMemoryFixture() {
  static_assert(sizeof(size_t) == sizeof(uint64_t));
  const long page_size_raw = sysconf(_SC_PAGESIZE);
  if (page_size_raw <= 0) return Fail("page-size");
  const size_t page_size = static_cast<size_t>(page_size_raw);
  if ((page_size & (page_size - 1)) != 0) {
    return FailCheck("page-size-power-of-two");
  }
  const size_t alias_bytes = page_size * 2;

  int shared_fd = ASharedMemory_create("kartpad-a1-memory", alias_bytes);
  if (shared_fd < 0) return Fail("shared-memory-create");
  void* reservation = MAP_FAILED;
  void* alias = MAP_FAILED;
  bool passed = false;

  do {
    if (ASharedMemory_setProt(shared_fd, PROT_READ | PROT_WRITE) != 0) {
      Fail("shared-memory-protection");
      break;
    }
    reservation = mmap(nullptr, kGuestReservationBytes, PROT_NONE,
                       MAP_PRIVATE | MAP_ANONYMOUS | MAP_NORESERVE, -1, 0);
    if (reservation == MAP_FAILED) {
      Fail("reserve-4gib");
      break;
    }
    const uintptr_t reservation_address =
        reinterpret_cast<uintptr_t>(reservation);
    if ((reservation_address & (page_size - 1)) != 0) {
      FailCheck("reservation-alignment");
      break;
    }

    auto* primary_address = static_cast<uint8_t*>(reservation) +
                            (kGuestReservationBytes / 2);
    void* primary = mmap(primary_address, alias_bytes, PROT_READ | PROT_WRITE,
                         MAP_SHARED | MAP_FIXED, shared_fd, 0);
    if (primary != primary_address) {
      Fail("primary-fixed-alias");
      break;
    }
    alias = mmap(nullptr, alias_bytes, PROT_READ | PROT_WRITE, MAP_SHARED,
                 shared_fd, 0);
    if (alias == MAP_FAILED) {
      Fail("secondary-alias");
      break;
    }

    auto* primary_bytes = static_cast<uint8_t*>(primary);
    auto* alias_data = static_cast<uint8_t*>(alias);
    for (size_t index = 0; index < alias_bytes; ++index) {
      primary_bytes[index] = static_cast<uint8_t>((index * 131U + 17U) & 0xffU);
    }
    bool alias_matches = true;
    for (size_t index = 0; index < alias_bytes; ++index) {
      if (alias_data[index] !=
          static_cast<uint8_t>((index * 131U + 17U) & 0xffU)) {
        alias_matches = false;
        break;
      }
    }
    if (!alias_matches) {
      FailCheck("alias-read");
      break;
    }
    if (mprotect(primary, alias_bytes, PROT_READ) != 0) {
      Fail("primary-read-only");
      break;
    }
    alias_data[page_size] = 0x5a;
    if (primary_bytes[page_size] != 0x5a) {
      FailCheck("alias-write-visible");
      break;
    }
    if (mprotect(primary, alias_bytes, PROT_NONE) != 0 ||
        mprotect(primary, alias_bytes, PROT_READ) != 0) {
      Fail("primary-protection-cycle");
      break;
    }
    if (primary_bytes[page_size] != 0x5a) {
      FailCheck("protection-cycle-preserved-data");
      break;
    }
    passed = true;
  } while (false);

  if (alias != MAP_FAILED) munmap(alias, alias_bytes);
  if (reservation != MAP_FAILED) {
    munmap(reservation, kGuestReservationBytes);
  }
  close(shared_fd);
  if (passed) {
    __android_log_print(
        ANDROID_LOG_INFO, kLogTag,
        "A1 guest memory passed reserve_bytes=%zu alias_bytes=%zu page_size=%zu "
        "writable_executable=0",
        kGuestReservationBytes, alias_bytes, page_size);
  }
  return passed;
}
