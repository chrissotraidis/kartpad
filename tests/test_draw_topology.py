"""Run maintained topology and merge conditions on ARM64 with ASan/UBSan.

GPU allocation/services are not modeled: these are production source-kernel
checks, not full renderer or affected-device acceptance.
"""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
PREAMBLE = r'''
#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <vector>
using u16=uint16_t; using u32=uint32_t; using IndexBuffer=std::vector<u16>;
using GXPrimitive=int;
constexpr int GX_QUADS=0, GX_TRIANGLES=1, GX_TRIANGLEFAN=2, GX_TRIANGLESTRIP=3,
              GX_LINES=4, GX_LINESTRIP=5, GX_POINTS=6;
#define UNLIKELY
#define FATAL(...) std::abort()
#define CHECK(condition, ...) assert(condition)
'''

class DrawTopology(unittest.TestCase):
    def sources(self):
        for platform in ('android', 'ios', 'macos', 'tvos'):
            yield platform, (ROOT / 'vendor/runtimes' / platform /
                             'aurora-main/lib/gx/command_processor.cpp').read_text()

    def run_cpp(self, source):
        with tempfile.TemporaryDirectory() as tmp:
            cpp, exe = Path(tmp) / 'probe.cpp', Path(tmp) / 'probe'
            cpp.write_text(PREAMBLE + source)
            subprocess.run([os.environ.get('CXX', 'clang++'), '-std=c++20',
                            '-fsanitize=address,undefined', '-fno-sanitize-recover=all',
                            str(cpp), '-o', str(exe)], check=True, capture_output=True)
            result = subprocess.run([str(exe)], capture_output=True, text=True, timeout=90)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_complete_topology_and_bounded_uint16_counts(self):
        for platform, text in self.sources():
            with self.subTest(platform=platform):
                start = text.index('static u32 prepare_idx_template(')
                function = text[start:text.index('// GX FIFO opcodes', start)]
                self.run_cpp(function + r'''
int main() {
  IndexBuffer b;
  // Every short count and every count at the former overflow boundary, plus
  // deterministic sampling throughout the legal FIFO range.
  std::vector<unsigned> counts;
  for (unsigned n=0;n<16;++n) counts.push_back(n);
  for (unsigned n=16;n<65520;n+=127) counts.push_back(n);
  for (unsigned n=65520;n<=65535;++n) counts.push_back(n);
  for (auto prim: {GX_QUADS,GX_TRIANGLES,GX_TRIANGLEFAN,GX_TRIANGLESTRIP}) {
    for (unsigned n: counts) {
      unsigned expected = prim==GX_QUADS ? (n/4)*6+(n%4==3?3:0) :
          prim==GX_TRIANGLES ? (n/3)*3 : n<3 ? 0 : (n-2)*3;
      assert(prepare_idx_template(b,prim,n)==expected);
      assert(b.size()%3==0);
      for (auto index:b) assert(index<n);
    }
  }
  prepare_idx_template(b,GX_QUADS,7);
  assert((b==IndexBuffer{0,1,2,2,3,0,4,5,6}));
  prepare_idx_template(b,GX_TRIANGLESTRIP,5);
  assert((b==IndexBuffer{0,1,2,2,1,3,2,3,4}));
  prepare_idx_template(b,GX_TRIANGLEFAN,5);
  assert((b==IndexBuffer{0,1,2,0,2,3,0,3,4}));
  // Two independent incomplete lists must not acquire a cross-draw triangle.
  IndexBuffer a;
  prepare_idx_template(a,GX_TRIANGLES,2);
  prepare_idx_template(b,GX_TRIANGLES,2);
  a.insert(a.end(),b.begin(),b.end()); assert(a.empty());
}
''')

    def test_previous_expansion_is_not_inferred_from_instance_count(self):
        for platform, text in self.sources():
            with self.subTest(platform=platform):
                condition = re.search(r'if \((lastDraw != nullptr.*?)\) LIKELY \{', text, re.S).group(1)
                self.run_cpp(r'''
struct Draw { unsigned instanceCount=1, vtxCount=2; bool expandedPrimitive=false; };
bool eligible(Draw* lastDraw, unsigned vtxCount, int prim=GX_TRIANGLES) {
 return ''' + condition + r''';
}
int main() {
 Draw d;
 assert(eligible(&d,3));
 d.expandedPrimitive=true;
 assert(!eligible(&d,3)); // one line, one line strip segment, or one point
 d.expandedPrimitive=false;
 assert(!eligible(&d,2,GX_LINES));
 assert(!eligible(&d,2,GX_LINESTRIP));
 assert(!eligible(&d,1,GX_POINTS));
 d.vtxCount=65530; assert(eligible(&d,6)); assert(!eligible(&d,7));
 d.vtxCount=65536; assert(!eligible(&d,3));
 d.vtxCount=UINT32_MAX; assert(!eligible(&d,3));
 assert(!eligible(nullptr,3));
}
''')

if __name__ == '__main__':
    unittest.main()
