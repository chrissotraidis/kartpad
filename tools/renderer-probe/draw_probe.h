// SPDX-License-Identifier: GPL-3.0-only
// Synthetic graphics-stage companion. Included inside probe.cpp's anonymous namespace.
void drawProbe(wgpu::Instance instance, wgpu::Device device, Errors& errors,
               bool robustness, bool packed, bool vertexAttribute, std::ostringstream& report) {
    constexpr unsigned width=16, vertices=width*width*4, phases=4, rowBytes=256;
    constexpr unsigned attributeBlock=vertices*8, prefix=256;
    constexpr unsigned uniformBytes=80+20*48;
    wgpu::Limits limits{}; device.GetLimits(&limits);
    const unsigned uniformStride=((uniformBytes+limits.minUniformBufferOffsetAlignment-1)/limits.minUniformBufferOffsetAlignment)*limits.minUniformBufferOffsetAlignment;
    auto queue=device.GetQueue();
    auto vertex=buffer(device,prefix+vertices*8,wgpu::BufferUsage::Storage|wgpu::BufferUsage::Vertex|wgpu::BufferUsage::CopyDst);
    auto attributes=buffer(device,prefix+12*attributeBlock,wgpu::BufferUsage::Storage|wgpu::BufferUsage::CopyDst);
    auto uniform=buffer(device,2*uniformStride,wgpu::BufferUsage::Uniform|wgpu::BufferUsage::CopyDst);
    auto indices=buffer(device,width*width*6*2,wgpu::BufferUsage::Index|wgpu::BufferUsage::CopyDst);
    std::vector<uint8_t> vertexData(prefix+vertices*8), attributeData(prefix+12*attributeBlock);
    std::vector<uint16_t> indexData;
    std::array<uint32_t,uniformBytes/4> uniformData{};
    uniformData[0]=prefix;
    for(unsigned slot=0;slot<12;++slot) uniformData[8+slot]=prefix+slot*attributeBlock;
    for(unsigned m=0;m<20;++m) {
        // Match Aurora's vec4(position,1) * mat3x4 convention.
        uniformData[20+m*12]=std::bit_cast<uint32_t>(1.f);
        uniformData[20+m*12+3]=std::bit_cast<uint32_t>(float(m*32)/256.f);
        uniformData[20+m*12+5]=std::bit_cast<uint32_t>(1.f);
        uniformData[20+m*12+7]=std::bit_cast<uint32_t>(float(m*16)/256.f);
    }
    for(unsigned cell=0;cell<width*width;++cell) {
        const unsigned v=cell*4;
        for(unsigned n : {0u,1u,2u,2u,1u,3u}) indexData.push_back(uint16_t(v+n));
        for(unsigned corner=0;corner<4;++corner) {
            const unsigned index=v+corner, off=prefix+index*8;
            vertexData[off]=uint8_t(index>>8); vertexData[off+1]=uint8_t(index);
            vertexData[off+4]=uint8_t((cell%20)*3); // raw GX row index in an aligned slot
        }
    }
    queue.WriteBuffer(vertex,0,vertexData.data(),vertexData.size());
    queue.WriteBuffer(indices,0,indexData.data(),indexData.size()*2);
    wgpu::TextureDescriptor td{.usage=wgpu::TextureUsage::RenderAttachment|wgpu::TextureUsage::CopySrc,
        .size={width,width,1},.format=wgpu::TextureFormat::RGBA8Unorm};
    auto target=device.CreateTexture(&td);
    td.usage=wgpu::TextureUsage::TextureBinding|wgpu::TextureUsage::CopyDst;
    auto texture=device.CreateTexture(&td);
    std::string code=kHelpers;
    code+=R"WGSL(
struct Uniform {
 vtx_start: u32, current_pnmtx: u32,
 render_viewport_size: vec2f, logical_viewport_size: vec2f, pad: vec2u,
 array_start: )WGSL";
    code+=packed ? "array<vec4u,3>" : "array<u32,12>";
    code+=R"WGSL(, postex_mtx: array<mat3x4f,20>,
};
@group(0) @binding(0) var<storage,read> vbuf: array<u32>;
@group(0) @binding(1) var<storage,read> abuf: array<u32>;
@group(1) @binding(0) var<uniform> ubuf: Uniform;
@group(2) @binding(0) var tex: texture_2d<f32>;
struct VertexOutput {
 @builtin(position) pos: vec4f,
 @location(0) @interpolate(flat) color: vec4u,
 @location(1) @interpolate(flat) cell: u32,
};
@vertex fn vs_main(@builtin(vertex_index) vidx: u32)WGSL";
    if(vertexAttribute) code+=", @location(0) pnmtx_attribute: u32";
    code+=R"WGSL() -> VertexOutput {
 let base = ubuf.vtx_start + vidx * 8u;
 let idx = load_u16(&vbuf, base, false);
 let matrix = )WGSL";
    code+=vertexAttribute ? "(pnmtx_attribute & 255u) / 3u;" : "load_u8(&vbuf, base+4u) / 3u;";
    code+=R"WGSL(
 let cell = vidx/4u;
 let slot = cell%12u;
 let arrayOffset = )WGSL";
    code+=packed ? "ubuf.array_start[slot/4u][slot%4u];\n" : "ubuf.array_start[slot];\n";
    code+=R"WGSL(
 let off = arrayOffset + idx*8u;
 let pos = fetch_s16_2(&abuf, off, 8u, false);
 let transformed = vec4f(pos, 0.0, 1.0) * ubuf.postex_mtx[(matrix + ubuf.current_pnmtx)%20u];
 var out: VertexOutput;
 out.pos = vec4f(transformed, 1.0);
 out.color = vec4u(round(fetch_rgba8(&abuf, off+4u, false)*255.0));
 out.cell = cell;
 return out;
}
@fragment fn fs_main(in: VertexOutput) -> @location(0) vec4f {
 let pixel = vec2i(i32(in.cell%16u), i32(in.cell/16u));
 let sampled = vec4u(round(textureLoad(tex, pixel, 0)*255.0));
 return vec4f(in.color ^ sampled)/255.0;
}
)WGSL";
    wgpu::ShaderSourceWGSL wgsl{}; wgsl.code=code.c_str();
    wgpu::ShaderModuleDescriptor md{.nextInChain=&wgsl}; auto module=device.CreateShaderModule(&md);
    std::array<wgpu::BindGroupLayoutEntry,2> storageLayout{};
    for(unsigned i=0;i<2;++i) {
        storageLayout[i].binding=i; storageLayout[i].visibility=wgpu::ShaderStage::Vertex;
        storageLayout[i].buffer.type=wgpu::BufferBindingType::ReadOnlyStorage;
    }
    wgpu::BindGroupLayoutDescriptor ld{.entryCount=2,.entries=storageLayout.data()};
    auto storageBL=device.CreateBindGroupLayout(&ld);
    wgpu::BindGroupLayoutEntry ul{}; ul.visibility=wgpu::ShaderStage::Vertex;
    ul.buffer.type=wgpu::BufferBindingType::Uniform; ul.buffer.hasDynamicOffset=true; ul.buffer.minBindingSize=uniformBytes;
    ld.entryCount=1; ld.entries=&ul; auto uniformBL=device.CreateBindGroupLayout(&ld);
    wgpu::BindGroupLayoutEntry tl{}; tl.visibility=wgpu::ShaderStage::Fragment;
    tl.texture.sampleType=wgpu::TextureSampleType::Float; tl.texture.viewDimension=wgpu::TextureViewDimension::e2D;
    ld.entries=&tl; auto textureBL=device.CreateBindGroupLayout(&ld);
    std::array<wgpu::BindGroupLayout,3> layouts{storageBL,uniformBL,textureBL};
    wgpu::PipelineLayoutDescriptor pld{.bindGroupLayoutCount=3,.bindGroupLayouts=layouts.data()};
    wgpu::ColorTargetState colorTarget{.format=wgpu::TextureFormat::RGBA8Unorm};
    wgpu::FragmentState fragment{.module=module,.entryPoint="fs_main",.targetCount=1,.targets=&colorTarget};
    wgpu::RenderPipelineDescriptor pd{}; pd.layout=device.CreatePipelineLayout(&pld);
    pd.vertex.module=module; pd.vertex.entryPoint="vs_main"; pd.fragment=&fragment;
    wgpu::VertexAttribute boneIndex{};
    boneIndex.format=wgpu::VertexFormat::Uint32; boneIndex.offset=4; boneIndex.shaderLocation=0;
    wgpu::VertexBufferLayout vertexLayout{};
    vertexLayout.arrayStride=8; vertexLayout.stepMode=wgpu::VertexStepMode::Vertex;
    vertexLayout.attributeCount=1; vertexLayout.attributes=&boneIndex;
    if(vertexAttribute) {pd.vertex.bufferCount=1;pd.vertex.buffers=&vertexLayout;}
    pd.primitive.topology=wgpu::PrimitiveTopology::TriangleList;
    auto pipeline=device.CreateRenderPipeline(&pd); errors.check();
    std::array<wgpu::BindGroupEntry,2> storageEntries{};
    storageEntries[0].buffer=vertex; storageEntries[0].size=vertexData.size();
    storageEntries[1].binding=1; storageEntries[1].buffer=attributes; storageEntries[1].size=attributeData.size();
    wgpu::BindGroupDescriptor bd{.layout=storageBL,.entryCount=2,.entries=storageEntries.data()};
    auto storageBind=device.CreateBindGroup(&bd);
    wgpu::BindGroupEntry ue{}; ue.buffer=uniform; ue.size=uniformBytes;
    bd.layout=uniformBL; bd.entryCount=1; bd.entries=&ue; auto uniformBind=device.CreateBindGroup(&bd);
    wgpu::BindGroupEntry te{}; te.textureView=texture.CreateView();
    bd.layout=textureBL; bd.entries=&te; auto textureBind=device.CreateBindGroup(&bd);
    std::array<wgpu::Buffer,phases> readbacks;
    std::array<std::vector<uint8_t>,phases> wanted;
    for(unsigned phase=0;phase<phases;++phase) {
        std::vector<uint8_t> textureData(width*width*4);
        wanted[phase].resize(width*width*4);
        for(unsigned cell=0;cell<width*width;++cell) {
            const std::array<uint8_t,4> color{uint8_t(cell*17+phase*29),uint8_t(cell*37+phase*7),uint8_t(cell*73+phase*3),255};
            for(unsigned channel=0;channel<4;++channel) {
                const uint8_t texel=channel==3 ? 0 : uint8_t(cell*(channel+3)+phase*11);
                textureData[cell*4+channel]=texel; wanted[phase][cell*4+channel]=color[channel]^texel;
            }
            for(unsigned corner=0;corner<4;++corner) {
                const int x=int(cell%16)*32-256+int(corner%2)*32-int((cell+phase)%20)*32;
                const int y=256-int(cell/16)*32-int(corner/2)*32-int((cell+phase)%20)*16;
                const unsigned off=prefix+(cell%12)*attributeBlock+(cell*4+corner)*8;
                attributeData[off]=uint8_t(x>>8); attributeData[off+1]=uint8_t(x);
                attributeData[off+2]=uint8_t(y>>8); attributeData[off+3]=uint8_t(y);
                std::memcpy(attributeData.data()+off+4,color.data(),4);
            }
        }
        uniformData[1]=phase; // Different contents make a wrong dynamic offset observable.
        const uint32_t dynamicOffset=(phase%2)*uniformStride;
        queue.WriteBuffer(attributes,0,attributeData.data(),attributeData.size());
        queue.WriteBuffer(uniform,dynamicOffset,uniformData.data(),sizeof(uniformData));
        wgpu::TexelCopyTextureInfo textureDest{.texture=texture};
        wgpu::TexelCopyBufferLayout textureLayout{.bytesPerRow=width*4,.rowsPerImage=width};
        wgpu::Extent3D extent{width,width,1}; queue.WriteTexture(&textureDest,textureData.data(),textureData.size(),&textureLayout,&extent);
        auto encoder=device.CreateCommandEncoder();
        wgpu::RenderPassColorAttachment ca{}; ca.view=target.CreateView(); ca.loadOp=wgpu::LoadOp::Clear; ca.storeOp=wgpu::StoreOp::Store;
        wgpu::RenderPassDescriptor rp{.colorAttachmentCount=1,.colorAttachments=&ca}; auto pass=encoder.BeginRenderPass(&rp);
        pass.SetPipeline(pipeline); pass.SetBindGroup(0,storageBind); pass.SetBindGroup(1,uniformBind,1,&dynamicOffset); pass.SetBindGroup(2,textureBind);
        if(vertexAttribute) pass.SetVertexBuffer(0,vertex,prefix,vertices*8);
        pass.SetIndexBuffer(indices,wgpu::IndexFormat::Uint16); pass.DrawIndexed(width*width*6); pass.End();
        readbacks[phase]=buffer(device,rowBytes*width,wgpu::BufferUsage::CopyDst|wgpu::BufferUsage::MapRead);
        wgpu::TexelCopyTextureInfo source{.texture=target};
        wgpu::TexelCopyBufferInfo destination{.layout={.bytesPerRow=rowBytes,.rowsPerImage=width},.buffer=readbacks[phase]};
        encoder.CopyTextureToBuffer(&source,&destination,&extent);
        auto commands=encoder.Finish(); queue.Submit(1,&commands); errors.check();
    }
    unsigned failures=0;
    for(unsigned phase=0;phase<phases;++phase) {
        auto mapped=std::make_shared<bool>(false);
        wait(instance,readbacks[phase].MapAsync(wgpu::MapMode::Read,0,rowBytes*width,wgpu::CallbackMode::WaitAnyOnly,
            [mapped](wgpu::MapAsyncStatus status,wgpu::StringView){*mapped=status==wgpu::MapAsyncStatus::Success;}));
        errors.check(); require(*mapped,"Draw readback failed");
        const auto* actual=static_cast<const uint8_t*>(readbacks[phase].GetConstMappedRange());
        for(unsigned y=0;y<width;++y) for(unsigned x=0;x<width*4;++x) {
            const auto expected=wanted[phase][y*width*4+x], got=actual[y*rowBytes+x];
            if(expected!=got && failures++<8) report<<"Draw mismatch phase="<<phase<<" pixel="<<y*width+x/4<<" channel="<<x%4<<" expected="<<unsigned(expected)<<" actual="<<unsigned(got)<<"\n";
        }
        readbacks[phase].Unmap();
    }
    report<<(failures?"FAIL":"PASS")<<" draw robustness="<<robustness<<" uniform="<<(packed?"vec4":"scalar")
          <<" vertex_attribute="<<vertexAttribute
          <<" frames="<<phases<<" checks="<<phases*width*width*4<<" mismatches="<<failures<<"\n";
}
