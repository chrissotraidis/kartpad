#include "kartpad/android/phase_metrics.h"
#include <cassert>
#include <cstdio>
#include <vector>
#include <string>
#include "kartpad/android/trace_scope.h"
namespace { bool enabled=false; std::vector<std::string> trace; }
extern "C" bool KartPadAndroidBeginTrace(const char* name) {
  if (!enabled) return false;
  trace.emplace_back(name); return true;
}
extern "C" void KartPadAndroidEndTrace() { trace.emplace_back("end"); }
int main() {
  kartpad::android::PhaseMetrics metrics;
  assert(metrics.mean_wall_ms() == 0 && metrics.mean_cpu_ms() == 0);
  for (unsigned i = 0; i < 300; ++i) metrics.add(2000000, 1000000);
  assert(metrics.count == 300 && metrics.mean_wall_ms() == 2);
  assert(metrics.mean_cpu_ms() == 1 && metrics.max_wall_ns == 2000000);
  metrics.add(8000000, 0);
  assert(metrics.max_wall_ns == 8000000 && metrics.wall_ns == 608000000);
  metrics.add(1, 0, false);
  metrics.add(1, 1);
  assert(!metrics.cpu_available);
  metrics = {};
  assert(metrics.count == 0 && metrics.max_wall_ns == 0);
  assert(metrics.cpu_available);
  { kartpad::android::TraceScope off("off"); enabled=true; }
  assert(trace.empty());
  {
    kartpad::android::TraceScope outer("outer");
    { kartpad::android::TraceScope inner("inner"); enabled=false; }
  }
  assert((trace == std::vector<std::string>{"outer", "inner", "end", "end"}));
  std::puts("PASS: phase aggregation and balanced nested tracing across enable changes");
}
