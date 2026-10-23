#pragma once
// The KPAD fixture has no translated functions or CPU dispatcher. Keep those
// unrelated boundaries explicit while compiling the complete production file.
#include <cstdint>
#include <cstdlib>
struct CpuContext { uint32_t gpr[32]{}; };
template <uint32_t> void InvokeDirectCpu(CpuContext*) { std::abort(); }
#define PPC_NATIVE_OVERRIDE(...)
