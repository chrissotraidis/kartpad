#include "scheduler_fixture.h"

#include "kartpad/scheduler/guest_scheduler.h"

#include <android/log.h>

#include <array>
#include <cstddef>
#include <cstdint>
#include <exception>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

using kartpad::scheduler::GuestCpuContext;
using kartpad::scheduler::GuestScheduler;
using kartpad::scheduler::StepAction;
using kartpad::scheduler::ThreadState;

constexpr char kLogTag[] = "KartPadFixture";
constexpr uint64_t kExpectedSchedulerHash = 0x7287563387fb1677ULL;
constexpr uint64_t kFiberSwitches = 1'000'000;

struct alignas(16) AndroidFiberContext {
  std::array<uint64_t, 10> x19_x28{};
  uint64_t fp = 0;
  uint64_t lr = 0;
  uint64_t sp = 0;
  uint64_t fpcr = 0;
  uint64_t fpsr = 0;
  uint64_t reserved = 0;
  std::array<uint64_t, 8> d8_d15{};
};

struct FiberState {
  AndroidFiberContext* fiber_context = nullptr;
  AndroidFiberContext* host_context = nullptr;
  uint64_t remaining = 0;
  uint64_t switches = 0;
  uint64_t failure = 0;
  uint64_t finished = 0;
  std::array<uint64_t, 9> expected_x20_x28{};
  std::array<uint64_t, 8> expected_d8_d15{};
  uint64_t expected_fpcr = 0;
  uint64_t expected_fpsr = 0;
  uint64_t expected_fp = 0;
};

static_assert(sizeof(AndroidFiberContext) == 192);
static_assert(offsetof(FiberState, expected_x20_x28) == 48);
static_assert(offsetof(FiberState, expected_d8_d15) == 120);
static_assert(offsetof(FiberState, expected_fpcr) == 184);
static_assert(offsetof(FiberState, expected_fpsr) == 192);
static_assert(offsetof(FiberState, expected_fp) == 200);

extern "C" void KartPadSwitchAndroidFiber(AndroidFiberContext* source,
                                           const AndroidFiberContext* target);
extern "C" void KartPadAndroidRegisterFiberEntry();

void Require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

uint64_t HashState(const std::vector<GuestScheduler::ThreadSnapshot>& snapshots,
                   uint64_t operations, uint64_t retraces) {
  uint64_t hash = 1469598103934665603ULL;
  const auto mix = [&](uint64_t value) {
    hash ^= value;
    hash *= 1099511628211ULL;
  };
  mix(operations);
  mix(retraces);
  for (const auto& snapshot : snapshots) {
    mix(snapshot.id);
    mix(snapshot.context.gpr[0]);
    mix(snapshot.context.gpr[31]);
    mix(snapshot.context.fpr_bits[0]);
    mix(snapshot.context.fpr_bits[31]);
    for (uint8_t byte : snapshot.context.simd_state) mix(byte);
    mix(snapshot.context.fpscr);
  }
  return hash;
}

uint64_t RunMillionSchedulerOperations() {
  GuestScheduler scheduler;
  uint64_t retraces = 0;
  scheduler.ConfigureViRetrace(100, [&](uint64_t index) {
    Require(index == retraces + 1, "VI retrace index mismatch");
    ++retraces;
  });
  for (uint32_t thread_index = 0; thread_index < 4; ++thread_index) {
    GuestCpuContext initial{};
    initial.gpr[31] = 0xA0000000U | thread_index;
    initial.fpr_bits[0] = 0x3FF0000000000000ULL + thread_index;
    initial.fpr_bits[31] = 0x7FF8000000000000ULL + thread_index;
    initial.fpscr = 0xF0000000U | thread_index;
    initial.simd_state.fill(static_cast<uint8_t>(0x20 + thread_index));
    (void)scheduler.Create(
        5, "stress-" + std::to_string(thread_index), initial,
        [thread_index](GuestCpuContext& context) {
          ++context.gpr[0];
          context.pc += 4;
          context.lr = 0x80000000U | thread_index;
          return StepAction::Yield();
        },
        false);
  }
  Require(scheduler.Run(1'000'000) == 1'000'000,
          "million-operation fixture ended early");
  Require(retraces == 10'000, "VI retrace cadence mismatch");
  const auto snapshots = scheduler.SnapshotAll();
  Require(snapshots.size() == 4, "stress thread count mismatch");
  for (const auto& snapshot : snapshots) {
    Require(snapshot.context.gpr[0] == 250'000,
            "round-robin distribution mismatch");
    const uint32_t index = static_cast<uint32_t>(snapshot.id - 1);
    Require(snapshot.context.gpr[31] == (0xA0000000U | index),
            "scheduler GPR preservation mismatch");
    Require(snapshot.context.fpr_bits[0] ==
                0x3FF0000000000000ULL + index &&
                snapshot.context.fpr_bits[31] ==
                    0x7FF8000000000000ULL + index,
            "scheduler FPR preservation mismatch");
    Require(snapshot.context.fpscr == (0xF0000000U | index),
            "scheduler FPSCR preservation mismatch");
    for (uint8_t byte : snapshot.context.simd_state) {
      Require(byte == static_cast<uint8_t>(0x20 + index),
              "scheduler SIMD preservation mismatch");
    }
  }
  return HashState(snapshots, scheduler.OperationCount(), retraces);
}

void TestSchedulerLifecycle() {
  GuestScheduler scheduler;
  int start_yield_steps = 0;
  const auto yielding = scheduler.Create(
      2, "start-yield", {}, [&](GuestCpuContext&) {
        return ++start_yield_steps == 1 ? StepAction::Yield()
                                        : StepAction::Exit(7);
      });
  Require(scheduler.Resume(yielding), "start/resume failed");
  Require(scheduler.Run(2) == 2 &&
              scheduler.Snapshot(yielding)->exit_code == 7,
          "yield/exit failed");

  int sleep_steps = 0;
  const auto sleeper = scheduler.Create(
      3, "sleep-wake", {}, [&](GuestCpuContext&) {
        return ++sleep_steps == 1 ? StepAction::SleepUntil(100)
                                  : StepAction::Exit();
      }, false);
  Require(scheduler.RunOne() == GuestScheduler::RunResult::Executed &&
              scheduler.RunOne() == GuestScheduler::RunResult::AdvancedToAlarm &&
              scheduler.RunOne() == GuestScheduler::RunResult::Executed &&
              scheduler.Snapshot(sleeper)->state == ThreadState::Terminated,
          "sleep/wake failed");

  uint64_t target = 0;
  int join_steps = 0;
  const auto joiner = scheduler.Create(
      1, "joiner", {}, [&](GuestCpuContext&) {
        return ++join_steps == 1 ? StepAction::WaitJoin(target)
                                 : StepAction::Exit();
      }, false);
  target = scheduler.Create(
      2, "target", {}, [](GuestCpuContext&) { return StepAction::Exit(42); },
      false);
  Require(scheduler.Run(3) == 3 &&
              scheduler.Snapshot(joiner)->state == ThreadState::Terminated &&
              scheduler.Snapshot(target)->exit_code == 42,
          "join failed");

  const auto cancelled = scheduler.Create(
      4, "cancel", {}, [](GuestCpuContext&) { return StepAction::Yield(); });
  Require(scheduler.Cancel(cancelled) &&
              scheduler.Snapshot(cancelled)->state == ThreadState::Cancelled,
          "cancel failed");
}

void RunFiberRegisterStress() {
  AndroidFiberContext host{};
  AndroidFiberContext fiber{};
  FiberState state{};
  state.fiber_context = &fiber;
  state.host_context = &host;
  state.remaining = kFiberSwitches;
  for (size_t index = 0; index < state.expected_x20_x28.size(); ++index) {
    state.expected_x20_x28[index] =
        0x2021222324252600ULL + static_cast<uint64_t>(index);
    fiber.x19_x28[index + 1] = state.expected_x20_x28[index];
  }
  for (size_t index = 0; index < state.expected_d8_d15.size(); ++index) {
    state.expected_d8_d15[index] =
        0xD8D9DADBDCDDDE00ULL + static_cast<uint64_t>(index);
    fiber.d8_d15[index] = state.expected_d8_d15[index];
  }
  state.expected_fpcr = 0x00400000;
  state.expected_fpsr = 0x08000000;
  state.expected_fp = 0x2929292929292929;
  fiber.x19_x28[0] = reinterpret_cast<uintptr_t>(&state);
  fiber.fpcr = state.expected_fpcr;
  fiber.fpsr = state.expected_fpsr;
  fiber.fp = state.expected_fp;
  fiber.lr = reinterpret_cast<uintptr_t>(&KartPadAndroidRegisterFiberEntry);
  alignas(16) std::array<std::byte, 64 * 1024> stack{};
  fiber.sp = reinterpret_cast<uintptr_t>(stack.data() + stack.size()) &
             ~uintptr_t{0x0f};

  while (state.finished == 0 && state.failure == 0) {
    KartPadSwitchAndroidFiber(&host, &fiber);
  }
  Require(state.failure == 0, "ELF register preservation mismatch");
  Require(state.finished == 1 && state.remaining == 0 &&
              state.switches == kFiberSwitches,
          "ELF fiber switch count mismatch");
}

}  // namespace

bool RunSchedulerFixture() {
  try {
    TestSchedulerLifecycle();
    const uint64_t first_hash = RunMillionSchedulerOperations();
    const uint64_t second_hash = RunMillionSchedulerOperations();
    Require(first_hash == kExpectedSchedulerHash && second_hash == first_hash,
            "scheduler deterministic hash mismatch");
    RunFiberRegisterStress();
    __android_log_print(
        ANDROID_LOG_INFO, kLogTag,
        "A1 ELF scheduler passed operations=2000000 hash=0x%016llx "
        "fiber_switches=%llu registers=x19-x30-sp-d8-d15-fpcr-fpsr",
        static_cast<unsigned long long>(first_hash),
        static_cast<unsigned long long>(kFiberSwitches));
    return true;
  } catch (const std::exception& error) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "A1 ELF scheduler failed: %s", error.what());
    return false;
  }
}
