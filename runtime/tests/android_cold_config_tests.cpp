// Exercise the maintained Android config branch on the host. Load host headers
// first so selecting Android does not change the host standard-library ABI.
#include <algorithm>
#include <array>
#include <cmath>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <optional>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>
#include <toml.hpp>
#undef __APPLE__
#define __ANDROID__ 1
#ifndef __linux__
#define __linux__ 1
#endif
#include "runtime_config.h"

namespace fs = std::filesystem;

// Model the config-backed settings_overlay.cpp globals initialized when an
// extraction worker loads libmain, before any Activity can set the paths.
static const float initialAudioVolume = RuntimeConfigFile::AudioVolume(1.0f);
static const bool initialMuted = RuntimeConfigFile::AudioMuted(false);
static const fs::path initialConfigPath = RuntimeConfigFile::ResolveConfigPath();

static void Check(bool value, const char* message) {
  if (!value) throw std::runtime_error(message);
}

int main(int argc, char** argv) {
  try {
    Check(argc == 3, "Expected startup order and synthetic temporary root");
    const std::string mode(argv[1]);
    Check(mode == "early-env" || mode == "late-env", "Unknown startup order");
    const bool earlyEnv = mode == "early-env";
    const fs::path root(argv[2]);
    const auto files = root / "files", cache = root / "cache", support = files / "KartPad";
    Check(initialAudioVolume == (earlyEnv ? 0.25f : 1.0f) && initialMuted == earlyEnv,
        "Incorrect config-backed settings at library load");
    Check(initialConfigPath == (earlyEnv ? support / "Config.toml" :
        fs::current_path() / RuntimeConfigFile::kApplicationDirectoryName / "Config.toml"),
        "Incorrect config path at library load");

    Check(::setenv("KARTPAD_ANDROID_FILES_DIR", files.c_str(), 1) == 0 &&
        ::setenv("KARTPAD_ANDROID_CACHE_DIR", cache.c_str(), 1) == 0,
        "Cannot set synthetic context paths");
    // The installer adds a Retro root after the extraction library is loaded.
    std::ofstream config(support / "Config.toml");
    config << "[paths]\ndvd_root = \"DVD\"\nretro_rewind_root = \"RetroRewind/RetroRewind6\"\n"
              "[audio]\nvolume = 0.25\nmuted = true\n";
    config.close();
    Check(config.good(), "Cannot write synthetic installed config");
    Check(RuntimeConfigFile::ResolveConfigPath() == support / "Config.toml",
        "Context config path did not update");
    Check(RuntimeConfigFile::CacheDataDirectory() == cache / "KartPad",
        "Context cache path did not update");
    Check(RuntimeConfigFile::RetroRewindRoot().empty(), "Expected cached pre-install Retro root");
    Check(earlyEnv ? RuntimeConfigFile::DvdRoot() == "DVD" : RuntimeConfigFile::DvdRoot().empty(),
        "Expected cached DVD root from library load");

    RuntimeConfigFile::Reload(); // The cold-launch hook runs before SDL starts.
    Check(RuntimeConfigFile::ResolvedDvdRoot() == support / "DVD",
        "Cold reload did not resolve the installed DVD root");
    Check(RuntimeConfigFile::ResolveRelativeToConfig(RuntimeConfigFile::RetroRewindRoot()) ==
        support / "RetroRewind/RetroRewind6", "Cold reload did not resolve the installed Retro root");
    Check(RuntimeConfigFile::AudioVolume() == 0.25f && RuntimeConfigFile::AudioMuted(),
        "Cold reload lost configured audio settings");
    Check(initialAudioVolume == (earlyEnv ? 0.25f : 1.0f) && initialMuted == earlyEnv,
        "Reload unexpectedly changed static settings initialized at library load");
    std::cout << mode << ": cached roots reproduced; cold reload resolves installed roots; "
              << (earlyEnv ? "early settings preserved\n" : "late setup leaves static defaults\n");
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
