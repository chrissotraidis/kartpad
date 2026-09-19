"""Distribution packaging must not rewrite executable modes or signed app bytes."""
import importlib.util
from pathlib import Path
import stat
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('assets', ROOT / 'scripts/package-coordinated-assets.py')
assets = importlib.util.module_from_spec(spec)
spec.loader.exec_module(assets)


class CoordinatedAssets(unittest.TestCase):
    def test_archive_preserves_payload_and_rejects_notice_collision(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = root / 'original.zip'
            with zipfile.ZipFile(original, 'w') as archive:
                for name, data, mode in (
                    ('KartPad.app/Contents/MacOS/KartPad', b'executable', stat.S_IFREG | 0o755),
                    ('KartPad.app/Contents/Frameworks/SDL', b'Versions/A/SDL', stat.S_IFLNK | 0o777),
                    ('KartPad.app/Contents/_CodeSignature/CodeResources', b'signature', stat.S_IFREG | 0o644),
                ):
                    info = zipfile.ZipInfo(name); info.external_attr = mode << 16
                    archive.writestr(info, data)
            assets.write_zip(root / 'candidate.zip', {'LICENSE': b'notice'}, original)
            with zipfile.ZipFile(original) as before, zipfile.ZipFile(root / 'candidate.zip') as after:
                for entry in before.infolist():
                    self.assertEqual(before.read(entry), after.read(entry.filename))
                    self.assertEqual(entry.external_attr, after.getinfo(entry.filename).external_attr)
            for notice in ('../private', 'KartPad.app/Contents/MacOS/KartPad'):
                with self.subTest(notice=notice), self.assertRaises(ValueError):
                    assets.write_zip(root / ('bad-' + str(len(notice)) + '.zip'), {notice: b'changed'}, original)

    def test_changed_input_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'candidate.apk'
            path.write_bytes(b'changed')
            with self.assertRaises(ValueError):
                assets.checked(path, assets.identity(b'audited'))


if __name__ == '__main__':
    unittest.main()
