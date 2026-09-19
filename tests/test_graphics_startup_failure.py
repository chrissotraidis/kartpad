"""Execute production backend selection with controlled adapter failures."""
from pathlib import Path
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]
class GraphicsStartupFailure(unittest.TestCase):
 def test_first_error_survives_fallback_and_failure_is_returned(self):
  for platform in ('android','ios','macos','tvos'):
   with self.subTest(platform=platform):
    root=ROOT/'vendor/runtimes'/platform
    text=(root/'aurora-main/lib/aurora.cpp').read_text()
    start=text.index('  const AuroraBackend requestedBackend = config.desiredBackend;')
    end=text.index('  if (requestedBackend != BACKEND_AUTO && selectedBackend != requestedBackend)',start)
    body=text[start:end]
    source=r'''
#include <array>
#include <cassert>
#include <cstdarg>
#include <cstdio>
#include <string>
#include <vector>
using AuroraBackend=int;
constexpr int BACKEND_AUTO=0, VULKAN=1, METAL=2;
constexpr int AURORA_INITIALIZATION_SUCCESS=0, AURORA_INITIALIZATION_GRAPHICS_UNAVAILABLE=1;
struct AuroraInfo {int initializationStatus=0;const char* initializationError=nullptr;};
struct Config {int desiredBackend;};
std::array<int,2> PreferredBackendOrder{VULKAN,METAL};
struct Logger {template<class...T>void info(T...){} template<class...T>void error(T...){}} Log;
int backend_name(int x){return x;}
std::string error;
const char* SDL_GetError(){return error.c_str();}
bool SDL_SetError(const char* fmt,...){char b[1024];va_list a;va_start(a,fmt);vsnprintf(b,sizeof(b),fmt,a);va_end(a);error=b;return false;}
namespace window {int destroys=0;bool create_window(int){return true;}void destroy_window(){destroys++;error="surface destroyed";}}
namespace webgpu {std::vector<bool> outcomes;unsigned index=0;bool initialize(int){
 bool success=outcomes.at(index++);error=index==1?"Insufficient Vulkan limits for maxInterStageShaderVariables":"later backend failure";return success;}}
AuroraInfo attempt(Config config){
''' + body + r'''
 return {};
}
int main(){
 webgpu::outcomes={false,false,false};webgpu::index=0;error.clear();
 auto failed=attempt({VULKAN});
 assert(failed.initializationStatus==AURORA_INITIALIZATION_GRAPHICS_UNAVAILABLE);
 assert(std::string(failed.initializationError)=="Insufficient Vulkan limits for maxInterStageShaderVariables");
 assert(webgpu::index==3 && window::destroys==3);
 webgpu::outcomes={false,true};webgpu::index=0;error.clear();
 auto fallback=attempt({VULKAN});assert(fallback.initializationStatus==AURORA_INITIALIZATION_SUCCESS);
 webgpu::outcomes={true};webgpu::index=0;error.clear();
 assert(attempt({VULKAN}).initializationStatus==AURORA_INITIALIZATION_SUCCESS);
 webgpu::outcomes={false,false};webgpu::index=0;error.clear();
 assert(attempt({BACKEND_AUTO}).initializationStatus==AURORA_INITIALIZATION_GRAPHICS_UNAVAILABLE);
}
'''
    with tempfile.TemporaryDirectory() as d:
     p=Path(d)/'test.cpp';p.write_text(source);exe=Path(d)/'test'
     build=subprocess.run(['clang++','-std=c++20','-fsanitize=address,undefined',str(p),'-o',str(exe)],text=True,capture_output=True)
     self.assertEqual(build.returncode,0,build.stderr)
     run=subprocess.run([str(exe)],text=True,capture_output=True)
     self.assertEqual(run.returncode,0,run.stderr)
    runtime=(root/'runtime/src/main.cpp').read_text()
    check=runtime.index('if (auroraInfo.initializationStatus != AURORA_INITIALIZATION_SUCCESS)')
    self.assertLess(check,runtime.index('aurora_set_frame_worker_wait_callback',check))
    self.assertIn('ShutdownProcessTranscript();\n            return 1;',runtime[check:check+1000])
if __name__=='__main__':unittest.main()
