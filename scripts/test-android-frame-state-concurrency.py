#!/usr/bin/env python3
"""Exercise the actual prepared VI/aspect functions with concurrent readers.

Uses ThreadSanitizer; a nonzero exit is a failed test (also usable against the
unguarded prepared baseline as a negative control). No GPU/driver claim.
"""
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
vi = (root / 'aurora-main/lib/dolphin/vi/vi.cpp').read_text()
vi = vi[vi.index('namespace aurora::vi {'):vi.index('\nextern "C" {')]
window = (root / 'aurora-main/lib/window.cpp').read_text()
fields_start = window.find('std::mutex g_presentAspectMutex;')
if fields_start < 0:
    fields_start = window.index('bool g_presentSurfaceFill')
fields = window[fields_start:window.index('AuroraWindowSize g_windowSize;', fields_start)]
functions = window[window.index('void set_present_surface_fill('):window.index('\nvoid set_background_input(')]
cpp = r'''
#include <algorithm>
#include <atomic>
#include <cassert>
#include <cmath>
#include <cstdint>
#include <mutex>
#include <optional>
#include <thread>
#include <vector>
template <typename T> struct Vec2 { T x,y; bool operator==(const Vec2&) const = default; };
struct GXRenderModeObj { uint32_t viTVmode,viWidth,viHeight,fbWidth,efbHeight; };
constexpr uint32_t VI_PAL=1,VI_DEBUG_PAL=4;
namespace aurora::window { void request_frame_buffer_resize(); }
''' + vi + r'''
namespace aurora::window {
void request_frame_buffer_resize() {
  // Reenter a reader: configure must have released its mode lock.
  assert(vi::render_mode_size().x >= 640);
}
void* g_window = reinterpret_cast<void*>(1);
thread_local bool reenterQuery = false;
void set_present_surface_fill(bool);
void unlock_present_aspect_ratio();
bool query_native_client_size(uint32_t& w,uint32_t& h) {
  if (reenterQuery) {
    reenterQuery = false;
    set_present_surface_fill(false);
  }
  w=2244; h=1008; return true;
}
bool SDL_GetWindowSizeInPixels(void*,int* w,int* h) { *w=2244; *h=1008; return true; }
''' + fields + functions + r'''
}
int main() {
  using namespace aurora;
  GXRenderModeObj a{0,640,480,640,480}, b{0,640,480,720,576};
  vi::configure(nullptr);
  assert((vi::visible_fb_size()==Vec2<uint32_t>{640,528}));
  vi::configure(&a);
  assert((vi::visible_fb_size()==Vec2<uint32_t>{640,480}));
  vi::configure(&b); // exercises resize callback reentrancy
  assert((vi::render_mode_size()==Vec2<uint32_t>{720,576}));
  window::lock_present_aspect_ratio(16,9);
  window::set_present_surface_fill(true);
  window::reenterQuery=true;
  float aspect=0;
  assert(window::get_present_aspect_ratio(aspect));
  assert(std::abs(aspect-2244.f/1008.f)<.0001f);
  std::atomic<bool> start=false;
  std::vector<std::thread> threads;
  threads.emplace_back([&] {
    while(!start.load()) std::this_thread::yield();
    for(int i=0;i<20000;++i) {
      vi::configure(i%3==0 ? nullptr : i%2==0 ? &a : &b);
      window::set_present_surface_fill(i%2);
      window::lock_present_aspect_ratio(i%2 ? 4 : 16,i%2 ? 3 : 9);
      if(i%3==0) window::unlock_present_aspect_ratio();
    }
  });
  for(int reader=0;reader<3;++reader) threads.emplace_back([&] {
    while(!start.load()) std::this_thread::yield();
    for(int i=0;i<20000;++i) {
      auto v=vi::visible_fb_size();
      assert((v==Vec2<uint32_t>{640,528} || v==Vec2<uint32_t>{640,480} || v==Vec2<uint32_t>{720,576}));
      auto s=vi::configured_fb_size();
      assert((s==Vec2<uint32_t>{640,528} || s==Vec2<uint32_t>{720,576}));
      float ratio=0;
      if(window::get_present_aspect_ratio(ratio)) assert(std::isfinite(ratio) && ratio>0);
    }
  });
  start=true;
  for(auto& thread:threads) thread.join();
}
'''
with tempfile.TemporaryDirectory() as directory:
    src = Path(directory) / 'frame_state.cpp'
    exe = Path(directory) / 'frame_state'
    src.write_text(cpp)
    subprocess.run(['clang++', '-std=c++20', '-O1', '-g', '-fsanitize=thread', '-pthread', str(src), '-o', str(exe)], check=True)
    subprocess.run([str(exe)], check=True, timeout=40)
print('PASS: actual VI/aspect concurrent state and callback reentrancy under ThreadSanitizer')
