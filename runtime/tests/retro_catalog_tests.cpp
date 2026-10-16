#include "kartpad/ghost/retro_catalog.h"
#include "retro_catalog_fixture.h"
#include <algorithm>
#include <fstream>
#include <iostream>

using namespace kartpad::ghost::retro;
using namespace retro_fixture;
static void Check(bool ok, const char* message) { if (!ok) throw std::runtime_error(message); }
template<class F> static void Reject(F call, const char* message) {
    bool rejected = false;
    try { call(); } catch (const std::runtime_error&) { rejected = true; }
    Check(rejected, message);
}
static size_t Find(const Bytes& b, std::initializer_list<uint8_t> pattern) {
    auto it = std::search(b.begin(), b.end(), pattern.begin(), pattern.end());
    Check(it != b.end(), "Missing synthetic test pattern"); return size_t(it - b.begin());
}
static void Synthetic() {
    auto [rt, ct] = Fixtures(); auto catalog = ParseCatalog(rt, ct);
    Check(catalog.tracks.size() == 8 && catalog.modFolder == "/RetroRewind6", "Padding entered catalog");
    auto destination = catalog.Select(0x100, 1, 2);
    Check(destination.raceSlot == 1 && destination.label == "Retro Variant" && destination.mode == "150F" &&
          destination.directory == "shared2/Pulsar/RetroRewind6/Ghosts/12345678/1/150F" &&
          destination.expertPath == "Ghosts/ExpertsRT/0_v1_150F.rkg", "Wrong variant destination");
    auto base = catalog.Select(0x100, 0, 0);
    Check(base.label == "Retro Course Base" && base.raceSlot == 0 &&
          base.directory == "shared2/Pulsar/RetroRewind6/Ghosts/12345678/150", "Wrong base destination");
    auto custom = catalog.Select(0x104, 0, 3);
    Check(custom.label == "Custom Course" && custom.expertPath == "Ghosts/ExpertsCT/0_200F.rkg" &&
          custom.directory == "shared2/Pulsar/RetroRewind6/Ghosts/56789abc/200F", "CT offset or expert index wrong");
    for (uint32_t mode = 0; mode < 4; ++mode)
        Check(catalog.Select(0x100, 2, mode).mode == Modes[mode], "Mode mapping changed");
    Reject([&] { catalog.Select(0xff, 0, 0); }, "Retail namespace accepted");
    Reject([&] { catalog.Select(0x108, 0, 0); }, "Missing track accepted");
    Reject([&] { catalog.Select(0x100, 3, 0); }, "Missing variant accepted");
    Reject([&] { catalog.Select(0x100, 0, 4); }, "Missing mode accepted");
    Check(ParseCatalog(rt, ct).identity == catalog.identity, "Catalog identity unstable");
    // Unused header padding still binds the complete file identity.
    auto changed = ct; changed[35] = 1;
    Check(ParseCatalog(rt, changed).identity != catalog.identity, "Config change not bound to identity");
    Check(ParseCatalog(ct, rt).identity != catalog.identity, "Source order not bound to identity");
    // A native shared CRC folder can have multiple explicit catalog aliases.
    auto alias = ct; U32(alias, 48 + 28 + 4, 0x12345678);
    auto aliases = ParseCatalog(rt, alias);
    Check(aliases.Select(0x100, 0, 0).directory == aliases.Select(0x104, 0, 0).directory,
          "Native shared CRC alias rejected");

    auto bad = [&](auto mutate, const char* message) {
        auto b = rt; mutate(b); Reject([&] { ParseCatalog(b, ct); }, message);
    };
    bad([](Bytes& b) { b[0] ^= 1; }, "Bad magic accepted");
    bad([](Bytes& b) { U32(b, 4, 2); }, "Old config accepted");
    bad([](Bytes& b) { U32(b, 12, 0xffffffff); }, "Out-of-range section accepted");
    bad([](Bytes& b) { U32(b, 16, 48); }, "Overlapping sections accepted");
    bad([](Bytes& b) { b[21] = '.'; }, "Unsafe root accepted");
    bad([](Bytes& b) { b[22] = 'X'; }, "Different roots accepted");
    bad([](Bytes& b) { b[48 + 14] = 1; }, "Unsupported regular namespace accepted");
    bad([](Bytes& b) { U32(b, 48 + 24, 3); }, "Variant count mismatch accepted");
    bad([](Bytes& b) { U16(b, 48 + 28 + 2, 0xffff); }, "Oversized variants accepted");
    bad([](Bytes& b) { b[48 + 28] = 32; }, "Battle track included");
    bad([](Bytes& b) { b[48 + 28 + 8 * 8] = 41; }, "Battle variant included");
    bad([](Bytes& b) { size_t p = Find(b, {0, 0x1a, 8, 0, 0, 1, 0, 2}); b[p + 2] = 3; }, "Bad BMG control accepted");
    bad([](Bytes& b) { size_t p = Find(b, {0, 'e', 0, 0}); U16(b, p + 2, 'A'); }, "Missing label terminator accepted");
    bad([](Bytes& b) { size_t p = Find(b, {'I','N','F','1'}); U32(b, p + 16, 0xffffffff); }, "Invalid string offset accepted");
    bad([](Bytes& b) { size_t p = Find(b, {'M','I','D','1'}); U32(b, p + 16, 0); }, "Missing label accepted");
    bad([](Bytes& b) { size_t p = Find(b, {'M','I','D','1'}); U32(b, p + 20, 0x20000); }, "Duplicate label ID accepted");
    bad([](Bytes& b) { size_t p = Find(b, {'D','A','T','1'}); U32(b, p + 4, 0xffffffff); }, "Oversized BMG block accepted");
    // Every cut inside the required config sections must reject without OOB reads.
    for (size_t length = 0; length < rt.size(); ++length)
        Reject([&] { ParseCatalog(std::span<const uint8_t>(rt).first(length), ct); }, "Truncated config accepted");
    auto unicode = MakeConfig({{0, 1, "XY", {}}, {1, 2, "A  B", {}}, {2, 3, "Third", {}}, {3, 4, "Fourth", {}}});
    size_t pair = Find(unicode, {0, 'X', 0, 'Y'}); U16(unicode, pair, 0xd83d); U16(unicode, pair + 2, 0xde00);
    auto decoded = ParseCatalog(unicode, ct);
    Check(decoded.tracks[0].label == "\xf0\x9f\x98\x80" && decoded.tracks[1].label == "A B", "UTF-16 or whitespace decoding failed");
    U16(unicode, pair + 2, 'Y'); Reject([&] { ParseCatalog(unicode, ct); }, "Unpaired surrogate accepted");
    std::cout << "Synthetic Retro catalog mapping, controls, aliases, selection and malformed-input checks passed\n";
}
static Bytes Read(const char* name) {
    std::ifstream f(name, std::ios::binary | std::ios::ate);
    Check(f.good() && f.tellg() > 0 && f.tellg() <= 8 * 1024 * 1024, "Cannot read bounded private config fixture");
    Bytes bytes(size_t(f.tellg())); f.seekg(0);
    Check(bool(f.read(reinterpret_cast<char*>(bytes.data()), std::streamsize(bytes.size()))), "Config fixture read failed");
    return bytes;
}
static void Actual(const char* rt, const char* ct) {
    auto catalog = ParseCatalog(Read(rt), Read(ct));
    Check(catalog.tracks.size() == 304, "Pinned race track count differs");
    size_t variants = 0; for (const auto& track : catalog.tracks) variants += track.variants.size();
    Check(variants == 341, "Pinned race variant count differs");
    auto lc = catalog.Select(0x158, 0, 0);
    Check(lc.label == "Wii Luigi Circuit" && lc.raceSlot == 0 &&
          lc.directory == "shared2/Pulsar/RetroRewind6/Ghosts/95ab4053/150" &&
          lc.expertPath == "Ghosts/ExpertsRT/88_150.rkg", "Pinned Wii course destination differs");
    Check(catalog.Select(0x1ac, 0, 0).expertPath == "Ghosts/ExpertsCT/0_150.rkg", "Pinned CT concatenation differs");
    for (const auto& track : catalog.tracks) for (const auto& variant : track.variants) for (uint32_t mode = 0; mode < 4; ++mode) {
        auto d = catalog.Select(track.pulsarId, variant.index, mode);
        Check(d.raceSlot < 32 && !d.label.empty() && d.directory.ends_with("/" + std::string(Modes[mode])), "Invalid pinned destination");
        Check(("/" + d.directory + "/123456.rkg").size() < 64, "Native IPC path limit exceeded");
    }
    std::cout << "Pinned 6.12.8 configs: 304 race tracks, 341 variants, 1364 valid destinations; identity " << catalog.identity << "\n";
}
int main(int argc, char** argv) {
    try {
        Check(argc == 1 || argc == 3, "Usage: retro_catalog_tests [ConfigRT.pul ConfigCT.pul]");
        Synthetic(); if (argc == 3) Actual(argv[1], argv[2]); return 0;
    } catch (const std::exception& e) { std::cerr << e.what() << '\n'; return 1; }
}
