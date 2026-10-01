#pragma once

#include "kartpad/ghost/retro_catalog.h"
#include "kartpad/ghost/rkg.h"

#include <cerrno>
#include <cstdio>
#include <filesystem>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

namespace kartpad::ghost::retro {
namespace fs = std::filesystem;

// Shared by the Apple and Android shells. Apply runs before guest startup;
// staging and export never change either RKSYS profile or the leaderboard.
class TransferStorage {
  static constexpr size_t MaxConfigBytes = 1024 * 1024;
  static constexpr size_t MaxRequestBytes = 2 * MaxConfigBytes + GhostBytes + 36;
  fs::path root_;

  struct FileDescriptor {
    int value;
    ~FileDescriptor() { if (value >= 0) ::close(value); }
  };

  fs::path Path(const fs::path& relative) const {
    Require(!relative.is_absolute(), "Invalid Retro ghost path");
    fs::path result = root_;
    for (const auto& component : relative) {
      Require(component != ".." && component != ".", "Invalid Retro ghost path");
      result /= component;
      const auto status = fs::symlink_status(result);
      Require(!fs::is_symlink(status), "Retro ghost storage contains a symbolic link");
    }
    return result;
  }

  void Directories(const fs::path& relative) const {
    const auto path = Path(relative);
    fs::create_directories(path);
    Require(fs::is_directory(Path(relative)), "Retro ghost storage is unavailable");
  }

  static std::vector<uint8_t> Read(const fs::path& path, size_t limit) {
    FileDescriptor file{::open(path.c_str(), O_RDONLY | O_CLOEXEC | O_NOFOLLOW)};
    Require(file.value >= 0, "Retro ghost file could not be opened");
    struct stat status{};
    Require(::fstat(file.value, &status) == 0 && S_ISREG(status.st_mode) &&
        status.st_size >= 0 && uint64_t(status.st_size) <= limit,
        "Unsupported Retro ghost file size or type");
    std::vector<uint8_t> bytes(static_cast<size_t>(status.st_size));
    size_t done = 0;
    while (done < bytes.size()) {
      const auto count = ::read(file.value, bytes.data() + done, bytes.size() - done);
      if (count < 0 && errno == EINTR) continue;
      Require(count > 0, "Retro ghost file changed while reading");
      done += static_cast<size_t>(count);
    }
    uint8_t extra;
    Require(::read(file.value, &extra, 1) == 0, "Retro ghost file changed while reading");
    return bytes;
  }

  // Build a complete temporary file, then link it into place without replacing
  // any existing entry. A crash exposes either the complete file or no file.
  void WriteNew(const fs::path& target, std::span<const uint8_t> bytes) const {
    auto temporary = (root_ / ".PendingRetroGhost-XXXXXX").string();
    FileDescriptor file{::mkstemp(temporary.data())};
    Require(file.value >= 0, "Retro ghost staging is unavailable");
    try {
      size_t done = 0;
      while (done < bytes.size()) {
        const auto count = ::write(file.value, bytes.data() + done, bytes.size() - done);
        if (count < 0 && errno == EINTR) continue;
        Require(count > 0, "Retro ghost file could not be written");
        done += static_cast<size_t>(count);
      }
      Require(::fsync(file.value) == 0, "Retro ghost file could not be synchronized");
      Require(::link(temporary.c_str(), target.c_str()) == 0,
          "Retro ghost destination already exists or is unavailable");
      // Synchronize the new directory entry before finalizing the request.
      FileDescriptor directory{::open(target.parent_path().c_str(), O_RDONLY | O_CLOEXEC)};
      Require(directory.value >= 0 && ::fsync(directory.value) == 0,
          "Retro ghost directory could not be synchronized");
    } catch (...) {
      ::unlink(temporary.c_str());
      throw;
    }
    ::unlink(temporary.c_str());
  }

  std::pair<std::vector<uint8_t>, std::vector<uint8_t>> Configs() const {
    return {Read(Path("RetroRewind/RetroRewind6/Binaries/ConfigRT.pul"), MaxConfigBytes),
        Read(Path("RetroRewind/RetroRewind6/Binaries/ConfigCT.pul"), MaxConfigBytes)};
  }

  size_t CheckFolder(const Destination& destination, std::span<const uint8_t> ghost) const {
    Require(("/" + destination.directory + "/000000.rkg").size() < 64, "Retro ghost path exceeds the native limit");
    const auto info = Validate(ghost);
    const auto expert = Path(fs::path("RetroRewind/RetroRewind6") / destination.expertPath);
    if (fs::exists(expert)) {
      const auto bytes = Read(expert, GhostBytes);
      const auto expertInfo = Validate(bytes);
      Require(Read32(ghost, info.bytes - 4) != Read32(bytes, expertInfo.bytes - 4),
          "This ghost matches the bundled expert and would not appear in the comparison list");
    }
    const auto folder = Path(fs::path("NAND") / destination.directory);
    if (!fs::exists(folder)) return 0;
    Require(fs::is_directory(folder), "Retro ghost folder is unavailable");
    size_t count = 0;
    for (const auto& entry : fs::directory_iterator(folder)) {
      Require(++count <= 37, "The selected Retro ghost folder is full");
      Require(!entry.is_symlink(), "Retro ghost folder contains a symbolic link");
      if (entry.is_regular_file() && entry.file_size() == ghost.size()) {
        const auto bytes = Read(entry.path(), GhostBytes);
        Require(!std::equal(bytes.begin(), bytes.end(), ghost.begin(), ghost.end()),
            "This comparison ghost is already in the selected folder");
      }
    }
    Require(count < 37, "The selected Retro ghost folder is full; export or manage existing ghosts first");
    return count;
  }

  static std::string Filename(uint32_t seed) {
    char name[11];
    std::snprintf(name, sizeof(name), "%06x.rkg", seed & 0xffffffu);
    return name;
  }

public:
  explicit TransferStorage(fs::path supportRoot) : root_(std::move(supportRoot)) {
    Require(root_.is_absolute() && fs::is_directory(root_) && !fs::is_symlink(root_),
        "Retro ghost storage is unavailable");
  }

  Catalog LoadCatalog() const {
    const auto [rt, ct] = Configs();
    return ParseCatalog(rt, ct);
  }

  bool HasPending() const { return fs::exists(Path("PendingRetroGhost.bin")); }

  void Cancel() const {
    const auto file = Path("PendingRetroGhost.bin");
    if (fs::exists(file)) Require(fs::remove(file), "Pending Retro ghost could not be cancelled");
  }

  void Stage(std::span<const uint8_t> ghost, uint32_t track, unsigned variant,
      unsigned mode, const std::string& selectedIdentity) const {
    Require(!HasPending(), "Apply or cancel the pending Retro ghost first");
    Validate(ghost);
    const auto [rt, ct] = Configs();
    const auto catalog = ParseCatalog(rt, ct);
    Require(catalog.identity == selectedIdentity, "Retro configuration changed; choose the destination again");
    const auto destination = catalog.Select(track, variant, mode);
    CheckFolder(destination, ghost);
    const auto folder = fs::path("NAND") / destination.directory;
    uint32_t seed = Read32(ghost, Validate(ghost).bytes - 4);
    for (unsigned tries = 0; fs::exists(Path(folder / Filename(seed))); ++tries, ++seed)
      Require(tries < 37, "No unused Retro ghost filename is available");
    std::vector<uint8_t> request(32);
    Write32(request, 0, 0x4b505231); // KPR1
    Write32(request, 4, track); Write32(request, 8, variant); Write32(request, 12, mode);
    Write32(request, 16, seed); Write32(request, 20, uint32_t(rt.size()));
    Write32(request, 24, uint32_t(ct.size())); Write32(request, 28, uint32_t(ghost.size()));
    request.insert(request.end(), rt.begin(), rt.end());
    request.insert(request.end(), ct.begin(), ct.end());
    request.insert(request.end(), ghost.begin(), ghost.end());
    const size_t end = request.size(); request.resize(end + 4);
    Write32(request, end, Crc(std::span<const uint8_t>(request).first(end)));
    WriteNew(Path("PendingRetroGhost.bin"), request);
  }

  bool Apply() const {
    if (!HasPending()) return false;
    const auto file = Path("PendingRetroGhost.bin");
    const auto request = Read(file, MaxRequestBytes);
    Require(request.size() >= 36 && Read32(request, 0) == 0x4b505231,
        "Invalid pending Retro ghost request");
    const size_t rtSize = Read32(request, 20), ctSize = Read32(request, 24), ghostSize = Read32(request, 28);
    Require(rtSize <= MaxConfigBytes && ctSize <= MaxConfigBytes && ghostSize <= GhostBytes &&
        36 + rtSize + ctSize + ghostSize == request.size(), "Invalid pending Retro ghost bounds");
    Require(Read32(request, request.size() - 4) == Crc(std::span<const uint8_t>(request).first(request.size() - 4)),
        "Pending Retro ghost checksum mismatch");
    const auto [rt, ct] = Configs();
    const auto bytes = std::span<const uint8_t>(request);
    Require(std::equal(rt.begin(), rt.end(), bytes.begin() + 32, bytes.begin() + 32 + rtSize) &&
        std::equal(ct.begin(), ct.end(), bytes.begin() + 32 + rtSize, bytes.begin() + 32 + rtSize + ctSize),
        "Retro configuration changed; cancel the pending import and choose its destination again");
    const auto destination = ParseCatalog(rt, ct).Select(Read32(request, 4), Read32(request, 8), Read32(request, 12));
    const auto ghost = bytes.subspan(32 + rtSize + ctSize, ghostSize);
    Validate(ghost);
    const auto folder = fs::path("NAND") / destination.directory;
    const auto target = Path(folder / Filename(Read32(request, 16)));
    Require(("/" + destination.directory + "/" + target.filename().string()).size() < 64,
        "Retro ghost path exceeds the native limit");
    if (fs::exists(target)) {
      Require(Read(target, GhostBytes) == std::vector<uint8_t>(ghost.begin(), ghost.end()),
          "Retro ghost filename was taken; cancel the pending import and choose it again");
    } else {
      CheckFolder(destination, ghost);
      Directories(folder);
      WriteNew(target, ghost);
    }
    Require(fs::remove(file), "Retro ghost was imported but its pending request could not be finalized");
    return true;
  }

  struct Record { std::string filename; std::vector<uint8_t> bytes; };

  std::vector<Record> Exportable(uint32_t track, unsigned variant, unsigned mode,
      const std::string& selectedIdentity) const {
    const auto catalog = LoadCatalog();
    Require(catalog.identity == selectedIdentity, "Retro configuration changed; choose the destination again");
    const auto destination = catalog.Select(track, variant, mode);
    const auto folder = Path(fs::path("NAND") / destination.directory);
    std::vector<Record> records;
    if (!fs::exists(folder)) return records;
    Require(fs::is_directory(folder), "Retro ghost folder is unavailable");
    size_t count = 0;
    for (const auto& entry : fs::directory_iterator(folder)) {
      Require(++count <= 100, "Retro ghost folder exceeds the native file limit");
      if (!entry.is_regular_file() || entry.is_symlink() || entry.file_size() > GhostBytes) continue;
      const auto name = entry.path().filename().string();
      if (name.size() > 12 || ("/" + destination.directory + "/" + name).size() >= 64) continue;
      try {
        auto bytes = Read(entry.path(), GhostBytes);
        Validate(bytes);
        records.push_back({name, std::move(bytes)});
      } catch (const std::exception&) {
        // A corrupt entry must not prevent exporting another valid ghost.
      }
    }
    std::sort(records.begin(), records.end(), [](const Record& a, const Record& b) { return a.filename < b.filename; });
    return records;
  }
};
} // namespace kartpad::ghost::retro
