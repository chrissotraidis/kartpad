#include <jni.h>

#include <atomic>
#include <cstdio>
#include <SDL3/SDL_hints.h>

namespace {

std::atomic<bool> g_show_fps{false};
std::atomic<int> g_aspect_mode{-1};
std::atomic<int> g_resolution_milli{-1};

}  // namespace

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeEnableActivityRecreation(
    JNIEnv*, jobject) {
  SDL_SetHint(SDL_HINT_ANDROID_ALLOW_RECREATE_ACTIVITY, "1");
}

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeApplyDisplaySettings(
    JNIEnv*, jobject, jboolean show_fps, jint aspect_mode,
    jfloat resolution_scale) {
  g_show_fps.store(show_fps == JNI_TRUE, std::memory_order_release);
  g_aspect_mode.store(static_cast<int>(aspect_mode), std::memory_order_release);
  g_resolution_milli.store(static_cast<int>(resolution_scale * 1000.0F),
                           std::memory_order_release);
}

extern "C" JNIEXPORT jstring JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeDebugDisplaySettings(
    JNIEnv* env, jobject) {
  char result[64]{};
  std::snprintf(result, sizeof(result), "fps=%s aspect=%d scale=%.1f",
                g_show_fps.load(std::memory_order_acquire) ? "true" : "false",
                g_aspect_mode.load(std::memory_order_acquire),
                g_resolution_milli.load(std::memory_order_acquire) / 1000.0);
  return env->NewStringUTF(result);
}
