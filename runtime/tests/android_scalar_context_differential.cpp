#include "ppc_runtime.h"
#include <array>
#include <bit>
#include <chrono>
#include <thread>

extern "C" bool baseline(unsigned, double&, double, double, double);
extern "C" bool candidate(unsigned, double&, double, double, double);
void ShowRuntimeFatalPopup(std::string_view, std::string_view) noexcept { std::abort(); }

struct Result {
    uint64_t value;
    uint32_t fpscr;
    int flags;
    bool write;
};
using Fn = bool (*)(unsigned, double&, double, double, double);

Result run(Fn fn, unsigned op, uint32_t fpscr, double a, double b, double c) {
    CpuContext cpu{};
    cpu.gpr[1] = 0x80001000;
    cpu.fpscr = fpscr;
    CpuContextScope scope(&cpu);
    std::feclearexcept(FE_ALL_EXCEPT);
    double d = std::bit_cast<double>(uint64_t{0x402a000000000000});
    bool write = fn(op, d, a, b, c);
    return {std::bit_cast<uint64_t>(d), cpu.fpscr, std::fetestexcept(FE_ALL_EXCEPT), write};
}

uint64_t rng(uint64_t& x) {
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    return x;
}

void check(uint64_t seed) {
    const std::array<uint64_t, 12> edges = {
        0, 0x8000000000000000ULL, 0x3ff0000000000000ULL, 0xbff0000000000000ULL,
        0x7ff0000000000000ULL, 0xfff0000000000000ULL, 0x7ff8000000000001ULL,
        0x7ff0000000000001ULL, 1, 0x0010000000000000ULL, 0x7fefffffffffffffULL,
        0x3810000000000000ULL};
    unsigned checks = 0;
    CpuContext outer{};
    outer.gpr[1] = 0x80002000;
    CpuContextScope outerScope(&outer);
    for (int mode : {FE_TONEAREST, FE_DOWNWARD, FE_UPWARD, FE_TOWARDZERO}) {
        std::fesetround(mode);
        for (unsigned i = 0; i < 4000; ++i) {
            double a = std::bit_cast<double>(i < edges.size() ? edges[i] : rng(seed));
            double b = std::bit_cast<double>(i < edges.size() ? edges[(i + 3) % edges.size()] : rng(seed));
            double c = std::bit_cast<double>(i < edges.size() ? edges[(i + 7) % edges.size()] : rng(seed));
            uint32_t fpscr = uint32_t(rng(seed));
            for (unsigned op = 0; op < 14; ++op) {
                auto x = run(baseline, op, fpscr, a, b, c);
                auto y = run(candidate, op, fpscr, a, b, c);
                if (x.value != y.value || x.fpscr != y.fpscr || x.flags != y.flags ||
                    x.write != y.write || g_currentCpuContext != &outer || std::fegetround() != mode) {
                    std::fprintf(stderr, "mismatch op=%u case=%u mode=%d\n", op, i, mode);
                    std::abort();
                }
                ++checks;
            }
        }
    }
    std::printf("PASS %u adapter differential cases; nested context and rounding preserved\n", checks);
}

int main() {
    std::thread t([] { check(0xabcdef01); });
    check(0x12345678);
    t.join();

    CpuContext cpu{};
    cpu.gpr[1] = 0x80001000;
    CpuContextScope scope(&cpu);
    std::fesetround(FE_TONEAREST);
    // Alternate order to expose drift. Emulator nanoseconds are not game FPS.
    for (int round = 0; round < 6; ++round) {
        for (int j = 0; j < 2; ++j) {
            int variant = (j + round) % 2;
            auto fn = variant ? candidate : baseline;
            double d = 0;
            auto start = std::chrono::steady_clock::now();
            for (int i = 0; i < 300000; ++i)
                fn(0, d, 1.25, 2.5, 0);
            auto ns = std::chrono::duration<double, std::nano>(
                std::chrono::steady_clock::now() - start).count() / 300000;
            std::printf("bench round=%d variant=%s ns=%.3f result=%.2f\n",
                        round, variant ? "candidate" : "baseline", ns, d);
        }
    }
}
