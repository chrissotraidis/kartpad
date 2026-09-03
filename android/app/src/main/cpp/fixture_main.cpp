#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <SDL3/SDL_vulkan.h>
#include <android/log.h>
#include <dawn/native/DawnNative.h>
#include <dawn/webgpu.h>
#include <unistd.h>

#include <cstddef>

namespace {

constexpr char kLogTag[] = "KartPadFixture";

void LogError(const char* message) {
  __android_log_print(ANDROID_LOG_ERROR, kLogTag, "%s: %s", message,
                      SDL_GetError());
}

}  // namespace

extern "C" __attribute__((visibility("default"))) int SDL_main(int, char**) {
  SDL_SetAppMetadata("KartPad", "0.0.1-a0", "dev.kartpad.android");
  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
    LogError("SDL_Init failed");
    return 1;
  }

  SDL_Window* window = SDL_CreateWindow(
      "KartPad", 960, 540,
      SDL_WINDOW_VULKAN | SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);
  if (window == nullptr) {
    LogError("SDL_CreateWindow failed");
    SDL_Quit();
    return 2;
  }
  if (!SDL_Vulkan_LoadLibrary(nullptr) || SDL_Vulkan_GetVkGetInstanceProcAddr() == nullptr) {
    LogError("SDL Vulkan loader unavailable");
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 3;
  }

  WGPURequestAdapterOptions options = WGPU_REQUEST_ADAPTER_OPTIONS_INIT;
  options.backendType = WGPUBackendType_Vulkan;
  dawn::native::Instance instance;
  const auto adapters = instance.EnumerateAdapters(&options);
  if (adapters.empty()) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "A0 Vulkan fixture failed: Dawn found no Vulkan adapter");
    SDL_Vulkan_UnloadLibrary();
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 4;
  }

  __android_log_print(ANDROID_LOG_INFO, kLogTag,
                      "A0 JNI/Vulkan fixture passed abi=arm64-v8a page_size=%ld adapters=%zu",
                      sysconf(_SC_PAGESIZE), adapters.size());
  SDL_Event event;
  while (SDL_WaitEvent(&event)) {
    if (event.type == SDL_EVENT_QUIT) break;
  }
  SDL_Vulkan_UnloadLibrary();
  SDL_DestroyWindow(window);
  SDL_Quit();
  return 0;
}
