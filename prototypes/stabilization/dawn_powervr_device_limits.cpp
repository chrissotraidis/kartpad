// Controlled native unit regression, not a Vulkan driver or gameplay test.
// Only physical-device identity/limits are fixtures. Adapter, DeviceBase, WGSL
// reflection and pipeline validation come from the linked Dawn library.
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <iterator>
#include <string>
#include <utility>

#include "dawn/native/DawnNative.h"
#include "src/dawn/native/Adapter.h"
#include "src/dawn/native/ErrorData.h"
#include "src/dawn/native/Instance.h"
#include "src/dawn/native/PhysicalDevice.h"
#include "src/dawn/native/null/DeviceNull.h"

namespace native = dawn::native;

void check(bool condition, const std::string& message) {
    if (!condition) {
        std::cerr << "FAIL: " << message << '\n';
        std::exit(1);
    }
}

class FixturePhysicalDevice final : public native::PhysicalDeviceBase {
  public:
    FixturePhysicalDevice(wgpu::BackendType backend, uint32_t vendor, uint32_t variables)
        : PhysicalDeviceBase(backend), mVariables(variables) {
        mVendorId = vendor;
        mName = "Controlled interstage native unit fixture";
    }
    bool SupportsExternalImages() const override { return false; }
    bool SupportsFeatureLevel(wgpu::FeatureLevel, native::InstanceBase*) const override {
        return true;
    }
    void SetupBackendAdapterToggles(dawn::platform::Platform*, native::TogglesState*) const override {}
    void SetupBackendDeviceToggles(dawn::platform::Platform*, native::TogglesState*) const override {}
    void PopulateBackendProperties(native::UnpackedPtr<native::AdapterInfo>&,
                                   const native::TogglesState&) const override {}
    native::ResultOrError<native::PhysicalDeviceSurfaceCapabilities> GetSurfaceCapabilities(
        native::InstanceBase*, const native::Surface*) const override {
        return native::PhysicalDeviceSurfaceCapabilities{};
    }

  private:
    native::MaybeError InitializeImpl() override { return {}; }
    void InitializeSupportedFeaturesImpl() override {}
    native::MaybeError InitializeSupportedLimitsImpl(native::CombinedLimits* limits) override {
        native::GetDefaultLimits(limits, wgpu::FeatureLevel::Core);
        limits->v1.maxInterStageShaderVariables = mVariables;
        return {};
    }
    native::FeatureValidationResult ValidateFeatureSupportedWithTogglesImpl(
        wgpu::FeatureName, const native::TogglesState&) const override { return {}; }
    native::ResultOrError<dawn::Ref<native::DeviceBase>> CreateDeviceImpl(
        native::AdapterBase* adapter,
        const native::UnpackedPtr<native::DeviceDescriptor>& descriptor,
        const native::TogglesState& toggles,
        dawn::Ref<native::DeviceBase::DeviceLostEvent>&& lost) override {
        // The unchanged Null device performs real frontend parsing/validation.
        // No mock ShaderModule or RenderPipeline implementation is used.
        return native::null::Device::Create(adapter, descriptor, toggles, std::move(lost));
    }
    uint32_t mVariables;
};

std::string boundaryShader(uint32_t variables, uint32_t firstLocation = 0) {
    std::string fields, writes, sum = "vec4f(0.0)";
    for (uint32_t i = 0; i < variables; ++i) {
        const std::string index = std::to_string(i);
        fields += "@location(" + std::to_string(firstLocation + i) + ") v" + index + ":vec4f,";
        writes += "o.v" + index + "=vec4f(1.0);";
        sum += "+i.v" + index;
    }
    return "struct O{@builtin(position) p:vec4f," + fields + "};"
           "@vertex fn vs()->O{var o:O;o.p=vec4f(0.,0.,0.,1.);" + writes + "return o;}"
           "@fragment fn fs(i:O)->@location(0) vec4f{return " + sum + ";}";
}

void validate(wgpu::Instance instance, wgpu::Device device,
              const std::string& source, bool accepted,
              const char* vertexEntry = "vs", const char* fragmentEntry = "fs") {
    device.PushErrorScope(wgpu::ErrorFilter::Validation);
    wgpu::ShaderSourceWGSL wgsl{};
    wgsl.code = source.c_str();
    wgpu::ShaderModuleDescriptor moduleDesc{.nextInChain = &wgsl};
    const auto module = device.CreateShaderModule(&moduleDesc);
    wgpu::ColorTargetState target{.format = wgpu::TextureFormat::RGBA8Unorm};
    wgpu::FragmentState fragment{.module = module, .entryPoint = fragmentEntry,
                               .targetCount = 1, .targets = &target};
    wgpu::RenderPipelineDescriptor pipeline{};
    pipeline.vertex.module = module;
    pipeline.vertex.entryPoint = vertexEntry;
    pipeline.fragment = &fragment;
    const auto result = device.CreateRenderPipeline(&pipeline);
    wgpu::ErrorType error = wgpu::ErrorType::Unknown;
    std::string message;
    const auto future = device.PopErrorScope(wgpu::CallbackMode::WaitAnyOnly,
        [&](wgpu::PopErrorScopeStatus status, wgpu::ErrorType type, wgpu::StringView text) {
            check(status == wgpu::PopErrorScopeStatus::Success, "PopErrorScope status");
            error = type;
            message = std::string(text);
        });
    check(instance.WaitAny(future, 5'000'000'000) == wgpu::WaitStatus::Success, "validation callback");
    check(accepted ? error == wgpu::ErrorType::NoError : error == wgpu::ErrorType::Validation,
          std::string(accepted ? "expected pipeline acceptance: " : "expected pipeline rejection: ") + message);
    if (!accepted) {
        check(message.find("Vertex output variable") != std::string::npos ||
              message.find("Total vertex output variables") != std::string::npos,
              "rejection must come from interstage validation: " + message);
    }
}

void runCase(native::InstanceBase* nativeInstance, wgpu::Instance instance,
             const std::string& productionShader, const char* name,
             wgpu::BackendType backend, uint32_t vendor,
             uint32_t physicalVariables, uint32_t requestedVariables,
             uint32_t expectedVariables, bool tiered = false, bool omitLimits = false) {
    auto physical = dawn::AcquireRef(new FixturePhysicalDevice(backend, vendor, physicalVariables));
    auto initialized = physical->Initialize();
    if (initialized.IsError()) {
        check(false, initialized.AcquireError()->GetFormattedMessage());
    }
    auto adapter = dawn::AcquireRef(new native::AdapterBase(
        nativeInstance, physical, wgpu::FeatureLevel::Core,
        native::TogglesState(native::ToggleStage::Adapter), wgpu::PowerPreference::Undefined));
    adapter->SetUseTieredLimits(tiered);
    check(adapter->GetLimits().v1.maxInterStageShaderVariables == physicalVariables,
          std::string(name) + ": fixture adapter limit");
    wgpu::Limits required{};
    required.maxInterStageShaderVariables = requestedVariables;
    wgpu::DeviceDescriptor descriptor{};
    if (!omitLimits) descriptor.requiredLimits = &required;
    // APICreateDevice routes through actual CreateDeviceInternal and ValidateLimits.
    auto* rawDevice = adapter->APICreateDevice(native::FromCppAPI(&descriptor));
    if (expectedVariables == 0) {
        check(rawDevice == nullptr, std::string(name) + ": unsupported request must fail");
        std::cout << "PASS " << name << ": request " << requestedVariables << " rejected\n";
        return;
    }
    check(rawDevice != nullptr, std::string(name) + ": device creation");
    const auto device = wgpu::Device::Acquire(native::ToAPI(rawDevice));
    wgpu::Limits actual{};
    check(device.GetLimits(&actual) == wgpu::Status::Success, "Device.GetLimits status");
    check(actual.maxInterStageShaderVariables == expectedVariables,
          std::string(name) + ": expected device limit " + std::to_string(expectedVariables) +
          ", got " + std::to_string(actual.maxInterStageShaderVariables));
    validate(instance, device, boundaryShader(expectedVariables), true);
    validate(instance, device, boundaryShader(expectedVariables + 1), false);
    validate(instance, device, boundaryShader(1, expectedVariables), false);
    if (expectedVariables == 14 && !productionShader.empty()) {
        validate(instance, device, productionShader, true, "vs_main", "fs_main");
        std::cout << "PASS " << name << ": supplied production WGSL accepted at device limit 14\n";
    }
    std::cout << "PASS " << name << ": device " << expectedVariables << ", boundary accepted; "
              << expectedVariables + 1 << " variables and location " << expectedVariables << " rejected\n";
}

int main(int argc, char** argv) {
    check(argc == 1 || argc == 2, "usage: dawn-powervr-device-limits [production.wgsl]");
    std::string productionShader;
    if (argc == 2) {
        std::ifstream input(argv[1], std::ios::binary);
        check(input.good(), "open supplied production WGSL");
        productionShader.assign(std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>());
        check(!input.bad() && !productionShader.empty(), "read supplied production WGSL");
    }
    const wgpu::InstanceFeatureName features[] = {
        wgpu::InstanceFeatureName::TimedWaitAny,
        wgpu::InstanceFeatureName::MultipleDevicesPerAdapter};
    wgpu::InstanceDescriptor descriptor{.requiredFeatureCount = 2, .requiredFeatures = features};
    native::Instance owner(&descriptor);
    wgpu::Instance instance(owner.Get());
    auto* nativeInstance = native::FromAPI(owner.Get());
    const auto imgtec = dawn::gpu_info::kVendorID_ImgTec;
    const auto other = dawn::gpu_info::kVendorID_QualcommPCI;
    const auto unspecified = wgpu::kLimitU32Undefined;
    runCase(nativeInstance, instance, productionShader, "ImgTec Vulkan omitted requiredLimits", wgpu::BackendType::Vulkan,
            imgtec, 14, unspecified, 14, false, true);
    runCase(nativeInstance, instance, productionShader, "ImgTec Vulkan undefined interstage", wgpu::BackendType::Vulkan,
            imgtec, 14, unspecified, 14);
    runCase(nativeInstance, instance, productionShader, "ImgTec Vulkan requested14", wgpu::BackendType::Vulkan,
            imgtec, 14, 14, 14);
    runCase(nativeInstance, instance, productionShader, "ImgTec Vulkan requested15", wgpu::BackendType::Vulkan,
            imgtec, 14, 15, 0);
    runCase(nativeInstance, instance, productionShader, "ImgTec Vulkan requested16", wgpu::BackendType::Vulkan,
            imgtec, 14, 16, 0);
    runCase(nativeInstance, instance, productionShader, "ImgTec Vulkan tiered adapter14", wgpu::BackendType::Vulkan,
            imgtec, 14, unspecified, 14, true);
    // Deliberately sub-default controls verify that both vendor and backend guards
    // are scoped. They represent test fixtures, not conforming physical adapters.
    runCase(nativeInstance, instance, productionShader, "other vendor Vulkan guard", wgpu::BackendType::Vulkan,
            other, 14, unspecified, 16);
    runCase(nativeInstance, instance, productionShader, "ImgTec Null guard", wgpu::BackendType::Null,
            imgtec, 14, unspecified, 16);
    runCase(nativeInstance, instance, productionShader, "other vendor Vulkan default16", wgpu::BackendType::Vulkan,
            other, 16, 14, 16);
    runCase(nativeInstance, instance, productionShader, "ImgTec Vulkan physical28 default16", wgpu::BackendType::Vulkan,
            imgtec, 28, unspecified, 16);
    runCase(nativeInstance, instance, productionShader, "ImgTec Vulkan physical28 requested20", wgpu::BackendType::Vulkan,
            imgtec, 28, 20, 20);
    std::cout << "PASS: controlled native adapter/device/shader validation; Null implementation, no Vulkan GPU or gameplay proof\n";
}
