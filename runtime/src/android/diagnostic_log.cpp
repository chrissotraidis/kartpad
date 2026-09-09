#include <android/log.h>
#include <android/trace.h>
#include <sys/system_properties.h>
#include <cstdarg>
#include <cstdio>
#include <time.h>
#include <array>
#include <mutex>
#include "kartpad/android/phase_metrics.h"

extern "C" bool KartPadAndroidBeginTrace(const char* name) {
  if (!ATrace_isEnabled()) return false;
  ATrace_beginSection(name);
  return true;
}

extern "C" void KartPadAndroidEndTrace() { ATrace_endSection(); }

// Allow the next native frame to be produced while encoding the sealed frame.
// Debug builds retain a worker-boundary switch for matched warm-scene comparisons.
// Public builds use the same enabled path without reading device debug properties.
extern "C" bool KartPadAndroidNativeFrameOverlapExperiment() {
#if !defined(NDEBUG)
  char value[PROP_VALUE_MAX]{};
  if (__system_property_get("debug.kartpad.native_overlap", value) == 1) {
    if (value[0] == '0') return false;
    if (value[0] == '1') return true;
  }
#endif
  return true;
}

// Used for coarse runtime metrics and capped slow-network-call diagnostics.
// stderr is already mirrored into the app's private per-launch console log.
extern "C" void KartPadAndroidLogMetric(const char* tag, const char* format, ...) {
  char message[1024];
  va_list args;
  va_start(args, format);
  std::vsnprintf(message, sizeof(message), format, args);
  va_end(args);
  __android_log_write(ANDROID_LOG_INFO, tag, message);
  timespec now{};
  clock_gettime(CLOCK_BOOTTIME, &now);
  std::fprintf(stderr, "[%s] elapsed_ms=%lld %s\n", tag,
               static_cast<long long>(now.tv_sec) * 1000 + now.tv_nsec / 1000000,
               message);
}

extern "C" long long KartPadAndroidThreadCpuNanos() {
  timespec value{};
  if (clock_gettime(CLOCK_THREAD_CPUTIME_ID, &value) != 0) return -1;
  return static_cast<long long>(value.tv_sec) * 1000000000 + value.tv_nsec;
}

extern "C" void KartPadAndroidRecordPhase(unsigned id, long long wall, long long cpu) {
  static constexpr const char* names[] = {
    "present_lock", "present_acquire", "present_encode", "present_finish",
    "present_submit", "present_schedule_wait", "present_call", "present_total",
    "worker_seal_encode", "worker_prepare", "worker_overlap_encode",
    "producer_wait_sealed", "producer_wait_ready"
  };
  static std::array<kartpad::android::PhaseMetrics, std::size(names)> windows{};
  static std::mutex mutex;
  if (id >= windows.size() || wall < 0) return;
  kartpad::android::PhaseMetrics report;
  {
    std::lock_guard lock(mutex);
    auto& window = windows[id];
    window.add(wall, std::max(0LL, cpu), cpu >= 0);
    if (window.count < 300) return;
    report = window;
    window = {};
  }
  // cpu_ms=-1 explicitly marks wall-only measurements, never GPU execution time.
  KartPadAndroidLogMetric("KartPadPhase",
      "phase=%s samples=%llu wall_ms=%.3f max_wall_ms=%.3f cpu_ms=%.3f",
      names[id], static_cast<unsigned long long>(report.count),
      report.mean_wall_ms(), double(report.max_wall_ns) / 1e6,
      report.cpu_available ? report.mean_cpu_ms() : -1.0);
}

// Called by the health worker, independent of SDL/guest execution.
#include <jni.h>
#include "kartpad/android/network_stall.h"
extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadRuntimeHealth_nativeSampleNetworkWaits(JNIEnv*, jobject) {
  kartpad::android::SampleNetworkWaits();
}
