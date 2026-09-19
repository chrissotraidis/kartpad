"""Maintained admission arithmetic and FIFO retry protocol, without GPU stubs claiming pixels.

The separately linked aurora_batch_probe verifies actual GPU submissions and pixels.
"""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

class StagingCapacity(unittest.TestCase):
    def compile_run(self, source):
        with tempfile.TemporaryDirectory() as directory:
            cpp, exe = Path(directory) / 'probe.cpp', Path(directory) / 'probe'
            cpp.write_text(source)
            build = subprocess.run([os.environ.get('CXX', 'clang++'), '-std=c++20', '-pthread',
                                    '-fsanitize=address,undefined', '-fno-sanitize-recover=all',
                                    str(cpp), '-o', str(exe)], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            result = subprocess.run([str(exe)], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_alignment_tail_and_overflow(self):
        for platform in ('android', 'ios', 'macos', 'tvos'):
            header = ROOT / 'vendor/runtimes' / platform / 'aurora-main/lib/gfx/staging_capacity.hpp'
            with self.subTest(platform=platform):
                self.compile_run('#include "' + str(header) + '"\n' + r'''
#include <cassert>
#include <random>
using namespace aurora::gfx;
int main() {
  assert(staging_padded(0,256)==256);
  assert(staging_padded(257,256)==512);
  assert(staging_padded(17,0)==17);
  bool overflow=false;
  try { staging_padded(UINT64_MAX,256); } catch(const StagingCapacityError&) {overflow=true;}
  assert(overflow);
  StagingSizes used{0,256,0,0}, demand{0,256,0,0}, tail{0,3840,0,0}, cap{4,4352,4,4};
  assert(staging_fits(used,demand,tail,cap));
  --cap[1]; assert(!staging_fits(used,demand,tail,cap));
  std::mt19937_64 rng(198305);
  for(unsigned trial=0;trial<10000;++trial) {
    bool expected=true;
    for(unsigned i=0;i<4;++i) {
      cap[i] = trial%2 ? rng()%20000 : rng();
      used[i] = trial%2 ? rng()%10000 : rng();
      demand[i] = trial%2 ? rng()%10000 : rng();
      tail[i] = trial%2 ? rng()%10000 : rng();
      __uint128_t end=__uint128_t(used[i])+demand[i]+tail[i];
      __uint128_t rounded=(end+3)/4*4;
      expected &= rounded<=cap[i] && rounded<=UINT32_MAX;
    }
    assert(staging_fits(used,demand,tail,cap)==expected);
  }
}
''')

    def test_fifo_preserves_suffix_and_retries_only_once(self):
        for platform in ('android', 'ios', 'macos', 'tvos'):
            path = ROOT / 'vendor/runtimes' / platform / 'aurora-main/lib/gx/fifo.cpp'
            text = path.read_text()
            function = text[text.index('void drain() {'):text.index('const uint8_t* get_buffer_data()')]
            header = path.parent.parent / 'gfx/staging_capacity.hpp'
            with self.subTest(platform=platform):
                self.compile_run('#include "' + str(header) + '"\n' + r'''
#include <cassert>
#include <chrono>
#include <mutex>
#include <vector>
#define UNLIKELY
namespace aurora {
std::chrono::nanoseconds wait_for_frame_worker_sealed() {return {};}
std::recursive_mutex mutex;
namespace gfx {
unsigned splits=0, used=0;
void split_staging_batch() {++splits;used=0;}
}
namespace gx::fifo {
namespace detail {uint8_t* sBufferData=nullptr;uint32_t sBufferSize=0;}
void note_drain_wait(uint64_t) {}
std::vector<uint8_t> decoded;
bool failRetry=false;
uint32_t process(const uint8_t* data, uint32_t size, bool) {
  std::lock_guard lock(aurora::mutex);
  if(failRetry && gfx::splits) return 0;
  uint32_t count=0;
  while(count<size && gfx::used<2) {decoded.push_back(data[count++]);++gfx::used;}
  return count;
}
''' + function + r'''
}
}
int main() {
  using namespace aurora;
  using namespace aurora::gx::fifo;
  uint8_t commands[]{1,2,3,4,5,6,7};
  detail::sBufferData=commands; detail::sBufferSize=sizeof(commands);
  drain();
  assert((decoded==std::vector<uint8_t>{1,2,3,4,5,6,7}));
  assert(gfx::splits==3 && detail::sBufferSize==0);
  gfx::splits=0;gfx::used=0;decoded.clear();failRetry=true;
  detail::sBufferSize=sizeof(commands);
  bool rejected=false;
  try {drain();} catch(const gfx::StagingCapacityError&) {rejected=true;}
  assert(rejected && gfx::splits==1 && decoded.size()==2);
}
''')

if __name__ == '__main__':
    unittest.main()
