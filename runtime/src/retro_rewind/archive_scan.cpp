#include "kartpad/retro_rewind/archive_scan.h"

#include <utility>

namespace kartpad::retro_rewind {

ArchiveScan::ArchiveScan(std::string expected_root,
                         const std::size_t maximum_entries,
                         const std::uint64_t maximum_expanded_bytes)
    : expected_root_(std::move(expected_root)),
      maximum_entries_(maximum_entries),
      maximum_expanded_bytes_(maximum_expanded_bytes) {}

ArchiveScanObservation ArchiveScan::Fail(const ArchiveScanError error) {
  error_ = error;
  return {.error = error, .selected = false};
}

ArchiveScanObservation ArchiveScan::Observe(
    const ArchiveMemberPath& path, const std::int64_t uncompressed_size,
    const bool symlink, const bool encrypted) {
  if (error_ != ArchiveScanError::None) {
    return {.error = error_, .selected = false};
  }
  if (!path || path.components.empty()) {
    return Fail(ArchiveScanError::InvalidPath);
  }
  if (symlink || encrypted || uncompressed_size < 0) {
    return Fail(ArchiveScanError::UnsupportedEntry);
  }
  if (path.components.front() != expected_root_) {
    return {};
  }
  if (selected_entries_ >= maximum_entries_) {
    return Fail(ArchiveScanError::EntryLimit);
  }

  const auto entry_bytes = static_cast<std::uint64_t>(uncompressed_size);
  if (selected_bytes_ > maximum_expanded_bytes_ ||
      entry_bytes > maximum_expanded_bytes_ - selected_bytes_) {
    return Fail(ArchiveScanError::ExpandedSizeLimit);
  }

  std::string path_key;
  for (const std::string& component : path.components) {
    if (!path_key.empty()) {
      path_key.push_back('/');
    }
    path_key.append(component);
  }
  if (!selected_paths_.insert(std::move(path_key)).second) {
    return Fail(ArchiveScanError::DuplicateEntry);
  }

  ++selected_entries_;
  selected_bytes_ += entry_bytes;
  return {.error = ArchiveScanError::None, .selected = true};
}

}  // namespace kartpad::retro_rewind
