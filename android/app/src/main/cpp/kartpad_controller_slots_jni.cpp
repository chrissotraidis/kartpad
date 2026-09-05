#include <jni.h>

#include <array>
#include <cstdint>
#include <limits>
#include <string>

#include <aurora/input.hpp>

namespace {

constexpr uint32_t kMaxVisibleControllers = 32;

std::string SanitizeName(const char* raw) {
  std::string result = raw != nullptr ? raw : "Controller";
  for (char& value : result) {
    if (value == '\t' || value == '\n' || value == '\r') {
      value = ' ';
    }
  }
  return result;
}

}  // namespace

extern "C" JNIEXPORT jobjectArray JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeControllerDevices(
    JNIEnv* env, jobject) {
  std::array<uint32_t, kMaxVisibleControllers> instances{};
  std::array<int32_t, kMaxVisibleControllers> players{};
  const uint32_t count = aurora::input::list_standard_gamepads(
      instances.data(), players.data(), kMaxVisibleControllers);
  jclass stringClass = env->FindClass("java/lang/String");
  if (stringClass == nullptr) {
    return nullptr;
  }
  jobjectArray output = env->NewObjectArray(count, stringClass, nullptr);
  if (output == nullptr) {
    return nullptr;
  }
  for (uint32_t index = 0; index < count; ++index) {
    std::array<char, 257> name{};
    (void)aurora::input::copy_standard_gamepad_name(
        instances[index], name.data(), name.size());
    const std::string row = std::to_string(instances[index]) + "\t" +
        std::to_string(players[index]) + "\t" + SanitizeName(name.data());
    jstring value = env->NewStringUTF(row.c_str());
    if (value == nullptr) {
      return nullptr;
    }
    env->SetObjectArrayElement(output, index, value);
    env->DeleteLocalRef(value);
  }
  return output;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeAssignControllerPlayer(
    JNIEnv*, jobject, jlong instance, jint player) {
  if (instance < 0 ||
      static_cast<uint64_t>(instance) > std::numeric_limits<uint32_t>::max() ||
      player < 0) {
    return JNI_FALSE;
  }
  return aurora::input::assign_standard_gamepad(
      static_cast<uint32_t>(instance), static_cast<uint32_t>(player))
      ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeClearControllerPlayer(
    JNIEnv*, jobject, jint player) {
  if (player < 0) {
    return JNI_FALSE;
  }
  return aurora::input::clear_standard_gamepad_player(
      static_cast<uint32_t>(player)) ? JNI_TRUE : JNI_FALSE;
}
