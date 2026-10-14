// SPDX-License-Identifier: GPL-3.0-only
// Synthetic readback probe for issue #102. No game files, saves, or device IDs.
#include <webgpu/webgpu_cpp.h>
#include <array>
#include <bit>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <mutex>
#include <memory>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>
#include <utility>
#include "shader_helpers.h"
#if defined(__ANDROID__) && !defined(KARTPAD_PROBE_CLI)
#include <jni.h>
#endif

namespace {
constexpr unsigned kCases = 256, kFields = 16;
std::string string(wgpu::StringView v) {
    return v.data ? std::string(v.data, v.length == WGPU_STRLEN ? strlen(v.data) : v.length) : "";
}
void require(bool ok, const char* message) { if (!ok) throw std::runtime_error(message); }
struct Errors {
    std::mutex mutex;
    std::string text;
    void add(const std::string& message) { std::lock_guard lock(mutex); text += message + "\n"; }
    void check() { std::lock_guard lock(mutex); if (!text.empty()) throw std::runtime_error(std::exchange(text, {})); }
};
void wait(wgpu::Instance instance, wgpu::Future future) {
    require(instance.WaitAny(future, 5'000'000'000) == wgpu::WaitStatus::Success, "GPU callback timed out");
}
wgpu::Buffer buffer(wgpu::Device device, size_t size, wgpu::BufferUsage usage) {
    wgpu::BufferDescriptor desc{.usage = usage, .size = size};
    return device.CreateBuffer(&desc);
}
#include "draw_probe.h"
std::string shader(bool packed) {
    std::string s = kHelpers;
    s += "\nstruct Uniform { head: vec4u, offsets: ";
    s += packed ? "array<vec4u, 3>" : "array<u32, 12>";
    s += R"WGSL(, transform: array<mat3x4f, 20>, };
@group(0) @binding(0) var<storage, read> data: array<u32>;
@group(0) @binding(1) var<storage, read_write> result: array<u32>;
@group(0) @binding(2) var<uniform> uni: Uniform;
@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) id: vec3u) {
 let i = id.x;
 let o = i * 16u;
 result[o + 0u] = load_u8(&data, i);
 result[o + 1u] = load_u16(&data, i, true);
 result[o + 2u] = load_u16(&data, i, false);
 result[o + 3u] = load_u32_raw(&data, i);
 result[o + 4u] = load_u32(&data, i, false);
 let signed_values = fetch_s16_4(&data, i, 8u, false);
 result[o + 5u] = bitcast<u32>(signed_values.x);
 result[o + 6u] = bitcast<u32>(signed_values.y);
 result[o + 7u] = bitcast<u32>(signed_values.z);
 result[o + 8u] = bitcast<u32>(signed_values.w);
 let bytes = raw_fetch_u8_3(&data, i);
 result[o + 9u] = bytes.x | (bytes.y << 8u) | (bytes.z << 16u);
 result[o + 10u] = load_u24(&data, i, false);
 let slot = i % 12u;
)WGSL";
    s += packed ? "result[o + 11u] = uni.offsets[slot / 4u][slot % 4u];\n"
                : "result[o + 11u] = uni.offsets[slot];\n";
    s += R"WGSL(
 let transformed = vec4f(1.0, 2.0, 3.0, 1.0) * uni.transform[i % 20u];
 result[o + 12u] = bitcast<u32>(transformed.x);
 result[o + 13u] = bitcast<u32>(transformed.y);
 result[o + 14u] = bitcast<u32>(transformed.z);
 result[o + 15u] = bitcast<u32>(fetch_f32_1(&data, 512u + (i % 64u) * 4u, false));
}
)WGSL";
    return s;
}
std::vector<uint32_t> expected(const std::array<uint8_t, 1024>& bytes) {
    std::vector<uint32_t> out(kCases * kFields);
    auto read = [&](unsigned off, unsigned count, bool big) {
        uint32_t value = 0;
        for (unsigned n = 0; n < count; ++n) value |= uint32_t(bytes[off+n]) << (8 * (big ? count-1-n : n));
        return value;
    };
    for (unsigned i = 0; i < kCases; ++i) {
        auto* p = out.data() + i*kFields;
        p[0]=read(i,1,false); p[1]=read(i,2,false); p[2]=read(i,2,true);
        p[3]=read(i,4,false); p[4]=read(i,4,true);
        for (unsigned n=0; n<4; ++n) {
            const int v = int(read(i+2*n,2,true));
            p[5+n]=std::bit_cast<uint32_t>(float(v < 32768 ? v : v-65536)/256.0f);
        }
        p[9]=read(i,3,false); p[10]=read(i,3,true); p[11]=0x12340000u+(i%12)*37;
        for (unsigned n=0;n<3;++n) p[12+n]=std::bit_cast<uint32_t>(float((i%20)*100+n*10+4));
        p[15]=read(512+(i%64)*4,4,true);
    }
    return out;
}
void run(wgpu::Instance instance, wgpu::Adapter adapter, bool robustness, std::ostringstream& report) {
    auto errors = std::make_shared<Errors>();
    const char* off[] = {"disable_robustness"};
    wgpu::DawnTogglesDescriptor toggles{};
    toggles.enabledToggleCount = robustness ? 0 : 1;
    toggles.enabledToggles = off;
    wgpu::DeviceDescriptor desc{};
    desc.nextInChain = &toggles;
    wgpu::Limits supported{}; adapter.GetLimits(&supported);
    wgpu::Limits required{};
    required.minUniformBufferOffsetAlignment=supported.minUniformBufferOffsetAlignment;
    required.minStorageBufferOffsetAlignment=supported.minStorageBufferOffsetAlignment;
    desc.requiredLimits=&required;
    desc.SetUncapturedErrorCallback([](const wgpu::Device&, wgpu::ErrorType, wgpu::StringView msg, Errors* state){ state->add(string(msg)); }, errors.get());
    auto createdDevice = std::make_shared<wgpu::Device>();
    wait(instance, adapter.RequestDevice(&desc, wgpu::CallbackMode::WaitAnyOnly,
        [createdDevice, errors](wgpu::RequestDeviceStatus status, wgpu::Device value, wgpu::StringView msg) {
            if (status == wgpu::RequestDeviceStatus::Success) *createdDevice = std::move(value);
            else errors->add(string(msg));
        }));
    auto device = std::move(*createdDevice);
    errors->check(); require(bool(device), "Device unavailable");
    auto queue = device.GetQueue();
    std::array<uint8_t,1024> bytes{};
    for (unsigned i=0;i<bytes.size();++i) bytes[i]=uint8_t((i*73+129) ^ (i>>1));
    for (unsigned i=0;i<64;++i) {
        const uint32_t value=std::bit_cast<uint32_t>((int(i)-32)*0.125f);
        for (unsigned n=0;n<4;++n) bytes[512+i*4+n]=uint8_t(value>>(24-8*n));
    }
    std::array<uint32_t,256> uniforms{};
    for(unsigned i=0;i<12;++i) uniforms[4+i]=0x12340000u+i*37;
    for(unsigned m=0;m<20;++m) for(unsigned col=0;col<3;++col) {
        // dot([1,2,3,1], [1,0,0,m*100+col*10+3]) has an exact integer result.
        uniforms[16+m*12+col*4]=std::bit_cast<uint32_t>(1.0f);
        uniforms[16+m*12+col*4+3]=std::bit_cast<uint32_t>(float(m*100+col*10+3));
    }
    auto input=buffer(device,bytes.size(),wgpu::BufferUsage::Storage|wgpu::BufferUsage::CopyDst);
    auto uniform=buffer(device,sizeof(uniforms),wgpu::BufferUsage::Uniform|wgpu::BufferUsage::CopyDst);
    constexpr auto resultBytes=kCases*kFields*sizeof(uint32_t);
    auto output=buffer(device,resultBytes,wgpu::BufferUsage::Storage|wgpu::BufferUsage::CopySrc);
    auto readback=buffer(device,resultBytes,wgpu::BufferUsage::MapRead|wgpu::BufferUsage::CopyDst);
    queue.WriteBuffer(input,0,bytes.data(),bytes.size()); queue.WriteBuffer(uniform,0,uniforms.data(),sizeof(uniforms));
    const auto wanted=expected(bytes);
    for(bool packed : {false,true}) {
      try {
        const auto code=shader(packed);
        wgpu::ShaderSourceWGSL wgsl{}; wgsl.code=code.c_str();
        wgpu::ShaderModuleDescriptor moduleDesc{.nextInChain=&wgsl};
        auto module=device.CreateShaderModule(&moduleDesc);
        wgpu::ComputePipelineDescriptor pipelineDesc{};
        pipelineDesc.compute.module=module; pipelineDesc.compute.entryPoint="main";
        auto pipeline=device.CreateComputePipeline(&pipelineDesc); errors->check();
        std::array<wgpu::BindGroupEntry,3> entries{};
        for(unsigned n=0;n<3;++n) entries[n].binding=n;
        entries[0].buffer=input; entries[0].size=bytes.size();
        entries[1].buffer=output; entries[1].size=resultBytes;
        entries[2].buffer=uniform; entries[2].size=sizeof(uniforms);
        wgpu::BindGroupDescriptor bindDesc{.layout=pipeline.GetBindGroupLayout(0),.entryCount=entries.size(),.entries=entries.data()};
        auto bind=device.CreateBindGroup(&bindDesc);
        auto encoder=device.CreateCommandEncoder(); auto pass=encoder.BeginComputePass();
        pass.SetPipeline(pipeline); pass.SetBindGroup(0,bind); pass.DispatchWorkgroups(kCases/64); pass.End();
        encoder.CopyBufferToBuffer(output,0,readback,0,resultBytes);
        auto commands=encoder.Finish(); queue.Submit(1,&commands); errors->check();
        auto mapped=std::make_shared<bool>(false);
        wait(instance,readback.MapAsync(wgpu::MapMode::Read,0,resultBytes,wgpu::CallbackMode::WaitAnyOnly,
            [mapped](wgpu::MapAsyncStatus status,wgpu::StringView){*mapped=status==wgpu::MapAsyncStatus::Success;}));
        errors->check(); require(*mapped,"Readback failed");
        const auto* actual=static_cast<const uint32_t*>(readback.GetConstMappedRange(0,resultBytes));
        unsigned failures=0;
        for(unsigned n=0;n<wanted.size();++n) if(actual[n]!=wanted[n]) {
            if(failures++ < 8) report<<"Mismatch case="<<n/kFields<<" field="<<n%kFields<<" expected="<<wanted[n]<<" actual="<<actual[n]<<"\n";
        }
        readback.Unmap();
        report<<(failures ? "FAIL" : "PASS")<<" robustness="<<robustness<<" uniform="<<(packed?"vec4":"scalar")
              <<" checks="<<wanted.size()<<" mismatches="<<failures<<"\n";
      } catch (const std::exception& e) {
        report<<"ERROR robustness="<<robustness<<" uniform="<<(packed?"vec4":"scalar")<<": "<<e.what()<<"\n";
      }
    }
    for (bool packed : {false, true}) for(bool vertexAttribute : {false,true}) {
        try { drawProbe(instance, device, *errors, robustness, packed, vertexAttribute, report); }
        catch (const std::exception& e) { report<<"ERROR draw robustness="<<robustness<<" uniform="<<(packed?"vec4":"scalar")<<" vertex_attribute="<<vertexAttribute<<": "<<e.what()<<"\n"; }
    }
    queue={}; device.Destroy();
}
std::string diagnose() {
    std::ostringstream report;
    report<<"KartPad synthetic renderer probe 3\nHelper SHA256: "<<kHelperSha<<"\n";
    report<<"No game data read. Validation enabled. Compute and indexed-draw readback; not gameplay acceptance.\n";
    try {
        const auto feature=wgpu::InstanceFeatureName::TimedWaitAny;
        wgpu::InstanceDescriptor desc{.requiredFeatureCount=1,.requiredFeatures=&feature};
        auto instance=wgpu::CreateInstance(&desc); require(bool(instance),"Instance unavailable");
        wgpu::RequestAdapterOptions options{};
#ifdef __ANDROID__
        options.backendType=wgpu::BackendType::Vulkan;
#else
        options.backendType=wgpu::BackendType::Metal;
#endif
        for(bool robust : {false,true}) {
        auto createdAdapter = std::make_shared<wgpu::Adapter>();
        wait(instance,instance.RequestAdapter(&options,wgpu::CallbackMode::WaitAnyOnly,
            [createdAdapter](wgpu::RequestAdapterStatus status,wgpu::Adapter value,wgpu::StringView){
                if(status==wgpu::RequestAdapterStatus::Success) *createdAdapter=std::move(value);
            }));
        auto adapter=std::move(*createdAdapter);
        require(bool(adapter),"Requested backend unavailable; no fallback used");
        wgpu::AdapterInfo info{}; adapter.GetInfo(&info);
        // The maintained Dawn dependency fixes the old SwiftShader toggle
        // assertion. Keep software execution explicit: it cannot clear a
        // hardware-specific rendering or performance report.
        report<<"Software adapter: "<<(info.adapterType == wgpu::AdapterType::CPU ? "yes" : "no")<<"\n";
        report<<"Adapter: "<<string(info.device)<<"\nDriver: "<<string(info.description)<<"\n";
        wgpu::Limits limits{}; adapter.GetLimits(&limits);
        report<<"Uniform alignment: "<<limits.minUniformBufferOffsetAlignment<<" Storage alignment: "<<limits.minStorageBufferOffsetAlignment<<"\n";
            try { run(instance,adapter,robust,report); }
            catch(const std::exception& e) { report<<"ERROR robustness="<<robust<<": "<<e.what()<<"\n"; }
        }
    } catch(const std::exception& e) {report<<"ERROR: "<<e.what()<<"\n";}
    return report.str();
}
}
#if defined(__ANDROID__) && !defined(KARTPAD_PROBE_CLI)
extern "C" JNIEXPORT jstring JNICALL Java_dev_kartpad_rendererprobe_ProbeActivity_runProbe(JNIEnv* env,jobject) {
    const auto report=diagnose(); return env->NewStringUTF(report.c_str());
}
#else
int main() {
    const auto report=diagnose(); std::cout<<report;
    return report.find("FAIL")!=std::string::npos || report.find("ERROR")!=std::string::npos ? 1 : 0;
}
#endif
