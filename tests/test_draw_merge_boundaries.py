"""Execute production FIFO invalidation and merge eligibility against boundary cases."""
from pathlib import Path
import re
import os
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class DrawMergeBoundaries(unittest.TestCase):
    def run_cpp(self, source):
        compiler = os.environ.get("CXX") or shutil.which("clang++") or shutil.which("g++")
        self.assertIsNotNone(compiler)
        with tempfile.TemporaryDirectory() as tmp:
            cpp, exe = Path(tmp) / "test.cpp", Path(tmp) / "test"
            cpp.write_text(source)
            subprocess.run([*shlex.split(compiler), "-std=c++20", "-fsanitize=address,undefined", str(cpp), "-o", str(exe)], check=True)
            result = subprocess.run([str(exe)], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)

    def sources(self):
        for platform in ("android", "ios", "macos", "tvos"):
            yield platform, (ROOT / "vendor/runtimes" / platform /
                             "aurora-main/lib/gx/command_processor.cpp").read_text()

    def test_vertex_invalidation_breaks_merge_without_pipeline_change(self):
        for platform, text in self.sources():
            with self.subTest(platform=platform):
                start = text.index("case CP_CMD_INVAL_VTX: {")
                case = text[start:text.index("case GX_LOAD_AURORA:", start)]
                self.run_cpp(r'''
#include <array>
#include <cassert>
constexpr int GX_VA_POS=9, GX_VA_TEX7=20, CP_CMD_INVAL_VTX=1;
struct Range { unsigned offset=0, size=0; };
struct Array { Range cachedRange; };
struct State { std::array<Array, 26> arrays; bool stateDirty=false;
               unsigned pipelineStateGeneration=73; } g_gxState;
void invalidate() { switch(CP_CMD_INVAL_VTX) {
''' + case + r'''
} }
int main() {
  for (auto& a:g_gxState.arrays) a.cachedRange={100,48};
  invalidate();
  for (int i=GX_VA_POS;i<=GX_VA_TEX7;++i)
    assert(g_gxState.arrays[i].cachedRange.size==0);
  assert(g_gxState.arrays[GX_VA_POS-1].cachedRange.size==48);
  // Without this boundary, handle_draw merges into the previous draw and
  // returns before handle_draw_unmerged can upload the changed arrays.
  assert(g_gxState.stateDirty && "invalidation must prevent reusing the prior draw upload");
  assert(g_gxState.pipelineStateGeneration==73);
}
''')

    def test_merged_indices_cannot_wrap_to_previous_vertices(self):
        for platform, text in self.sources():
            with self.subTest(platform=platform):
                match = re.search(r"if \((lastDraw != nullptr.*?)\) LIKELY \{", text, re.S)
                self.assertIsNotNone(match)
                self.run_cpp(r'''
#include <cassert>
#include <cstdint>
constexpr int GX_LINES=1, GX_LINESTRIP=2, GX_POINTS=3, GX_TRIANGLES=4, GX_QUADS=5;
struct Draw { uint32_t instanceCount=1, vtxCount=0; bool expandedPrimitive=false; };
bool eligible(Draw* lastDraw, uint16_t vtxCount, int prim=GX_TRIANGLES) {
  return ''' + match.group(1) + r''';
}
int main() {
  Draw d;
  assert(eligible(&d,3));
  d.vtxCount=65530;
  assert(eligible(&d,6)); // highest generated index is exactly 65535
  assert(!eligible(&d,7) && "16-bit merged indices would wrap to vertex zero");
  assert(eligible(&d,6,GX_QUADS)); // incomplete tail emits no extra vertices
  d.vtxCount=65536; assert(!eligible(&d,1));
  d.vtxCount=UINT32_MAX; assert(!eligible(&d,1));
  d.vtxCount=0; d.instanceCount=2; assert(!eligible(&d,3));
  d.instanceCount=1; assert(!eligible(&d,3,GX_LINES));
  assert(!eligible(nullptr,3));
}
''')

    def test_maximum_quad_count_does_not_wrap_loop_counter(self):
        for platform, text in self.sources():
            with self.subTest(platform=platform):
                start = text.index("static u32 prepare_idx_template(")
                function = text[start:text.index("// GX FIFO opcodes", start)]
                self.run_cpp(r'''
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
''' + function + r'''
int main() {
  IndexBuffer b;
  for(unsigned count: {0u, 4u, 65532u, 65533u, 65534u, 65535u}) {
    const auto n=prepare_idx_template(b,GX_QUADS,count);
    assert(n==(count/4)*6+(count%4==3?3:0));
    for(auto index:b) assert(index<count);
  }
}
''')

    def test_vertex_format_switch_breaks_merge_even_at_equal_stride(self):
        for platform, text in self.sources():
            with self.subTest(platform=platform):
                start = text.index("static u32 calculate_last_vtx_size(")
                function = text[start:text.index("static void handle_draw_unmerged(", start)]
                self.run_cpp(r'''
#include <array>
#include <cassert>
#include <cstdint>
using u32=uint32_t; using GXVtxFmt=int; using GXAttr=int;
constexpr int GX_VA_PNMTXIDX=0, GX_VA_POS=9, GX_VA_NRM=10, GX_VA_TEX7=20;
constexpr int GX_NONE=0, GX_DIRECT=1, GX_INDEX8=2, GX_INDEX16=3, GX_NRM_NBT3=9;
struct Attr { unsigned type=0, cnt=0; };
struct Format { std::array<Attr, 26> attrs; };
struct State { std::array<Format, 8> vtxFmts; std::array<int,26> vtxDesc{};
  GXVtxFmt lastVtxFmt=0; unsigned lastVtxSize=6; bool stateDirty=false; } g_gxState;
unsigned comp_type_size(GXAttr, unsigned type) {return type==2 || type==3 ? 2 : 4;}
unsigned comp_cnt_count(GXAttr, unsigned count) {return count;}
''' + function + r'''
int main() {
  g_gxState.vtxDesc[GX_VA_POS]=GX_DIRECT;
  g_gxState.vtxFmts[0].attrs[GX_VA_POS]={2,3};
  g_gxState.vtxFmts[1].attrs[GX_VA_POS]={3,3};
  assert(calculate_last_vtx_size(1)==6);
  assert(g_gxState.lastVtxFmt==1);
  assert(g_gxState.stateDirty && "new format must not use the previous draw shader/layout");
}
''')


if __name__ == "__main__":
    unittest.main()
