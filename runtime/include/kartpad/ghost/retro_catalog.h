#pragma once

#include <algorithm>
#include <array>
#include <cstdint>
#include <map>
#include <span>
#include <stdexcept>
#include <string>
#include <string_view>
#include <vector>

// Pulsar expanded v3 catalogs: ConfigRT/CT, English BMG names, and native ghost
// paths. No game assets, filesystem access, or license-specific storage here.
namespace kartpad::ghost::retro {
inline constexpr std::array<std::string_view, 4> Modes{"150", "200", "150F", "200F"};
enum class Source { Retro, Custom };
struct Variant {
    uint32_t index;
    uint8_t raceSlot;
    std::string label;
    std::string ghostDirectory; // Relative to managed NAND, without mode/name.
};
struct Track {
    uint32_t pulsarId, crc32, sourceIndex;
    Source source;
    std::string label;
    std::vector<Variant> variants; // Includes base variant 0.
};
struct Destination {
    uint32_t pulsarId, variantIndex;
    uint8_t raceSlot;
    // Native IPC paths include a leading slash and must fit 64 bytes with NUL.
    // Consumers must also bound the appended filename against that full path.
    std::string mode, label, directory;
    std::string expertPath; // Relative to the installed RetroRewind6 asset root.
};
struct Catalog {
    // FNV-1a64 of length-framed RT/CT bytes: change detection, not authentication.
    // Callers must retain their asset hash gate or compare config bytes directly.
    std::string identity, modFolder;
    std::vector<Track> tracks;
    Destination Select(uint32_t pulsarId, uint32_t variantIndex, uint32_t modeIndex) const {
        if (pulsarId < 0x100 || pulsarId - 0x100 >= tracks.size() || modeIndex >= Modes.size())
            throw std::runtime_error("Unknown Retro ghost destination");
        const auto& track = tracks[pulsarId - 0x100];
        if (variantIndex >= track.variants.size())
            throw std::runtime_error("Unknown Retro track variant");
        const auto& variant = track.variants[variantIndex];
        std::string mode(Modes[modeIndex]);
        std::string expert = track.source == Source::Retro ? "Ghosts/ExpertsRT/" : "Ghosts/ExpertsCT/";
        expert += std::to_string(track.sourceIndex);
        if (variantIndex != 0) expert += "_v" + std::to_string(variantIndex);
        expert += "_" + mode + ".rkg";
        return {pulsarId, variantIndex, variant.raceSlot, mode, variant.label,
                variant.ghostDirectory + "/" + mode, expert};
    }
};

namespace detail {
inline void Check(bool ok, const char* error) { if (!ok) throw std::runtime_error(error); }
struct Bytes {
    std::span<const uint8_t> data;
    std::span<const uint8_t> At(size_t pos, size_t count) const {
        Check(pos <= data.size() && count <= data.size() - pos, "Truncated Retro catalog");
        return data.subspan(pos, count);
    }
    uint16_t U16(size_t pos) const { auto b = At(pos, 2); return uint16_t(b[0]) << 8 | b[1]; }
    uint32_t U32(size_t pos) const {
        auto b = At(pos, 4);
        return uint32_t(b[0]) << 24 | uint32_t(b[1]) << 16 | uint32_t(b[2]) << 8 | b[3];
    }
    bool Is(size_t pos, std::string_view text) const {
        auto b = At(pos, text.size());
        return std::string_view(reinterpret_cast<const char*>(b.data()), b.size()) == text;
    }
};
inline std::string Hex(uint32_t value) {
    std::string out(8, '0');
    for (int i = 7; i >= 0; --i) { out[i] = "0123456789abcdef"[value & 15]; value >>= 4; }
    return out;
}
inline void Utf8(std::string& out, uint32_t cp) {
    if (cp < 0x80) out += char(cp);
    else if (cp < 0x800) { out += char(0xc0 | cp >> 6); out += char(0x80 | (cp & 63)); }
    else if (cp < 0x10000) {
        out += char(0xe0 | cp >> 12); out += char(0x80 | (cp >> 6 & 63)); out += char(0x80 | (cp & 63));
    } else {
        out += char(0xf0 | cp >> 18); out += char(0x80 | (cp >> 12 & 63));
        out += char(0x80 | (cp >> 6 & 63)); out += char(0x80 | (cp & 63));
    }
}
struct Bmg {
    Bytes info, strings;
    std::map<uint32_t, uint32_t> messages;
    std::vector<size_t> stringOffsets;
    explicit Bmg(Bytes b) {
        Check(b.Is(0, "MESGbmg1") && b.U32(8) == b.data.size() && b.At(16, 1)[0] == 2,
              "Unsupported Retro BMG header");
        uint32_t count = b.U32(12);
        Check(count >= 3 && count <= 16, "Invalid Retro BMG block count");
        std::map<uint32_t, Bytes> blocks;
        size_t pos = 32;
        for (uint32_t i = 0; i < count; ++i) {
            uint32_t tag = b.U32(pos), size = b.U32(pos + 4);
            Check(size >= 8 && blocks.emplace(tag, Bytes{b.At(pos, size)}).second,
                  "Invalid Retro BMG block");
            pos += size;
        }
        Check(pos == b.data.size() && blocks.contains(0x494e4631) && blocks.contains(0x44415431) &&
              blocks.contains(0x4d494431), "Missing Retro BMG block");
        info = blocks.at(0x494e4631); strings = blocks.at(0x44415431);
        auto mid = blocks.at(0x4d494431);
        uint32_t entries = info.U16(8);
        Check(info.U16(10) == 8 && entries == mid.U16(8) && mid.At(10, 1)[0] == 16,
              "Unsupported Retro BMG entries");
        info.At(16, size_t(entries) * 8); mid.At(16, size_t(entries) * 4);
        for (uint32_t i = 0; i < entries; ++i) {
            size_t offset = info.U32(16 + i * 8);
            Check(offset % 2 == 0 && offset < strings.data.size() - 8, "Invalid Retro BMG string offset");
            Check(messages.emplace(mid.U32(16 + i * 4), uint32_t(offset)).second, "Duplicate Retro BMG message ID");
            stringOffsets.push_back(offset);
        }
        stringOffsets.push_back(strings.data.size() - 8);
        std::sort(stringOffsets.begin(), stringOffsets.end());
    }
    std::string Label(uint32_t id) const {
        auto found = messages.find(id);
        Check(found != messages.end(), "Missing Retro track label");
        size_t start = found->second;
        size_t end = *std::upper_bound(stringOffsets.begin(), stringOffsets.end(), start);
        Bytes text{strings.At(8 + start, end - start)};
        size_t pos = 0;
        std::string out;
        for (;;) {
            uint32_t cp = text.U16(pos); pos += 2;
            if (cp == 0) break;
            if (cp == 0x1a) { // BMG control length is a byte, includes the introducer.
                uint8_t length = text.At(pos, 1)[0];
                Check(length >= 4 && length % 2 == 0, "Invalid Retro BMG control");
                text.At(pos - 2, length); pos += length - 2;
                continue;
            }
            if (cp >= 0xd800 && cp <= 0xdbff) {
                uint32_t low = text.U16(pos); pos += 2;
                Check(low >= 0xdc00 && low <= 0xdfff, "Invalid Retro BMG surrogate");
                cp = 0x10000 + ((cp - 0xd800) << 10) + low - 0xdc00;
            } else Check(cp < 0xdc00 || cp > 0xdfff, "Invalid Retro BMG surrogate");
            if (cp == 9 || cp == 10 || cp == 13 || cp == 32) {
                if (!out.empty() && out.back() != ' ') out += ' ';
            } else {
                Check(cp >= 32 && cp != 127, "Invalid Retro BMG label character");
                Utf8(out, cp);
            }
            Check(out.size() <= 1024, "Retro track label too long");
        }
        if (!out.empty() && out.back() == ' ') out.pop_back();
        Check(!out.empty(), "Empty Retro track label");
        return out;
    }
};
struct Config {
    Bytes cups;
    Bmg bmg;
    std::string root;
    uint32_t realTracks, storedTracks, variantCount;
    explicit Config(Bytes b) : cups{Section(b, 12, "CUPS", 3)}, bmg{BmgSection(b)} {
        Check(b.Is(0, "PULS") && b.U32(4) == 3, "Unsupported Retro config version");
        (void)Section(b, 8, "INFO", 1);
        auto name = b.At(20, 14);
        size_t end = 0; while (end < name.size() && name[end] != 0) ++end;
        Check(end > 1 && end <= 13 && name[0] == '/', "Invalid Retro mod folder");
        for (size_t i = 1; i < end; ++i)
            Check((name[i] >= 'a' && name[i] <= 'z') || (name[i] >= 'A' && name[i] <= 'Z') ||
                  (name[i] >= '0' && name[i] <= '9') || name[i] == '_', "Unsafe Retro mod folder");
        root.assign(reinterpret_cast<const char*>(name.data()), end);
        Check(cups.At(14, 1)[0] == 0, "Only expanded Retro course catalogs are supported");
        uint32_t cupCount = cups.U16(12);
        Check(cupCount > 0 && cupCount <= 1024, "Invalid Retro cup count");
        realTracks = cupCount * 4; storedTracks = (cupCount + (cupCount & 1)) * 4;
        variantCount = cups.U32(24);
        Check(variantCount <= 65536 && cups.data.size() == 28 + size_t(storedTracks) * 10 + size_t(variantCount) * 2,
              "Invalid Retro course tables");
        uint32_t sum = 0;
        for (uint32_t i = 0; i < storedTracks; ++i) sum += cups.U16(28 + i * 8 + 2);
        Check(sum == variantCount, "Retro variant count mismatch");
    }
    static std::span<const uint8_t> Section(Bytes b, size_t field, std::string_view tag, uint32_t version) {
        size_t pos = b.U32(field);
        Check(pos >= 36 && b.Is(pos, tag) && b.U32(pos + 4) == version,
              "Invalid Retro config section");
        uint32_t size = b.U32(pos + 8);
        Check(size >= 12, "Invalid Retro config section size");
        return b.At(pos, size);
    }
    static Bytes BmgSection(Bytes b) {
        size_t info = b.U32(8), cups = b.U32(12), bmg = b.U32(16);
        Check(info >= 36 && info < cups && cups < bmg && info + size_t(b.U32(info + 8)) == cups &&
              cups + size_t(b.U32(cups + 8)) == bmg, "Overlapping Retro config sections");
        return {b.At(bmg, b.U32(bmg + 8))};
    }
};
} // namespace detail

inline Catalog ParseCatalog(std::span<const uint8_t> rt, std::span<const uint8_t> ct) {
    using namespace detail;
    Check(rt.size() <= 8 * 1024 * 1024 && ct.size() <= 8 * 1024 * 1024, "Retro config too large");
    Config configs[]{Config{Bytes{rt}}, Config{Bytes{ct}}};
    Check(configs[0].root == configs[1].root, "Retro config roots differ");
    Catalog out; out.modFolder = configs[0].root;
    uint64_t hash = 14695981039346656037ull;
    auto feed = [&](uint8_t byte) { hash = (hash ^ byte) * 1099511628211ull; };
    for (uint8_t b : std::string_view("kartpad-retro-catalog-v1")) feed(b);
    for (auto bytes : {rt, ct}) {
        for (int shift = 56; shift >= 0; shift -= 8) feed(uint8_t(uint64_t(bytes.size()) >> shift));
        for (uint8_t byte : bytes) feed(byte);
    }
    out.identity = "v1-" + Hex(uint32_t(hash >> 32)) + Hex(uint32_t(hash));
    for (uint32_t source = 0; source < 2; ++source) {
        auto& config = configs[source]; uint32_t variantOffset = 0;
        for (uint32_t i = 0; i < config.realTracks; ++i) {
            size_t pos = 28 + i * 8; uint32_t variants = config.cups.U16(pos + 2);
            Check(variants <= 15, "Too many Retro track variants for BMG IDs");
            Track track{uint32_t(0x100 + out.tracks.size()), config.cups.U32(pos + 4), i,
                        source == 0 ? Source::Retro : Source::Custom, config.bmg.Label(0x20000 + i), {}};
            std::string directory = "shared2/Pulsar" + out.modFolder + "/Ghosts/" + Hex(track.crc32);
            for (uint32_t v = 0; v <= variants; ++v) {
                uint8_t slot = v == 0 ? config.cups.At(pos, 1)[0] :
                    config.cups.At(28 + size_t(config.storedTracks) * 8 + size_t(variantOffset + v - 1) * 2, 1)[0];
                Check(slot < 32, "Battle or invalid slot in Retro race catalog");
                auto label = variants == 0 ? track.label : config.bmg.Label(0x420000 + (i << 4) + v);
                track.variants.push_back({v, slot, label, directory + (v == 0 ? "" : "/" + std::to_string(v))});
            }
            variantOffset += variants; out.tracks.push_back(std::move(track));
        }
    }
    return out;
}
} // namespace kartpad::ghost::retro
