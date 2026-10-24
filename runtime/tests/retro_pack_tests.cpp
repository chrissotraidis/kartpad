#include "kartpad/ghost/retro_transfer.h"
#include "retro_catalog_fixture.h"
#include "retro_ghost_fixture.h"

#include <fstream>
#include <iostream>
#include <set>

using namespace kartpad::ghost;
using namespace kartpad::ghost::retro;

static std::vector<uint8_t> Read(const fs::path& path, size_t limit) {
  Require(fs::is_regular_file(path) && !fs::is_symlink(path) && fs::file_size(path) <= limit,
      "Invalid pack fixture file");
  std::ifstream in(path, std::ios::binary);
  std::vector<uint8_t> bytes{std::istreambuf_iterator<char>(in), {}};
  Require(!in.bad() && bytes.size() == fs::file_size(path), "Pack fixture read failed");
  return bytes;
}
static void Write(const fs::path& path, std::span<const uint8_t> bytes) {
  fs::create_directories(path.parent_path());
  std::ofstream out(path, std::ios::binary);
  out.write(reinterpret_cast<const char*>(bytes.data()), bytes.size());
  Require(out.good(), "Fixture write failed");
}
template<class F> static void Reject(F&& call) {
  bool rejected = false;
  try { call(); } catch (const std::exception&) { rejected = true; }
  Require(rejected, "Bundled expert was accepted as a new comparison");
}

int main(int argc, char** argv) {
  Require(argc == 1 || argc == 3, "Usage: retro_pack_tests [private RetroRewind6 root version]");
  const std::string version = argc == 3 ? argv[2] : "synthetic";
  Require(version == "synthetic" || version == "6.12.8" || version == "6.13.4", "Unknown pack fixture version");
  const size_t expectedExperts = version == "synthetic" ? 2 : version == "6.12.8" ? 373 : 394;
  char temporary[] = "/tmp/kartpad-retro-pack.XXXXXX";
  Require(::mkdtemp(temporary) != nullptr, "Temporary storage unavailable");
  const fs::path temporaryRoot(temporary), root = temporaryRoot / "support";
  fs::create_directories(root);
  try {
    // The supplied pack is read-only. All imported files and save sentinels
    // belong to a fresh temporary root, never an existing player profile.
    const fs::path pack = argc == 3 ? fs::path(argv[1]) : temporaryRoot / "synthetic-pack";
    if (argc == 1) {
      const auto [rt, ct] = retro_fixture::Fixtures();
      Write(pack / "Binaries/ConfigRT.pul", rt);
      Write(pack / "Binaries/ConfigCT.pul", ct);
      const auto catalog = ParseCatalog(rt, ct);
      Write(pack / catalog.Select(0x100, 1, 2).expertPath, retro_fixture::Ghost(true, 90));
      Write(pack / catalog.Select(0x104, 0, 3).expertPath, retro_fixture::Ghost(false, 91));
    }
    const auto rt = Read(pack / "Binaries/ConfigRT.pul", 1024 * 1024);
    const auto ct = Read(pack / "Binaries/ConfigCT.pul", 1024 * 1024);
    std::set<fs::path> allExperts;
    for (const char* name : {"ExpertsRT", "ExpertsCT"}) {
      const auto directory = pack / "Ghosts" / name;
      if (!fs::exists(directory)) continue;
      for (const auto& file : fs::directory_iterator(directory)) {
        if (file.path().extension() == ".rkg") allExperts.insert(file.path().lexically_normal());
      }
    }
    Require(allExperts.size() == expectedExperts, "Pack expert coverage incomplete");
    Write(root / "RetroRewind/RetroRewind6/Binaries/ConfigRT.pul", rt);
    Write(root / "RetroRewind/RetroRewind6/Binaries/ConfigCT.pul", ct);
    TransferStorage storage(root);
    const auto catalog = storage.LoadCatalog();
    const std::vector<uint8_t> sentinel{4, 1, 9, 8};
    const std::array<fs::path, 3> saves{
        root / "NAND/title/00010004/524d4350/data/rksys.dat",
        root / "RetroRewind/riivolution/save/RetroWFC/RMCP/rksys.dat",
        root / "RetroRewind/riivolution/save/RetroWFC2/RMCP/rksys.dat"};
    for (const auto& save : saves) Write(save, sentinel);
    size_t destinations = 0, experts = 0, padded = 0, nonbaseExperts = 0;
    std::array<size_t, 4> expertModes{};
    std::set<fs::path> mappedExperts;
    for (const auto& track : catalog.tracks) for (const auto& variant : track.variants) {
      for (unsigned mode = 0; mode < Modes.size(); ++mode) {
        const auto destination = catalog.Select(track.pulsarId, variant.index, mode);
        const auto folder = root / "NAND" / destination.directory;
        const auto leaderboard = folder.parent_path() / "ldb.pul";
        Write(leaderboard, sentinel);
        auto roundTrip = [&](const std::vector<uint8_t>& bytes) {
          Require(storage.Exportable(track.pulsarId, variant.index, mode, catalog.identity).empty(),
              "Unexpected comparison before staging");
          storage.Stage(bytes, track.pulsarId, variant.index, mode, catalog.identity);
          Require(storage.HasPending(), "Missing request");
          Require(storage.Exportable(track.pulsarId, variant.index, mode, catalog.identity).empty(),
              "Staging published a comparison before cold application");
          Require(storage.Apply() && !storage.HasPending(), "Cold application failed");
          const auto records = storage.Exportable(track.pulsarId, variant.index, mode, catalog.identity);
          Require(records.size() == 1 && records[0].bytes == bytes, "Pack transfer changed ghost bytes");
          Require(Read(leaderboard, sentinel.size()) == sentinel, "Leaderboard sentinel changed");
          for (const auto& save : saves)
            Require(Read(save, sentinel.size()) == sentinel, "Save sentinel changed");
          Require(fs::remove(folder / records[0].filename), "Fixture cleanup failed");
        };
        // Exercise every actual destination, including modes without experts.
        roundTrip(retro_fixture::Ghost((destinations & 1) != 0, uint8_t(destinations)));
        ++destinations;
        const auto expertPath = pack / destination.expertPath;
        if (!fs::exists(expertPath)) continue;
        const auto expert = Read(expertPath, GhostBytes);
        std::vector<uint8_t> inputs;
        const auto info = Validate(expert, &inputs);
        mappedExperts.insert(expertPath.lexically_normal());
        ++experts; ++expertModes[mode];
        if (variant.index != 0) ++nonbaseExperts;
        if (info.bytes != expert.size()) ++padded;
        const auto installedExpert = root / "RetroRewind/RetroRewind6" / destination.expertPath;
        Write(installedExpert, expert);
        Reject([&] { storage.Stage(expert, track.pulsarId, variant.index, mode, catalog.identity); });
        Require(!storage.HasPending(), "Rejected expert left a pending request");
        // Change only valid date metadata and its checksum; inputs and trailing
        // padding stay exact. This tests transfer, not replay compatibility.
        auto comparison = expert;
        const auto who = Read32(comparison, 8);
        Write32(comparison, 8, (who & ~(127u << 13)) | (((((who >> 13) & 127) + 1) % 100) << 13));
        Write32(comparison, info.bytes - 4, Crc(std::span<const uint8_t>(comparison).first(info.bytes - 4)));
        std::vector<uint8_t> comparisonInputs;
        Validate(comparison, &comparisonInputs);
        Require(inputs == comparisonInputs, "Metadata fixture changed driving inputs");
        roundTrip(comparison);
        Require(Read(installedExpert, GhostBytes) == expert, "Bundled expert changed");
        fs::remove(installedExpert);
      }
    }
    Require(mappedExperts == allExperts && experts == expectedExperts, "Pack expert coverage incomplete");
    std::cout << "Pack host transfer: " << destinations << " destinations, " << experts
              << " experts (" << nonbaseExperts << " nonbase, " << padded << " padded), modes "
              << expertModes[0] << '/' << expertModes[1] << '/' << expertModes[2] << '/' << expertModes[3]
              << "; exact bytes, unchanged inputs/saves/leaderboards, expert exclusion passed\n";
    fs::remove_all(temporaryRoot);
    return 0;
  } catch (const std::exception& error) {
    // Retain only this owned temporary fixture when a failure needs inspection.
    std::cerr << error.what() << "; fixture retained at " << temporaryRoot << '\n';
    return 1;
  }
}
