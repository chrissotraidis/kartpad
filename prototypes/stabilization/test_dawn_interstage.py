#!/usr/bin/env python3
"""Compile the actual control/candidate Vulkan limit branches, without a GPU.

Usage: test_dawn_interstage.py UNPATCHED_DAWN PATCHED_DAWN
Only the surrounding Dawn types/error macro are mocked; the check and reported
limit are extracted verbatim. Both directions and all 0..256 component pairs
are exercised, including under-floor negative controls and non-ImgTec parity.
"""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile


def branch(root):
    source = (root / 'src/dawn/native/vulkan/PhysicalDeviceVk.cpp').read_text()
    start = source.index('    // Reserve 4 components for the SPIR-V builtin `position`.')
    end = source.index('    CHECK_AND_SET_V1_MAX_LIMIT(maxComputeSharedMemorySize', start)
    return source[start:end]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('control', type=Path)
    parser.add_argument('candidate', type=Path)
    args = parser.parse_args()
    code = r'''
#include <algorithm>
#include <cassert>
#include <cstdint>
#include <cstdio>
namespace gpu_info { bool IsImgTec(uint32_t vendor) { return vendor == 0x1010; } }
uint32_t vendor;
uint32_t baseVariables = 16;
uint32_t GetVendorId() { return vendor; }
struct Limits { struct { uint32_t maxInterStageShaderVariables; } v1; };
struct VkLimits { uint32_t maxVertexOutputComponents, maxFragmentInputComponents; };
#define DAWN_INTERNAL_ERROR(message) false
'''
    for name, root in [('control', args.control), ('candidate', args.candidate)]:
        code += ('bool ' + name + '(VkLimits vkLimits, Limits* limits) {\n'
                 'const Limits baseLimits{{baseVariables}};\n' + branch(root) + '\nreturn true;\n}\n')
    reflection = (args.candidate / 'src/dawn/native/ShaderModule.cpp').read_text()
    # Exercise the production vertex and fragment variable-count predicate.
    # This is a bounded reflection-policy test, not a mock 14-variable device.
    predicates = re.findall(r'if \((metadata->totalInterStageShaderVariables > maxInterStageShaderVariables)\)', reflection)
    assert len(predicates) == 2, 'Vertex/fragment reflection changed; review the fixture'
    code += ('bool countRejected(uint32_t count, uint32_t maxInterStageShaderVariables) {\n'
             'struct Metadata { uint32_t totalInterStageShaderVariables; } value{count};\n'
             'const auto* metadata = &value;\nreturn ' + predicates[0] + ';\n}\n')
    code += r'''
int main() {
    uint64_t cases = 0;
    for (baseVariables = 15; baseVariables <= 16; ++baseVariables) {
    for (vendor = 0; vendor <= 1; ++vendor) {
        const uint32_t savedVendor = vendor;
        vendor = savedVendor ? 0x1010 : 0x5143;
        for (uint32_t vertex = 0; vertex <= 256; ++vertex) {
            for (uint32_t fragment = 0; fragment <= 256; ++fragment) {
                Limits before{{0xdead}}, after{{0xdead}};
                const bool a = control({vertex, fragment}, &before);
                const bool b = candidate({vertex, fragment}, &after);
                const uint32_t controlFloor = baseVariables * 4 + 8;
                const uint32_t candidateFloor = savedVendor ? 64u : controlFloor;
                assert(a == (vertex >= controlFloor && fragment >= controlFloor));
                assert(b == (vertex >= candidateFloor && fragment >= candidateFloor));
                if (!savedVendor) assert(a == b && before.v1.maxInterStageShaderVariables ==
                                                  after.v1.maxInterStageShaderVariables);
                if (a) assert(before.v1.maxInterStageShaderVariables ==
                              std::min(vertex, fragment) / 4 - 2);
                if (b) assert(after.v1.maxInterStageShaderVariables ==
                              std::min(vertex, fragment) / 4 - 2);
                if (!b) assert(after.v1.maxInterStageShaderVariables == 0xdead);
                ++cases;
            }
        }
        vendor = savedVendor;
    }
    }
    baseVariables = 16;
    vendor = 0x1010;
    Limits result{{0}};
    assert(!control({64,64}, &result));
    assert(candidate({64,64}, &result) && result.v1.maxInterStageShaderVariables == 14);
    assert(!countRejected(10, result.v1.maxInterStageShaderVariables));
    assert(!countRejected(14, result.v1.maxInterStageShaderVariables));
    assert(countRejected(15, result.v1.maxInterStageShaderVariables));
    assert(!candidate({63,256}, &result) && !candidate({256,63}, &result));
    std::printf("PASS: %llu control/candidate component pairs; 64 -> 14; eight reserved components; non-ImgTec parity; production reflection predicate accepts 10/14, rejects 15\n",
                static_cast<unsigned long long>(cases));
}
'''
    with tempfile.TemporaryDirectory(prefix='kartpad-interstage-') as directory:
        source = Path(directory) / 'test.cpp'
        source.write_text(code)
        executable = Path(directory) / 'test'
        subprocess.run(['clang++', '-std=c++20', '-O1', '-fsanitize=address,undefined',
                        str(source), '-o', str(executable)], check=True)
        subprocess.run([str(executable)], check=True)


if __name__ == '__main__':
    main()
