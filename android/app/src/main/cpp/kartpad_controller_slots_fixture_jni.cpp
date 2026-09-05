#include <jni.h>

#include <array>
#include <mutex>
#include <string>

namespace {

constexpr std::array<jlong, 2> kInstances{101, 202};
constexpr std::array<const char*, 2> kNames{
    "KartPad Virtual One", "KartPad Virtual Two"};
std::array<jint, 2> g_players{0, -1};
std::mutex g_mutex;

}  // namespace

extern "C" JNIEXPORT jobjectArray JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeControllerDevices(
    JNIEnv* env, jobject) {
  std::scoped_lock lock(g_mutex);
  jclass stringClass = env->FindClass("java/lang/String");
  if (stringClass == nullptr) {
    return nullptr;
  }
  jobjectArray output = env->NewObjectArray(kInstances.size(), stringClass, nullptr);
  if (output == nullptr) {
    return nullptr;
  }
  for (size_t index = 0; index < kInstances.size(); ++index) {
    const std::string row = std::to_string(kInstances[index]) + "\t" +
        std::to_string(g_players[index]) + "\t" + kNames[index];
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
  if (player < 0 || player >= 4) {
    return JNI_FALSE;
  }
  std::scoped_lock lock(g_mutex);
  size_t selected = kInstances.size();
  for (size_t index = 0; index < kInstances.size(); ++index) {
    if (kInstances[index] == instance) {
      selected = index;
    }
    if (g_players[index] == player) {
      g_players[index] = -1;
    }
  }
  if (selected == kInstances.size()) {
    return JNI_FALSE;
  }
  g_players[selected] = player;
  return JNI_TRUE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeClearControllerPlayer(
    JNIEnv*, jobject, jint player) {
  if (player < 0 || player >= 4) {
    return JNI_FALSE;
  }
  std::scoped_lock lock(g_mutex);
  for (jint& assigned : g_players) {
    if (assigned == player) {
      assigned = -1;
    }
  }
  return JNI_TRUE;
}
