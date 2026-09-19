"""Execute production map callbacks and frame-begin wait with a controlled Dawn service."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class StagingMapLifecycle(unittest.TestCase):
    def test_callbacks_waits_and_reset_on_all_runtime_pins(self):
        for platform in ('android', 'ios', 'macos', 'tvos'):
            with self.subTest(platform=platform):
                folder = ROOT / 'vendor/runtimes' / platform / 'aurora-main/lib/gfx'
                baseline = os.environ.get('KARTPAD_MAP_BASELINE')
                path = Path(baseline) / f'{platform}-before.cpp' if baseline else folder / 'common.cpp'
                text = path.read_text()
                start = text.index('void map_staging_buffer() {')
                end = text.index('  g_recordingSnapshotSlot = currentStagingBuffer;', start)
                body = text[start:end] + '  return true;\n}\n'
                if baseline:
                    state = text[text.index('enum class BufferMapState {'):text.index('static wgpu::Limits g_cachedLimits;')]
                    reset = 's_mappingState.store(BufferMapState::Unmapped, std::memory_order_release);'
                    load = 's_mappingState.load(std::memory_order_acquire)'
                else:
                    state = f'#include "{folder / "staging_map.hpp"}"\nusing namespace aurora::gfx;\nstatic StagingMapState s_mappingState;'
                    reset = 's_mappingState.reset();'
                    load = 's_mappingState.state()'
                source = r'''
#include <array>
#include <atomic>
#include <cassert>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <functional>
#include <string>
#include <string_view>
#include <thread>
#include <vector>
#define ZoneScoped
#define ZoneScopedN(x)
#define ASSERT(c, ...) assert(c)
namespace wgpu {
enum class MapAsyncStatus {Success, CallbackCancelled, Aborted, Error};
enum class MapMode {Write}; enum class CallbackMode {AllowSpontaneous};
using StringView = std::string_view;
}
namespace magic_enum {template<class T> std::string_view enum_name(T){return "status";}}
struct Logger {template<class... T> void warn(T...) {}} Log;
using Callback = std::function<void(wgpu::MapAsyncStatus, wgpu::StringView)>;
std::vector<Callback> callbacks;
struct Buffer {void MapAsync(wgpu::MapMode, uint64_t, uint64_t, wgpu::CallbackMode, Callback callback) {
  callbacks.push_back(std::move(callback));
}};
std::array<Buffer, 3> g_stagingBuffers;
size_t currentStagingBuffer = 0;
uint32_t g_frameIndex = 0;
uint64_t g_stagingEpoch = 0;
constexpr uint64_t StagingBufferSize = 4096;
struct Instance {unsigned calls=0;std::function<void()> next;
  void ProcessEvents(){++calls;if(next){auto callback=std::move(next);next={};callback();}}
} g_instance;
namespace webgpu {bool lost=false;void fail_if_device_lost(){if(lost) std::exit(23);}}
''' + state + '\n' + body + '\nvoid reset() {' + reset + '}\n' + \
                    'BufferMapState state() { return ' + load + '; }\n' + r'''
int main(int argc, char** argv) {
  assert(argc == 2); const std::string mode = argv[1];
  reset(); map_staging_buffer(); assert(callbacks.size() == 1);
  map_staging_buffer(); assert(callbacks.size() == 1); // Do not map twice.
  if (mode == "stale") {
    const auto old = callbacks[0];
    reset(); currentStagingBuffer = 1; map_staging_buffer();
    assert(callbacks.size() == 2);
    // A completion from a cancelled/reset request belongs only to that request.
    for (auto status : {wgpu::MapAsyncStatus::Success, wgpu::MapAsyncStatus::Aborted,
                        wgpu::MapAsyncStatus::CallbackCancelled, wgpu::MapAsyncStatus::Error}) {
      old(status, "old generation");
      assert(state() == BufferMapState::Mapping);
    }
    callbacks[1](wgpu::MapAsyncStatus::Success, "");
    assert(state() == BufferMapState::Mapped);
    assert(begin_frame_impl(true)); assert(g_instance.calls == 0);
  } else if (mode == "delay") {
    auto callback = callbacks[0];
    std::thread completion([callback]{
      std::this_thread::sleep_for(std::chrono::milliseconds(30));
      callback(wgpu::MapAsyncStatus::Success, "");
    });
    const auto cpu = std::clock();
    assert(begin_frame_impl(true)); completion.join();
    std::printf("delayed map: ProcessEvents=%u CPU-ms=%.3f\n", g_instance.calls,
                1000.0 * (std::clock() - cpu) / CLOCKS_PER_SEC);
    std::fflush(stdout);
    assert(g_instance.calls < 1000); // The original busy loop performs many thousands.
  } else if (mode == "events") {
    g_instance.next = []{callbacks[0](wgpu::MapAsyncStatus::Success, "");};
    assert(begin_frame_impl(true)); assert(g_instance.calls == 1);
  } else if (mode == "cancel") {
    g_instance.next = []{callbacks[0](wgpu::MapAsyncStatus::Aborted, "cancelled");};
    assert(!begin_frame_impl(true)); assert(state() == BufferMapState::Unmapped);
    map_staging_buffer(); assert(callbacks.size() == 2);
    callbacks[1](wgpu::MapAsyncStatus::Success, "");
    assert(begin_frame_impl(true));
  } else if (mode == "loss") {
    g_instance.next = []{webgpu::lost=true;};
    begin_frame_impl(true); // Must reach the existing loss handler, even without a map callback.
    assert(false);
  } else { assert(false); }
}
'''
                with tempfile.TemporaryDirectory() as directory:
                    cpp = Path(directory) / 'probe.cpp'
                    executable = Path(directory) / 'probe'
                    cpp.write_text(source)
                    sanitizers = os.environ.get('KARTPAD_MAP_SANITIZERS', 'address,undefined')
                    build = subprocess.run(['clang++', '-std=c++20', '-pthread', f'-fsanitize={sanitizers}',
                                            str(cpp), '-o', str(executable)], capture_output=True, text=True)
                    self.assertEqual(build.returncode, 0, build.stderr)
                    for mode in ('stale', 'delay', 'events', 'cancel', 'loss'):
                        with self.subTest(mode=mode):
                            run = subprocess.run([str(executable), mode], capture_output=True, text=True, timeout=5)
                            if run.stdout: print(platform, run.stdout.strip())
                            self.assertEqual(run.returncode, 23 if mode == 'loss' else 0, run.stderr)


if __name__ == '__main__':
    unittest.main()
