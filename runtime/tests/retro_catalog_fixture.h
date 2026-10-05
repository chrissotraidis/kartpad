#pragma once
#include <cstdint>
#include <map>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

// Entirely synthetic v3 configs for portable transfer/catalog tests.
namespace retro_fixture {
using Bytes = std::vector<uint8_t>;
inline void U16(Bytes& b, size_t p, uint16_t v) { b.at(p) = uint8_t(v >> 8); b.at(p + 1) = uint8_t(v); }
inline void U32(Bytes& b, size_t p, uint32_t v) { U16(b, p, uint16_t(v >> 16)); U16(b, p + 2, uint16_t(v)); }
inline void Tag(Bytes& b, size_t p, const std::string& s) { for (char c : s) b.at(p++) = uint8_t(c); }
struct FixtureVariant { uint8_t raceSlot; std::string label; };
struct FixtureTrack { uint8_t raceSlot; uint32_t crc32; std::string label; std::vector<FixtureVariant> variants; };
inline Bytes MakeConfig(const std::vector<FixtureTrack>& tracks, const std::string& root = "/RetroRewind6") {
    if (tracks.empty() || tracks.size() % 4 || root.size() > 13) throw std::runtime_error("Invalid synthetic config");
    size_t cups = tracks.size() / 4, stored = (cups + (cups & 1)) * 4, variantCount = 0;
    std::map<uint32_t, std::string> labels;
    for (size_t i = 0; i < tracks.size(); ++i) {
        variantCount += tracks[i].variants.size(); labels[0x20000 + uint32_t(i)] = tracks[i].label;
        if (!tracks[i].variants.empty()) {
            labels[0x420000 + (uint32_t(i) << 4)] = tracks[i].label + " Base";
            for (size_t v = 0; v < tracks[i].variants.size(); ++v)
                labels[0x420001 + (uint32_t(i) << 4) + uint32_t(v)] = tracks[i].variants[v].label;
        }
    }
    Bytes c(28 + stored * 10 + variantCount * 2); Tag(c, 0, "CUPS"); U32(c, 4, 3); U32(c, 8, uint32_t(c.size()));
    U16(c, 12, uint16_t(cups)); U32(c, 24, uint32_t(variantCount));
    size_t vp = 28 + stored * 8;
    for (size_t i = 0; i < tracks.size(); ++i) {
        size_t p = 28 + i * 8; c[p] = tracks[i].raceSlot; c[p + 1] = tracks[i].raceSlot;
        U16(c, p + 2, uint16_t(tracks[i].variants.size())); U32(c, p + 4, tracks[i].crc32);
        for (const auto& v : tracks[i].variants) { c[vp++] = v.raceSlot; c[vp++] = v.raceSlot; }
    }
    // Dummy stored records deliberately use battle slots and duplicate zero CRCs.
    for (size_t i = tracks.size(); i < stored; ++i) c[28 + i * 8] = 41;
    Bytes inf(16 + labels.size() * 8), mid(16 + labels.size() * 4), dat(10);
    Tag(inf, 0, "INF1"); U32(inf, 8, uint32_t(labels.size()) << 16 | 8);
    Tag(mid, 0, "MID1"); U16(mid, 8, uint16_t(labels.size())); mid[10] = 16;
    Tag(dat, 0, "DAT1"); size_t index = 0;
    for (const auto& [id, label] : labels) {
        U32(inf, 16 + index * 8, uint32_t(dat.size() - 8)); U32(mid, 16 + index * 4, id); ++index;
        // Format controls contain embedded NULs; a string reader cannot stop there.
        dat.insert(dat.end(), {0, 0x1a, 8, 0, 0, 1, 0, 2});
        for (char ch : label) { dat.push_back(0); dat.push_back(uint8_t(ch)); }
        dat.insert(dat.end(), {0, 0});
    }
    for (auto* block : {&inf, &dat, &mid}) U32(*block, 4, uint32_t(block->size()));
    Bytes bmg(32); Tag(bmg, 0, "MESGbmg1"); U32(bmg, 12, 3); bmg[16] = 2;
    for (auto* block : {&inf, &dat, &mid}) bmg.insert(bmg.end(), block->begin(), block->end());
    U32(bmg, 8, uint32_t(bmg.size()));
    Bytes out(48); Tag(out, 0, "PULS"); U32(out, 4, 3); U32(out, 8, 36);
    U32(out, 12, 48); U32(out, 16, uint32_t(48 + c.size())); Tag(out, 20, root);
    Tag(out, 36, "INFO"); U32(out, 40, 1); U32(out, 44, 12);
    out.insert(out.end(), c.begin(), c.end()); out.insert(out.end(), bmg.begin(), bmg.end());
    return out;
}
inline std::pair<Bytes, Bytes> Fixtures() {
    return {MakeConfig({{0, 0x12345678, "Retro Course", {{1, "Retro Variant"}, {2, "Other Variant"}}},
                        {8, 0x23456789, "Another Retro", {}}, {13, 0x3456789a, "Retro Road", {}},
                        {24, 0x456789ab, "Retro Circuit", {}}}),
            MakeConfig({{0, 0x56789abc, "Custom Course", {}}, {1, 0x6789abcd, "Custom Farm", {}},
                        {13, 0x789abcde, "Custom Road", {}}, {24, 0x89abcdef, "Custom Circuit", {}}})};
}
} // namespace retro_fixture
