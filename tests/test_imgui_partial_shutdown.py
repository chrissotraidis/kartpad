"""Failed startup and repeated cleanup must not call an uninitialized backend."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def shutdown(text):
    start = text.index('void shutdown() noexcept {')
    return text[start:text.index('\nvoid process_event(', start)]


HARNESS = r'''
#include <cassert>
#include <vector>
#define ZoneScoped
struct ImGuiIO {void* BackendRendererUserData=nullptr; void* BackendPlatformUserData=nullptr;};
namespace ImGui {
bool context=false;
ImGuiIO io;
void* GetCurrentContext(){return context ? &io : nullptr;}
ImGuiIO& GetIO(){assert(context);return io;}
void DestroyContext(){assert(context);context=false;io={};}
}
bool g_useSdlRenderer=false, g_frameDataBuilt=false;
float g_scale=0;
std::vector<int> g_sdlTextures,g_wgpuTextures;
int rendererCalls=0, platformCalls=0, textures=0;
void SDL_DestroyTexture(int){++textures;}
void ImGui_ImplSDLRenderer3_Shutdown(){assert(g_useSdlRenderer);assert(ImGui::GetIO().BackendRendererUserData);++rendererCalls;ImGui::io.BackendRendererUserData=nullptr;}
void ImGui_ImplWGPU_Shutdown(){assert(!g_useSdlRenderer);assert(ImGui::GetIO().BackendRendererUserData);++rendererCalls;ImGui::io.BackendRendererUserData=nullptr;}
void ImGui_ImplSDL3_Shutdown(){assert(ImGui::GetIO().BackendPlatformUserData);++platformCalls;ImGui::io.BackendPlatformUserData=nullptr;}
'''

CASES = r'''
int main(){
  shutdown(); shutdown(); // no context, including cleanup after failed profile validation
  for(bool sdl:{false,true}) {
    for(int mask=0;mask<4;++mask) { // context only, either backend, both backends
      ImGui::context=true;
      ImGui::io.BackendRendererUserData=(mask&1)?&rendererCalls:nullptr;
      ImGui::io.BackendPlatformUserData=(mask&2)?&platformCalls:nullptr;
      g_useSdlRenderer=sdl;g_scale=2.f;g_frameDataBuilt=true;
      g_sdlTextures={1,2};g_wgpuTextures={3};
      int r=rendererCalls,p=platformCalls,t=textures;
      shutdown(); shutdown();
      assert(rendererCalls==r+bool(mask&1));assert(platformCalls==p+bool(mask&2));
      assert(textures==t+2 && g_sdlTextures.empty() && g_wgpuTextures.empty());
      assert(!ImGui::context && !g_useSdlRenderer && g_scale==0 && !g_frameDataBuilt);
    }
  }
}
'''


class ImGuiPartialShutdown(unittest.TestCase):
    def test_partial_and_repeated_cleanup_on_each_maintained_runtime(self):
        for platform in ('android','ios','macos','tvos'):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as directory:
                source=ROOT/'vendor/runtimes'/platform/'aurora-main/lib/imgui.cpp'
                cpp=Path(directory)/'test.cpp'; exe=Path(directory)/'test'
                cpp.write_text(HARNESS + shutdown(source.read_text()) + CASES)
                built=subprocess.run([os.environ.get('CXX','clang++'),'-std=c++20',
                    '-fsanitize=address,undefined','-fno-sanitize-recover=all',str(cpp),'-o',str(exe)],capture_output=True,text=True)
                self.assertEqual(built.returncode,0,built.stderr)
                ran=subprocess.run([str(exe)],capture_output=True,text=True,timeout=15)
                self.assertEqual(ran.returncode,0,ran.stderr)


if __name__=='__main__':
    unittest.main()
