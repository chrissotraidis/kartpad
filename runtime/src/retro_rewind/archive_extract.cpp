#include "kartpad/retro_rewind/archive_extract.h"

#include "kartpad/retro_rewind/archive_path.h"
#include "kartpad/retro_rewind/archive_scan.h"

#include "mz.h"
#include "mz_strm.h"
#include "mz_zip.h"
#include "mz_zip_rw.h"

#include <cerrno>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <string>
#include <string_view>
#include <sys/stat.h>
#include <unistd.h>
#include <utility>
#include <vector>

namespace kartpad::retro_rewind {
namespace {

constexpr std::size_t kCopyBufferBytes = 1024 * 1024;

class FileDescriptor {
 public:
  explicit FileDescriptor(const int value = -1) : value_(value) {}
  ~FileDescriptor() {
    if (value_ >= 0) close(value_);
  }
  FileDescriptor(const FileDescriptor&) = delete;
  FileDescriptor& operator=(const FileDescriptor&) = delete;
  FileDescriptor(FileDescriptor&& other) noexcept
      : value_(std::exchange(other.value_, -1)) {}
  FileDescriptor& operator=(FileDescriptor&& other) noexcept {
    if (this != &other) {
      if (value_ >= 0) close(value_);
      value_ = std::exchange(other.value_, -1);
    }
    return *this;
  }
  int get() const { return value_; }
  explicit operator bool() const { return value_ >= 0; }

 private:
  int value_;
};

bool IsCancelled(const ArchiveExtractCallbacks& callbacks) {
  return callbacks.cancelled != nullptr &&
         callbacks.cancelled(callbacks.context);
}

bool IsStrictUtf8(const std::string_view value) {
  std::size_t index = 0;
  while (index < value.size()) {
    const auto first = static_cast<unsigned char>(value[index++]);
    if (first <= 0x7f) continue;
    std::uint32_t scalar = 0;
    std::size_t trailing = 0;
    if (first >= 0xc2 && first <= 0xdf) {
      scalar = first & 0x1f;
      trailing = 1;
    } else if (first >= 0xe0 && first <= 0xef) {
      scalar = first & 0x0f;
      trailing = 2;
    } else if (first >= 0xf0 && first <= 0xf4) {
      scalar = first & 0x07;
      trailing = 3;
    } else {
      return false;
    }
    if (trailing > value.size() - index) return false;
    for (std::size_t offset = 0; offset < trailing; ++offset) {
      const auto next = static_cast<unsigned char>(value[index++]);
      if ((next & 0xc0) != 0x80) return false;
      scalar = (scalar << 6) | (next & 0x3f);
    }
    if ((trailing == 2 && scalar < 0x800) ||
        (trailing == 3 && scalar < 0x10000) || scalar > 0x10ffff ||
        (scalar >= 0xd800 && scalar <= 0xdfff)) {
      return false;
    }
  }
  return true;
}

ArchiveExtractError MapScanError(const ArchiveScanError error) {
  switch (error) {
    case ArchiveScanError::None:
      return ArchiveExtractError::None;
    case ArchiveScanError::UnsupportedEntry:
      return ArchiveExtractError::UnsupportedEntry;
    case ArchiveScanError::DuplicateEntry:
      return ArchiveExtractError::DuplicateEntry;
    case ArchiveScanError::EntryLimit:
    case ArchiveScanError::ExpandedSizeLimit:
      return ArchiveExtractError::LimitExceeded;
    case ArchiveScanError::InvalidPath:
      return ArchiveExtractError::MalformedArchive;
  }
  return ArchiveExtractError::MalformedArchive;
}

bool EntryInfo(void* reader, mz_zip_file** info, ArchiveMemberPath* path,
               bool* directory, ArchiveExtractError* error) {
  if (mz_zip_reader_entry_get_info(reader, info) != MZ_OK || *info == nullptr ||
      (*info)->filename == nullptr) {
    *error = ArchiveExtractError::MalformedArchive;
    return false;
  }
  const std::string_view name{(*info)->filename,
                              static_cast<std::size_t>((*info)->filename_size)};
  if (!IsStrictUtf8(name)) {
    *error = ArchiveExtractError::MalformedArchive;
    return false;
  }
  *path = ValidateArchiveMemberPath(name);
  *directory = path->directory ||
               mz_zip_attrib_is_dir((*info)->external_fa,
                                    (*info)->version_madeby) == MZ_OK;
  return true;
}

FileDescriptor OpenOrCreateDirectory(const int parent, const std::string& name) {
  if (mkdirat(parent, name.c_str(), 0700) != 0 && errno != EEXIST) {
    return FileDescriptor{-1};
  }
  return FileDescriptor{
      openat(parent, name.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)};
}

FileDescriptor OpenParent(const int staging, const ArchiveMemberPath& path,
                          const std::size_t component_count) {
  const int duplicate = dup(staging);
  FileDescriptor current{duplicate};
  if (!current) return FileDescriptor{-1};
  for (std::size_t index = 0; index < component_count; ++index) {
    FileDescriptor next = OpenOrCreateDirectory(current.get(), path.components[index]);
    if (!next) return FileDescriptor{-1};
    current = std::move(next);
  }
  return current;
}

bool WriteAll(const int descriptor, const std::uint8_t* bytes, std::size_t count) {
  while (count > 0) {
    const ssize_t written = write(descriptor, bytes, count);
    if (written < 0) {
      if (errno == EINTR) continue;
      return false;
    }
    if (written == 0) return false;
    bytes += written;
    count -= static_cast<std::size_t>(written);
  }
  return true;
}

}  // namespace

ArchiveExtractResult ExtractArchive(
    const char* archive_path, const char* staging_parent,
    const char* expected_root, const std::size_t maximum_entries,
    const std::uint64_t maximum_expanded_bytes,
    const ArchiveExtractCallbacks callbacks) {
  ArchiveExtractResult result;
  if (archive_path == nullptr || *archive_path == '\0' ||
      staging_parent == nullptr || *staging_parent == '\0' ||
      expected_root == nullptr || *expected_root == '\0' ||
      maximum_entries == 0 || maximum_expanded_bytes == 0) {
    result.error = ArchiveExtractError::InvalidArgument;
    return result;
  }

  FileDescriptor staging{open(staging_parent,
                              O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)};
  if (!staging) {
    result.error = ArchiveExtractError::IoFailure;
    return result;
  }

  void* reader = mz_zip_reader_create();
  if (reader == nullptr || mz_zip_reader_open_file(reader, archive_path) != MZ_OK) {
    if (reader != nullptr) mz_zip_reader_delete(&reader);
    result.error = ArchiveExtractError::OpenFailed;
    return result;
  }

  ArchiveScan scan{expected_root, maximum_entries, maximum_expanded_bytes};
  int32_t status = mz_zip_reader_goto_first_entry(reader);
  while (status == MZ_OK && result.error == ArchiveExtractError::None) {
    if (IsCancelled(callbacks)) {
      result.error = ArchiveExtractError::Cancelled;
      break;
    }
    mz_zip_file* info = nullptr;
    ArchiveMemberPath path;
    bool directory = false;
    if (!EntryInfo(reader, &info, &path, &directory, &result.error)) break;
    const auto observation = scan.Observe(
        path, info->uncompressed_size,
        mz_zip_attrib_is_symlink(info->external_fa, info->version_madeby) == MZ_OK,
        (info->flag & MZ_ZIP_FLAG_ENCRYPTED) != 0);
    if (!observation) {
      result.error = MapScanError(observation.error);
      break;
    }
    if (observation.selected && directory && info->uncompressed_size != 0) {
      result.error = ArchiveExtractError::UnsupportedEntry;
      break;
    }
    status = mz_zip_reader_goto_next_entry(reader);
  }
  result.selected_entries = scan.selected_entries();
  result.selected_bytes = scan.selected_bytes();
  if (result.error == ArchiveExtractError::None && status != MZ_END_OF_LIST) {
    result.error = ArchiveExtractError::MalformedArchive;
  }
  if (result.error == ArchiveExtractError::None && result.selected_entries == 0) {
    result.error = ArchiveExtractError::MissingRoot;
  }

  std::vector<std::uint8_t> buffer(kCopyBufferBytes);
  if (result.error == ArchiveExtractError::None) {
    status = mz_zip_reader_goto_first_entry(reader);
  }
  while (status == MZ_OK && result.error == ArchiveExtractError::None) {
    if (IsCancelled(callbacks)) {
      result.error = ArchiveExtractError::Cancelled;
      break;
    }
    mz_zip_file* info = nullptr;
    ArchiveMemberPath path;
    bool directory = false;
    if (!EntryInfo(reader, &info, &path, &directory, &result.error)) break;
    if (path.components.front() == expected_root) {
      if (directory) {
        if (!OpenParent(staging.get(), path, path.components.size())) {
          result.error = ArchiveExtractError::IoFailure;
          break;
        }
      } else {
        FileDescriptor parent =
            OpenParent(staging.get(), path, path.components.size() - 1);
        if (!parent) {
          result.error = ArchiveExtractError::IoFailure;
          break;
        }
        FileDescriptor output{openat(parent.get(), path.components.back().c_str(),
                                     O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC |
                                         O_NOFOLLOW,
                                     0600)};
        if (!output || mz_zip_reader_entry_open(reader) != MZ_OK) {
          result.error = ArchiveExtractError::IoFailure;
          break;
        }
        std::uint64_t entry_bytes = 0;
        while (result.error == ArchiveExtractError::None) {
          if (IsCancelled(callbacks)) {
            result.error = ArchiveExtractError::Cancelled;
            break;
          }
          const int32_t count = mz_zip_reader_entry_read(
              reader, buffer.data(), static_cast<int32_t>(buffer.size()));
          if (count < 0) {
            result.error = ArchiveExtractError::MalformedArchive;
            break;
          }
          if (count == 0) break;
          const auto unsigned_count = static_cast<std::uint64_t>(count);
          if (entry_bytes > static_cast<std::uint64_t>(info->uncompressed_size) ||
              unsigned_count >
                  static_cast<std::uint64_t>(info->uncompressed_size) - entry_bytes) {
            result.error = ArchiveExtractError::MalformedArchive;
            break;
          }
          if (!WriteAll(output.get(), buffer.data(),
                        static_cast<std::size_t>(count))) {
            result.error = ArchiveExtractError::IoFailure;
            break;
          }
          entry_bytes += unsigned_count;
          result.extracted_bytes += unsigned_count;
          if (callbacks.progress != nullptr) {
            callbacks.progress(callbacks.context, result.extracted_bytes,
                               result.selected_bytes);
          }
        }
        if (mz_zip_reader_entry_close(reader) != MZ_OK &&
            result.error == ArchiveExtractError::None) {
          result.error = ArchiveExtractError::MalformedArchive;
        }
        if (result.error == ArchiveExtractError::None &&
            entry_bytes != static_cast<std::uint64_t>(info->uncompressed_size)) {
          result.error = ArchiveExtractError::MalformedArchive;
        }
      }
    }
    status = mz_zip_reader_goto_next_entry(reader);
  }
  if (result.error == ArchiveExtractError::None && status != MZ_END_OF_LIST) {
    result.error = ArchiveExtractError::MalformedArchive;
  }
  if (mz_zip_reader_close(reader) != MZ_OK &&
      result.error == ArchiveExtractError::None) {
    result.error = ArchiveExtractError::MalformedArchive;
  }
  mz_zip_reader_delete(&reader);
  return result;
}

}  // namespace kartpad::retro_rewind
