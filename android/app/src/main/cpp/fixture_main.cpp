#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <SDL3/SDL_vulkan.h>
#include <android/log.h>
#include <jni.h>
#include <dawn/native/DawnNative.h>
#include <dawn/webgpu.h>
#include <unistd.h>

#include "guest_memory_fixture.h"
#include "kartpad/android/gamepad_contract.h"
#include "scheduler_fixture.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cstddef>
#include <cstdint>
#include <thread>

namespace {

constexpr char kLogTag[] = "KartPadFixture";

void LogError(const char* message) {
  __android_log_print(ANDROID_LOG_ERROR, kLogTag, "%s: %s", message,
                      SDL_GetError());
}

bool RunAndroidGamepadContract() {
  using namespace kartpad::android;
  RawGamepadState input;
  input.connected = true;
  input.buttons = kGamepadSouth | kGamepadEast | kGamepadWest |
                  kGamepadNorth | kGamepadBack | kGamepadStart |
                  kGamepadLeftShoulder | kGamepadRightShoulder |
                  kGamepadDpadUp | kGamepadDpadDown |
                  kGamepadDpadLeft | kGamepadDpadRight;
  input.left_trigger = kTriggerThreshold;
  input.right_trigger = kTriggerThreshold;
  input.left_x = 32767;
  input.left_y = -32768;
  const auto mapped = MapGamepadToClassic(input);
  constexpr uint32_t kExpectedButtons =
      kClassicA | kClassicB | kClassicX | kClassicY | kClassicMinus |
      kClassicPlus | kClassicL | kClassicR | kClassicUp | kClassicDown |
      kClassicLeft | kClassicRight | kClassicZl | kClassicZr;
  return mapped.connected && mapped.buttons == kExpectedButtons &&
         mapped.left_stick_x == 1.0f && mapped.left_stick_y == 1.0f &&
         !MapGamepadToClassic({}).connected;
}

struct MapState {
  bool complete = false;
  WGPUMapAsyncStatus status = WGPUMapAsyncStatus_Error;
};

struct LifecycleState {
  std::atomic_bool foreground_pending = false;
  std::atomic_int orientation_pending = SDL_ORIENTATION_UNKNOWN;
  std::atomic_int current_orientation = SDL_ORIENTATION_UNKNOWN;
  std::atomic_int background_count = 0;
};

bool LifecycleEventFilter(void* userdata, SDL_Event* event) {
  auto* state = static_cast<LifecycleState*>(userdata);
  if (event->type == SDL_EVENT_WILL_ENTER_BACKGROUND) {
    const int cycle = state->background_count.fetch_add(
                          1, std::memory_order_acq_rel) +
                      1;
    __android_log_print(ANDROID_LOG_INFO, kLogTag,
                        "A1 lifecycle background observed cycle=%d", cycle);
  } else if (event->type == SDL_EVENT_DID_ENTER_FOREGROUND) {
    state->foreground_pending.store(true, std::memory_order_release);
  } else if (event->type == SDL_EVENT_DISPLAY_ORIENTATION &&
             event->display.data1 != SDL_ORIENTATION_UNKNOWN) {
    const int orientation = event->display.data1;
    const int previous = state->current_orientation.exchange(
        orientation, std::memory_order_acq_rel);
    if (orientation != previous) {
      state->orientation_pending.store(orientation,
                                       std::memory_order_release);
      __android_log_print(ANDROID_LOG_INFO, kLogTag,
                          "A1 orientation observed orientation=%d previous=%d",
                          orientation, previous);
    }
  }
  return true;
}

bool RunDeterministicReadback(dawn::native::Instance& instance,
                              WGPUDevice device) {
  constexpr uint32_t kWidth = 4;
  constexpr uint32_t kHeight = 4;
  constexpr uint32_t kBytesPerRow = 256;
  constexpr std::array<uint8_t, 4> kExpected = {32, 128, 224, 255};

  WGPUQueue queue = nullptr;
  WGPUTexture texture = nullptr;
  WGPUTextureView view = nullptr;
  WGPUBuffer readback = nullptr;
  WGPUCommandEncoder encoder = nullptr;
  WGPURenderPassEncoder pass = nullptr;
  WGPUCommandBuffer commands = nullptr;
  MapState map_state;
  bool passed = false;

  do {
    queue = wgpuDeviceGetQueue(device);
    if (queue == nullptr) break;

    WGPUTextureDescriptor texture_desc = WGPU_TEXTURE_DESCRIPTOR_INIT;
    texture_desc.usage = WGPUTextureUsage_RenderAttachment | WGPUTextureUsage_CopySrc;
    texture_desc.dimension = WGPUTextureDimension_2D;
    texture_desc.size = {kWidth, kHeight, 1};
    texture_desc.format = WGPUTextureFormat_RGBA8Unorm;
    texture = wgpuDeviceCreateTexture(device, &texture_desc);
    if (texture == nullptr) break;
    view = wgpuTextureCreateView(texture, nullptr);
    if (view == nullptr) break;

    WGPUBufferDescriptor buffer_desc = WGPU_BUFFER_DESCRIPTOR_INIT;
    buffer_desc.usage = WGPUBufferUsage_CopyDst | WGPUBufferUsage_MapRead;
    buffer_desc.size = kBytesPerRow * kHeight;
    readback = wgpuDeviceCreateBuffer(device, &buffer_desc);
    if (readback == nullptr) break;

    encoder = wgpuDeviceCreateCommandEncoder(device, nullptr);
    if (encoder == nullptr) break;
    WGPURenderPassColorAttachment color = WGPU_RENDER_PASS_COLOR_ATTACHMENT_INIT;
    color.view = view;
    color.loadOp = WGPULoadOp_Clear;
    color.storeOp = WGPUStoreOp_Store;
    color.clearValue = {32.0 / 255.0, 128.0 / 255.0, 224.0 / 255.0, 1.0};
    WGPURenderPassDescriptor pass_desc = WGPU_RENDER_PASS_DESCRIPTOR_INIT;
    pass_desc.colorAttachmentCount = 1;
    pass_desc.colorAttachments = &color;
    pass = wgpuCommandEncoderBeginRenderPass(encoder, &pass_desc);
    if (pass == nullptr) break;
    wgpuRenderPassEncoderEnd(pass);

    WGPUTexelCopyTextureInfo source = WGPU_TEXEL_COPY_TEXTURE_INFO_INIT;
    source.texture = texture;
    source.aspect = WGPUTextureAspect_All;
    WGPUTexelCopyBufferInfo destination = WGPU_TEXEL_COPY_BUFFER_INFO_INIT;
    destination.buffer = readback;
    destination.layout.bytesPerRow = kBytesPerRow;
    destination.layout.rowsPerImage = kHeight;
    WGPUExtent3D copy_size = {kWidth, kHeight, 1};
    wgpuCommandEncoderCopyTextureToBuffer(encoder, &source, &destination, &copy_size);
    commands = wgpuCommandEncoderFinish(encoder, nullptr);
    if (commands == nullptr) break;
    wgpuQueueSubmit(queue, 1, &commands);

    WGPUBufferMapCallbackInfo callback = WGPU_BUFFER_MAP_CALLBACK_INFO_INIT;
    callback.mode = WGPUCallbackMode_AllowProcessEvents;
    callback.userdata1 = &map_state;
    callback.callback = [](WGPUMapAsyncStatus status, WGPUStringView, void* userdata,
                           void*) {
      auto* state = static_cast<MapState*>(userdata);
      state->status = status;
      state->complete = true;
    };
    wgpuBufferMapAsync(readback, WGPUMapMode_Read, 0, buffer_desc.size, callback);
    for (int attempt = 0; attempt < 500 && !map_state.complete; ++attempt) {
      dawn::native::DeviceTick(device);
      dawn::native::InstanceProcessEvents(instance.Get());
      std::this_thread::sleep_for(std::chrono::milliseconds(2));
    }
    if (!map_state.complete || map_state.status != WGPUMapAsyncStatus_Success) break;

    const auto* bytes = static_cast<const uint8_t*>(
        wgpuBufferGetConstMappedRange(readback, 0, buffer_desc.size));
    if (bytes == nullptr) break;
    passed = true;
    for (uint32_t y = 0; y < kHeight && passed; ++y) {
      for (uint32_t x = 0; x < kWidth; ++x) {
        const uint8_t* pixel = bytes + y * kBytesPerRow + x * kExpected.size();
        if (!std::equal(kExpected.begin(), kExpected.end(), pixel)) {
          passed = false;
          break;
        }
      }
    }
    wgpuBufferUnmap(readback);
  } while (false);

  if (commands != nullptr) wgpuCommandBufferRelease(commands);
  if (pass != nullptr) wgpuRenderPassEncoderRelease(pass);
  if (encoder != nullptr) wgpuCommandEncoderRelease(encoder);
  if (readback != nullptr) wgpuBufferRelease(readback);
  if (view != nullptr) wgpuTextureViewRelease(view);
  if (texture != nullptr) wgpuTextureRelease(texture);
  if (queue != nullptr) wgpuQueueRelease(queue);
  return passed;
}

bool RunSurfacePresent(dawn::native::Instance& instance,
                       dawn::native::Adapter& adapter, WGPUDevice device,
                       SDL_Window* window, WGPUSurface* retained_surface,
                       bool replace_surface,
                       int* presented_width, int* presented_height) {
  if (!SDL_GetWindowSizeInPixels(window, presented_width, presented_height) ||
      *presented_width <= 0 || *presented_height <= 0) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "surface step failed: window-size");
    return false;
  }

  WGPUQueue queue = nullptr;
  WGPUTexture texture = nullptr;
  WGPUTextureView view = nullptr;
  WGPUCommandEncoder encoder = nullptr;
  WGPURenderPassEncoder pass = nullptr;
  WGPUCommandBuffer commands = nullptr;
  WGPUSurfaceCapabilities capabilities = WGPU_SURFACE_CAPABILITIES_INIT;
  bool capabilities_valid = false;
  bool configured = false;
  bool passed = false;
  const char* failed_step = "get-queue";
  int status_detail = 0;

  do {
    queue = wgpuDeviceGetQueue(device);
    if (queue == nullptr) break;
    if (replace_surface && *retained_surface != nullptr) {
      wgpuSurfaceRelease(*retained_surface);
      *retained_surface = nullptr;
    }
    if (*retained_surface == nullptr) {
      void* native_window = SDL_GetPointerProperty(
          SDL_GetWindowProperties(window),
          SDL_PROP_WINDOW_ANDROID_WINDOW_POINTER, nullptr);
      if (native_window == nullptr) {
        failed_step = "native-window";
        break;
      }
      WGPUSurfaceSourceAndroidNativeWindow source =
          WGPU_SURFACE_SOURCE_ANDROID_NATIVE_WINDOW_INIT;
      source.window = native_window;
      WGPUSurfaceDescriptor surface_desc = WGPU_SURFACE_DESCRIPTOR_INIT;
      surface_desc.nextInChain = &source.chain;
      failed_step = "create-surface";
      *retained_surface =
          wgpuInstanceCreateSurface(instance.Get(), &surface_desc);
      if (*retained_surface == nullptr) break;
    }
    failed_step = "surface-capabilities";
    const WGPUStatus capabilities_status =
        wgpuSurfaceGetCapabilities(*retained_surface, adapter.Get(),
                                   &capabilities);
    status_detail = static_cast<int>(capabilities_status);
    if (capabilities_status != WGPUStatus_Success || capabilities.formatCount == 0) {
      break;
    }
    capabilities_valid = true;

    WGPUSurfaceConfiguration config = WGPU_SURFACE_CONFIGURATION_INIT;
    config.device = device;
    config.format = capabilities.formats[0];
    config.width = static_cast<uint32_t>(*presented_width);
    config.height = static_cast<uint32_t>(*presented_height);
    config.presentMode = WGPUPresentMode_Fifo;
    wgpuSurfaceConfigure(*retained_surface, &config);
    configured = true;

    failed_step = "current-texture";
    WGPUSurfaceTexture current = WGPU_SURFACE_TEXTURE_INIT;
    wgpuSurfaceGetCurrentTexture(*retained_surface, &current);
    status_detail = static_cast<int>(current.status);
    if ((current.status != WGPUSurfaceGetCurrentTextureStatus_SuccessOptimal &&
         current.status != WGPUSurfaceGetCurrentTextureStatus_SuccessSuboptimal) ||
        current.texture == nullptr) {
      break;
    }
    texture = current.texture;
    failed_step = "texture-view";
    view = wgpuTextureCreateView(texture, nullptr);
    if (view == nullptr) break;
    failed_step = "command-encoder";
    encoder = wgpuDeviceCreateCommandEncoder(device, nullptr);
    if (encoder == nullptr) break;
    WGPURenderPassColorAttachment color = WGPU_RENDER_PASS_COLOR_ATTACHMENT_INIT;
    color.view = view;
    color.loadOp = WGPULoadOp_Clear;
    color.storeOp = WGPUStoreOp_Store;
    color.clearValue = {0.05, 0.20, 0.24, 1.0};
    WGPURenderPassDescriptor pass_desc = WGPU_RENDER_PASS_DESCRIPTOR_INIT;
    pass_desc.colorAttachmentCount = 1;
    pass_desc.colorAttachments = &color;
    failed_step = "render-pass";
    pass = wgpuCommandEncoderBeginRenderPass(encoder, &pass_desc);
    if (pass == nullptr) break;
    wgpuRenderPassEncoderEnd(pass);
    failed_step = "finish-commands";
    commands = wgpuCommandEncoderFinish(encoder, nullptr);
    if (commands == nullptr) break;
    wgpuQueueSubmit(queue, 1, &commands);
    failed_step = "present";
    const WGPUStatus present_status = wgpuSurfacePresent(*retained_surface);
    status_detail = static_cast<int>(present_status);
    if (present_status != WGPUStatus_Success) break;
    dawn::native::DeviceTick(device);
    passed = true;
  } while (false);

  if (commands != nullptr) wgpuCommandBufferRelease(commands);
  if (pass != nullptr) wgpuRenderPassEncoderRelease(pass);
  if (encoder != nullptr) wgpuCommandEncoderRelease(encoder);
  if (view != nullptr) wgpuTextureViewRelease(view);
  if (texture != nullptr) wgpuTextureRelease(texture);
  if (configured) wgpuSurfaceUnconfigure(*retained_surface);
  if (capabilities_valid) wgpuSurfaceCapabilitiesFreeMembers(capabilities);
  if (queue != nullptr) wgpuQueueRelease(queue);
  if (!passed) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "surface step failed: %s status=%d", failed_step,
                        status_detail);
  }
  return passed;
}

}  // namespace

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadSurface_nativeBeginSurfaceMutation(JNIEnv*, jobject) {}

extern "C" JNIEXPORT void JNICALL
Java_dev_kartpad_android_KartPadSurface_nativeEndSurfaceMutation(JNIEnv*, jobject, jboolean) {}

extern "C" __attribute__((visibility("default"))) int SDL_main(int, char**) {
  SDL_SetAppMetadata("KartPad", "0.0.1-a0", "dev.kartpad.android");
  if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS)) {
    LogError("SDL_Init failed");
    return 1;
  }
  if (!RunGuestMemoryFixture()) {
    SDL_Quit();
    return 2;
  }
  if (!RunSchedulerFixture()) {
    SDL_Quit();
    return 3;
  }
  if (!RunAndroidGamepadContract()) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "A2 SDL gamepad contract failed");
    SDL_Quit();
    return 10;
  }
  __android_log_print(ANDROID_LOG_INFO, kLogTag,
                      "A2 SDL gamepad contract passed");
  SDL_Window* window = SDL_CreateWindow(
      "KartPad", 960, 540, SDL_WINDOW_VULKAN | SDL_WINDOW_HIGH_PIXEL_DENSITY);
  if (window == nullptr) {
    LogError("SDL_CreateWindow failed");
    SDL_Quit();
    return 4;
  }
  if (!SDL_Vulkan_LoadLibrary(nullptr) || SDL_Vulkan_GetVkGetInstanceProcAddr() == nullptr) {
    LogError("SDL Vulkan loader unavailable");
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 5;
  }

  WGPURequestAdapterOptions options = WGPU_REQUEST_ADAPTER_OPTIONS_INIT;
  options.backendType = WGPUBackendType_Vulkan;
  dawn::native::Instance instance;
  auto adapters = instance.EnumerateAdapters(&options);
  if (adapters.empty()) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "A0 Vulkan fixture failed: Dawn found no Vulkan adapter");
    SDL_Vulkan_UnloadLibrary();
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 6;
  }
  __android_log_print(ANDROID_LOG_INFO, kLogTag,
                      "A0 JNI/Vulkan fixture passed abi=arm64-v8a page_size=%ld adapters=%zu",
                      sysconf(_SC_PAGESIZE), adapters.size());
  WGPUDeviceDescriptor device_desc = WGPU_DEVICE_DESCRIPTOR_INIT;
  device_desc.uncapturedErrorCallbackInfo.callback =
      [](WGPUDevice const*, WGPUErrorType type, WGPUStringView message, void*, void*) {
        __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                            "Dawn uncaptured error type=%d message=%.*s",
                            static_cast<int>(type), static_cast<int>(message.length),
                            message.data == nullptr ? "" : message.data);
      };
  WGPUDevice device = adapters.front().CreateDevice(&device_desc);
  if (device == nullptr) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "A1 Vulkan fixture failed: device creation");
    SDL_Vulkan_UnloadLibrary();
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 7;
  }
  if (!RunDeterministicReadback(instance, device)) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "A1 Vulkan fixture failed: deterministic clear/readback mismatch");
    wgpuDeviceRelease(device);
    SDL_Vulkan_UnloadLibrary();
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 8;
  }

  __android_log_print(ANDROID_LOG_INFO, kLogTag,
                      "A1 Vulkan readback passed rgba=20-80-e0-ff "
                      "abi=arm64-v8a page_size=%ld adapters=%zu",
                      sysconf(_SC_PAGESIZE), adapters.size());
  int presented_width = 0;
  int presented_height = 0;
  WGPUSurface surface = nullptr;
  if (!RunSurfacePresent(instance, adapters.front(), device, window, &surface,
                         false,
                         &presented_width, &presented_height)) {
    __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                        "A1 Vulkan fixture failed: surface clear/present");
    if (surface != nullptr) wgpuSurfaceRelease(surface);
    wgpuDeviceRelease(device);
    SDL_Vulkan_UnloadLibrary();
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 9;
  }
  __android_log_print(ANDROID_LOG_INFO, kLogTag,
                      "A1 Vulkan present passed abi=arm64-v8a page_size=%ld "
                      "size=%dx%d generation=1",
                      sysconf(_SC_PAGESIZE), presented_width, presented_height);
  int exit_code = 0;
  int presentation_generation = 1;
  LifecycleState lifecycle;
  lifecycle.current_orientation.store(
      SDL_GetCurrentDisplayOrientation(SDL_GetDisplayForWindow(window)),
      std::memory_order_release);
  SDL_SetEventFilter(LifecycleEventFilter, &lifecycle);
  SDL_Event event;
  while (SDL_WaitEvent(&event)) {
    if (event.type == SDL_EVENT_QUIT) break;
    const int orientation = lifecycle.orientation_pending.exchange(
        SDL_ORIENTATION_UNKNOWN, std::memory_order_acq_rel);
    const bool foreground = lifecycle.foreground_pending.exchange(
        false, std::memory_order_acq_rel);
    if (orientation != SDL_ORIENTATION_UNKNOWN || foreground) {
      // Allow Android's SurfaceView transaction to settle before querying the
      // replacement ANativeWindow. This is bounded by the runner's marker
      // timeout and avoids presenting through a transition-era surface.
      std::this_thread::sleep_for(std::chrono::seconds(3));
      if (!RunSurfacePresent(instance, adapters.front(), device, window,
                             &surface, foreground,
                             &presented_width, &presented_height)) {
        __android_log_print(ANDROID_LOG_ERROR, kLogTag,
                            "A1 Vulkan fixture failed: surface recreation");
        exit_code = 10;
        break;
      }
      ++presentation_generation;
      __android_log_print(ANDROID_LOG_INFO, kLogTag,
                          "A1 Vulkan recreate passed generation=%d reason=%s "
                          "orientation=%d page_size=%ld size=%dx%d",
                          presentation_generation,
                          orientation != SDL_ORIENTATION_UNKNOWN ? "orientation"
                                                                 : "foreground",
                          lifecycle.current_orientation.load(
                              std::memory_order_acquire),
                          sysconf(_SC_PAGESIZE),
                          presented_width, presented_height);
    }
  }
  SDL_SetEventFilter(nullptr, nullptr);
  if (surface != nullptr) wgpuSurfaceRelease(surface);
  wgpuDeviceRelease(device);
  SDL_Vulkan_UnloadLibrary();
  SDL_DestroyWindow(window);
  SDL_Quit();
  return exit_code;
}
