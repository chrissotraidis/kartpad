#pragma once

extern "C" bool KartPadAndroidBeginTrace(const char* name);
extern "C" void KartPadAndroidEndTrace();

namespace kartpad::android {
// Fixed labels only. Sections are emitted only during an explicit system trace.
class TraceScope {
 public:
  explicit TraceScope(const char* name) : active_(KartPadAndroidBeginTrace(name)) {}
  ~TraceScope() { if (active_) KartPadAndroidEndTrace(); }
  TraceScope(const TraceScope&) = delete;
  TraceScope& operator=(const TraceScope&) = delete;
 private:
  bool active_;
};
}
