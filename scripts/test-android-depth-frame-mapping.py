#!/usr/bin/env python3
"""Exercise actual depth mapping math across a sealed/live mode change.

Run against a prepared runtime. The unlatched baseline must fail. GPU readback
and the full frame-resource barrier fixture are separate acceptance gates.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
source = (root / 'aurora-main/lib/gfx/depth_peek.cpp').read_text()
header = (root / 'aurora-main/lib/gfx/depth_peek.hpp').read_text()
def section(text, start, end):
    return text[text.index(start):text.index(end, text.index(start))]
params = section(source, 'struct Params {', 'static_assert(sizeof(Params)')
math = section(source, 'Params make_params(', '\nbool ensure_slot(')
fixed = 'struct FrameMapping {' in header
mapping = (section(header, 'struct FrameMapping {', 'FrameMapping capture_frame_mapping()')
           if fixed else 'struct FrameMapping { Vec2<uint32_t> logicalSize; AuroraViewportPolicy viewportPolicy; };\n')
capture = (section(source, 'FrameMapping capture_frame_mapping()', '\nvoid encode_frame_snapshot(')
           if fixed else 'FrameMapping capture_frame_mapping() { return {vi::configured_fb_size(), gx::g_gxState.viewportPolicy}; }\n')
invoke = 'make_params(size, mapping)' if fixed else 'make_params(size, mapping.logicalSize)'
cpp = r'''
#include <algorithm>
#include <cassert>
#include <cmath>
#include <cstdint>
template<class T> struct Vec2 { T x,y; };
enum AuroraViewportPolicy { AURORA_VIEWPORT_NATIVE, AURORA_VIEWPORT_FIT, AURORA_VIEWPORT_STRETCH };
namespace wgpu { struct Extent3D {uint32_t width,height,depthOrArrayLayers;}; }
namespace vi { Vec2<uint32_t> mode; auto configured_fb_size() {return mode;} }
namespace gx {struct {AuroraViewportPolicy viewportPolicy;} g_gxState;}
''' + mapping + params + math + capture + '\nParams encode(wgpu::Extent3D size, FrameMapping mapping) { return ' + invoke + '; }\n' + r'''
void near(float a,float b) { assert(std::abs(a-b)<0.0001f); }
int main() {
  for (auto policy : {AURORA_VIEWPORT_NATIVE,AURORA_VIEWPORT_FIT,AURORA_VIEWPORT_STRETCH}) {
    vi::mode={640,480}; gx::g_gxState.viewportPolicy=policy;
    const auto sealed=capture_frame_mapping();
    const auto serial=encode({1280,1080,1},sealed);
    // Producer B changes both dimensions and mapping while A's encoder is delayed.
    vi::mode={720,576}; gx::g_gxState.viewportPolicy=policy==AURORA_VIEWPORT_STRETCH ? AURORA_VIEWPORT_FIT : AURORA_VIEWPORT_STRETCH;
    const auto delayed=encode({1280,1080,1},sealed);
    assert(delayed.dstWidth==640 && delayed.dstHeight==480);
    near(delayed.scaleX,serial.scaleX); near(delayed.scaleY,serial.scaleY);
    near(delayed.offsetX,serial.offsetX); near(delayed.offsetY,serial.offsetY);
    if(policy==AURORA_VIEWPORT_FIT) {near(delayed.scaleX,2);near(delayed.scaleY,2);near(delayed.offsetY,60);}
    const auto next=encode({1280,1080,1},capture_frame_mapping());
    assert(next.dstWidth==720 && next.dstHeight==576);
  }
}
'''
with tempfile.TemporaryDirectory() as directory:
    src=Path(directory)/'mapping.cpp'; exe=Path(directory)/'mapping'
    src.write_text(cpp)
    subprocess.run(['clang++','-std=c++20','-fsanitize=address,undefined',str(src),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,timeout=10)
print('PASS: sealed depth mapping survives next-frame mode/policy changes under ASan/UBSan')
