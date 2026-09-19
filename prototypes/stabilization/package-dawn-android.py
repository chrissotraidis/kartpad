#!/usr/bin/env python3
"""Prepare a portable, audited Dawn dependency archive; does not publish it."""
import argparse
import gzip
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
IDENTITY = 'b0fd045b0a694eb07ac3fcf0d741f8697b935856'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('install', type=Path)
    parser.add_argument('source', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--strip', type=Path, required=True, help='Pinned Android NDK llvm-strip')
    args = parser.parse_args()
    if (args.source / 'KARTPAD_DAWN_VERSION').read_text().strip() != IDENTITY:
        parser.error('source does not carry the reviewed Dawn identity')
    if args.output.exists():
        parser.error('output already exists')
    spec = importlib.util.spec_from_file_location('dawn_dependencies', ROOT / 'prototypes/stabilization/verify-dawn-dependencies.py')
    dependencies = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(dependencies)
    dependency_records = dependencies.verify(args.source)
    files = {}
    for folder in ('include', 'lib/cmake/Dawn'):
        for path in sorted((args.install / folder).rglob('*')):
            if path.is_symlink():
                parser.error('unexpected symlink in install tree')
            if path.is_file():
                data = path.read_bytes()
                if path.name == 'DawnTargets.cmake':
                    data, count = re.subn(rb'/[^;"\n]+/sysroot/usr/lib/aarch64-linux-android/28/liblog\.so',
                                          b'log', data)
                    if count != 1:
                        parser.error('expected exactly one Android liblog relocation')
                files[path.relative_to(args.install).as_posix()] = data
    library = (args.install / 'lib/libwebgpu_dawn.a').read_bytes()
    with tempfile.TemporaryDirectory() as directory:
        stripped = Path(directory) / 'libwebgpu_dawn.a'
        stripped.write_bytes(library)
        subprocess.run([str(args.strip.resolve()), '--strip-debug', str(stripped)], check=True)
        files['lib/libwebgpu_dawn.a'] = stripped.read_bytes()
    for path in sorted((ROOT / 'tools/renderer-probe/licenses').glob('*.txt')):
        files['LICENSES/' + path.name] = path.read_bytes()
    files['LICENSES/Dawn-LICENSE'] = (args.source / 'LICENSE').read_bytes()
    for dependency in dependency_records:
        folder = args.source / dependency['path']
        notices = [path for path in folder.iterdir() if path.is_file() and
                   path.name.upper().startswith(('LICENSE', 'COPYING', 'COPYRIGHT', 'NOTICE'))]
        for subfolder in ('LICENSES', 'licenses'):
            if (folder / subfolder).is_dir():
                notices.extend(path for path in (folder / subfolder).rglob('*') if path.is_file())
        for path in notices:
            if path.is_symlink() or path.stat().st_size > 1_000_000:
                parser.error('unexpected dependency notice')
            files['LICENSES/' + path.relative_to(args.source).as_posix()] = path.read_bytes()
    for path in sorted((ROOT / 'prototypes/stabilization/dependencies').glob('dawn-*.patch')):
        files['build-recipe/' + path.relative_to(ROOT).as_posix()] = path.read_bytes()
    for name in ('prototypes/stabilization/pin-dawn-version.py',
                 'prototypes/stabilization/verify-dawn-dependencies.py',
                 'prototypes/stabilization/build-dawn-android.sh', 'cmake/dawn-kartpad-ci.cmake'):
        files['build-recipe/' + name] = (ROOT / name).read_bytes()
    for name, data in files.items():
        if b'/Users/' in data or b'/usr/local/lib/android/sdk' in data:
            parser.error(f'host path remains in {name}')
    record = {
        'schemaVersion': 1, 'dawnVersionIdentity': IDENTITY,
        'upstreamRevision': '13abc3bc8ea2d3c2050f9e77a12d012108ceee24',
        'upstreamSourceArchiveSHA256': '713bea5b92d4f6c5175752fd7cbf1c3c5ce36598ff5dd98685d8a1216614ebba',
        'upstreamSourceURL': 'https://github.com/google/dawn/archive/13abc3bc8ea2d3c2050f9e77a12d012108ceee24.tar.gz',
        'androidABI': 'arm64-v8a', 'androidAPI': 28, 'ndk': '29.0.14206865',
        'sourceDependencies': dependency_records,
        'originalLibrarySHA256': sha(library),
        'packaging': 'Remove debug sections only; relocate Android liblog to logical log. Original symbols retained privately.',
        'buildRecipe': 'prototypes/stabilization/build-dawn-android.sh',
        'files': {name: {'bytes': len(data), 'sha256': sha(data)} for name, data in sorted(files.items())},
    }
    files['KARTPAD-DAWN.json'] = (json.dumps(record, indent=2, sort_keys=True) + '\n').encode()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('xb') as stream, gzip.GzipFile(filename='', mode='wb', fileobj=stream, mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w', format=tarfile.USTAR_FORMAT) as archive:
            for name, data in sorted(files.items()):
                info = tarfile.TarInfo(name)
                info.size = len(data)
                info.mode = 0o644
                archive.addfile(info, io.BytesIO(data))
    with tarfile.open(args.output) as archive:
        if archive.getnames() != sorted(files):
            raise RuntimeError('archive member coverage differs')
        for member in archive:
            if not member.isfile() or archive.extractfile(member).read() != files[member.name]:
                raise RuntimeError('archive readback differs')
    print(json.dumps({'archive': str(args.output), 'bytes': args.output.stat().st_size,
                      'sha256': sha(args.output.read_bytes()), 'files': len(files),
                      'librarySHA256': sha(files['lib/libwebgpu_dawn.a']),
                      'targetsSHA256': sha(files['lib/cmake/Dawn/DawnTargets.cmake'])}, indent=2))


if __name__ == '__main__':
    main()
