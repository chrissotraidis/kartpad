#!/usr/bin/env python3
"""Add notices to the audited 0.5.0 candidates without changing app payloads.

This prepares local assets; it neither approves acceptance nor publishes them.
The historical public-release packagers retain their original contracts.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import shutil
import stat
import subprocess
import tarfile
import zipfile

REPO = Path(__file__).resolve().parents[1]


def identity(data):
    return {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}


def checked(path, expected):
    data = path.read_bytes()
    if identity(data) != expected:
        raise ValueError(f'Candidate identity differs: {path.name}')
    return data


def safe_name(name):
    p = PurePosixPath(name)
    return bool(name) and not p.is_absolute() and '..' not in p.parts


def write_zip(output, extras, original=None):
    """Preserve every original entry, its mode and its bytes, including symlinks."""
    expected = {}
    with zipfile.ZipFile(output, 'x', zipfile.ZIP_DEFLATED, compresslevel=9) as target:
        if original:
            with zipfile.ZipFile(original) as source:
                for entry in source.infolist():
                    if not safe_name(entry.filename) or entry.filename in expected or entry.filename in extras:
                        raise ValueError('Unsafe, duplicate or replaced original ZIP entry')
                    data = source.read(entry)
                    expected[entry.filename] = (identity(data), entry.external_attr)
                    target.writestr(entry, data)
        for name, data in sorted(extras.items()):
            if not safe_name(name):
                raise ValueError('Unsafe notice path')
            entry = zipfile.ZipInfo(name, (2020, 1, 1, 0, 0, 0))
            entry.create_system = 3
            entry.external_attr = (stat.S_IFREG | 0o644) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            target.writestr(entry, data)
            expected[name] = (identity(data), entry.external_attr)
    with zipfile.ZipFile(output) as archive:
        actual = {e.filename: (identity(archive.read(e)), e.external_attr) for e in archive.infolist()}
        if actual != expected or len(archive.infolist()) != len(expected):
            raise ValueError('ZIP readback differs in bytes, coverage or modes')
    return len(expected)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('record', 'source-record', 'artifacts', 'source', 'android-build', 'ios-build', 'mac-build', 'dolphin', 'dawn', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Output directory already exists; preserve prior assets')
    record = json.loads(args.record.read_text())
    source_record = json.loads(args.source_record.read_text())
    checked(args.source, {k: source_record[k] for k in ('bytes', 'sha256')})
    for name, expected in record['artifacts'].items():
        if PurePosixPath(name).name != name:
            parser.error('Input artifact name must be a basename')
        checked(args.artifacts / name, expected)
    def artifact(suffix):
        matches = [name for name in record['artifacts'] if name.endswith(suffix)]
        if len(matches) != 1:
            parser.error(f'Expected exactly one {suffix} input artifact')
        return args.artifacts / matches[0]
    with tarfile.open(args.source) as archive:
        manifest = json.load(archive.extractfile('SOURCE-MANIFEST.json'))
        if manifest['candidateArtifacts'] != record['artifacts'] or manifest['sourceRevision'] != record['source']:
            parser.error('Source delivery does not bind these candidates')

    extras = {name: (REPO / path).read_bytes() for name, path in {
        'LICENSE': 'LICENSE', 'LICENSES/GPL-3.0.txt': 'LICENSES/GPL-3.0.txt',
        'INSTALL_ANDROID.md': 'docs/INSTALL_ANDROID.md', 'INSTALL_IPA.md': 'docs/INSTALL_IPA.md',
        'INSTALL_MACOS.md': 'docs/INSTALL_MACOS.md', 'MULTIPLAYER.md': 'docs/MULTIPLAYER.md',
        'RELEASE_NOTES.md': 'docs/releases/v0.5.0.md', 'SOURCE_AND_REBUILD.md': 'docs/releases/v0.5.0-source.md',
        'RIGHTS_AND_LICENSES.md': 'RIGHTS_AND_LICENSES.md', 'THIRD_PARTY_NOTICES.md': 'THIRD_PARTY_NOTICES.md',
        'dependencies.lock.json': 'dependencies.lock.json',
        'ThirdPartyLicenses/WiiCompiled-GPL-3.0.txt': 'vendor/runtimes/android/LICENSE',
        'ThirdPartyLicenses/Aurora-MIT.txt': 'vendor/runtimes/android/aurora-main/LICENSE',
        'ThirdPartyLicenses/CryptoPP.txt': 'vendor/runtimes/android/runtime/third_party/cryptopp/License.txt',
        'ThirdPartyLicenses/PugiXML-MIT.txt': 'vendor/runtimes/android/runtime/third_party/pugixml/LICENSE.md',
        'ThirdPartyLicenses/TOML11-MIT.txt': 'vendor/runtimes/android/runtime/third_party/toml11/LICENSE',
        'ThirdPartyLicenses/Mbed-TLS.txt': '.android-bootstrap/dependencies/mbedtls-4.1.1/LICENSE',
        'ThirdPartyLicenses/Minizip-NG.txt': '.android-bootstrap/dependencies/minizip-ng-55db144e03027b43263e5ebcb599bf0878ba58de/LICENSE',
    }.items()}
    for label, relative in {
        'Abseil-Apache-2.0.txt': 'abseil-cpp-src/LICENSE', 'FreeType.txt': 'freetype-src/LICENSE.TXT',
        'FreeType-FTL.txt': 'freetype-src/docs/FTL.TXT', 'Tracy-BSD-3-Clause.txt': 'tracy-src/LICENSE',
        'fmt-MIT.txt': 'fmt-src/LICENSE', 'imgui-MIT.txt': 'imgui-src/LICENSE.txt',
        'libpng.txt': 'png-src/LICENSE', 'xxHash-BSD-2-Clause.txt': 'xxhash-src/LICENSE',
        'zstd-BSD.txt': 'zstd-src/LICENSE',
    }.items():
        data = [(build / '_deps' / relative).read_bytes() for build in (args.android_build, args.ios_build, args.mac_build)]
        if data[0] != data[1] or data[0] != data[2]:
            parser.error(f'Platform dependency notices differ: {label}')
        extras['ThirdPartyLicenses/' + label] = data[0]
    sdl = (args.ios_build / '_deps/sdl-src/LICENSE.txt').read_bytes()
    if sdl != (args.mac_build / '_deps/sdl-src/LICENSE.txt').read_bytes():
        parser.error('Apple SDL notices differ')
    with zipfile.ZipFile(REPO / '.android-bootstrap/dependencies/SDL3-devel-3.4.4-android.zip') as archive:
        if archive.read('LICENSE.txt') != sdl:
            parser.error('Android SDL notice differs')
    extras['ThirdPartyLicenses/SDL3-Zlib.txt'] = sdl
    extras['ThirdPartyLicenses/FreeType-Credit.txt'] = b'KartPad uses FreeType (https://freetype.org), under the included FreeType Project License.\n'
    # Preserve the notices embedded in these headers, without shipping code in
    # the notices bundle. The complete headers are in the source delivery.
    aurora = REPO / 'vendor/runtimes/android/aurora-main'
    for label, path, start, end in (
        ('magic_enum-MIT.txt', aurora / 'include/magic_enum.hpp', b'// Licensed under', b'\n#ifndef'),
        ('libogc-SRAM.txt', aurora / 'lib/card/SRAM.hpp', b'/*---', b'*/'),
        ('sse2neon-MIT.txt', args.mac_build.parent / 'macos-source/third_party/sse2neon/sse2neon.h', b'/*', b'*/'),
    ):
        data = path.read_bytes()
        first = data.index(start)
        last = data.index(end, first)
        extras['ThirdPartyLicenses/' + label] = data[first:last + (2 if end == b'*/' else 0)] + b'\n'
    lock = json.loads(extras['dependencies.lock.json'])
    dolphin_pin = next(d['commit'] for d in lock['dependencies'] if d['name'] == 'Dolphin')
    for label, path in {'Dolphin-COPYING.txt': 'COPYING', 'Dolphin-Externals.md': 'Externals/licenses.md'}.items():
        extras['ThirdPartyLicenses/' + label] = subprocess.check_output(['git', '-C', str(args.dolphin), 'show', dolphin_pin + ':' + path])
    dawn = json.loads((args.dawn / 'KARTPAD-DAWN.json').read_text())
    dawn_lock = next(d for d in lock['dependencies'] if d['name'] == 'Dawn prebuilt')
    if dawn['dawnVersionIdentity'] != dawn_lock['androidDawnVersionIdentity']:
        parser.error('Dawn notices do not identify the pinned dependency')
    for name, expected in dawn['files'].items():
        if name.startswith('LICENSES/'):
            if not safe_name(name):
                parser.error('Unsafe Dawn license path')
            extras['ThirdPartyLicenses/Dawn/' + name.removeprefix('LICENSES/')] = checked(args.dawn / name, expected)
    packaging_commit = subprocess.check_output(['git', '-C', str(REPO), 'rev-parse', 'HEAD'], text=True).strip()
    if subprocess.check_output(['git', '-C', str(REPO), 'status', '--porcelain'], text=True).strip():
        parser.error('Commit packaging source and notices before generating assets')
    provenance = {
        'schemaVersion': 1, 'status': 'candidate_not_release_approval', 'version': '0.5.0',
        'compiledSourceCommit': record['source'], 'packagingSourceCommit': packaging_commit,
        'inputArtifacts': record['artifacts'], 'sourceArchive': identity(args.source.read_bytes()),
        'notices': {name: identity(data) for name, data in sorted(extras.items())},
        'acceptance': 'See release draft and validation records. Packaging does not approve physical or gameplay acceptance.',
    }
    extras['KartPadCoordinatedProvenance.json'] = (json.dumps(provenance, indent=2, sort_keys=True) + '\n').encode()
    args.output.mkdir(parents=True)
    write_zip(args.output / 'KartPad-v0.5.0-notices.zip', extras)
    for original, target in {
        artifact('.ipa'): 'KartPad-v0.5.0-ios-unsigned.ipa',
        artifact('.zip'): 'KartPad-v0.5.0-macos-arm64.zip',
    }.items():
        write_zip(args.output / target, extras, original)
    for original, target in {
        artifact('.apk'): 'KartPad-v0.5.0-android-arm64.apk',
        args.source: 'KartPad-v0.5.0-source.tar.gz',
    }.items():
        shutil.copyfile(original, args.output / target)
        if identity(original.read_bytes()) != identity((args.output / target).read_bytes()):
            parser.error('Copied asset readback differs')
    result = {p.name: identity(p.read_bytes()) for p in sorted(args.output.iterdir())}
    (args.output / 'SHA256SUMS.txt').write_text(''.join(f'{v["sha256"]}  {k}\n' for k, v in result.items()))
    print(json.dumps({'status': provenance['status'], 'packagingCommit': packaging_commit, 'artifacts': result}, indent=2))


if __name__ == '__main__':
    main()
