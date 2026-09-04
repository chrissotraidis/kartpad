#include "kartpad/retro_rewind/archive_scan.h"

#include <cstdint>
#include <iostream>
#include <limits>

namespace {

using kartpad::retro_rewind::ArchiveScan;
using kartpad::retro_rewind::ArchiveScanError;
using kartpad::retro_rewind::ValidateArchiveMemberPath;

bool Expect(const bool condition, const char* message) {
  if (!condition) {
    std::cerr << message << '\n';
  }
  return condition;
}

}  // namespace

int main() {
  bool ok = true;

  ArchiveScan scan{"RetroRewind6.12.5", 3, 100};
  const auto ignored =
      scan.Observe(ValidateArchiveMemberPath("Other/file"), 90, false, false);
  ok &= Expect(ignored && !ignored.selected, "safe foreign entry was not ignored");
  ok &= Expect(scan.selected_entries() == 0 && scan.selected_bytes() == 0,
               "ignored entry changed selected totals");

  const auto root = scan.Observe(
      ValidateArchiveMemberPath("RetroRewind6.12.5/"), 0, false, false);
  const auto first = scan.Observe(
      ValidateArchiveMemberPath("RetroRewind6.12.5/a"), 40, false, false);
  const auto second = scan.Observe(
      ValidateArchiveMemberPath("RetroRewind6.12.5/b"), 60, false, false);
  ok &= Expect(root && root.selected && first && first.selected && second &&
                   second.selected,
               "selected entries were not accepted");
  ok &= Expect(scan.selected_entries() == 3 && scan.selected_bytes() == 100,
               "selected totals are incorrect");
  const auto count_limit = scan.Observe(
      ValidateArchiveMemberPath("RetroRewind6.12.5/c"), 0, false, false);
  ok &= Expect(!count_limit && count_limit.error == ArchiveScanError::EntryLimit,
               "entry limit did not fail closed");
  const auto latched = scan.Observe(ValidateArchiveMemberPath("Other/safe"), 0,
                                    false, false);
  ok &= Expect(!latched && latched.error == ArchiveScanError::EntryLimit,
               "scan error was not latched");

  ArchiveScan size_scan{"RetroRewind6.12.5", 10, 99};
  const auto size_limit = size_scan.Observe(
      ValidateArchiveMemberPath("RetroRewind6.12.5/file"), 100, false, false);
  ok &= Expect(!size_limit &&
                   size_limit.error == ArchiveScanError::ExpandedSizeLimit,
               "expanded-size limit did not fail closed");

  ArchiveScan overflow_scan{"RetroRewind6.12.5", 10,
                            std::numeric_limits<std::uint64_t>::max()};
  const auto large = overflow_scan.Observe(
      ValidateArchiveMemberPath("RetroRewind6.12.5/a"),
      std::numeric_limits<std::int64_t>::max(), false, false);
  const auto overflow = overflow_scan.Observe(
      ValidateArchiveMemberPath("RetroRewind6.12.5/b"),
      std::numeric_limits<std::int64_t>::max(), false, false);
  ok &= Expect(large && overflow,
               "valid signed archive sizes should not overflow uint64 totals");
  const auto overflow_limit = overflow_scan.Observe(
      ValidateArchiveMemberPath("RetroRewind6.12.5/c"), 2, false, false);
  ok &= Expect(!overflow_limit &&
                   overflow_limit.error == ArchiveScanError::ExpandedSizeLimit,
               "uint64 expanded-size overflow was not rejected");

  struct UnsupportedCase {
    std::int64_t size;
    bool symlink;
    bool encrypted;
  };
  for (const UnsupportedCase test_case : {
           UnsupportedCase{1, true, false},
           UnsupportedCase{1, false, true},
           UnsupportedCase{-1, false, false},
       }) {
    ArchiveScan unsupported{"RetroRewind6.12.5", 10, 100};
    const auto result = unsupported.Observe(
        ValidateArchiveMemberPath("Other/file"), test_case.size,
        test_case.symlink, test_case.encrypted);
    ok &= Expect(!result && result.error == ArchiveScanError::UnsupportedEntry,
                 "unsupported entry was accepted");
  }

  ArchiveScan invalid{"RetroRewind6.12.5", 10, 100};
  const auto invalid_result = invalid.Observe(
      ValidateArchiveMemberPath("../file"), 1, false, false);
  ok &= Expect(!invalid_result &&
                   invalid_result.error == ArchiveScanError::InvalidPath,
               "invalid path was accepted by scan");

  return ok ? 0 : 1;
}
