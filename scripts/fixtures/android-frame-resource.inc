// Test-only instrumentation, injected explicitly by prepare-android-resource-fixture.py.
// Never included by the normal Android preparation or public APK build.
#if !defined(__ANDROID__) || defined(NDEBUG)
#error Resource fixture requires a local Android Debug build
#endif
#include "gfx/pipeline_cache.hpp"
#include <sys/system_properties.h>
#include <dolphin/gx.h>
#include <dolphin/gx/GXAurora.h>

extern "C" size_t KartPadAndroidFixtureStagingSlot();

namespace kartpad_resource_fixture {
std::mutex mutex;
std::condition_variable cv;
bool armed = false, entered = false, released = false;

void fail(const char* message) {
  std::fprintf(stderr, "RESOURCE_FIXTURE FAIL %s\n", message);
  std::fflush(stderr);
  std::abort();
}

void before_encode() {
  std::unique_lock lock(mutex);
  if (!armed) return;
  entered = true;
  cv.notify_all();
  if (!cv.wait_for(lock, std::chrono::seconds(15), [] { return released; }))
    fail("producer did not release encoder within 15 seconds");
  armed = false;
}

void arm() {
  std::lock_guard lock(mutex);
  armed = true; entered = false; released = false;
}

void wait_entered() {
  std::unique_lock lock(mutex);
  if (!cv.wait_for(lock, std::chrono::seconds(15), [] { return entered; }))
    fail("encoder did not reach the forced overlap barrier");
}

void release() {
  std::lock_guard lock(mutex);
  if (!entered || released) fail("invalid encoder barrier sequence");
  std::fprintf(stderr, "RESOURCE_FIXTURE B-recorded-before-A-encode\n");
  released = true;
  cv.notify_all();
}

alignas(32) std::array<unsigned char, 64> texture;
alignas(32) std::array<unsigned char, 64 * 64 * 4> copied;

void draw(bool next) {
  u32 width, height;
  AuroraGetRenderSize(&width, &height);
  const float identity[3][4] = {{1,0,0,0}, {0,1,0,0}, {0,0,1,0}};
  const float projection[4][4] = {{2.f/width,0,0,-1}, {0,2.f/height,0,-1},
                                 {0,0,-1,0}, {0,0,0,1}};
  GXSetCopyClear({0,0,0,255}, GX_MAX_Z24);
  GXSetCopyFilter(GX_FALSE,nullptr,GX_FALSE,nullptr);
  GXSetViewport(0,0,width,height,0,1);
  GXSetScissor(0,0,width,height);
  GXSetProjection(projection, GX_ORTHOGRAPHIC);
  GXLoadPosMtxImm(identity, GX_PNMTX0);
  GXSetCurrentMtx(GX_PNMTX0);
  GXSetCullMode(GX_CULL_NONE);
  GXSetZMode(GX_FALSE,GX_ALWAYS,GX_FALSE);
  GXSetBlendMode(GX_BM_NONE,GX_BL_ONE,GX_BL_ZERO,GX_LO_COPY);
  GXSetColorUpdate(GX_TRUE); GXSetAlphaUpdate(GX_TRUE);
  GXSetNumChans(0); GXSetNumTevStages(1);
  GXSetTevColorOp(GX_TEVSTAGE0,GX_TEV_ADD,GX_TB_ZERO,GX_CS_SCALE_1,GX_TRUE,GX_TEVPREV);
  GXSetTevAlphaOp(GX_TEVSTAGE0,GX_TEV_ADD,GX_TB_ZERO,GX_CS_SCALE_1,GX_TRUE,GX_TEVPREV);
  GXSetTevKColor(GX_KCOLOR0,next ? GXColor{0,0,255,255} : GXColor{255,0,0,255});
  GXSetTevKColorSel(GX_TEVSTAGE0,GX_TEV_KCSEL_K0);
  GXSetTevKAlphaSel(GX_TEVSTAGE0,GX_TEV_KASEL_K0_A);
  GXSetTevAlphaIn(GX_TEVSTAGE0,GX_CA_ZERO,GX_CA_ZERO,GX_CA_ZERO,GX_CA_KONST);

  // Reuse the identical guest texture address with opposing RGBA8 tiled pixels.
  for (unsigned i=0; i<16; ++i) {
    texture[2*i]=255; texture[2*i+1]=next ? 255 : 0;
    texture[32+2*i]=255; texture[33+2*i]=0;
  }
  GXInvalidateTexAll();
  GXTexObj object{};
  GXInitTexObj(&object,texture.data(),4,4,GX_TF_RGBA8,GX_CLAMP,GX_CLAMP,GX_FALSE);
  GXInitTexObjLOD(&object,GX_NEAR,GX_NEAR,0,0,0,GX_FALSE,GX_FALSE,GX_ANISO_1);
  GXLoadTexObj(&object,GX_TEXMAP0);
  for (unsigned half=0; half<2; ++half) {
    const auto matrixSlot=half ? GX_PNMTX9 : GX_PNMTX1;
    const float palette[3][4]={{.5f,0,0,float(next ? 1-half : half)*width*.5f},
                               {0,1,0,0},{0,0,1,0}};
    GXLoadPosMtxImm(palette,matrixSlot);
    GXClearVtxDesc(); GXSetVtxDesc(GX_VA_PNMTXIDX,GX_DIRECT);
    GXSetVtxDesc(GX_VA_POS,GX_DIRECT);
    GXSetVtxAttrFmt(GX_VTXFMT0,GX_VA_POS,GX_POS_XYZ,GX_F32,0);
    GXSetNumTexGens(half ? 1 : 0);
    if (half) {
      GXSetVtxDesc(GX_VA_TEX0,GX_DIRECT);
      GXSetVtxAttrFmt(GX_VTXFMT0,GX_VA_TEX0,GX_TEX_ST,GX_F32,0);
      GXSetTexCoordGen(GX_TEXCOORD0,GX_TG_MTX2x4,GX_TG_TEX0,GX_IDENTITY);
    }
    GXSetTevOrder(GX_TEVSTAGE0,half ? GX_TEXCOORD0 : GX_TEXCOORD_NULL,
                  half ? GX_TEXMAP0 : GX_TEXMAP_NULL,GX_COLOR_NULL);
    GXSetTevColorIn(GX_TEVSTAGE0,GX_CC_ZERO,GX_CC_ZERO,GX_CC_ZERO,
                    half ? GX_CC_TEXC : GX_CC_KONST);
    const float left=0, right=float(width);
    const float vertices[4][4]={{left,0,0,0},{right,0,1,0},
                              {right,float(height),1,1},{left,float(height),0,1}};
    GXBegin(GX_QUADS,GX_VTXFMT0,4);
    for (const auto& v : vertices) {
      GXMatrixIndex1u8(GX_VA_PNMTXIDX,matrixSlot);
      GXPosition3f32(v[0],v[1],0);
      if (half) GXTexCoord2f32(v[2],v[3]);
    }
    GXEnd();
  }
  GXSetTexCopySrcRender(0,0,width,height);
  GXSetTexCopyDst(64,64,GX_TF_RGBA8,GX_FALSE);
  // Also forces the actual GX FIFO to drain while A remains paused.
  GXCopyTex(copied.data(),GX_FALSE);
  // Sample this frame's EFB copy back into the captured image. A's copy must
  // remain correct while B schedules another copy at the same guest address.
  GXInitTexObj(&object,copied.data(),64,64,GX_TF_RGBA8,GX_CLAMP,GX_CLAMP,GX_FALSE);
  GXInitTexObjLOD(&object,GX_NEAR,GX_NEAR,0,0,0,GX_FALSE,GX_FALSE,GX_ANISO_1);
  GXLoadTexObj(&object,GX_TEXMAP0);
  GXSetVtxDesc(GX_VA_PNMTXIDX,GX_NONE);
  GXSetCurrentMtx(GX_PNMTX0);
  const float sampled[4][4]={{0,0,1,0},{float(width),0,0,0},
                           {float(width),float(height),0,1},{0,float(height),1,1}};
  GXBegin(GX_QUADS,GX_VTXFMT0,4);
  for (const auto& v : sampled) {
    GXPosition3f32(v[0],v[1],0);
    GXTexCoord2f32(v[2],v[3]);
  }
  GXEnd();
}
} // namespace kartpad_resource_fixture

extern "C" int KartPadAndroidResourceFixture() {
  char value[PROP_VALUE_MAX]{};
  if (__system_property_get("debug.kartpad.resource_fixture",value)!=1 ||
      (value[0]!='1' && value[0]!='2')) return -1;
  const bool overlap=value[0]=='2';
  if (KartPadAndroidNativeFrameOverlapExperiment()!=overlap)
    kartpad_resource_fixture::fail("fixture and native-overlap switches disagree");
  using namespace kartpad_resource_fixture;
  const std::string prefix=std::string("/data/user/0/dev.kartpad.android/files/resource-")+
                           (overlap ? "overlap" : "serial");
  aurora::gfx::set_skip_unready_pipelines(false);
  AuroraSetViewportPolicy(AURORA_VIEWPORT_NATIVE);
  aurora_set_pause_on_focus_lost(false);
  if (!aurora_begin_frame()) fail("initial begin failed");
  alignas(32) static std::array<unsigned char, 256 * 1024> fifo;
  GXInit(fifo.data(),fifo.size());
  for (unsigned pair=0; pair<6; ++pair) {
    // Previous worker is DONE before mutating capture-path storage.
    const auto path=prefix+"-"+std::to_string(pair)+"-A.bmp";
    aurora_request_frame_capture(aurora::gfx::current_frame()+1,path.c_str());
    draw(false);
    const auto aSlot=KartPadAndroidFixtureStagingSlot();
    if (overlap) arm();
    aurora_end_frame();
    if (!aurora_begin_frame()) fail("B begin failed");
    if (overlap) wait_entered();
    else aurora_wait_for_frame_worker();
    draw(true);
    std::fprintf(stderr,"RESOURCE_FIXTURE pair=%u A-slot=%zu B-slot=%zu\n",
                 pair,aSlot,KartPadAndroidFixtureStagingSlot());
    if (overlap) release();
    aurora_wait_for_frame_worker();
    if (!aurora_flush_efb_copy_to_ram(copied.data())) fail("B EFB readback failed");
    const auto dataPath=prefix+"-"+std::to_string(pair)+"-B.rgba8";
    std::ofstream output(dataPath,std::ios::binary);
    output.write(reinterpret_cast<const char*>(copied.data()),copied.size());
    if (!output) fail("could not write B readback");
    aurora_end_frame();
    if (!aurora_begin_frame()) fail("next A begin failed");
    aurora_wait_for_frame_worker();
    // A seal + demanded B batch + B seal rotates three slots. Add one empty
    // cycle so the next pair holds a different A slot; cover every slot twice.
    aurora_end_frame();
    if (!aurora_begin_frame()) fail("padding begin failed");
    aurora_wait_for_frame_worker();
    std::fprintf(stderr,"RESOURCE_FIXTURE pair=%u mode=%s complete\n",pair,
                 overlap ? "overlap" : "serial");
  }
  std::fprintf(stderr,"RESOURCE_FIXTURE PASS mode=%s pairs=6\n",overlap ? "overlap" : "serial");
  std::fflush(stderr);
  return 0;
}
