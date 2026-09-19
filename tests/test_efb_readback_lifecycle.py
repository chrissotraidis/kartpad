"""Exercise maintained EFB mapping functions with controlled callback lifetimes."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def function(text, signature):
    start = text.index(signature)
    return text[start:text.index('\n}\n', start) + 3]


class EfbReadbackLifecycle(unittest.TestCase):
    def test_all_runtime_pins(self):
        for platform in ('android', 'ios', 'macos', 'tvos'):
            with self.subTest(platform=platform):
                baseline = os.environ.get('KARTPAD_EFB_BASELINE')
                path = (Path(baseline) / f'{platform}-efb-ram-before.cpp' if baseline else
                        ROOT / 'vendor/runtimes' / platform / 'aurora-main/lib/gfx/efb_ram_copy.cpp')
                text = path.read_text()
                declarations = text[text.index('struct PendingCopy {'):text.index('uint32_t align_to(')]
                functions = '\n'.join(function(text, signature) for signature in (
                    'void ensure_native_texture(', 'HostPixelOrder texture_pixel_order(',
                    'void complete_async_slot(', 'void drain_async_events(',
                    'bool complete_downloads()', 'void cancel()', 'void after_submit()', 'void shutdown()'))
                source = PREAMBLE + declarations + functions + MAIN
                with tempfile.TemporaryDirectory() as directory:
                    cpp = Path(directory) / 'probe.cpp'
                    executable = Path(directory) / 'probe'
                    cpp.write_text(source)
                    build = subprocess.run(['clang++', '-std=c++20', '-pthread',
                                            '-fsanitize=address,undefined', '-fno-omit-frame-pointer',
                                            str(cpp), '-o', str(executable)], capture_output=True, text=True)
                    self.assertEqual(build.returncode, 0, build.stderr)
                    for mode in ('uv', 'epoch', 'success', 'timeout', 'message', 'stale', 'shutdown'):
                        with self.subTest(mode=mode):
                            env = dict(os.environ, ASAN_OPTIONS='detect_stack_use_after_return=1')
                            run = subprocess.run([str(executable), mode], capture_output=True,
                                                 text=True, timeout=5, env=env)
                            self.assertEqual(run.returncode, 0, run.stderr)


PREAMBLE = r'''
#include <array>
#include <cassert>
#include <cstdint>
#include <cstring>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>
namespace wgpu {
enum class MapAsyncStatus { Success, CallbackCancelled, Aborted, Error };
enum class MapMode { Read }; enum class CallbackMode { WaitAnyOnly, AllowSpontaneous };
enum class WaitStatus { Success, TimedOut };
enum class TextureFormat { RGBA8Unorm, BGRA8Unorm };
struct StringView { const char* data=nullptr; size_t length=0; };
using Callback = std::function<void(MapAsyncStatus, StringView)>;
std::vector<Callback> callbacks;
struct BufferState {
  std::array<uint8_t, 64> pixels{};
  std::function<void()> onDestroy;
  ~BufferState() { if(onDestroy) onDestroy(); }
};
struct Buffer {
  std::shared_ptr<BufferState> state = std::make_shared<BufferState>();
  size_t MapAsync(MapMode, uint64_t, uint64_t, CallbackMode, Callback callback) const {
    callbacks.push_back(std::move(callback)); return callbacks.size()-1;
  }
  const void* GetConstMappedRange(uint64_t, uint64_t) { return state->pixels.data(); }
  void Unmap() {}
};
}
std::string capturedMessage;
std::string copy_message(wgpu::StringView view) {return view.data ? std::string(view.data, view.length) : "";}
std::string copy_message(const std::string& message) {return message;}
std::string copy_message(unsigned) {return {};}
struct Logger {
  template<class A, class B, class C> void error(const char*, A, B, C message) {capturedMessage=copy_message(message);}
  template<class... A> void error(const char*, A...) {}
  template<class... A> void warn(A...) {}
} Log;
namespace magic_enum {template<class T> std::string_view enum_name(T) {return "status";}}
enum GXTexFmt { GX_TF_RGBA8 };
enum class HostPixelOrder { RGBA, BGRA };
struct Texture {struct {uint32_t width, height;} size; wgpu::TextureFormat format=wgpu::TextureFormat::RGBA8Unorm;};
using TextureHandle = std::shared_ptr<Texture>;
struct Range {};
std::array<float, 12> uniform{};
int uniformWrites=0, guestWrites=0;
uint64_t testEpoch=1;
uint64_t staging_epoch() { return testEpoch; }
TextureHandle new_conv_texture(uint32_t width,uint32_t height,GXTexFmt,const char*) {
  return std::make_shared<Texture>(Texture{{width,height}});
}
Range push_uniform(const std::array<float, 12>& value) {uniform=value;++uniformWrites;return {};}
size_t encoded_size(GXTexFmt,uint32_t width,uint32_t height) {return width*height*4;}
bool encode(void* dest,size_t length,GXTexFmt,uint32_t,uint32_t,const uint8_t*,uint32_t,uint32_t,uint32_t,HostPixelOrder) {
  std::memset(dest, 0x37, length); return true;
}
void notify_guest_write(void*,size_t) {++guestWrites;}
struct Instance {
  std::string mode;
  explicit operator bool() const {return true;}
  void ProcessEvents() {}
  wgpu::WaitStatus WaitAny(size_t future, uint64_t) {
    if(mode=="timeout") return wgpu::WaitStatus::TimedOut;
    if(mode=="message") {
      const std::string ephemeral(1024, 'x');
      wgpu::callbacks[future](wgpu::MapAsyncStatus::Error, {ephemeral.data(),ephemeral.size()});
    } else {wgpu::callbacks[future](wgpu::MapAsyncStatus::Success, {});}
    return wgpu::WaitStatus::Success;
  }
} g_instance;
'''

MAIN = r'''
int main(int argc, char** argv) {
  assert(argc==2); const std::string mode=argv[1]; g_instance.mode=mode;
  std::array<uint8_t, 80> destination; destination.fill(0xab);
  void* dest=destination.data()+8;
  if(mode=="uv") {
    PendingCopy copy{.dest=dest,.width=4,.height=4,.texture=new_conv_texture(8,8,GX_TF_RGBA8,"")};
    TextureHandle cache;
    ensure_native_texture(copy,&cache);
    assert(cache && copy.nativeTexture==cache && uniformWrites==1);
    assert(uniform[10]==0.f && uniform[11]==1.f);
    ensure_native_texture(copy,&cache); assert(uniformWrites==1);
    PendingCopy next{.dest=dest,.width=4,.height=4,.texture=copy.texture};
    ensure_native_texture(next,&cache); assert(next.nativeTexture==cache && uniformWrites==2);
    PendingCopy native{.dest=dest,.width=4,.height=4,.texture=cache};
    ensure_native_texture(native); assert(!native.nativeTexture && uniformWrites==2);
  } else if(mode=="epoch") {
    PendingCopy copy{.dest=dest,.width=4,.height=4,.texture=new_conv_texture(8,8,GX_TF_RGBA8,"")};
    ensure_native_texture(copy);
    const auto texture=copy.nativeTexture;
    ++testEpoch;
    ensure_native_texture(copy);
    assert(copy.nativeTexture==texture && uniformWrites==2);
    ensure_native_texture(copy); assert(uniformWrites==2);
  } else if(mode=="success" || mode=="timeout" || mode=="message") {
    Download download;
    download.copy={.dest=dest,.width=4,.height=4,.texture=new_conv_texture(4,4,GX_TF_RGBA8,"")};
    download.bufferSize=64;download.bytesPerRow=16;
    g_downloads.push_back(download);
    const bool success=complete_downloads();
    assert(success==(mode=="success")); assert(g_downloads.empty());
    if(mode=="timeout") {
      // Deliver after complete_downloads has returned and destroyed its locals.
      wgpu::callbacks[0](wgpu::MapAsyncStatus::Aborted, {});
      assert(guestWrites==0);
    } else if(mode=="message") {
      assert(capturedMessage==std::string(512,'x')); assert(guestWrites==0);
    } else { assert(guestWrites==1); }
  } else if(mode=="stale" || mode=="shutdown") {
    auto& first=g_asyncSlots[dest]; first.dest=dest;first.width=first.height=4;
    first.hostWidth=first.hostHeight=4;first.bufferSize=64;first.bytesPerRow=16;
    first.state=AsyncState::CopySubmitted;
    after_submit(); assert(g_asyncMapsInFlight==1);
    const auto old=wgpu::callbacks[0];
    if(mode=="shutdown") {
      first.buffer.state->onDestroy=[old] {old(wgpu::MapAsyncStatus::CallbackCancelled,{});};
      shutdown(); assert(g_asyncSlots.empty() && g_asyncMapsInFlight==0);
    } else {
      shutdown();
      auto& second=g_asyncSlots[dest]; second.dest=dest;second.width=second.height=4;
      second.hostWidth=second.hostHeight=4;second.bufferSize=64;second.bytesPerRow=16;
      second.state=AsyncState::CopySubmitted;
      after_submit(); assert(g_asyncMapsInFlight==1);
      for(auto status : {wgpu::MapAsyncStatus::Success,wgpu::MapAsyncStatus::Aborted,
                         wgpu::MapAsyncStatus::CallbackCancelled,wgpu::MapAsyncStatus::Error}) {
        old(status,{});
        assert(g_asyncMapsInFlight==1 && second.state==AsyncState::MapPending && guestWrites==0);
      }
      wgpu::callbacks[1](wgpu::MapAsyncStatus::Success,{});
      assert(g_asyncMapsInFlight==0 && second.state==AsyncState::Idle && guestWrites==1);
    }
  } else {assert(false);}
  for(size_t i=0;i<destination.size();++i) {
    assert(destination[i]==((guestWrites && i>=8 && i<72) ? 0x37 : 0xab));
  }
}
'''

if __name__ == '__main__':
    unittest.main()
