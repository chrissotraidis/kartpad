#pragma once

#include <cstddef>
#include <cstdint>

namespace kartpad::retro_rewind {

enum class ArchiveExtractError {
  None,
  Cancelled,
  InvalidArgument,
  OpenFailed,
  MalformedArchive,
  UnsupportedEntry,
  DuplicateEntry,
  LimitExceeded,
  MissingRoot,
  IoFailure,
};

struct ArchiveExtractCallbacks {
  void* context = nullptr;
  bool (*cancelled)(void* context) = nullptr;
  void (*progress)(void* context, std::uint64_t extracted_bytes,
                   std::uint64_t total_bytes) = nullptr;
};

struct ArchiveExtractResult {
  ArchiveExtractError error = ArchiveExtractError::None;
  std::size_t selected_entries = 0;
  std::uint64_t selected_bytes = 0;
  std::uint64_t extracted_bytes = 0;

  explicit operator bool() const { return error == ArchiveExtractError::None; }
};

ArchiveExtractResult ExtractArchive(
    const char* archive_path, const char* staging_parent,
    const char* expected_root, std::size_t maximum_entries,
    std::uint64_t maximum_expanded_bytes,
    ArchiveExtractCallbacks callbacks = {});

}  // namespace kartpad::retro_rewind
