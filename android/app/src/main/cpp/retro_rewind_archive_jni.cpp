#include "kartpad/retro_rewind/archive_extract.h"

#include <jni.h>

#include <cstddef>
#include <cstdint>

namespace {

class UtfChars {
 public:
  UtfChars(JNIEnv* environment, jstring value)
      : environment_(environment), value_(value) {
    if (value_ != nullptr) chars_ = environment_->GetStringUTFChars(value_, nullptr);
  }
  ~UtfChars() {
    if (chars_ != nullptr) environment_->ReleaseStringUTFChars(value_, chars_);
  }
  UtfChars(const UtfChars&) = delete;
  UtfChars& operator=(const UtfChars&) = delete;
  const char* get() const { return chars_; }

 private:
  JNIEnv* environment_;
  jstring value_;
  const char* chars_ = nullptr;
};

struct JavaCallbacks {
  JNIEnv* environment = nullptr;
  jobject cancellation = nullptr;
  jobject progress = nullptr;
  jmethodID is_cancelled = nullptr;
  jmethodID on_progress = nullptr;
};

bool IsCancelled(void* opaque) {
  auto* callbacks = static_cast<JavaCallbacks*>(opaque);
  if (callbacks->environment->ExceptionCheck()) return true;
  const jboolean cancelled = callbacks->environment->CallBooleanMethod(
      callbacks->cancellation, callbacks->is_cancelled);
  return callbacks->environment->ExceptionCheck() || cancelled == JNI_TRUE;
}

void ReportProgress(void* opaque, const std::uint64_t extracted,
                    const std::uint64_t total) {
  auto* callbacks = static_cast<JavaCallbacks*>(opaque);
  if (callbacks->environment->ExceptionCheck()) return;
  callbacks->environment->CallVoidMethod(
      callbacks->progress, callbacks->on_progress,
      static_cast<jlong>(extracted), static_cast<jlong>(total));
}

}  // namespace

extern "C" JNIEXPORT jint JNICALL
Java_dev_kartpad_android_RetroRewindArchiveExtractor_nativeExtract(
    JNIEnv* environment, jclass, jstring archive_path, jstring staging_directory,
    jstring expected_root, jint maximum_entries, jlong maximum_expanded_bytes,
    jobject cancellation, jobject progress, jlongArray counts) {
  if (archive_path == nullptr || staging_directory == nullptr ||
      expected_root == nullptr || maximum_entries <= 0 ||
      maximum_expanded_bytes <= 0 || cancellation == nullptr || progress == nullptr ||
      counts == nullptr || environment->GetArrayLength(counts) != 3) {
    return static_cast<jint>(
        kartpad::retro_rewind::ArchiveExtractError::InvalidArgument);
  }

  jclass cancellation_class = environment->GetObjectClass(cancellation);
  jclass progress_class = environment->GetObjectClass(progress);
  if (cancellation_class == nullptr || progress_class == nullptr) {
    if (cancellation_class != nullptr) environment->DeleteLocalRef(cancellation_class);
    if (progress_class != nullptr) environment->DeleteLocalRef(progress_class);
    return static_cast<jint>(
        kartpad::retro_rewind::ArchiveExtractError::InvalidArgument);
  }
  JavaCallbacks callbacks{
      .environment = environment,
      .cancellation = cancellation,
      .progress = progress,
      .is_cancelled = environment->GetMethodID(cancellation_class, "isCancelled", "()Z"),
      .on_progress = environment->GetMethodID(progress_class, "onProgress", "(JJ)V"),
  };
  environment->DeleteLocalRef(cancellation_class);
  environment->DeleteLocalRef(progress_class);
  if (environment->ExceptionCheck() || callbacks.is_cancelled == nullptr ||
      callbacks.on_progress == nullptr) {
    return static_cast<jint>(
        kartpad::retro_rewind::ArchiveExtractError::InvalidArgument);
  }

  UtfChars archive{environment, archive_path};
  UtfChars staging{environment, staging_directory};
  UtfChars root{environment, expected_root};
  if (archive.get() == nullptr || staging.get() == nullptr || root.get() == nullptr) {
    return static_cast<jint>(
        kartpad::retro_rewind::ArchiveExtractError::InvalidArgument);
  }

  const auto result = kartpad::retro_rewind::ExtractArchive(
      archive.get(), staging.get(), root.get(),
      static_cast<std::size_t>(maximum_entries),
      static_cast<std::uint64_t>(maximum_expanded_bytes),
      {.context = &callbacks,
       .cancelled = IsCancelled,
       .progress = ReportProgress});
  if (!environment->ExceptionCheck()) {
    const jlong values[] = {
        static_cast<jlong>(result.selected_entries),
        static_cast<jlong>(result.selected_bytes),
        static_cast<jlong>(result.extracted_bytes),
    };
    environment->SetLongArrayRegion(counts, 0, 3, values);
  }
  return static_cast<jint>(result.error);
}
