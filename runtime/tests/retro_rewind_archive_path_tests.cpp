#include "kartpad/retro_rewind/archive_path.h"

#include <initializer_list>
#include <iostream>
#include <string>
#include <string_view>

namespace {

using kartpad::retro_rewind::ArchivePathError;
using kartpad::retro_rewind::ValidateArchiveMemberPath;

bool ExpectValid(const std::string_view input,
                 const std::initializer_list<std::string_view> components,
                 const bool directory = false) {
  const auto result = ValidateArchiveMemberPath(input);
  if (!result || result.directory != directory ||
      result.components.size() != components.size()) {
    std::cerr << "expected valid archive path\n";
    return false;
  }
  std::size_t index = 0;
  for (const std::string_view expected : components) {
    if (result.components[index++] != expected) {
      std::cerr << "archive component mismatch\n";
      return false;
    }
  }
  return true;
}

bool ExpectInvalid(const std::string_view input,
                   const ArchivePathError expected) {
  const auto result = ValidateArchiveMemberPath(input);
  if (result || result.error != expected || !result.components.empty()) {
    std::cerr << "unexpected archive path validation result\n";
    return false;
  }
  return true;
}

}  // namespace

int main() {
  bool ok = true;
  ok &= ExpectValid("RetroRewind6.12.5/file.bin",
                    {"RetroRewind6.12.5", "file.bin"});
  ok &= ExpectValid("RetroRewind6.12.5/a/b/", {"RetroRewind6.12.5", "a", "b"},
                    true);
  ok &= ExpectValid("RetroRewind6.12.5/caf\xC3\xA9.bin",
                    {"RetroRewind6.12.5", "caf\xC3\xA9.bin"});
  ok &= ExpectValid("file", {"file"});

  ok &= ExpectInvalid("", ArchivePathError::Empty);
  ok &= ExpectInvalid("/absolute", ArchivePathError::Absolute);
  ok &= ExpectInvalid("folder\\file", ArchivePathError::Backslash);
  const std::string embedded_nul{"folder\0file", 11};
  ok &= ExpectInvalid(embedded_nul, ArchivePathError::Nul);
  ok &= ExpectInvalid("folder//file", ArchivePathError::EmptyComponent);
  ok &= ExpectInvalid("folder//", ArchivePathError::EmptyComponent);
  ok &= ExpectInvalid("./file", ArchivePathError::DotComponent);
  ok &= ExpectInvalid("folder/./file", ArchivePathError::DotComponent);
  ok &= ExpectInvalid("../file", ArchivePathError::ParentComponent);
  ok &= ExpectInvalid("folder/../file", ArchivePathError::ParentComponent);
  ok &= ExpectInvalid("C:/file", ArchivePathError::Colon);
  ok &= ExpectInvalid("folder/name:stream", ArchivePathError::Colon);

  return ok ? 0 : 1;
}
