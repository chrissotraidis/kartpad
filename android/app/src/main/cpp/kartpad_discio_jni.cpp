#include <jni.h>

#include <algorithm>
#include <atomic>
#include <filesystem>
#include <memory>
#include <optional>
#include <string>

#include "DiscIO/DiscExtractor.h"
#include "DiscIO/Filesystem.h"
#include "DiscIO/Volume.h"

namespace {

jstring Error(JNIEnv* env, const char* message) {
  return env->NewStringUTF(message);
}

}  // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_dev_kartpad_android_KartPadDiscImageImporter_nativeExtract(
    JNIEnv* env, jobject, jint fd, jstring destination_string) {
  if (fd < 0 || destination_string == nullptr) {
    return Error(env, "The selected disc image could not be opened.");
  }
  const char* destination_chars =
      env->GetStringUTFChars(destination_string, nullptr);
  if (destination_chars == nullptr) return nullptr;
  const std::filesystem::path destination(destination_chars);
  env->ReleaseStringUTFChars(destination_string, destination_chars);

  try {
    const std::string image = "/proc/self/fd/" + std::to_string(fd);
    std::unique_ptr<DiscIO::Volume> volume = DiscIO::CreateVolume(image);
    if (!volume) {
      return Error(env, "Dolphin could not read the selected ISO or WBFS image.");
    }
    const DiscIO::Partition partition = volume->GetGamePartition();
    const DiscIO::FileSystem* filesystem = volume->GetFileSystem(partition);
    if (!filesystem || !filesystem->IsValid()) {
      return Error(env, "Dolphin could not read the game filesystem.");
    }
    if (volume->GetGameID(partition) != "RMCP01" ||
        volume->GetRevision(partition) != std::optional<u16>{0}) {
      return Error(
          env, "KartPad currently supports RMCP01 (PAL), revision 0 only.");
    }

    std::error_code filesystem_error;
    std::filesystem::create_directories(destination / "files", filesystem_error);
    if (filesystem_error ||
        !DiscIO::ExportSystemData(*volume, partition, destination.string())) {
      return Error(env, "System-data extraction failed.");
    }

    const u64 total =
        std::max<u64>(1, filesystem->GetRoot().GetTotalChildren());
    std::atomic<u64> completed{0};
    DiscIO::ExportDirectory(
        *volume, partition, filesystem->GetRoot(), true, "",
        (destination / "files").string(),
        [&completed](const std::string&) {
          ++completed;
          return false;
        });
    if (completed.load() != total ||
        !std::filesystem::is_regular_file(
            destination / "files" / "rel" / "StaticR.rel")) {
      return Error(env, "Game-file extraction was incomplete.");
    }
    return nullptr;
  } catch (...) {
    return Error(env, "The selected disc image could not be extracted.");
  }
}
