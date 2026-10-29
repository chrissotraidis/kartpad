"""Execute maintained selector expressions and interpolation readers with synthetic bytes.

The GPU regression in the Android runtime checks the full FIFO/shader/readback path.
This portable companion checks every selector byte in all four staged source trees.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

from runtime_sources import PLATFORMS, runtime_source


def function_source(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    depth = 1
    end = opening + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]


def shader_expression(source, attribute):
    # Use the expression emitted by the real attr_load branch. The FIFO fetch is
    # replaced by its byte result; no matrix-selection logic is reimplemented.
    branch = source[source.index("auto attr_load("):].split(f"case {attribute}:", 1)[1]
    expression = re.search(r'return fmt::format\("([^"]+)"', branch)[1]
    expression = expression.replace("raw_fetch_u8_1(&{}, {})", "raw")
    if "{" in expression or "}" in expression:
        raise AssertionError("Unrecognized selector expression")
    return expression


def probe_source(platform):
    shader = runtime_source(platform, "aurora-main/lib/gx/shader.cpp")
    processor = runtime_source(platform, "aurora-main/lib/gx/command_processor.cpp")
    position = shader_expression(shader, "GX_VA_PNMTXIDX")
    texture = shader_expression(shader, "GX_VA_TEX7MTXIDX")
    mask = function_source(processor, "static uint16_t pn_mtx_mask(")
    usage = function_source(processor, "static PnMtxUsage pn_mtx_usage(")
    attribute_check = ""
    if platform == "android":
        attribute = re.search(r"let in_pnmtxidx = ([^;]*pnmtx_attribute[^;]+);", shader)[1]
        attribute_check = f"assert(({attribute}) == expectedSlot);"
    return r'''
#include <cassert>
#include <cstddef>
#include <cstdint>
using HashType = uint64_t;
constexpr unsigned MaxPnMtx = 10;
constexpr unsigned GX_VA_PNMTXIDX = 0;
constexpr unsigned GX_DIRECT = 1;
struct { unsigned vtxDesc[1]{GX_DIRECT}; unsigned currentPnMtx = 0; } g_gxState;
// Stable test hash, used only to compare identities for the same effective stream.
struct Hasher {
  uint64_t value = 1469598103934665603ULL;
  template<class T> void update(T input) { value = (value ^ input) * 1099511628211ULL; }
  uint64_t digest() const { return value; }
};
struct PnMtxUsage { uint16_t mask = 0; HashType topologySignature = 0; };
''' + "#include <algorithm>\n" + mask + "\n" + usage + f'''
unsigned position(unsigned raw) {{ return {position}; }}
unsigned texture(unsigned raw) {{ return {texture}; }}
int main() {{
  for (unsigned raw = 0; raw < 256; ++raw) {{
    const auto selector = raw & 0x3f;
    const auto expectedSlot = selector / 3;
    assert(position(raw) == expectedSlot);
    assert(texture(raw) == selector);
    const uint32_t pnmtx_attribute = 0xa5ff0000u | raw;
    {attribute_check}
    // Two vertices, with non-selector bytes between them, exercise the stride.
    const uint8_t vertices[] = {{uint8_t(raw), 255, 27, 255}};
    const uint8_t canonical[] = {{uint8_t(selector), 255, 27, 255}};
    const uint16_t expectedMask = (expectedSlot < 10 ? 1u << expectedSlot : 0u) | (1u << 9);
    assert(pn_mtx_mask(vertices, 2, 2) == expectedMask);
    const auto result = pn_mtx_usage(vertices, 2, 2);
    assert(result.mask == expectedMask);
    assert(result.topologySignature == pn_mtx_usage(canonical, 2, 2).topologySignature);
  }}
  g_gxState.vtxDesc[0] = 0;
  g_gxState.currentPnMtx = 3;
  assert(pn_mtx_mask(nullptr, 2, 2) == 8);
  assert(pn_mtx_usage(nullptr, 2, 2).mask == 8);
  assert(pn_mtx_usage(nullptr, 2, 2).topologySignature == 0);
}}
'''


class MatrixSelectorTests(unittest.TestCase):
    def test_all_maintained_platforms_ignore_unused_selector_bits(self):
        compiler = shutil.which("clang++") or shutil.which("g++")
        self.assertIsNotNone(compiler, "requires a C++ compiler")
        for platform in PLATFORMS:
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as directory:
                source = Path(directory) / "probe.cpp"
                source.write_text(probe_source(platform))
                binary = Path(directory) / "probe"
                subprocess.run([compiler, "-std=c++20", "-fsanitize=address,undefined",
                                "-fno-omit-frame-pointer", str(source), "-o", str(binary)],
                               check=True, capture_output=True, text=True)
                subprocess.run([str(binary)], check=True, capture_output=True, text=True)


if __name__ == "__main__":
    unittest.main()
