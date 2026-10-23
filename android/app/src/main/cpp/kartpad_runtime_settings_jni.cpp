#include <jni.h>
#include <SDL3/SDL_hints.h>
#include <SDL3/SDL_system.h>

#include <algorithm>
#include <atomic>
#include <cstdio>

#include "kartpad/android/controller_mapping.hpp"
#include "kartpad/android/runtime_settings.hpp"
#include "runtime_config.h"

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeReloadRuntimeConfig(
    JNIEnv* env, jobject) {
  try {
    RuntimeConfigFile::Reload();
  } catch (const std::exception& error) {
    const auto exception = env->FindClass("java/lang/IllegalStateException");
    if (exception) env->ThrowNew(exception, error.what());
  }
}

// The runtime's live sound-category levels (runtime/src/music_attenuation.cpp, in this library).
// Declared here rather than including the runtime header, which isn't on this target's path.
namespace MusicAttenuation {
void SetMusicVolume(float volume) noexcept;
void SetSoundEffectsVolume(float volume) noexcept;
void SetUiVolume(float volume) noexcept;
void SetVoicesVolume(float volume) noexcept;
}  // namespace MusicAttenuation

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeEnableActivityRecreation(
    JNIEnv*, jobject) {
  SDL_SetHint(SDL_HINT_ANDROID_ALLOW_RECREATE_ACTIVITY, "1");
}

// Music, and game sounds (effects, voices, menus), 0 to 1. Takes effect immediately; KartPad also
// saves both in Config.toml, which the runtime applies at the next start.
extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeApplySoundLevels(
    JNIEnv*, jobject, jfloat music, jfloat sounds) {
  const float musicLevel = std::clamp(static_cast<float>(music), 0.0f, 1.0f);
  const float soundsLevel = std::clamp(static_cast<float>(sounds), 0.0f, 1.0f);
  MusicAttenuation::SetMusicVolume(musicLevel);
  MusicAttenuation::SetSoundEffectsVolume(soundsLevel);
  MusicAttenuation::SetVoicesVolume(soundsLevel);
  MusicAttenuation::SetUiVolume(soundsLevel);
  std::printf("[KartPadSound] music=%.2f sounds=%.2f\n", musicLevel, soundsLevel);
  std::fflush(stdout);
}

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeApplyDisplaySettings(
    JNIEnv*, jobject, jboolean show_fps, jint fps_size, jint aspect_mode,
    jfloat resolution_scale) {
  kartpad::android::PublishDisplaySettings({
      .show_fps = show_fps == JNI_TRUE,
      .fps_size = static_cast<int>(fps_size),
      .aspect_mode = static_cast<int>(aspect_mode),
      .resolution_scale = static_cast<float>(resolution_scale),
  });
}

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeApplyControllerMapping(
    JNIEnv* env, jobject, jintArray values) {
  if (values == nullptr || env->GetArrayLength(values) != 12) return;
  jint raw[12]{};
  env->GetIntArrayRegion(values, 0, 12, raw);
  if (env->ExceptionCheck()) return;
  kartpad::android::ControllerButtonMapping mapping{};
  for (std::size_t index = 0; index < mapping.size(); ++index) {
    if (raw[index] < 0 || raw[index] >= static_cast<jint>(kartpad::android::kMappablePhysicalButtons.size())) return;
    mapping[index] = static_cast<uint8_t>(raw[index]);
  }
  kartpad::android::PublishControllerButtonMapping(mapping);
}

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeApplyControllerAutoAccelerate(
    JNIEnv*, jobject, jboolean enabled) {
  kartpad::android::PublishControllerAutoAccelerate(enabled == JNI_TRUE);
}

namespace {
// KartPadDeviceRumble.setActive, resolved on the UI thread: the game thread's
// class loader cannot find app classes.
std::atomic<jclass> g_deviceRumbleClass{nullptr};
std::atomic<jmethodID> g_deviceRumbleSetActive{nullptr};
std::atomic<bool> g_deviceRumbleActive{false};
}  // namespace

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeApplyControllerRumble(
    JNIEnv* env, jobject, jboolean enabled, jint strengthPercent) {
  if (g_deviceRumbleClass.load(std::memory_order_acquire) == nullptr) {
    if (jclass local = env->FindClass("dev/kartpad/android/KartPadDeviceRumble")) {
      const jmethodID setActive = env->GetStaticMethodID(local, "setActive", "(Z)V");
      if (setActive != nullptr) {
        g_deviceRumbleSetActive.store(setActive, std::memory_order_release);
        g_deviceRumbleClass.store(static_cast<jclass>(env->NewGlobalRef(local)),
                                  std::memory_order_release);
      }
      env->DeleteLocalRef(local);
    }
    if (env->ExceptionCheck()) env->ExceptionClear();
  }
  kartpad::android::PublishControllerRumble(enabled == JNI_TRUE, strengthPercent);
}

void kartpad::android::SetDeviceRumble(const bool active) noexcept {
  if (g_deviceRumbleActive.exchange(active, std::memory_order_acq_rel) == active) return;
  const jclass target = g_deviceRumbleClass.load(std::memory_order_acquire);
  const jmethodID setActive = g_deviceRumbleSetActive.load(std::memory_order_acquire);
  auto* env = static_cast<JNIEnv*>(SDL_GetAndroidJNIEnv());
  if (target == nullptr || setActive == nullptr || env == nullptr) return;
  env->CallStaticVoidMethod(target, setActive, active ? JNI_TRUE : JNI_FALSE);
  if (env->ExceptionCheck()) env->ExceptionClear();
}

#include "kartpad/ghost/rkg.h"
extern "C" JNIEXPORT jbyteArray JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeGhostTransfer(
    JNIEnv* env, jobject, jbyteArray save, jbyteArray ghost, jint license, jint slot, jboolean downloaded) {
  try {
    if (!save || env->GetArrayLength(save) != kartpad::ghost::SaveBytes) return nullptr;
    std::vector<uint8_t> s(kartpad::ghost::SaveBytes);
    env->GetByteArrayRegion(save,0,s.size(),reinterpret_cast<jbyte*>(s.data()));
    if(env->ExceptionCheck()) return nullptr;
    std::vector<uint8_t> result;
    if(ghost){
      auto n=env->GetArrayLength(ghost);if(n<0x90||n>kartpad::ghost::GhostBytes)return nullptr;
      std::vector<uint8_t> g(n);env->GetByteArrayRegion(ghost,0,n,reinterpret_cast<jbyte*>(g.data()));
      if(env->ExceptionCheck())return nullptr;
      result=kartpad::ghost::Import(s,g,license);
    }else result=kartpad::ghost::Export(s,license,slot,downloaded);
    auto out=env->NewByteArray(result.size());if(out)env->SetByteArrayRegion(out,0,result.size(),reinterpret_cast<const jbyte*>(result.data()));return out;
  } catch (const std::exception& error) {
    // Keep validation failures distinguishable from an empty license.
    const auto exception = env->FindClass("java/lang/IllegalArgumentException");
    if (exception) env->ThrowNew(exception, error.what());
    return nullptr;
  }
}
