// Exercise the production ARM64 stack-switch assembly with TLS and host FP state.
// This is a switch-boundary test, not the full guest scheduler or JNI lifecycle.
#include "ppc_runtime.h"
#include <memory>
#include <thread>
struct alignas(16) SwitchContext {
    uint64_t registers[12]{};
    uint64_t sp = 0;
    uint32_t fpcr = 0, fpsr = 0;
    uint64_t d[8]{};
};
static_assert(sizeof(SwitchContext) == 176);
extern "C" void KartPadSwitchAndroidRuntimeFiber(SwitchContext*, const SwitchContext*);
extern "C" bool baseline(unsigned, double&, double, double, double);
struct Fixture {
    SwitchContext caller, fiber;
    CpuContext cpu{};
    unsigned completed = 0;
};
static thread_local Fixture* currentFixture;
static void fiber_entry(Fixture* f) {
    std::fesetround(FE_DOWNWARD);
    for (;;) {
        if (currentFixture != f || CurrentCpuContext() != &f->cpu || std::fegetround() != FE_DOWNWARD)
            std::abort();
        double result = 0;
        baseline(0, result, 1.25, 2.5, 0);
        if (result != 3.75) std::abort();
        ++f->completed;
        KartPadSwitchAndroidRuntimeFiber(&f->fiber, &f->caller);
    }
}
static void exercise() {
    Fixture f;
    f.cpu.gpr[1] = 0x80001000;
    currentFixture = &f;
    auto stack = std::make_unique<std::byte[]>(65536);
    f.fiber.registers[0] = reinterpret_cast<uintptr_t>(&f);
    f.fiber.registers[11] = reinterpret_cast<uintptr_t>(&fiber_entry);
    f.fiber.sp = (reinterpret_cast<uintptr_t>(stack.get()) + 65536) & ~uintptr_t(15);
    CpuContextScope scope(&f.cpu);
    std::fesetround(FE_UPWARD);
    for (unsigned i = 0; i < 10000; ++i) {
        KartPadSwitchAndroidRuntimeFiber(&f.caller, &f.fiber);
        if (currentFixture != &f || CurrentCpuContext() != &f.cpu ||
            std::fegetround() != FE_UPWARD || f.completed != i + 1) std::abort();
    }
    currentFixture = nullptr;
}
void test_fiber_tls() {
    std::thread t(exercise);
    exercise();
    t.join();
    std::puts("PASS 40000 production assembly switches; TLS and host rounding preserved");
}
