#include <jni.h>

#include <cstdint>
#include <span>
#include <string>
#include <string_view>
#include <vector>

#include "kartpad/mii/mii_database.h"

namespace {

std::vector<uint8_t> CopyBytes(JNIEnv* env, jbyteArray array) {
  if (array == nullptr) return {};
  const jsize size = env->GetArrayLength(array);
  std::vector<uint8_t> bytes(static_cast<std::size_t>(size));
  if (size != 0) {
    env->GetByteArrayRegion(array, 0, size,
                            reinterpret_cast<jbyte*>(bytes.data()));
  }
  return bytes;
}

void Throw(JNIEnv* env, const char* type, const std::string& message) {
  if (jclass exception = env->FindClass(type); exception != nullptr) {
    env->ThrowNew(exception, message.c_str());
  }
}

jbyteArray ToByteArray(JNIEnv* env, const std::vector<uint8_t>& bytes) {
  jbyteArray result = env->NewByteArray(static_cast<jsize>(bytes.size()));
  if (result != nullptr && !bytes.empty()) {
    env->SetByteArrayRegion(result, 0, static_cast<jsize>(bytes.size()),
                            reinterpret_cast<const jbyte*>(bytes.data()));
  }
  return result;
}

jstring ToJavaString(JNIEnv* env, std::string_view utf8) {
  std::u16string utf16;
  for (std::size_t index = 0; index < utf8.size();) {
    const uint8_t first = static_cast<uint8_t>(utf8[index++]);
    uint32_t code_point = 0xfffdu;
    std::size_t continuations = 0;
    if (first < 0x80u) {
      code_point = first;
    } else if ((first & 0xe0u) == 0xc0u) {
      code_point = first & 0x1fu;
      continuations = 1;
    } else if ((first & 0xf0u) == 0xe0u) {
      code_point = first & 0x0fu;
      continuations = 2;
    } else if ((first & 0xf8u) == 0xf0u) {
      code_point = first & 0x07u;
      continuations = 3;
    }
    bool valid = index + continuations <= utf8.size();
    for (std::size_t count = 0; valid && count < continuations; ++count) {
      const uint8_t next = static_cast<uint8_t>(utf8[index++]);
      valid = (next & 0xc0u) == 0x80u;
      code_point = (code_point << 6) | (next & 0x3fu);
    }
    if (!valid || code_point > 0x10ffffu ||
        (code_point >= 0xd800u && code_point <= 0xdfffu)) {
      code_point = 0xfffdu;
    }
    if (code_point <= 0xffffu) {
      utf16.push_back(static_cast<char16_t>(code_point));
    } else {
      code_point -= 0x10000u;
      utf16.push_back(static_cast<char16_t>(0xd800u + (code_point >> 10)));
      utf16.push_back(static_cast<char16_t>(0xdc00u + (code_point & 0x3ffu)));
    }
  }
  return env->NewString(reinterpret_cast<const jchar*>(utf16.data()),
                        static_cast<jsize>(utf16.size()));
}

}  // namespace

extern "C" JNIEXPORT jobjectArray JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeListMiis(
    JNIEnv* env, jobject, jbyteArray database_array) {
  const auto database = CopyBytes(env, database_array);
  if (env->ExceptionCheck()) return nullptr;
  if (const auto valid = kartpad::mii::ValidateDatabase(database); !valid) {
    Throw(env, "java/lang/IllegalArgumentException", valid.message);
    return nullptr;
  }
  const auto records = kartpad::mii::ListMiis(database);
  jclass string_class = env->FindClass("java/lang/String");
  if (string_class == nullptr) return nullptr;
  jobjectArray result = env->NewObjectArray(
      static_cast<jsize>(records.size() * 3), string_class, nullptr);
  if (result == nullptr) return nullptr;
  std::size_t index = 0;
  for (const auto& record : records) {
    const std::string slot = std::to_string(record.slot);
    const std::string creator = record.creatorName.empty()
        ? "Unknown" : record.creatorName;
    const std::string name = record.name.empty() ? "Unnamed Mii" : record.name;
    for (const std::string* value : {&slot, &name, &creator}) {
      jstring text = ToJavaString(env, *value);
      if (text == nullptr) return nullptr;
      env->SetObjectArrayElement(result, static_cast<jsize>(index++), text);
      env->DeleteLocalRef(text);
    }
  }
  return result;
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeImportMii(
    JNIEnv* env, jobject, jbyteArray database_array, jbyteArray mii_array) {
  auto database = CopyBytes(env, database_array);
  const auto mii = CopyBytes(env, mii_array);
  if (env->ExceptionCheck()) return nullptr;
  const auto result = kartpad::mii::ImportMii(database, mii);
  if (!result) {
    Throw(env, "java/lang/IllegalArgumentException", result.message);
    return nullptr;
  }
  return ToByteArray(env, database);
}

extern "C" JNIEXPORT jbyteArray JNICALL
Java_dev_kartpad_android_KartPadActivity_nativeRemoveMii(
    JNIEnv* env, jobject, jbyteArray database_array, jint slot) {
  auto database = CopyBytes(env, database_array);
  if (env->ExceptionCheck()) return nullptr;
  const auto result = kartpad::mii::RemoveMii(
      database, static_cast<std::size_t>(slot));
  if (!result) {
    Throw(env, "java/lang/IllegalArgumentException", result.message);
    return nullptr;
  }
  return ToByteArray(env, database);
}
