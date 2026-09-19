#!/usr/bin/env python3
"""Link the ROM-free GPU probe against a verified existing Mac Ninja build."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[2]


def block(text, prefix):
    start = text.index(prefix)
    end = text.index('\n\n', start)
    return dict(line.strip().split(' = ', 1) for line in text[start:end].splitlines()[1:]
                if ' = ' in line)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    build, output = args.build.resolve(), args.output.resolve()
    ninja = (build / 'build.ninja').read_text()
    compile_flags = block(ninja, 'build aurora-build/CMakeFiles/aurora_gx.dir/lib/gfx/common.cpp.o:')
    link_flags = block(ninja, 'build KartPadDual:')
    includes = shlex.split(compile_flags['INCLUDES'])
    source = next(Path(item[2:]).parent.parent for item in includes
                  if item.startswith('-I') and item.endswith('/aurora-main/include'))
    spec = importlib.util.spec_from_file_location('maintained', ROOT / 'scripts/stage-maintained-runtime.py')
    maintained = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(maintained)
    maintained.verify(ROOT, 'macos', source)
    subprocess.run(['cmake', '--build', str(build), '--target', 'aurora_gx', 'aurora_core',
                    'aurora_pad', 'aurora_si', 'aurora_vi', 'aurora_mtx', '-j4'], check=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    # Retain renderer dependencies and framework order, excluding translated game archives.
    libraries = [item for item in shlex.split(link_flags['LINK_LIBRARIES'])
                 if not Path(item).name.startswith('libmkw_')]
    argv = ['clang++', *shlex.split(compile_flags['DEFINES']), *includes,
            *shlex.split(compile_flags['FLAGS']), '-I' + str(source / 'aurora-main/lib'),
            str(ROOT / 'prototypes/stabilization/aurora_batch_probe.cpp'),
            *libraries, '-o', str(output)]
    subprocess.run(argv, cwd=build, check=True)
    revision = subprocess.check_output(['git', 'rev-parse', 'HEAD'],
                                       cwd=ROOT / 'vendor/runtimes/macos', text=True).strip()
    runtime = ROOT / 'vendor/runtimes/macos'
    source_hash = hashlib.sha256()
    for name, path in sorted(maintained.maintained_files(runtime).items()):
        source_hash.update(name.encode() + b'\0')
        source_hash.update(path.read_bytes())
    record = {'runtime_revision': revision,
              'runtime_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain'], cwd=runtime)),
              'maintained_source_sha256': source_hash.hexdigest(),
              'sha256': hashlib.sha256(output.read_bytes()).hexdigest(), 'command': argv}
    output.with_suffix('.build.json').write_text(json.dumps(record, indent=2) + '\n')
    print(f'Built actual Aurora probe: {output}')


if __name__ == '__main__':
    main()
