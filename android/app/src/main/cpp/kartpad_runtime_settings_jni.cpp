#include <jni.h>
#include <SDL3/SDL_hints.h>

#include "kartpad/android/controller_mapping.hpp"
#include "kartpad/android/runtime_settings.hpp"

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeEnableActivityRecreation(
    JNIEnv*, jobject) {
  SDL_SetHint(SDL_HINT_ANDROID_ALLOW_RECREATE_ACTIVITY, "1");
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
    if (raw[index] < 0 || raw[index] >= 12) return;
    mapping[index] = static_cast<uint8_t>(raw[index]);
  }
  kartpad::android::PublishControllerButtonMapping(mapping);
}

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeApplyControllerAutoAccelerate(
    JNIEnv*, jobject, jboolean enabled) {
  kartpad::android::PublishControllerAutoAccelerate(enabled == JNI_TRUE);
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
