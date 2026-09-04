#pragma once

#include "kartpad/retro_rewind/archive_path.h"

#include <cstddef>
#include <cstdint>
#include <string>
#include <unordered_set>

namespace kartpad::retro_rewind {

enum class ArchiveScanError {
  None,
  InvalidPath,
  UnsupportedEntry,
  DuplicateEntry,
  EntryLimit,
  ExpandedSizeLimit,
};

struct ArchiveScanObservation {
  ArchiveScanError error = ArchiveScanError::None;
  bool selected = false;

  explicit operator bool() const { return error == ArchiveScanError::None; }
};

class ArchiveScan {
 public:
  ArchiveScan(std::string expected_root, std::size_t maximum_entries,
              std::uint64_t maximum_expanded_bytes);

  ArchiveScanObservation Observe(const ArchiveMemberPath& path,
                                 std::int64_t uncompressed_size,
                                 bool symlink, bool encrypted);

  std::size_t selected_entries() const { return selected_entries_; }
  std::uint64_t selected_bytes() const { return selected_bytes_; }
  ArchiveScanError error() const { return error_; }

 private:
  ArchiveScanObservation Fail(ArchiveScanError error);

  std::string expected_root_;
  std::size_t maximum_entries_ = 0;
  std::uint64_t maximum_expanded_bytes_ = 0;
  std::size_t selected_entries_ = 0;
  std::uint64_t selected_bytes_ = 0;
  std::unordered_set<std::string> selected_paths_;
  ArchiveScanError error_ = ArchiveScanError::None;
};

}  // namespace kartpad::retro_rewind
