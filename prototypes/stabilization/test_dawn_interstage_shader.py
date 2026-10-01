#!/usr/bin/env python3
"""Test actual largest GX WGSL generation on Dawn's Null backend.

Requires an existing macOS Dawn package and header-only test dependencies.
No app, translated game inputs, emulator or hardware adapter is used. The
production generator is copied mechanically, replacing only its module return
with the generated WGSL string; the emitted source is not hand-reimplemented.
The cached host backend reifies a request of 14 to 16. This is shader/pipeline
validation, not proof of a 14-variable device or PowerVR driver execution.
"""
import argparse
import hashlib
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('aurora', 'dawn', 'abseil', 'fmt', 'xxhash', 'tracy', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    shader = args.aurora / 'lib/gx/shader.cpp'
    original = shader.read_text()
    signature = 'wgpu::ShaderModule build_shader(const ShaderConfig& config) noexcept'
    assert original.count(signature) == 1
    end = original.index('  wgpu::ShaderSourceWGSL wgslDescriptor{};')
    transformed = original[:end].replace(signature, 'std::string build_shader_for_test(const ShaderConfig& config) noexcept')
    transformed += '  return shaderSource;\n}\n} // namespace aurora::gx\n'
    generated = args.output / 'shader_generator.cpp'
    generated.write_text(transformed)
    executable = args.output / 'interstage_shader'
    command = ['clang++', '-std=c++20', '-O1', '-DFMT_HEADER_ONLY', '-DXXH_INLINE_ALL',
               '-DAURORA', '-DTARGET_PC', '-ffunction-sections', '-fdata-sections',
               str(ROOT / 'prototypes/stabilization/dawn_interstage_shader.cpp'),
               str(generated), str(args.aurora / 'lib/gx/shader_info.cpp')]
    for folder in (args.aurora / 'include', args.aurora / 'lib', args.aurora / 'lib/gx',
                   args.dawn / 'include', args.abseil, args.fmt / 'include',
                   args.xxhash, args.tracy / 'public'):
        command += ['-I', str(folder)]
    command += [str(args.dawn / 'lib/libwebgpu_dawn.a'), '-Wl,-dead_strip']
    for framework in ('Foundation', 'IOSurface', 'QuartzCore', 'Cocoa', 'IOKit', 'Metal'):
        command += ['-framework', framework]
    command += ['-o', str(executable)]
    subprocess.run(command, check=True)
    wgsl = args.output / 'largest.wgsl'
    subprocess.run([str(executable), str(wgsl)], check=True)
    for path in (shader, args.aurora / 'lib/gx/shader_info.cpp', wgsl):
        print(path.name, hashlib.sha256(path.read_bytes()).hexdigest())


if __name__ == '__main__':
    main()
