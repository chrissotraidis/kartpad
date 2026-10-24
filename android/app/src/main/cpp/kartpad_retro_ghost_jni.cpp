#include <jni.h>
#include "kartpad/ghost/retro_transfer.h"

namespace {
using kartpad::ghost::Require;
using kartpad::ghost::retro::TransferStorage;

std::string Text(JNIEnv* env, jstring value) {
  Require(value != nullptr, "Missing Retro ghost selection");
  const auto type = env->GetObjectClass(value);
  const auto method = type ? env->GetMethodID(type, "getBytes", "(Ljava/lang/String;)[B") : nullptr;
  const auto encoding = env->NewStringUTF("UTF-8");
  const auto bytes = method ? static_cast<jbyteArray>(env->CallObjectMethod(value, method, encoding)) : nullptr;
  if (encoding) env->DeleteLocalRef(encoding);
  if (type) env->DeleteLocalRef(type);
  Require(bytes != nullptr && !env->ExceptionCheck(), "Retro ghost selection could not be read");
  std::string result(env->GetArrayLength(bytes), '\0');
  env->GetByteArrayRegion(bytes, 0, result.size(), reinterpret_cast<jbyte*>(result.data()));
  env->DeleteLocalRef(bytes);
  Require(!env->ExceptionCheck(), "Retro ghost selection could not be read");
  return result;
}
void Error(JNIEnv* env, const std::exception& error) {
  if (env->ExceptionCheck()) return;
  const auto type = env->FindClass("java/lang/IllegalArgumentException");
  if (type) env->ThrowNew(type, error.what());
}
std::string Quote(const std::string& text) {
  std::string result = "\"";
  for (unsigned char c : text) {
    if (c == '"' || c == '\\') { result += '\\'; result += char(c); }
    else if (c < 32) {
      char escaped[7]; std::snprintf(escaped, sizeof(escaped), "\\u%04x", c); result += escaped;
    } else result += char(c);
  }
  return result + '"';
}
// NewStringUTF uses modified UTF-8. Convert standard catalog UTF-8 through the
// Java decoder so supplementary BMG characters survive the JNI boundary.
jstring JavaText(JNIEnv* env, const std::string& text) {
  const auto bytes = env->NewByteArray(text.size());
  if (!bytes) return nullptr;
  env->SetByteArrayRegion(bytes, 0, text.size(), reinterpret_cast<const jbyte*>(text.data()));
  const auto type = env->FindClass("java/lang/String");
  const auto constructor = type ? env->GetMethodID(type, "<init>", "([BLjava/lang/String;)V") : nullptr;
  const auto encoding = env->NewStringUTF("UTF-8");
  auto result = constructor ? static_cast<jstring>(env->NewObject(type, constructor, bytes, encoding)) : nullptr;
  env->DeleteLocalRef(bytes); if (encoding) env->DeleteLocalRef(encoding);
  if (type) env->DeleteLocalRef(type);
  return result;
}
}

extern "C" JNIEXPORT jstring JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeRetroGhostCatalog(JNIEnv* env, jobject, jstring root) {
  try {
    const auto catalog = TransferStorage(Text(env, root)).LoadCatalog();
    std::string json = "{\"identity\":" + Quote(catalog.identity) + ",\"tracks\":[";
    for (size_t i = 0; i < catalog.tracks.size(); ++i) {
      const auto& track = catalog.tracks[i];
      if (i) json += ',';
      json += "{\"id\":" + std::to_string(track.pulsarId) + ",\"label\":" + Quote(track.label) + ",\"variants\":[";
      for (size_t v = 0; v < track.variants.size(); ++v) {
        if (v) json += ',';
        json += "{\"index\":" + std::to_string(track.variants[v].index) + ",\"label\":" + Quote(track.variants[v].label) + '}';
      }
      json += "]}";
    }
    return JavaText(env, json + "]}");
  } catch (const std::exception& error) { Error(env, error); return nullptr; }
}

extern "C" JNIEXPORT jobjectArray JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeRetroGhostFiles(JNIEnv* env, jobject,
    jstring root, jint track, jint variant, jint mode, jstring identity) {
  try {
    const auto records = TransferStorage(Text(env, root)).Exportable(track, variant, mode, Text(env, identity));
    const auto type = env->FindClass("java/lang/String");
    const auto result = type ? env->NewObjectArray(records.size(), type, nullptr) : nullptr;
    if (type) env->DeleteLocalRef(type);
    if (result) for (size_t i = 0; i < records.size(); ++i) {
      auto name = JavaText(env, records[i].filename);
      if (!name) return nullptr;
      env->SetObjectArrayElement(result, i, name); env->DeleteLocalRef(name);
      if (env->ExceptionCheck()) return nullptr;
    }
    return result;
  } catch (const std::exception& error) { Error(env, error); return nullptr; }
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeRetroGhostTransfer(JNIEnv* env, jobject,
    jstring root, jint track, jint variant, jint mode, jstring identity, jstring filename, jbyteArray ghost) {
  try {
    TransferStorage storage(Text(env, root)); const auto selected = Text(env, identity);
    if (ghost) {
      const auto count = env->GetArrayLength(ghost);
      Require(count >= 0x90 && size_t(count) <= kartpad::ghost::GhostBytes, "Unsupported ghost size");
      std::vector<uint8_t> bytes(count);
      env->GetByteArrayRegion(ghost, 0, count, reinterpret_cast<jbyte*>(bytes.data()));
      if (env->ExceptionCheck()) return nullptr;
      storage.Stage(bytes, track, variant, mode, selected);
      return env->NewByteArray(0);
    }
    const auto name = Text(env, filename);
    for (const auto& record : storage.Exportable(track, variant, mode, selected)) if (record.filename == name) {
      const auto result = env->NewByteArray(record.bytes.size());
      if (result) env->SetByteArrayRegion(result, 0, record.bytes.size(), reinterpret_cast<const jbyte*>(record.bytes.data()));
      return result;
    }
    throw std::runtime_error("The selected Retro ghost is unavailable; choose it again");
  } catch (const std::exception& error) { Error(env, error); return nullptr; }
}

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeRetroGhostPending(JNIEnv* env, jobject, jstring root, jboolean apply) {
  try {
    TransferStorage storage(Text(env, root));
    if (apply) storage.Apply(); else storage.Cancel();
  } catch (const std::exception& error) { Error(env, error); }
}
