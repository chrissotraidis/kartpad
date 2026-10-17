#!/usr/bin/env python3
"""Run production repacking and its existing golden tests without a GPU.

--benchmark compares CPU conversion only; it is not a phone FPS measurement.
--source permits an unchanged source snapshot for a same-compiler A/B.
"""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GX = ROOT / 'vendor/runtimes/android/aurora-main'


def source(path):
    text = path.read_text()
    header = (GX / 'lib/gx/gx.hpp').read_text()
    declarations = '\n'.join(re.search(r'struct ' + name + r' \{.*?\n\};', header, re.S)[0]
                             for name in ('AttrArray', 'AttrConfig'))
    helpers = text[text.index('bool is_index_attr('):text.index('} // namespace')]
    predicate_text = (GX / 'lib/gx/shader.cpp').read_text()
    predicate = predicate_text[predicate_text.index('bool kartpad_uses_vertex_pnmtx('):predicate_text.index('// The twelve vertex-array')]
    shader_config = re.search(r'struct ShaderConfig \{.*?\n\};', header, re.S)[0]
    # Only the actual prefix used by the predicate is needed; no GPU types.
    shader_config = shader_config[:shader_config.index('  std::array<TevSwap')] + '};'
    implementation = text[text.index('u8 repacked_layout('):text.index('const std::vector<u8>& repack(')]
    golden = (GX / 'tests/kartpad_vertex_repack_test.cpp').read_text()
    golden = golden[golden.index('namespace {'):golden.index('TEST(KartPadVertexRepack, AdrenoModelParsing)')]
    tests = re.findall(r'TEST\(KartPadVertexRepack, (\w+)\)', golden)
    return r'''
#include <dolphin/gx/GXEnum.h>
#include <algorithm>
#include <array>
#include <bit>
#include <chrono>
#include <cmath>
#include <cstring>
#include <iostream>
#include <stdexcept>
#include <vector>
namespace aurora::gx {
constexpr u32 MaxVtxAttr = GX_VA_MAX_ATTR;
namespace gfx { struct Range { u32 offset=0, size=0; }; }
''' + declarations + '\n' + shader_config + '\nbool experiment = false; bool kartpad_vertex_pnmtx() noexcept {return experiment;}\n' + predicate + '\nnamespace kartpad_repack {\n' + helpers + implementation + r'''
}}
using namespace aurora::gx;
struct Check {
  Check(bool ok, const char* expression, int line) {
    if (!ok) throw std::runtime_error(std::string(expression)+" at "+std::to_string(line));
  }
  template<class T> Check& operator<<(const T&) { return *this; }
};
#define TEST(suite, name) void name()
#define EXPECT_EQ(a,b) Check((a)==(b), #a " == " #b, __LINE__)
#define ASSERT_EQ(a,b) EXPECT_EQ(a,b)
''' + golden + (ROOT / 'tests/native/vertex_repack_bench.cpp').read_text() + '\nint main(int argc, char**) {\n' + '\n'.join(name+'();' for name in tests) + r'''
ShaderConfig config{};
config.attrs[GX_VA_PNMTXIDX]=attr(GX_DIRECT,1,GX_U8,0);config.vtxStride=48;
EXPECT_EQ(kartpad_uses_vertex_pnmtx(config),false);
experiment=true;EXPECT_EQ(kartpad_uses_vertex_pnmtx(config),true);
for(unsigned stride : {0u,1u,3u,7u,47u}) {config.vtxStride=stride;EXPECT_EQ(kartpad_uses_vertex_pnmtx(config),false);}
config.vtxStride=48;
for(unsigned line : {1u,2u,3u}) {config.lineMode=line;EXPECT_EQ(kartpad_uses_vertex_pnmtx(config),false);}
config.lineMode=0;config.kartpadConstantPnMtx=1;EXPECT_EQ(kartpad_uses_vertex_pnmtx(config),false);
config.kartpadConstantPnMtx=0;
for(unsigned offset : {1u,2u,3u,48u}) {config.attrs[GX_VA_PNMTXIDX].offset=offset;EXPECT_EQ(kartpad_uses_vertex_pnmtx(config),false);}
config.attrs[GX_VA_PNMTXIDX].offset=44;EXPECT_EQ(kartpad_uses_vertex_pnmtx(config),true);
config.attrs[GX_VA_PNMTXIDX].attrType=GX_NONE;EXPECT_EQ(kartpad_uses_vertex_pnmtx(config),false);
std::cout << "Repack golden tests and vertex attribute eligibility passed\n";
if (argc > 1) benchmark();
}
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=GX / 'lib/gx/kartpad_vertex_repack.cpp')
    parser.add_argument('--benchmark', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='kartpad-repack-') as directory:
        cpp, exe = Path(directory) / 'repack.cpp', Path(directory) / 'repack'
        cpp.write_text(source(args.source))
        flags = ['-O3'] if args.benchmark else ['-O1', '-g', '-fsanitize=address,undefined', '-fno-sanitize-recover=all']
        subprocess.run([os.environ.get('CXX', 'clang++'), '-std=c++20', '-DTARGET_PC', *flags,
                        '-I'+str(GX / 'include'), str(cpp), '-o', str(exe)], check=True)
        subprocess.run([str(exe), *(['benchmark'] if args.benchmark else [])], check=True)


if __name__ == '__main__':
    main()
