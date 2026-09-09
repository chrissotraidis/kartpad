#!/usr/bin/env python3
"""Check prepared sealed debug-frame ownership under ASan/UBSan; no GPU claim."""
from pathlib import Path
import sys
import subprocess,tempfile
s=(Path(sys.argv[1]) / 'aurora-main/lib/gfx/common.cpp').read_text()
def block(start,end):return s[s.index(start):s.index(end,s.index(start))]
debug=block('struct DebugFrameData {','constexpr uint64_t StagingBufferSize')
seal=block('void seal_frame(SealedFrame& out)','\nvoid render(SealedFrame& frame')
clear=block('#if defined(AURORA_GFX_DEBUG_GROUPS)\n  if (finalize && !debugFrame.groups.empty())','\nvoid seal_frame(')
# Exact render_impl tail supplies frame-owned finalization and warnings.
marker=block('    case CommandType::DebugMarker: {','\n    } break;\n    }\n  }')
expr=marker[marker.index('      pass.InsertDebugMarker'):marker.index('\n#endif')]
pre='''#include <vector>\n#include <string>\n#include <ranges>\n#include <cassert>\n#include <cstdint>\n#include <utility>\n#define AURORA_GFX_DEBUG_GROUPS\n#define ZoneScoped\nstruct {template<class...T> void warn(T...) {}} Log;\n'''
code=pre+debug+'''namespace depth_peek {int capture_frame_mapping(){return 0;}} struct RenderPass{};struct SealedFrameData {int depthMapping=0;DebugFrameData debug;std::vector<RenderPass> passes;};struct SealedFrame{SealedFrameData d;auto& data(){return d;}};std::vector<int> g_retiredBindGroups;std::vector<RenderPass> g_renderPasses;uint32_t g_currentRenderPass=0;void recycle_render_passes(auto& p){p.clear();}\n'''+seal+'''\nnamespace wgpu {using StringView=std::string;} struct Pass{std::vector<std::string> values;void InsertDebugMarker(const std::string& x){values.push_back(x);}};\nvoid encode(Pass& pass,DebugFrameData& debugFrame,bool finalize){struct {struct {size_t debugMarkerIndex=0;} data;}cmd;\n'''+expr+'\n'+clear+'''
int main(){SealedFrame a,b; Pass output;g_debugFrame.markers={"A"};g_debugFrame.groups={"unclosedA"};seal_frame(a);g_debugFrame.markers={"B"};g_debugFrame.groups={"unclosedB"};encode(output,a.data().debug,false);encode(output,a.data().debug,true);assert((output.values==std::vector<std::string>{"A","A"}));assert((g_debugFrame.markers==std::vector<std::string>{"B"}));assert((g_debugFrame.groups==std::vector<std::string>{"unclosedB"}));seal_frame(b);encode(output,b.data().debug,true);assert((output.values==std::vector<std::string>{"A","A","B"}));assert(b.data().debug.markers.empty());}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'t.cpp';p.write_text(code);subprocess.run(['clang++','-std=c++20','-fsanitize=address,undefined',str(p),'-o',d+'/t'],check=True);subprocess.run([d+'/t'],check=True)
print('PASS: actual seal/marker/finalize bodies preserve A replay and next-frame B under ASan/UBSan')
