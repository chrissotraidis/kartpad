#include "kartpad/retro_rewind/archive_extract.h"

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

namespace fs = std::filesystem;
using kartpad::retro_rewind::ArchiveExtractCallbacks;
using kartpad::retro_rewind::ArchiveExtractError;
using kartpad::retro_rewind::ExtractArchive;

namespace {

struct ProgressState {
  std::uint64_t last = 0;
  std::uint64_t total = 0;
  int calls = 0;
  bool cancel_after_progress = false;
};

bool Cancelled(void* opaque) {
  const auto* state = static_cast<ProgressState*>(opaque);
  return state->cancel_after_progress && state->calls > 0;
}

void Progress(void* opaque, const std::uint64_t extracted,
              const std::uint64_t total) {
  auto* state = static_cast<ProgressState*>(opaque);
  if (extracted < state->last || total < extracted) {
    std::cerr << "invalid progress sequence\n";
    std::exit(2);
  }
  state->last = extracted;
  state->total = total;
  ++state->calls;
}

bool Expect(const bool condition, const std::string& message) {
  if (!condition) std::cerr << message << '\n';
  return condition;
}

std::string Read(const fs::path& path) {
  std::ifstream stream{path, std::ios::binary};
  return {std::istreambuf_iterator<char>{stream},
          std::istreambuf_iterator<char>{}};
}

bool Run(const fs::path& fixtures, const fs::path& work,
         const std::string& name, const ArchiveExtractError expected,
         const std::uint64_t limit = 1000, const bool cancel = false) {
  const fs::path stage = work / ("stage-" + name);
  fs::create_directory(stage);
  ProgressState progress{.cancel_after_progress = cancel};
  const auto result = ExtractArchive(
      (fixtures / (name + ".zip")).c_str(), stage.c_str(), "RetroRewind6", 10,
      limit,
      ArchiveExtractCallbacks{.context = &progress,
                              .cancelled = Cancelled,
                              .progress = Progress});
  bool ok = Expect(result.error == expected,
                   name + ": unexpected extraction result " +
                       std::to_string(static_cast<int>(result.error)));
  if (expected == ArchiveExtractError::None) {
    ok &= Expect(result.selected_entries == 2, "valid: selected entry count");
    ok &= Expect(result.selected_bytes == 7, "valid: selected byte count");
    ok &= Expect(result.extracted_bytes == 7, "valid: extracted byte count");
    ok &= Expect(progress.calls > 0 && progress.last == 7 && progress.total == 7,
                 "valid: final progress");
    ok &= Expect(Read(stage / "RetroRewind6/version.txt") == "6.12.5\n",
                 "valid: extracted content");
    ok &= Expect(!fs::exists(stage / "foreign.txt"),
                 "valid: foreign-root content escaped selection");
  }
  return ok;
}

}  // namespace

int main(const int argc, char** argv) {
  if (argc != 3) {
    std::cerr << "usage: test FIXTURES WORK\n";
    return 64;
  }
  const fs::path fixtures = argv[1];
  const fs::path work = argv[2];
  fs::create_directories(work);

  bool ok = true;
  ok &= Run(fixtures, work, "valid", ArchiveExtractError::None);
  ok &= Run(fixtures, work, "traversal", ArchiveExtractError::MalformedArchive);
  ok &= Run(fixtures, work, "duplicate", ArchiveExtractError::DuplicateEntry);
  ok &= Run(fixtures, work, "alias", ArchiveExtractError::DuplicateEntry);
  ok &= Run(fixtures, work, "symlink", ArchiveExtractError::UnsupportedEntry);
  ok &= Run(fixtures, work, "slash-data", ArchiveExtractError::UnsupportedEntry);
  ok &= Run(fixtures, work, "encrypted", ArchiveExtractError::UnsupportedEntry);
  ok &= Run(fixtures, work, "invalid-utf8", ArchiveExtractError::MalformedArchive);
  ok &= Run(fixtures, work, "entry-limit", ArchiveExtractError::LimitExceeded);
  ok &= Run(fixtures, work, "missing", ArchiveExtractError::MissingRoot);
  ok &= Run(fixtures, work, "valid", ArchiveExtractError::LimitExceeded, 6);
  ok &= Run(fixtures, work, "cancel", ArchiveExtractError::Cancelled, 1000, true);
  ok &= Run(fixtures, work, "corrupt", ArchiveExtractError::MalformedArchive);

  const fs::path outside = work / "outside";
  const fs::path stage = work / "stage-preexisting-symlink";
  fs::create_directory(outside);
  fs::create_directory(stage);
  fs::create_directory_symlink(outside, stage / "RetroRewind6");
  const auto symlink_result = ExtractArchive(
      (fixtures / "valid.zip").c_str(), stage.c_str(), "RetroRewind6", 10, 1000);
  ok &= Expect(symlink_result.error == ArchiveExtractError::IoFailure,
               "preexisting output symlink was not rejected");
  ok &= Expect(fs::is_empty(outside), "preexisting output symlink was followed");

  return ok ? 0 : 1;
}
