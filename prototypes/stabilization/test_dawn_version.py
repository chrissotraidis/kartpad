#!/usr/bin/env python3
"""Exercise the actual Dawn version generator under unrelated parent repositories."""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('dawn_source', type=Path)
args = parser.parse_args()
source = args.dawn_source.resolve()
spec = importlib.util.spec_from_file_location('pin_dawn', root/'prototypes/stabilization/pin-dawn-version.py')
pin = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pin)
sys.path.insert(0, str(source/'generator'))
import dawn_version_generator as generator
patch = root/'prototypes/stabilization/dependencies/dawn-optional-debug-utils.patch'
identities = []
with tempfile.TemporaryDirectory(prefix='kartpad-dawn-identity-') as directory:
    for name in ('parent-a', 'parent-b'):
        parent = Path(directory)/name
        parent.mkdir()
        subprocess.run(['git','init','-q',str(parent)],check=True)
        subprocess.run(['git','-C',str(parent),'-c','user.name=Test','-c','user.email=test@example.invalid',
                        'commit','--allow-empty','-qm',name],check=True)
        archive = parent/'archive'
        (archive/'src/dawn').mkdir(parents=True)
        (archive/'src/dawn/CMakeLists.txt').write_text((source/'src/dawn/CMakeLists.txt').read_text())
        identity = pin.pin(archive, patch)
        identities.append(identity)
        actual = generator.get_version(argparse.Namespace(version_file=str(archive/'KARTPAD_DAWN_VERSION'),dawn_dir=str(archive))).strip()
        assert actual == identity != generator.get_git_hash(str(archive))
        before = (archive/'src/dawn/CMakeLists.txt').read_bytes()
        assert pin.pin(archive,patch) == identity
        assert before == (archive/'src/dawn/CMakeLists.txt').read_bytes()
    assert identities[0] == identities[1]
    second = root/'prototypes/stabilization/dependencies/dawn-swiftshader-dynamic-state.patch'
    combined = pin.pin(archive, patch, second)
    assert combined != identity
    assert combined == pin.pin(archive, patch, second)
    changed_second = Path(directory)/'changed-second.patch'
    changed_second.write_bytes(second.read_bytes()+b'\nchanged additional dependency\n')
    assert pin.pin(archive, patch, changed_second) != combined
    changed = Path(directory)/'changed.patch'
    changed.write_bytes(patch.read_bytes()+b'\nchanged dependency\n')
    assert pin.pin(archive,changed) != identity
print('Dawn identity is parent-independent, idempotent, and changes with patch content.')
