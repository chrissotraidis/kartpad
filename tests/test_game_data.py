import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "builder"))
from kartpad_builder import game_data  # noqa: E402
from kartpad_builder.errors import BuildError  # noqa: E402


class GameDataTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.extraction = game_data.extraction_root(self.root / "work", "profile", "ab" * 32)
        for name, data in (("sys/main.dol", b"synthetic dol"), ("files/rel/StaticR.rel", b"synthetic rel"),
                           ("ticket.bin", b"ticket"), ("disc/header.bin", b"header"),
                           ("kartpad-disc-manifest.json", b"{}")):
            path = self.extraction / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)

    def test_extraction_root_is_the_pack_builds_short_path(self):
        self.assertEqual(self.extraction, self.root / "work/profile/inputs/abababababababab/disc")

    def test_exports_the_dolphin_layout_without_kartpad_manifest(self):
        folder = game_data.export(self.extraction, self.root / "out/personal.so.data")
        names = sorted(str(path.relative_to(folder)) for path in folder.rglob("*") if path.is_file())
        self.assertEqual(names, ["disc/header.bin", "files/rel/StaticR.rel", "sys/main.dol", "ticket.bin"])
        self.assertEqual((folder / "sys/main.dol").read_bytes(), b"synthetic dol")
        self.assertFalse((self.root / "out/personal.so.data.partial").exists())

    def test_refuses_incomplete_extraction_and_existing_output(self):
        with self.assertRaisesRegex(BuildError, "already exists"):
            (self.root / "taken").mkdir()
            game_data.export(self.extraction, self.root / "taken")
        (self.extraction / "sys/main.dol").unlink()
        (self.extraction / "sys").rmdir()
        with self.assertRaisesRegex(BuildError, "no sys folder"):
            game_data.export(self.extraction, self.root / "out2")


if __name__ == "__main__":
    unittest.main()
