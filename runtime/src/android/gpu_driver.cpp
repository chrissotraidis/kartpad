// Custom Vulkan drivers on Android (Turnip, or a newer Qualcomm Adreno driver).
//
// Many Snapdragon phones ship Adreno drivers years out of date, and several rendering faults
// players report on them are driver bugs. Like other Android emulators, KartPad can load a driver
// package the player chose: libadrenotools (android/third_party/adrenotools, BSD-2-Clause) loads the
// driver .so into its own linker namespace and hooks the system Vulkan loader to use it.
//
// Dawn is linked into this library and opens Vulkan itself with dlopen("libvulkan.so"). This
// library is linked with --wrap=dlopen/--wrap=dlclose, so once a driver is loaded that one request
// gets the adrenotools handle instead; every other dlopen passes straight through. No Dawn change
// is needed. The app passes the selection through the environment before the runtime starts
// (KartPadGpuDriverSettings.kt). Any failure keeps the phone's own driver: a bad package must never
// stop the game from starting.

#if defined(__ANDROID__)

#include <adrenotools/driver.h>

#include <android/api-level.h>
#include <dlfcn.h>
#include <sys/stat.h>

#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

extern "C" void* __real_dlopen(const char* filename, int flags);
extern "C" int __real_dlclose(void* handle);
// runtime/src/android/diagnostic_log.cpp: logcat plus the per-launch console log in reports.
extern "C" void KartPadAndroidLogMetric(const char* tag, const char* format, ...);

namespace {

std::atomic<void*> g_vulkanOverride{nullptr};

const char* Env(const char* name) {
    const char* value = std::getenv(name);
    return value != nullptr && value[0] != 0 ? value : nullptr;
}

std::string WithSlash(const char* path) {
    std::string value(path);
    if (!value.empty() && value.back() != '/') value.push_back('/');
    return value;
}

bool IsFile(const std::string& path) {
    struct stat st {};
    return stat(path.c_str(), &st) == 0 && S_ISREG(st.st_mode);
}

void Report(const char* state, const char* reason, const char* lib, const char* detail = nullptr) {
    KartPadAndroidLogMetric("KartPadGpuDriver", "state=%s reason=%s lib=%s api=%d detail=%s", state, reason,
                            lib != nullptr ? lib : "-", android_get_device_api_level(),
                            detail != nullptr ? detail : "-");
}

bool IsVulkanLoaderName(const char* filename) {
    if (filename == nullptr) return false;
    const char* base = std::strrchr(filename, '/');
    base = base != nullptr ? base + 1 : filename;
    return std::strcmp(base, "libvulkan.so") == 0 || std::strcmp(base, "libvulkan.so.1") == 0;
}

} // namespace

extern "C" void* __wrap_dlopen(const char* filename, int flags) {
    if (void* override = g_vulkanOverride.load(std::memory_order_acquire); override != nullptr &&
                                                                        IsVulkanLoaderName(filename)) {
        return override;
    }
    return __real_dlopen(filename, flags);
}

extern "C" int __wrap_dlclose(void* handle) {
    // Dawn keeps using the driver for the life of the process; never unload it underneath it.
    if (handle != nullptr && handle == g_vulkanOverride.load(std::memory_order_acquire)) return 0;
    return __real_dlclose(handle);
}

extern "C" void KartPadLoadCustomGpuDriver() {
    const char* driverDir = Env("KARTPAD_GPU_DRIVER_DIR");
    const char* driverLib = Env("KARTPAD_GPU_DRIVER_LIB");
    if (driverDir == nullptr || driverLib == nullptr) {
        return; // the phone's own driver
    }
    const std::string dir = WithSlash(driverDir);
    const char* hookEnv = Env("KARTPAD_GPU_HOOK_DIR");
    const std::string hookDir = hookEnv != nullptr ? WithSlash(hookEnv) : std::string();
    if (!IsFile(dir + driverLib)) {
        Report("fallback", "driver_missing", driverLib);
        return;
    }
    if (hookDir.empty() || !IsFile(hookDir + "libmain_hook.so") || !IsFile(hookDir + "libhook_impl.so")) {
        Report("fallback", "hooks_missing", driverLib);
        return;
    }
    // Android 9 has no memfd for the patched loader copy; adrenotools ignores this from Android 10.
    const char* tmpDir = Env("KARTPAD_GPU_TMP_DIR");
    const std::string tmp = tmpDir != nullptr ? WithSlash(tmpDir) : std::string();
    void* handle = adrenotools_open_libvulkan(RTLD_NOW, ADRENOTOOLS_DRIVER_CUSTOM, tmp.empty() ? nullptr : tmp.c_str(),
                                              hookDir.c_str(), dir.c_str(), driverLib, nullptr, nullptr);
    if (handle == nullptr) {
        const char* error = dlerror();
        Report("fallback", "open_failed", driverLib, error);
        return;
    }
    if (dlsym(handle, "vkGetInstanceProcAddr") == nullptr) {
        Report("fallback", "no_vkGetInstanceProcAddr", driverLib);
        return;
    }
    g_vulkanOverride.store(handle, std::memory_order_release);
    Report("loaded", "ok", driverLib);
}

// Graphics could not start. If that was with the player's driver, mark the app's start counter
// failed so the next start uses the phone's own driver (KartPadGpuDriverSettings.kt), and return
// a note for the error message; otherwise an empty note.
extern "C" const char* KartPadGpuDriverStartFailedNote() {
    if (g_vulkanOverride.load(std::memory_order_acquire) == nullptr) return "";
    Report("failed", "graphics_start", Env("KARTPAD_GPU_DRIVER_LIB"));
    if (const char* starts = Env("KARTPAD_GPU_DRIVER_STARTS")) {
        if (std::FILE* file = std::fopen(starts, "w")) {
            std::fputs("99", file);
            std::fclose(file);
        }
    }
    return "\n\nThis start used the GPU driver you chose. KartPad will use the phone's own driver the next "
           "time you start the game.";
}

#else

extern "C" void KartPadLoadCustomGpuDriver() {}
extern "C" const char* KartPadGpuDriverStartFailedNote() { return ""; }

#endif

