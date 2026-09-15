#include <jni.h>
#include <android/log.h>
#include <dawn/native/DawnNative.h>
#include <webgpu/webgpu_cpp.h>
#include <atomic>
#include <cstdio>
#include <mutex>
#include <string>

// The request is serviced by KartPadPerf on the game thread, before shutdown can
// destroy the device. JNI never reads the renderer's mutable device handle.
namespace aurora::webgpu { extern wgpu::Device g_device; }
namespace {
std::atomic<int> request{0};
std::mutex resultMutex;
std::string result;
}

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeRequestGraphicsMemory(JNIEnv*, jobject, jboolean release) {
  { std::lock_guard lock(resultMutex); result.clear(); }
  request.store(release == JNI_TRUE ? 2 : 1, std::memory_order_release);
}

extern "C" JNIEXPORT jstring JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeReadGraphicsMemory(JNIEnv* env, jobject) {
  std::lock_guard lock(resultMutex);
  return env->NewStringUTF(result.c_str());
}

extern "C" void KartPadAndroidProcessGraphicsMemoryRequest() {
  const int action = request.exchange(0, std::memory_order_acquire);
  if (action == 0) return;
  if (!aurora::webgpu::g_device) {
    std::lock_guard lock(resultMutex);
    result = "Graphics device is not ready. Resume the game and try again.";
    return;
  }
  auto device = aurora::webgpu::g_device.Get();
  const auto before = dawn::native::GetAllocatorMemoryInfo(device);
  const bool pending = action == 2 && dawn::native::ReduceMemoryUsage(device);
  const auto usage = dawn::native::ComputeEstimatedMemoryUsageInfo(device);
  const auto after = dawn::native::GetAllocatorMemoryInfo(device);
  constexpr double mib = 1024.0 * 1024.0;
  char text[768];
  std::snprintf(text, sizeof(text),
      "Live textures: %.1f MiB\nLive buffers: %.1f MiB\nAllocator used: %.1f MiB\nAllocator reserved: %.1f MiB\n\n%s\n\nThese are graphics-library estimates, not Android's total app memory. Releasing unused memory may cause a brief hitch while buffers are rebuilt. Game data and settings are kept.",
      usage.texturesUsage / mib, usage.buffersUsage / mib,
      after.totalUsedMemory / mib, after.totalAllocatedMemory / mib,
      action == 1 ? "Use Release Unused to test reclaiming cached graphics allocations."
                  : pending ? "Release requested. Some GPU work is still pending; refresh or release again shortly."
                            : "Unused graphics memory release completed.");
  __android_log_print(ANDROID_LOG_INFO, "KartPadMemory",
      "action=%s textures_bytes=%llu buffers_bytes=%llu allocator_used_bytes=%llu allocator_reserved_before_bytes=%llu allocator_reserved_after_bytes=%llu pending=%d",
      action == 2 ? "release" : "sample", (unsigned long long)usage.texturesUsage,
      (unsigned long long)usage.buffersUsage, (unsigned long long)after.totalUsedMemory,
      (unsigned long long)before.totalAllocatedMemory, (unsigned long long)after.totalAllocatedMemory, pending);
  { std::lock_guard lock(resultMutex); result = text; }
}
