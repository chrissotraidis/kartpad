#!/usr/bin/env python3
"""TSAN source ownership before SEALED. O0 prevents fixture optimization from
erasing the redundant baseline store. No native-code race or GPU claim.
"""
from pathlib import Path
import subprocess,sys,tempfile
root=Path(sys.argv[1])
s=(root/'aurora-main/lib/dolphin/gx/GXAurora.cpp').read_text()
setter=s[s.index('void AuroraSetViewportPolicy('):s.index('\nvoid AuroraGetRenderSize(')]
s=(root/'aurora-main/lib/gfx/depth_peek.cpp').read_text()
capture=s[s.index('FrameMapping capture_frame_mapping()'):s.index('\nvoid encode_frame_snapshot(')]
cpp=r'''
#include <atomic>
#include <cassert>
#include <cstdint>
#include <thread>
template<class T> struct Vec2 {T x,y;};
enum AuroraViewportPolicy { AURORA_VIEWPORT_NATIVE,AURORA_VIEWPORT_FIT,AURORA_VIEWPORT_STRETCH };
namespace aurora {
namespace gx {struct {AuroraViewportPolicy viewportPolicy=AURORA_VIEWPORT_FIT; int logicalViewport,logicalScissor;} g_gxState;
void set_logical_viewport(int){} void set_logical_scissor(int){}
namespace fifo {int drains=0;void drain(){++drains;}}}
namespace window {void set_frame_buffer_aspect_fit(bool){} void set_present_surface_fill(bool){} void* get_sdl_window(){return nullptr;}}
namespace vi {Vec2<uint32_t> configured_fb_size(){return {640,480};}}
}
using namespace aurora;
using gx::g_gxState;
struct FrameMapping {Vec2<uint32_t> logicalSize; AuroraViewportPolicy viewportPolicy;};
'''+setter+capture+r'''
int main(){
 AuroraSetViewportPolicy(AURORA_VIEWPORT_STRETCH); assert(gx::fifo::drains==1);
 AuroraSetViewportPolicy(AURORA_VIEWPORT_FIT); assert(gx::fifo::drains==2);
 std::atomic<bool> start=false;
 std::thread producer([&]{while(!start.load()){} for(int i=0;i<100000;++i)AuroraSetViewportPolicy(AURORA_VIEWPORT_FIT);});
 std::thread encoder([&]{while(!start.load()){} for(int i=0;i<100000;++i)assert(capture_frame_mapping().viewportPolicy==AURORA_VIEWPORT_FIT);});
 start=true;producer.join();encoder.join();assert(gx::fifo::drains==2);
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'policy.cpp';p.write_text(cpp);exe=Path(d)/'policy'
 subprocess.run(['clang++','-std=c++20','-O0','-g','-fsanitize=thread','-pthread',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True,timeout=20)
print('PASS: unchanged viewport setter and pre-SEALED capture under ThreadSanitizer')
