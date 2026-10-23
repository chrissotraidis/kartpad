// Synthetic representative layouts, no game data. A/B checksum covers all output bytes.
void benchmark() {
  for (bool character : {false, true}) {
    std::array<AttrConfig, MaxVtxAttr> src{};
    u8 offset=0;
    if(character) src[GX_VA_PNMTXIDX]=attr(GX_DIRECT,1,GX_U8,offset++);
    src[GX_VA_POS]=attr(GX_INDEX8,3,GX_F32,offset++,12);
    src[GX_VA_NRM]=attr(GX_INDEX8,3,GX_S16,offset++,6,14);
    src[GX_VA_CLR0]=attr(GX_INDEX8,1,GX_RGBA8,offset++,4);
    src[GX_VA_TEX0]=attr(GX_INDEX8,2,GX_S16,offset++,4,14);
    auto dst=src;
    const auto stride=kartpad_repack::repacked_layout(dst);
    std::array<AttrArray,MaxVtxAttr> arrays{};
    std::vector<u8> positions(256*12),normals(256*6),colors(256*4),uvs(256*4);
    for (unsigned i=0;i<256;i++) {
      for(unsigned j=0;j<3;j++) put_be_float(positions.data()+i*12+j*4,float(i*3+j)/8.f);
      for(unsigned j=0;j<6;j++) normals[i*6+j]=u8(i+j);
      for(unsigned j=0;j<4;j++) {colors[i*4+j]=u8(i+j);uvs[i*4+j]=u8(i+j);}
    }
    arrays[GX_VA_POS]=array(positions.data(),positions.size(),12);
    arrays[GX_VA_NRM]=array(normals.data(),normals.size(),6);
    arrays[GX_VA_CLR0]=array(colors.data(),colors.size(),4);
    arrays[GX_VA_TEX0]=array(uvs.data(),uvs.size(),4);
    for(unsigned count : {3u,32u,256u,2048u}) {
      std::vector<u8> vertices(count*offset),out;
      for(unsigned i=0;i<count;i++) for(unsigned j=0;j<offset;j++)
        vertices[i*offset+j]=character&&j==0 ? u8((i%20)*3) : u8(i);
      auto run=[&]{kartpad_repack::repack_with_layout(src,offset,dst,stride,vertices.data(),count,arrays,out);};
      run();
      uint64_t hash=14695981039346656037ull;
      for(auto byte:out) {hash^=byte;hash*=1099511628211ull;}
      std::array<double,7> timings{};
      const unsigned iterations=1000000/count;
      for(auto& ns:timings) {
        const auto begin=std::chrono::steady_clock::now();
        for(unsigned i=0;i<iterations;i++) run();
        ns=std::chrono::duration<double,std::nano>(std::chrono::steady_clock::now()-begin).count()/iterations;
      }
      std::sort(timings.begin(),timings.end());
      std::cout<<(character?"character":"track")<<" vertices="<<count<<" median_ns="<<timings[3]<<" hash="<<std::hex<<hash<<std::dec<<"\n";
    }
  }
}
