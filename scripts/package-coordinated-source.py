#!/usr/bin/env python3
"""Compose a candidate source delivery without relabeling its compiled artifacts."""
import argparse
import gzip
import hashlib
import io
import json
import posixpath
from pathlib import Path, PurePosixPath
import tarfile
import zipfile

REPO = Path(__file__).resolve().parents[1]
PRIOR_SHA256 = '0d1d601eea44bb75db24a1ee0cdc765e4554b51e168ad46155ef1b8cd0a2056e'
RETAIN_FILES = {
    'KartPad-dolphin-dependency-source.tar.gz', 'KartPad-profile-tool-source.tar.gz',
    'android-source-reconstruction.md', 'cmake-dependencies.json', 'dawn-dependencies.json',
    'dependency-archives-manifest.json', 'dolphin-dependency-layout.json',
    'dolphin-dependency-source-manifest.json', 'maven-source-manifest.json',
    'profile-source-manifest.json',
}
RETAIN_PREFIXES = ('dependency-archives/', 'dawn-dependency-archives/', 'maven-source/')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def core_fingerprint(core):
    with tarfile.open(fileobj=io.BytesIO(core), mode='r:gz') as archive:
        metadata = json.load(archive.extractfile('metadata/kartpad.json'))
        members = archive.getnames()
        if len(members) != len(set(members)):
            raise ValueError('duplicate core source member')
        expected = {'metadata/kartpad.json', 'restore-source-git.py'}
        hashes = {}
        def visit(node, prefix=''):
            if node['label'] != 'kartpad' + ('/' + prefix.rstrip('/') if prefix else ''):
                raise ValueError('unexpected core source label')
            for entry in node['entries']:
                path = PurePosixPath(entry['path'])
                if path.is_absolute() or '..' in path.parts or '.git' in path.parts:
                    raise ValueError('unsafe core source path')
                if entry.get('submodule'):
                    visit(entry['source'], prefix + entry['path'] + '/')
                else:
                    name = 'source/' + node['label'] + '/' + entry['path']
                    expected.add(name)
                    member = archive.getmember(name)
                    if not member.isfile() and not member.issym():
                        raise ValueError('unexpected core source member type')
                    if member.issym():
                        resolved = posixpath.normpath(posixpath.join(posixpath.dirname(name), member.linkname))
                        if member.linkname.startswith('/') or not resolved.startswith('source/' + node['label'] + '/'):
                            raise ValueError('escaping core source symlink')
                    data = member.linkname.encode() if member.issym() else archive.extractfile(member).read()
                    if sha(data) != entry['sha256'] or len(data) != entry['bytes']:
                        raise ValueError('core source member differs from metadata')
                    hashes[prefix + entry['path']] = sha(data)
        visit(metadata)
        if set(members) != expected:
            raise ValueError('core source manifest coverage differs')
        if sha(archive.extractfile('restore-source-git.py').read()) != hashes['scripts/restore-source-git.py']:
            raise ValueError('restoration helper differs from compilation source')
        digest = hashlib.sha256()
        for name, value in sorted(hashes.items()):
            encoded = name.encode()
            digest.update(len(encoded).to_bytes(8, 'big'))
            digest.update(encoded)
            digest.update(bytes.fromhex(value))
        return metadata['commit'], {'files': len(hashes), 'sha256': digest.hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('prior', 'core', 'record', 'artifacts', 'output'):
        parser.add_argument('--' + name, type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('output already exists')
    record = json.loads(args.record.read_text())
    core = args.core.read_bytes()
    revision, fingerprint = core_fingerprint(core)
    if revision != record['source']:
        parser.error('core source revision does not identify the candidate')
    for name, expected in record['artifacts'].items():
        if PurePosixPath(name).name != name:
            parser.error('artifact name must be a basename')
        data = (args.artifacts / name).read_bytes()
        if len(data) != expected['bytes'] or sha(data) != expected['sha256']:
            parser.error('artifact identity differs from reviewed candidate')
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            if name.endswith('.apk'):
                manifest = json.loads(archive.read('assets/kartpad-build.json'))
            elif name.endswith('.ipa'):
                manifest = json.loads(archive.read('Payload/KartPad.app/kartpad-build.json'))
            elif name.endswith('.zip'):
                manifest = json.loads(archive.read('KartPad.app/Contents/Resources/Runtime/build-fingerprint.json'))
                if manifest['SourceCommit'] != revision:
                    parser.error('Mac artifact has a different compilation source')
                continue
            else:
                continue
            if manifest['source_revision'] != revision or manifest['source_dirty'] or manifest['kartpad_source'] != fingerprint:
                parser.error('embedded app source fingerprint differs from source delivery')
    prior = args.prior.read_bytes()
    if sha(prior) != PRIOR_SHA256:
        parser.error('prior source delivery identity differs')
    files = {}
    with tarfile.open(fileobj=io.BytesIO(prior), mode='r:gz') as archive:
        old = json.load(archive.extractfile('SOURCE-MANIFEST.json'))
        names = archive.getnames()
        if len(names) != len(set(names)) or set(names) != set(old['files']) | {'SOURCE-MANIFEST.json'}:
            parser.error('prior manifest coverage differs')
        for member in archive.getmembers():
            name = member.name
            if not member.isfile() or name.startswith('/') or '..' in PurePosixPath(name).parts:
                parser.error('unsafe prior source member')
            if name == 'SOURCE-MANIFEST.json':
                continue
            data = archive.extractfile(member).read()
            if len(data) != old['files'][name]['bytes'] or sha(data) != old['files'][name]['sha256']:
                parser.error('prior source member failed integrity check')
            if name in RETAIN_FILES or name.startswith(RETAIN_PREFIXES):
                files[name] = data
    files['KartPad-core-source.tar.gz'] = core
    files['REBUILD.md'] = (REPO / 'docs/releases/v0.5.0-source.md').read_bytes()
    files['packaging/package-coordinated-source.py'] = Path(__file__).read_bytes()
    manifest = {
        'schemaVersion': 2, 'status': 'candidate_not_release_approval',
        'sourceRevision': revision, 'sourceFingerprint': fingerprint,
        'candidateArtifacts': record['artifacts'], 'retainedDependencySourceArchiveSHA256': PRIOR_SHA256,
        'files': {name: {'bytes': len(data), 'sha256': sha(data)} for name, data in sorted(files.items())},
    }
    files['SOURCE-MANIFEST.json'] = (json.dumps(manifest, indent=2, sort_keys=True) + '\n').encode()
    with args.output.open('xb') as target, gzip.GzipFile(fileobj=target, filename='', mode='wb', mtime=0) as compressed:
        with tarfile.open(fileobj=compressed, mode='w|') as archive:
            for name, data in sorted(files.items()):
                info = tarfile.TarInfo(name); info.size = len(data); info.mode = 0o644
                archive.addfile(info, io.BytesIO(data))
    print(json.dumps({'bytes': args.output.stat().st_size, 'sha256': sha(args.output.read_bytes()),
                      'members': len(files), 'source': revision, 'status': manifest['status']}, indent=2))


if __name__ == '__main__':
    main()
