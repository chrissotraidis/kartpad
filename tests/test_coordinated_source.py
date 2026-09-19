"""Source delivery must reject unaccounted bytes before publishing an archive."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('coordinated_source', ROOT / 'scripts/package-coordinated-source.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class CoordinatedSource(unittest.TestCase):
    def core(self, *, extra=False, corrupt=False, escaping=False):
        data = b'helper\n'
        files = {'scripts/restore-source-git.py': data, 'runtime.cpp': b'source\n'}
        metadata = {'label': 'kartpad', 'commit': 'fixture', 'entries': [
            {'path': name, 'sha256': hashlib.sha256(value).hexdigest(), 'bytes': len(value)}
            for name, value in files.items()
        ]}
        buffer = io.BytesIO()
        with tarfile.open(fileobj=buffer, mode='w:gz') as archive:
            def add(name, contents):
                info = tarfile.TarInfo(name); info.size = len(contents)
                archive.addfile(info, io.BytesIO(contents))
            add('metadata/kartpad.json', json.dumps(metadata).encode())
            add('restore-source-git.py', b'changed' if corrupt else data)
            for name, contents in files.items():
                if escaping and name == 'runtime.cpp':
                    info = tarfile.TarInfo('source/kartpad/' + name)
                    info.type = tarfile.SYMTYPE; info.linkname = '../../../private'
                    archive.addfile(info)
                else:
                    add('source/kartpad/' + name, contents)
            if extra:
                add('private/save.dat', b'not covered')
        return buffer.getvalue()

    def test_exact_source_is_bound_and_extra_or_escaping_content_rejected(self):
        revision, fingerprint = module.core_fingerprint(self.core())
        self.assertEqual(revision, 'fixture')
        self.assertEqual(fingerprint['files'], 2)
        for option in ('extra', 'corrupt', 'escaping'):
            with self.subTest(option=option), self.assertRaises(ValueError):
                module.core_fingerprint(self.core(**{option: True}))


if __name__ == '__main__':
    unittest.main()
