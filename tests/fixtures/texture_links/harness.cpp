// Synthetic resources only; no game data or translated game function.
#include <array>
#include <cassert>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

#define MKW_RESTRICT __restrict__

constexpr uint32_t ram = 0x81000000u;
constexpr uint32_t model = ram + 0x1000u;
constexpr uint32_t table = model + 0x200u;
constexpr uint32_t wrapper = ram + 0x80u;
std::array<uint8_t, 0x4000> bytes{};
std::vector<uint32_t> found;
std::string filter;
uint32_t capacity = 0;
uint32_t result = 0;

struct CpuContext { std::array<uint32_t, 32> gpr{}; };
namespace MemoryInline {
uint32_t FlatRead32(uint32_t address) {
    if (address < ram || uint64_t{address} + 4u > uint64_t{ram} + bytes.size())
        throw std::out_of_range("guest read");
    const auto offset = address - ram;
    return uint32_t{bytes[offset]} << 24 | uint32_t{bytes[offset + 1]} << 16 |
           uint32_t{bytes[offset + 2]} << 8 | bytes[offset + 3];
}
}
void write(uint32_t address, uint32_t value) {
    assert(address >= ram && uint64_t{address} + 4 <= uint64_t{ram} + bytes.size());
    for (unsigned i = 0; i < 4; ++i) bytes[address - ram + i] = value >> (24 - 8 * i);
}
bool matches(uint32_t address) {
    std::string name;
    while (true) {
        if (address < ram || address - ram >= bytes.size()) throw std::out_of_range("name");
        char c = char(bytes[address++ - ram]);
        if (!c) break;
        name += c;
    }
    return filter.empty() || name.rfind(filter, 0) == 0;
}

// The test inserts a synthetic traversal after applying the production injector.
@FUNCTION@

void reset() {
    bytes.fill(0); found.clear(); filter.clear(); capacity = 8; result = 0;
    write(wrapper, model); write(model, 0x4d444c30u); write(model + 4, 0x300u);
}
void metadata(uint32_t target, const char* name, unsigned slot) {
    // Names deliberately live outside MDL0, in a separate BRRES-like pool.
    uint32_t name_address = ram + 0x3000u + slot * 0x40u;
    for (const char* p = name; *p; ++p) bytes[name_address++ - ram] = *p;
    write(target, ram + 0x3000u + slot * 0x40u - target);
}
void links(const std::vector<uint32_t>& targets) {
    write(table, uint32_t(targets.size()));
    for (size_t i = 0; i < targets.size(); ++i) {
        write(table + 4u + uint32_t(i) * 8u, 0); // unused material link
        write(table + 8u + uint32_t(i) * 8u, targets[i] - table);
    }
}
void run(uint32_t selected_table = table) {
    CpuContext ctx{}; ctx.gpr[3] = wrapper; ctx.gpr[4] = selected_table;
    func_802289DC(&ctx);
}
int main() {
    reset();
    metadata(model + 0x40, "body", 0);
    metadata(model + 0x80, "lm_0", 1);
    metadata(model + 0xc0, "lm_1", 2);
    // Invalid first and middle entries, followed by valid negative-relative
    // links. A stale link must neither crash nor hide later light maps.
    links({0x7e000000u, model + 0x40, ram + 0x3800u, model + 0x80, model + 0xc0});
    run();
    assert(result == 3 && found == std::vector<uint32_t>({model + 0x40, model + 0x80, model + 0xc0}));
    found.clear(); filter = "lm_"; capacity = 1; run();
    assert(result == 2 && found == std::vector<uint32_t>({model + 0x80}));
    found.clear(); capacity = 0; run();
    assert(result == 2 && found.empty());

    reset();
    metadata(model + 0x2cc, "lm_last", 0); // exact final 0x34-byte record
    links({model + 0x2cc}); run(); assert(result == 1);
    found.clear(); write(model + 4, 0x2ff); run();
    assert(result == 0 && found.empty()); // one-byte truncation
    write(model + 4, 0xffffffffu); run();
    assert(result == 0); // owning model must not wrap the guest address space
    write(model + 4, 0x20); run(); assert(result == 0);

    reset(); metadata(model + 0x40, "body", 0); metadata(model + 0x80, "lm_0", 1);
    links({model + 0x40, model + 0x80}); run();
    assert(result == 2 && found.size() == 2); // valid Original-like resource
    bool threw = false;
    try { run(0x70000000u); } catch (const std::out_of_range&) { threw = true; }
    assert(threw); // an unrelated bad table still faults; no global clamping
    reset(); metadata(model + 0x40, "body", 0); links({model + 0x40});
    write(model + 0x40, 0x70000000u - (model + 0x40));
    threw = false;
    try { run(); } catch (const std::out_of_range&) { threw = true; }
    assert(threw); // no blanket suppression of malformed name pointers
    std::cout << "texture-link traversal passed\n";
}
