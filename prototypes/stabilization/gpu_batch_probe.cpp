#include "batch_reservation.hpp"
#ifdef __ANDROID__
#include "../../vendor/runtimes/android/aurora-main/lib/gfx/staging_map.hpp"
#else
#include "../../vendor/runtimes/macos/aurora-main/lib/gfx/staging_map.hpp"
#endif
#include <webgpu/webgpu_cpp.h>
#include <algorithm>
#include <atomic>
#include <memory>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <thread>
using namespace kartpad::prototype;
using namespace std::chrono_literals;
static void require(bool ok,const char* message) {if(!ok) throw std::runtime_error(message);}
static constexpr unsigned Width=16, Draws=769;
static std::atomic_uint errors{0};
static std::array<unsigned char,4> color(unsigned draw,bool accumulate=false) {
  if(accumulate) return {static_cast<unsigned char>(draw%31+1),
    static_cast<unsigned char>((draw*3%31+1)*2),
    static_cast<unsigned char>(draw*7%31+1),static_cast<unsigned char>(draw%17+1)};
  return {static_cast<unsigned char>((draw*17+3)%251),static_cast<unsigned char>((draw*31+7)%251),
          static_cast<unsigned char>((draw*43+11)%251),255};
}
struct GPU {
  wgpu::Instance instance=wgpu::CreateInstance();
  wgpu::Device device{};
  wgpu::Queue queue{};
  wgpu::Limits limits{};
  GPU() {
    struct AdapterResult { bool done=false; wgpu::Adapter value; };
    auto adapterResult=std::make_shared<AdapterResult>();
    wgpu::RequestAdapterOptions options{};
#ifdef __ANDROID__
    options.backendType=wgpu::BackendType::Vulkan;
#else
    options.backendType=wgpu::BackendType::Metal;
#endif
    instance.RequestAdapter(&options,wgpu::CallbackMode::AllowProcessEvents,
      [adapterResult](wgpu::RequestAdapterStatus status,wgpu::Adapter a,wgpu::StringView) {
        if(status==wgpu::RequestAdapterStatus::Success) adapterResult->value=std::move(a);
        adapterResult->done=true;
      });wait(adapterResult->done);
    auto adapter=std::move(adapterResult->value);
    require(bool(adapter),"Requested hardware backend unavailable");
    wgpu::AdapterInfo info{};adapter.GetInfo(&info);
    std::cout<<"GPU: "<<std::string(info.device.data,info.device.length)<<"\n";
    wgpu::DeviceDescriptor descriptor{};
    descriptor.SetUncapturedErrorCallback([](const wgpu::Device&,wgpu::ErrorType,wgpu::StringView message) {
      ++errors;std::cerr<<"GPU validation: "<<std::string(message.data,message.length)<<"\n";
    });
    struct DeviceResult { bool done=false; wgpu::Device value; };
    auto deviceResult=std::make_shared<DeviceResult>();
    adapter.RequestDevice(&descriptor,wgpu::CallbackMode::AllowProcessEvents,
      [deviceResult](wgpu::RequestDeviceStatus status,wgpu::Device d,wgpu::StringView) {
        if(status==wgpu::RequestDeviceStatus::Success) deviceResult->value=std::move(d);
        deviceResult->done=true;
      });wait(deviceResult->done);device=std::move(deviceResult->value);
    require(bool(device),"Device unavailable");
    device.GetLimits(&limits);queue=device.GetQueue();
  }
  void wait(bool& done) {
    const auto deadline=std::chrono::steady_clock::now()+30s;
    while(!done) {
      instance.ProcessEvents();
      require(std::chrono::steady_clock::now()<deadline,"GPU callback timed out");
      std::this_thread::sleep_for(100us);
    }
    require(errors==0,"GPU validation failed");
  }
  void map(wgpu::Buffer buffer,wgpu::MapMode mode,uint64_t size) {
    using aurora::gfx::BufferMapState;
    auto result=std::make_shared<aurora::gfx::StagingMapState>();
    const auto generation=result->request();
    buffer.MapAsync(mode,0,size,wgpu::CallbackMode::AllowSpontaneous,
      [result,generation](wgpu::MapAsyncStatus status,wgpu::StringView){
        result->complete(generation,status==wgpu::MapAsyncStatus::Success
            ? BufferMapState::Mapped : BufferMapState::Unmapped);
      });
    const auto deadline=std::chrono::steady_clock::now()+30s;
    while(result->state()==BufferMapState::Mapping) {
      instance.ProcessEvents();
      result->wait_for_progress();
      require(std::chrono::steady_clock::now()<deadline,"GPU callback timed out");
    }
    require(result->state()==BufferMapState::Mapped,"Buffer map failed");
    require(errors==0,"GPU validation failed");
  }
  wgpu::Buffer buffer(uint64_t size,wgpu::BufferUsage usage,bool mapped=false) {
    wgpu::BufferDescriptor desc{};desc.size=size;desc.usage=usage;desc.mappedAtCreation=mapped;
    return device.CreateBuffer(&desc);
  }
};

static std::vector<unsigned char> render(GPU& gpu,unsigned drawsPerBatch,bool mixedLimits,bool accumulate=false) {
  const auto ua=gpu.limits.minUniformBufferOffsetAlignment;
  const auto sa=gpu.limits.minStorageBufferOffsetAlignment;
  Sizes capacity{32ull*drawsPerBatch, uint64_t(ua)*drawsPerBatch+3840,
                 12ull*drawsPerBatch, uint64_t(sa)*drawsPerBatch};
  if(mixedLimits) capacity[3]=uint64_t(sa)*std::max(1u,drawsPerBatch/2);
  Sizes base{};uint64_t total=0;
  for(unsigned i=0;i<4;++i){base[i]=total;total+=capacity[i];}
  BatchReservation reservation(capacity,{0,3840,0,0});
  std::array<wgpu::Buffer,4> destination{
    gpu.buffer(capacity[0],wgpu::BufferUsage::Vertex|wgpu::BufferUsage::CopyDst),
    gpu.buffer(capacity[1],wgpu::BufferUsage::Uniform|wgpu::BufferUsage::CopyDst),
    gpu.buffer(capacity[2],wgpu::BufferUsage::Index|wgpu::BufferUsage::CopyDst),
    gpu.buffer(capacity[3],wgpu::BufferUsage::Storage|wgpu::BufferUsage::CopyDst)};
  std::array<wgpu::Buffer,3> staging;
  for(auto& b:staging)b=gpu.buffer(total,wgpu::BufferUsage::MapWrite|wgpu::BufferUsage::CopySrc,true);
  unsigned slot=0,batches=0;
  std::array<bool,3> mapped{true,true,true};
  auto* memory=static_cast<unsigned char*>(staging[slot].GetMappedRange());
  wgpu::TextureDescriptor textureDesc{};textureDesc.size={Width,Width,1};
  textureDesc.format=wgpu::TextureFormat::RGBA8Unorm;
  textureDesc.usage=wgpu::TextureUsage::RenderAttachment|wgpu::TextureUsage::CopySrc;
  auto texture=gpu.device.CreateTexture(&textureDesc);auto view=texture.CreateView();

  wgpu::ShaderSourceWGSL wgsl{};
  wgsl.code=R"(
    struct U { color: vec4f }
    @group(0) @binding(0) var<uniform> u: U;
    @group(0) @binding(1) var<storage,read> multiplier: array<vec4f>;
    @vertex fn vs(@location(0) p: vec2f)->@builtin(position) vec4f {return vec4f(p,0,1);}
    @fragment fn fs()->@location(0) vec4f {return u.color*multiplier[0];}
  )";
  wgpu::ShaderModuleDescriptor shaderDesc{};shaderDesc.nextInChain=&wgsl;
  auto shader=gpu.device.CreateShaderModule(&shaderDesc);
  std::array<wgpu::BindGroupLayoutEntry,2> entries{};
  for(unsigned i=0;i<2;++i){entries[i].binding=i;entries[i].visibility=wgpu::ShaderStage::Fragment;
    entries[i].buffer.hasDynamicOffset=true;entries[i].buffer.minBindingSize=16;}
  entries[0].buffer.type=wgpu::BufferBindingType::Uniform;
  entries[1].buffer.type=wgpu::BufferBindingType::ReadOnlyStorage;
  wgpu::BindGroupLayoutDescriptor bglDesc{};bglDesc.entryCount=2;bglDesc.entries=entries.data();
  auto layout=gpu.device.CreateBindGroupLayout(&bglDesc);
  wgpu::PipelineLayoutDescriptor plDesc{};plDesc.bindGroupLayoutCount=1;plDesc.bindGroupLayouts=&layout;
  auto pipelineLayout=gpu.device.CreatePipelineLayout(&plDesc);
  std::array<wgpu::BindGroupEntry,2> bgEntries{};
  for(unsigned i=0;i<2;++i){bgEntries[i].binding=i;bgEntries[i].buffer=destination[i==0?1:3];bgEntries[i].size=16;}
  wgpu::BindGroupDescriptor bgDesc{};bgDesc.layout=layout;bgDesc.entryCount=2;bgDesc.entries=bgEntries.data();
  auto bindGroup=gpu.device.CreateBindGroup(&bgDesc);
  wgpu::VertexAttribute attr{};attr.format=wgpu::VertexFormat::Float32x2;attr.shaderLocation=0;
  wgpu::VertexBufferLayout vertex{};vertex.arrayStride=8;vertex.attributeCount=1;vertex.attributes=&attr;
  wgpu::ColorTargetState target{};target.format=textureDesc.format;
  // The overwrite workload checks the final draw per tile. Additive rendering
  // also makes every earlier draw observable, catching lost submitted prefixes.
  wgpu::BlendState blend{};
  blend.color.operation=blend.alpha.operation=wgpu::BlendOperation::Add;
  blend.color.srcFactor=blend.color.dstFactor=wgpu::BlendFactor::One;
  blend.alpha.srcFactor=blend.alpha.dstFactor=wgpu::BlendFactor::One;
  if(accumulate) target.blend=&blend;
  wgpu::FragmentState fragment{};fragment.module=shader;fragment.entryPoint="fs";
  fragment.targetCount=1;fragment.targets=&target;
  wgpu::RenderPipelineDescriptor pipeDesc{};pipeDesc.layout=pipelineLayout;
  pipeDesc.vertex.module=shader;pipeDesc.vertex.entryPoint="vs";
  pipeDesc.vertex.bufferCount=1;pipeDesc.vertex.buffers=&vertex;pipeDesc.fragment=&fragment;
  auto pipeline=gpu.device.CreateRenderPipeline(&pipeDesc);
  struct Draw {unsigned number;std::vector<Range> ranges;};
  std::vector<Draw> draws;
  auto flush=[&]() {
    require(!draws.empty(),"Empty flush");
    auto used=reservation.used();used[1]+=3840;
    std::memset(memory+base[1]+reservation.used()[1],0,3840);
    staging[slot].Unmap();mapped[slot]=false;memory=nullptr;
    auto encoder=gpu.device.CreateCommandEncoder();
    for(unsigned i=0;i<4;++i)encoder.CopyBufferToBuffer(staging[slot],base[i],destination[i],0,(used[i]+3)&~3ull);
    wgpu::RenderPassColorAttachment attachment{};attachment.view=view;
    attachment.loadOp=batches?wgpu::LoadOp::Load:wgpu::LoadOp::Clear;
    attachment.storeOp=wgpu::StoreOp::Store;attachment.clearValue={0,0,0,0};
    wgpu::RenderPassDescriptor passDesc{};passDesc.colorAttachmentCount=1;passDesc.colorAttachments=&attachment;
    auto pass=encoder.BeginRenderPass(&passDesc);pass.SetPipeline(pipeline);
    for(const auto& draw:draws) {
      auto tile=draw.number%(Width*Width);
      pass.SetScissorRect(tile%Width,tile/Width,1,1);
      const uint32_t offsets[]{uint32_t(draw.ranges[1].offset),uint32_t(draw.ranges[3].offset)};
      pass.SetBindGroup(0,bindGroup,2,offsets);
      pass.SetVertexBuffer(0,destination[0],draw.ranges[0].offset,32);
      pass.SetIndexBuffer(destination[2],wgpu::IndexFormat::Uint16,draw.ranges[2].offset,12);
      pass.DrawIndexed(6);
    }
    pass.End();auto command=encoder.Finish();gpu.queue.Submit(1,&command);
    ++batches;draws.clear();reservation.reset_after_submission();
    slot=(slot+1)%staging.size();
    if(!mapped[slot]){gpu.map(staging[slot],wgpu::MapMode::Write,total);mapped[slot]=true;}
    memory=static_cast<unsigned char*>(staging[slot].GetMappedRange());
  };
  const std::array requests{Request{Buffer::Vertex,32,0},Request{Buffer::Uniform,16,ua},
                            Request{Buffer::Index,12,0},Request{Buffer::Storage,16,sa}};
  constexpr float vertices[]{-1,-1,1,-1,1,1,-1,1};
  constexpr uint16_t indices[]{0,1,2,2,3,0};
  constexpr float factors[]{1,0.5,1,1};
  for(unsigned n=0;n<Draws;++n) {
    std::vector<Range> ranges;
    if(n%37==0) {
      const auto before=reservation.used();
      const std::array tooLarge{Request{Buffer::Uniform,capacity[1]+1,ua}};
      require(reservation.reserve(tooLarge,ranges)==Admission::Oversized,"Oversized draw must fail before commit");
      require(reservation.used()==before,"Rejected draw changed live buffer offsets");
    }
    auto status=reservation.reserve(requests,ranges);
    if(status==Admission::Flush){flush();status=reservation.reserve(requests,ranges);}
    require(status==Admission::Accepted,"Draw admission failed");
    const auto rgba=color(n,accumulate);float values[4];for(unsigned i=0;i<4;++i)values[i]=rgba[i]/255.f;
    const void* inputs[]{vertices,values,indices,factors};const size_t sizes[]{32,16,12,16};
    for(unsigned i=0;i<4;++i){auto* dst=memory+base[i]+ranges[i].offset;
      std::memset(dst,0,ranges[i].size);std::memcpy(dst,inputs[i],sizes[i]);}
    draws.push_back({n,std::move(ranges)});
  }
  if(!draws.empty())flush();
  for(unsigned i=0;i<3;++i)if(mapped[i])staging[i].Unmap();
  auto readback=gpu.buffer(Width*256,wgpu::BufferUsage::CopyDst|wgpu::BufferUsage::MapRead);
  auto encoder=gpu.device.CreateCommandEncoder();
  wgpu::TexelCopyTextureInfo src{};src.texture=texture;
  wgpu::TexelCopyBufferInfo dst{};dst.buffer=readback;dst.layout.bytesPerRow=256;dst.layout.rowsPerImage=Width;
  wgpu::Extent3D extent{Width,Width,1};encoder.CopyTextureToBuffer(&src,&dst,&extent);
  auto command=encoder.Finish();gpu.queue.Submit(1,&command);gpu.map(readback,wgpu::MapMode::Read,Width*256);
  const auto* bytes=static_cast<const unsigned char*>(readback.GetConstMappedRange());
  std::vector<unsigned char> pixels(Width*Width*4);
  for(unsigned y=0;y<Width;++y)std::memcpy(pixels.data()+y*Width*4,bytes+y*256,Width*4);
  readback.Unmap();
  for(unsigned tile=0;tile<Width*Width;++tile) {
    const unsigned last=tile+((Draws-1-tile)/(Width*Width))*(Width*Width);
    auto expected=color(last);expected[1]=static_cast<unsigned char>(std::lround(expected[1]*0.5));
    if(accumulate) {
      expected={};
      for(unsigned draw=tile;draw<Draws;draw+=Width*Width) {
        const auto contribution=color(draw,true);
        for(unsigned channel=0;channel<4;++channel)
          expected[channel]+=channel==1?contribution[channel]/2:contribution[channel];
      }
    }
    for(unsigned channel=0;channel<4;++channel)
      require(std::abs(int(pixels[tile*4+channel])-int(expected[channel]))<=1,"Rendered pixel disagrees with independent expected output");
  }
  require(errors==0,"GPU error");
  std::cout<<"PASS: "<<(accumulate?"accumulate, ":"overwrite, ")<<Draws<<" indexed draws, "<<batches<<" batches, 3 staging slots, "
           <<total*3<<" staging bytes, output matches expected pixels\n";
  return pixels;
}
int main() {
 try {
  GPU gpu;
  auto control=render(gpu,Draws,false);
  require(render(gpu,5,false)==control,"Split and unsplit pixels differ");
  require(render(gpu,5,true)==control,"Mixed-buffer pressure changes pixels");
  require(render(gpu,1,false)==control,"Single-draw batch pixels differ");
  auto accumulated=render(gpu,Draws,false,true);
  require(render(gpu,5,false,true)==accumulated,"Split accumulation differs");
  require(render(gpu,5,true,true)==accumulated,"Mixed-buffer accumulation differs");
  require(render(gpu,1,false,true)==accumulated,"Single-draw accumulation differs");
  std::cout<<"PASS: all split outputs byte-identical to control, zero GPU validation errors\n";
 } catch(const std::exception& e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}
}
