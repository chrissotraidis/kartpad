// The full game-data check shared by the iPhone/iPad and Mac importers.
#pragma once

#import <Foundation/Foundation.h>

#include <cstdint>
#include <string>
#include <sys/stat.h>
#include <utility>
#include <vector>

// Every file the disc's own table (sys/fst.bin) lists must be present at its full size. The game
// checks the same rule when it starts (#370); checking at import too means a copy that didn't
// finish is caught there and never shows as ready to play. Returns nil when complete.
static inline NSString *KartPadIncompleteGameFilesError(NSString *root, NSString *cloudHint) {
  NSString *damaged = @"The game data's file table (sys/fst.bin) is damaged. Import your game data again.";
  NSData *fst = [NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"sys/fst.bin"]];
  if (fst == nil) return @"KartPad could not read sys/fst.bin.";
  const uint8_t *bytes = static_cast<const uint8_t *>(fst.bytes);
  const uint64_t length = fst.length;
  const auto be32 = [bytes](uint64_t at) -> uint64_t {
    return (uint64_t(bytes[at]) << 24) | (uint64_t(bytes[at + 1]) << 16) |
           (uint64_t(bytes[at + 2]) << 8) | uint64_t(bytes[at + 3]);
  };
  if (length < 12) return damaged;
  const uint64_t count = be32(8);
  if (count < 1 || count * 12 > length) return damaged;
  const uint64_t names = count * 12;
  const std::string filesRoot = std::string(root.fileSystemRepresentation) + "/files/";
  // A directory entry stores the index just past its last child.
  std::vector<std::pair<uint64_t, std::string>> directories{{count, ""}};
  unsigned long listed = 0;
  unsigned long incomplete = 0;
  std::string example;
  for (uint64_t index = 1; index < count; ++index) {
    while (directories.size() > 1 && index >= directories.back().first) directories.pop_back();
    const uint64_t word = be32(index * 12);
    const uint64_t nameStart = names + (word & 0xFFFFFF);
    uint64_t nameEnd = nameStart;
    while (nameEnd < length && bytes[nameEnd] != 0) ++nameEnd;
    if (nameStart >= length || nameEnd == nameStart) return damaged;
    const std::string name(reinterpret_cast<const char *>(bytes + nameStart), nameEnd - nameStart);
    if (name == "." || name == ".." || name.find('/') != std::string::npos) return damaged;
    const std::string path = directories.back().second + name;
    const uint64_t size = be32(index * 12 + 8);
    if ((word >> 24) != 0) {
      directories.emplace_back(size, path + "/");
      continue;
    }
    ++listed;
    struct stat info {};
    if (stat((filesRoot + path).c_str(), &info) != 0 || !S_ISREG(info.st_mode) ||
        uint64_t(info.st_size) < size) {
      if (incomplete++ == 0) example = path;
    }
  }
  if (incomplete == 0) return nil;
  return [NSString stringWithFormat:
      @"The game data is incomplete: %lu of %lu game files are missing or cut short, for example "
      @"files/%s. A copy probably didn't finish. %@",
      incomplete, listed, example.c_str(), cloudHint];
}
