#include "kartpad/retro_rewind/archive_path.h"

#include <algorithm>
#include <cstddef>

namespace kartpad::retro_rewind {
namespace {

ArchiveMemberPath InvalidPath(const ArchivePathError error) {
  ArchiveMemberPath result;
  result.error = error;
  return result;
}

}  // namespace

ArchiveMemberPath ValidateArchiveMemberPath(const std::string_view name) {
  if (name.empty()) {
    return InvalidPath(ArchivePathError::Empty);
  }
  if (name.front() == '/') {
    return InvalidPath(ArchivePathError::Absolute);
  }
  if (name.find('\\') != std::string_view::npos) {
    return InvalidPath(ArchivePathError::Backslash);
  }
  if (name.find('\0') != std::string_view::npos) {
    return InvalidPath(ArchivePathError::Nul);
  }

  ArchiveMemberPath result;
  result.directory = name.back() == '/';
  const std::size_t content_size = name.size() - (result.directory ? 1 : 0);
  if (content_size == 0) {
    return InvalidPath(ArchivePathError::Empty);
  }
  if (name[content_size - 1] == '/') {
    return InvalidPath(ArchivePathError::EmptyComponent);
  }

  std::size_t component_start = 0;
  while (component_start < content_size) {
    const std::size_t slash = name.find('/', component_start);
    const std::size_t component_end =
        std::min(slash == std::string_view::npos ? content_size : slash,
                 content_size);
    const std::string_view component =
        name.substr(component_start, component_end - component_start);
    if (component.empty()) {
      return InvalidPath(ArchivePathError::EmptyComponent);
    }
    if (component == ".") {
      return InvalidPath(ArchivePathError::DotComponent);
    }
    if (component == "..") {
      return InvalidPath(ArchivePathError::ParentComponent);
    }
    if (component.find(':') != std::string_view::npos) {
      return InvalidPath(ArchivePathError::Colon);
    }
    result.components.emplace_back(component);
    component_start = component_end + 1;
  }

  return result;
}

}  // namespace kartpad::retro_rewind
