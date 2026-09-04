#pragma once

#include <string>
#include <string_view>
#include <vector>

namespace kartpad::retro_rewind {

enum class ArchivePathError {
  None,
  Empty,
  Absolute,
  Backslash,
  Nul,
  EmptyComponent,
  DotComponent,
  ParentComponent,
  Colon,
};

struct ArchiveMemberPath {
  ArchivePathError error = ArchivePathError::None;
  std::vector<std::string> components;
  bool directory = false;

  explicit operator bool() const { return error == ArchivePathError::None; }
};

// Treats the archive name as opaque bytes. UTF-8 validation belongs to the
// platform archive reader; this function enforces the cross-platform path
// traversal contract without applying host filesystem normalization.
ArchiveMemberPath ValidateArchiveMemberPath(std::string_view name);

}  // namespace kartpad::retro_rewind
