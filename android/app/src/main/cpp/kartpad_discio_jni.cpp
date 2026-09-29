#include <jni.h>

#include <algorithm>
#include <array>
#include <filesystem>
#include <memory>
#include <optional>
#include <string>

#include "Common/CommonTypes.h"
#include "DiscIO/DiscExtractor.h"
#include "DiscIO/Filesystem.h"
#include "DiscIO/Volume.h"
#include "kartpad_disc_image_volume.h"

namespace IOS::ES {
void KartPadSetUserCommonKey(const std::array<u8, 16>& key);
}

namespace {

jstring Error(JNIEnv* env, const char* message) {
  return env->NewStringUTF(message);
}

// Dolphin's ExportDirectory logs individual failures but returns void and keeps
// visiting entries. A progress count therefore cannot establish a complete copy.
bool ExportCheckedDirectory(const DiscIO::Volume& volume,
                            const DiscIO::Partition& partition,
                            const DiscIO::FileInfo& directory,
                            const std::filesystem::path& destination,
                            unsigned depth = 0) {
  if (depth > 64) return false;
  std::error_code error;
  std::filesystem::create_directories(destination, error);
  if (error) return false;
  for (const auto& entry : directory) {
    const std::filesystem::path name(entry.GetName());
    if (name.empty() || name == "." || name == ".." || name != name.filename())
      return false;
    const auto path = destination / name;
    if (entry.IsDirectory()) {
      if (!ExportCheckedDirectory(volume, partition, entry, path, depth + 1))
        return false;
    } else if (!DiscIO::ExportFile(volume, partition, &entry, path.string())) {
      return false;
    }
  }
  return true;
}

}  // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_dev_kartpad_android_KartPadDiscImageImporter_nativeExtract(
    JNIEnv* env, jobject, jint fd, jstring destination_string, jbyteArray common_key) {
  if (fd < 0 || destination_string == nullptr) {
    return Error(env, "The selected disc image could not be opened.");
  }
  // KartPad does not include console keys: reading an encrypted Wii disc image
  // needs the player's own 16-byte Wii common key.
  if (common_key == nullptr || env->GetArrayLength(common_key) != 16) {
    return Error(env, "KartPad needs your Wii common key (common-key.bin) to read a disc image.");
  }
  std::array<u8, 16> key{};
  env->GetByteArrayRegion(common_key, 0, 16, reinterpret_cast<jbyte*>(key.data()));
  IOS::ES::KartPadSetUserCommonKey(key);
  const char* destination_chars =
      env->GetStringUTFChars(destination_string, nullptr);
  if (destination_chars == nullptr) return nullptr;
  const std::filesystem::path destination(destination_chars);
  env->ReleaseStringUTFChars(destination_string, destination_chars);

  try {
    std::unique_ptr<DiscIO::Volume> volume = KartPadOpenDiscDescriptor(fd);
    if (!volume) {
      return Error(env, "Dolphin could not read the selected ISO, WBFS or RVZ image.");
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

    constexpr u64 reserve = 64 * 1024 * 1024;
    const auto& root = filesystem->GetRoot();
    const u64 entries = root.GetTotalChildren();
    const u64 bytes = root.GetTotalSize();
    if (entries > 100'000 || bytes > 8ULL * 1024 * 1024 * 1024)
      return Error(env, "The disc exceeds KartPad's import limit.");
    std::error_code filesystem_error;
    const auto space = std::filesystem::space(destination, filesystem_error);
    if (filesystem_error)
      return Error(env, "Available game-data storage could not be checked.");
    // Keep room for system files, allocation overhead, and atomic configuration.
    const u64 required = bytes + reserve + entries * 4096;
    if (space.available < required) {
      const auto message = "Not enough free storage to import this disc. Free at least " +
          std::to_string((required - space.available + 1024 * 1024 - 1) / (1024 * 1024)) +
          " MiB more and try again. Your existing game data and saves are unchanged.";
      return Error(env, message.c_str());
    }
    std::filesystem::create_directories(destination / "files", filesystem_error);
    if (filesystem_error ||
        !DiscIO::ExportSystemData(*volume, partition, destination.string())) {
      return Error(env, "System-data extraction failed.");
    }

    if (!ExportCheckedDirectory(*volume, partition, root, destination / "files") ||
        !std::filesystem::is_regular_file(
            destination / "files" / "rel" / "StaticR.rel")) {
      return Error(env, "Game-file extraction failed. Check free storage and the selected disc image, then try again. Existing game data and saves are unchanged.");
    }
    return nullptr;
  } catch (...) {
    return Error(env, "The selected disc image could not be extracted.");
  }
}
