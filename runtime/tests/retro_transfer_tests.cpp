#include "kartpad/ghost/retro_transfer.h"
#include "retro_catalog_fixture.h"
#include "retro_ghost_fixture.h"

#include <fstream>
#include <iostream>

using namespace kartpad::ghost;
using namespace kartpad::ghost::retro;
using retro_fixture::Ghost;

static void Write(const fs::path& path, std::span<const uint8_t> bytes) {
  fs::create_directories(path.parent_path());
  std::ofstream out(path, std::ios::binary);
  out.write(reinterpret_cast<const char*>(bytes.data()), bytes.size());
  Require(out.good(), "test write failed");
}
static std::vector<uint8_t> ReadFile(const fs::path& path) {
  std::ifstream in(path, std::ios::binary);
  return {std::istreambuf_iterator<char>(in), std::istreambuf_iterator<char>()};
}
template<class F> static void Reject(F&& call) {
  bool rejected = false;
  try { call(); } catch (const std::exception&) { rejected = true; }
  Require(rejected, "unsafe operation accepted");
}

int main() {
  char temporary[] = "/tmp/kartpad-retro-transfer.XXXXXX";
  const char* directory = ::mkdtemp(temporary);
  Require(directory != nullptr, "test storage unavailable");
  const fs::path root(directory);
  // Retain this owned test fixture on failure to make the defect inspectable.
  auto [rt, ct] = retro_fixture::Fixtures();
  const auto rtPath = root / "RetroRewind/RetroRewind6/Binaries/ConfigRT.pul";
  const auto ctPath = root / "RetroRewind/RetroRewind6/Binaries/ConfigCT.pul";
  Write(rtPath, rt); Write(ctPath, ct);
  TransferStorage storage(root);
  const auto catalog = storage.LoadCatalog();
  const auto original = root / "NAND/title/00010004/524d4350/data/rksys.dat";
  const auto retro = root / "RetroRewind/riivolution/save/RetroWFC/RMCP/rksys.dat";
  const auto separate = root / "RetroRewind/riivolution/save/RetroWFC2/RMCP/rksys.dat";
  const std::vector<uint8_t> progress{4, 1, 9, 8};
  Write(original, progress); Write(retro, progress); Write(separate, progress);

  // Explicit destination wins: retail header course 8 is reused by many tracks.
  for (unsigned mode = 0; mode < 4; ++mode) {
    for (bool compressed : {false, true}) {
      const auto ghost = Ghost(compressed, uint8_t(mode + 10 * compressed));
      const auto destination = catalog.Select(0x100, 1, mode);
      const auto folder = root / "NAND" / destination.directory;
      const auto leaderboard = folder.parent_path() / "ldb.pul";
      Write(leaderboard, progress);
      const auto before = storage.Exportable(0x100, 1, mode, catalog.identity).size();
      storage.Stage(ghost, 0x100, 1, mode, catalog.identity);
      Require(storage.HasPending(), "request not staged");
      Require(storage.Exportable(0x100, 1, mode, catalog.identity).size() == before, "staging changed live ghost storage");
      Require(storage.Apply() && !storage.HasPending(), "import not applied");
      const auto records = storage.Exportable(0x100, 1, mode, catalog.identity);
      Require(records.size() == (compressed ? 2u : 1u), "missing round-trip ghost");
      bool found = false;
      for (const auto& record : records) {
        Require(record.filename.size() == 10, "NAND filename too long");
        if (record.bytes == ghost) found = true;
      }
      Require(found, "ghost bytes changed during transfer");
      Require(ReadFile(leaderboard) == progress, "leaderboard changed");
      Reject([&] { storage.Stage(ghost, 0x100, 1, mode, catalog.identity); });
      Require(!storage.HasPending(), "duplicate request staged");
      // The next iteration's staging must leave the existing entry intact.
      if (!compressed) {
        const auto saved = ReadFile(folder / records[0].filename);
        storage.Stage(Ghost(true, uint8_t(mode + 10)), 0x100, 1, mode, catalog.identity);
        Require(ReadFile(folder / records[0].filename) == saved, "staging changed existing ghost");
        storage.Cancel();
      }
    }
  }
  Require(ReadFile(original) == progress && ReadFile(retro) == progress &&
      ReadFile(separate) == progress, "save data changed");
  Require(!storage.Apply(), "empty apply did work");

  // Config replacement, malformed requests and cancellation never alter storage.
  const auto ghost = Ghost(false, 82);
  Reject([&] { storage.Stage(ghost, 0x100, 0, 0, "stale"); });
  Reject([&] { storage.Stage(ghost, 0x100, 0, 4, catalog.identity); });
  Reject([&] { storage.Stage(ghost, 0x999, 0, 0, catalog.identity); });
  auto broken = ghost; broken[80] ^= 1;
  Reject([&] { storage.Stage(broken, 0x100, 0, 0, catalog.identity); });
  storage.Stage(ghost, 0x100, 0, 0, catalog.identity);
  auto changed = rt; changed.back() ^= 1; Write(rtPath, changed);
  Reject([&] { storage.Apply(); });
  Require(storage.HasPending(), "stale request lost"); Write(rtPath, rt);
  const auto pending = root / "PendingRetroGhost.bin";
  auto request = ReadFile(pending); auto invalid = request; invalid.back() ^= 1; Write(pending, invalid);
  Reject([&] { storage.Apply(); }); Require(storage.HasPending(), "corrupt request lost");
  Write(pending, request); storage.Cancel(); Require(!storage.HasPending(), "cancel failed");

  // A name taken between staging and apply must never be overwritten.
  storage.Stage(ghost, 0x100, 0, 0, catalog.identity); request = ReadFile(pending);
  const auto destination = catalog.Select(0x100, 0, 0);
  const auto folder = root / "NAND" / destination.directory;
  char name[11]; std::snprintf(name, sizeof(name), "%06x.rkg", Read32(request, 16) & 0xffffffu);
  Write(folder / name, progress);
  Reject([&] { storage.Apply(); }); Require(ReadFile(folder / name) == progress, "collision overwritten");
  storage.Cancel();
  storage.Stage(ghost, 0x100, 0, 0, catalog.identity); request = ReadFile(pending);
  std::snprintf(name, sizeof(name), "%06x.rkg", Read32(request, 16) & 0xffffffu);
  Require(ReadFile(folder / name).empty(), "collision name reused");
  // Simulate a completed publication followed by process death before request cleanup.
  Write(folder / name, ghost);
  Require(storage.Apply() && !storage.HasPending(), "completed import not retryable");

  // Native code skips any comparison with the bundled expert's stored CRC.
  const auto custom = catalog.Select(0x104, 0, 2);
  Write(root / "RetroRewind/RetroRewind6" / custom.expertPath, ghost);
  Reject([&] { storage.Stage(ghost, 0x104, 0, 2, catalog.identity); });

  const auto crowded = root / "NAND" / catalog.Select(0x104, 0, 3).directory;
  for (unsigned i = 0; i < 37; ++i) Write(crowded / (std::to_string(i) + ".rkg"), progress);
  Reject([&] { storage.Stage(ghost, 0x104, 0, 3, catalog.identity); });
  Require(!storage.HasPending(), "full folder request staged");

  // Symlinks cannot redirect an import into another profile or outside the root.
  const auto unsafe = root / "NAND" / catalog.Select(0x105, 0, 0).directory;
  fs::create_directories(unsafe.parent_path()); fs::create_directory_symlink(root, unsafe);
  Reject([&] { storage.Stage(ghost, 0x105, 0, 0, catalog.identity); });
  Require(ReadFile(original) == progress && ReadFile(retro) == progress &&
      ReadFile(separate) == progress, "failure changed save data");
  std::cout << "Retro staging: four modes, variants, compressed/uncompressed exact round-trip, saves/leaderboards, duplicates, collisions, retries, stale/corrupt requests, experts, capacity and symlink guards passed\n";
  fs::remove_all(root);
}
