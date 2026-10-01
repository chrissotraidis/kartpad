// Synthetic configs only. Null backend validation, never GPU/device gameplay.
#include "gx/shader_info.hpp"
#include <cassert>
#include <fstream>
#include <iostream>
#include <regex>

namespace aurora {
AuroraConfig g_config{};
void log_internal(AuroraLogLevel, const char*, const char* message, unsigned int size) noexcept {
  std::cerr.write(message, size) << '\n';
}
void Module::show_fatal_dialog(const char*, std::string_view message) noexcept {
  std::cerr << message << '\n';
}
namespace gfx {
uint32_t align_uniform(uint32_t value) { return (value + 255) & ~255u; }
}
namespace gx {
std::string build_shader_for_test(const ShaderConfig& config) noexcept;
}
}

void wait(wgpu::Instance instance, wgpu::Future future) {
  assert(instance.WaitAny(future, 5'000'000'000) == wgpu::WaitStatus::Success);
}

std::string boundary_shader(unsigned variables) {
  std::string fields, writes, sum = "vec4f(0.0)";
  for (unsigned i = 0; i < variables; ++i) {
    fields += "@location(" + std::to_string(i) + ") v" + std::to_string(i) + ": vec4f,";
    writes += "o.v" + std::to_string(i) + " = vec4f(1.0);";
    sum += "+i.v" + std::to_string(i);
  }
  return "struct O { @builtin(position) p:vec4f," + fields + "};"
         "@vertex fn vs_main()->O {var o:O;o.p=vec4f(0.,0.,0.,1.);" + writes + "return o;}"
         "@fragment fn fs_main(i:O)->@location(0) vec4f {return " + sum + ";}";
}

void validate(wgpu::Instance instance, wgpu::Device device, const std::string& source, bool accepted) {
  device.PushErrorScope(wgpu::ErrorFilter::Validation);
  wgpu::ShaderSourceWGSL wgsl{};
  wgsl.code = source.c_str();
  wgpu::ShaderModuleDescriptor moduleDesc{.nextInChain = &wgsl};
  const auto module = device.CreateShaderModule(&moduleDesc);
  wgpu::ColorTargetState target{.format = wgpu::TextureFormat::RGBA8Unorm};
  wgpu::FragmentState fragment{.module = module, .entryPoint = "fs_main",
                               .targetCount = 1, .targets = &target};
  wgpu::RenderPipelineDescriptor pipeline{};
  pipeline.vertex.module = module;
  pipeline.vertex.entryPoint = "vs_main";
  pipeline.fragment = &fragment;
  const auto result = device.CreateRenderPipeline(&pipeline);
  wgpu::ErrorType error = wgpu::ErrorType::Unknown;
  std::string message;
  wait(instance, device.PopErrorScope(wgpu::CallbackMode::WaitAnyOnly,
      [&](wgpu::PopErrorScopeStatus status, wgpu::ErrorType type, wgpu::StringView text) {
        assert(status == wgpu::PopErrorScopeStatus::Success);
        error = type;
        message = std::string(text);
      }));
  if (accepted && error != wgpu::ErrorType::NoError) std::cerr << message << '\n';
  assert(accepted ? error == wgpu::ErrorType::NoError : error == wgpu::ErrorType::Validation);
  if (!accepted) std::cout << "Expected boundary rejection: " << message << '\n';
  if (!accepted) assert(message.find("inter-stage") != std::string::npos ||
                        message.find("inter stage") != std::string::npos ||
                        message.find("maxInterStage") != std::string::npos ||
                        message.find("Vertex output variable") != std::string::npos ||
                        message.find("Total vertex output variables") != std::string::npos);
}

int main(int argc, char** argv) {
  assert(argc == 2);
  using namespace aurora::gx;
  // Sixteen TEV stages consume all eight coordinates and both color channels.
  ShaderConfig config{};
  config.numTexGens = 8;
  config.tevStageCount = 16;
  config.attrs[GX_VA_POS] = {.attrType = GX_DIRECT, .cnt = 3, .compType = GX_F32};
  config.attrs[GX_VA_NRM] = {.attrType = GX_DIRECT, .cnt = 3, .compType = GX_F32};
  config.attrs[GX_VA_CLR0] = {.attrType = GX_DIRECT, .cnt = 4, .compType = GX_RGBA8};
  config.attrs[GX_VA_CLR1] = config.attrs[GX_VA_CLR0];
  for (unsigned i = 0; i < 8; ++i) {
    config.attrs[GX_VA_TEX0 + i] = {.attrType = GX_DIRECT, .cnt = 2, .compType = GX_F32};
    config.tcgs[i].src = static_cast<GXTexGenSrc>(GX_TG_TEX0 + i);
    config.tcgs[i].type = GX_TG_MTX3x4;
  }
  for (unsigned i = 0; i < 16; ++i) {
    auto& stage = config.tevStages[i];
    stage.texCoordId = static_cast<GXTexCoordID>(i % 8);
    stage.texMapId = static_cast<GXTexMapID>(i % 8);
    stage.channelId = i % 2 ? GX_COLOR1A1 : GX_COLOR0A0;
    stage.colorPass.a = GX_CC_TEXC;
    stage.colorPass.c = GX_CC_RASC;
    stage.alphaPass.a = GX_CA_TEXA;
    stage.alphaPass.c = GX_CA_RASA;
  }
  for (auto& channel : config.colorChannels) {
    channel.lightingEnabled = true;
    channel.matSrc = GX_SRC_VTX;
    channel.ambSrc = GX_SRC_VTX;
  }
  const auto info = build_shader_info(config);
  assert(info.sampledTexCoords.count() == 8 && info.sampledColorChannels.count() == 2);
  const auto source = build_shader_for_test(config);
  const auto start = source.find("struct VertexOutput");
  const auto end = source.find("};", start);
  assert(start != std::string::npos && end != std::string::npos);
  const auto interface = source.substr(start, end - start);
  const std::regex location("@location\\(([0-9]+)\\)");
  const unsigned count = std::distance(std::sregex_iterator(interface.begin(), interface.end(), location),
                                     std::sregex_iterator());
  // The pinned generator uses vertex lighting: two channels + eight texcoords.
  assert(!UsePerPixelLighting && count == 10);
  std::ofstream(argv[1]) << source;

  const auto feature = wgpu::InstanceFeatureName::TimedWaitAny;
  wgpu::InstanceDescriptor instanceDesc{.requiredFeatureCount = 1, .requiredFeatures = &feature};
  const auto instance = wgpu::CreateInstance(&instanceDesc);
  wgpu::RequestAdapterOptions options{};
  options.backendType = wgpu::BackendType::Null;
  wgpu::Adapter adapter;
  wait(instance, instance.RequestAdapter(&options, wgpu::CallbackMode::WaitAnyOnly,
      [&](wgpu::RequestAdapterStatus status, wgpu::Adapter result, wgpu::StringView) {
        assert(status == wgpu::RequestAdapterStatus::Success);
        adapter = std::move(result);
      }));
  wgpu::AdapterInfo adapterInfo{};
  adapter.GetInfo(&adapterInfo);
  assert(adapterInfo.backendType == wgpu::BackendType::Null); // no hardware fallback
  wgpu::Limits requested{};
  requested.maxInterStageShaderVariables = 14;
  wgpu::DeviceDescriptor deviceDesc{};
  deviceDesc.requiredLimits = &requested;
  wgpu::Device device;
  wait(instance, adapter.RequestDevice(&deviceDesc, wgpu::CallbackMode::WaitAnyOnly,
      [&](wgpu::RequestDeviceStatus status, wgpu::Device result, wgpu::StringView) {
        assert(status == wgpu::RequestDeviceStatus::Success);
        device = std::move(result);
      }));
  wgpu::Limits actual{};
  device.GetLimits(&actual);
  // Dawn reifies requests below its default, so this cached host backend
  // cannot prove device creation at 14. Check the actual limit, not the request.
  assert(actual.maxInterStageShaderVariables == 16);
  validate(instance, device, source, true);
  validate(instance, device, boundary_shader(14), true);
  validate(instance, device, boundary_shader(16), true);
  validate(instance, device, boundary_shader(17), false);
  std::cout << "PASS: actual largest GX interface (10 locations), synthetic 14 and 16 accepted, 17 rejected; Null device reports 16, not 14; no GPU use\n";
}
