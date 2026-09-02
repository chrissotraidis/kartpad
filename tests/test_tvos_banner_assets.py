from __future__ import annotations

import json
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
GENERATOR = REPO / "scripts/generate-tvos-banner-assets.py"
OPENING_BNR = REPO / "private/self-build/disc/files/opening.bnr"


def png_size(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        raise AssertionError(f"not a PNG: {path}")
    return struct.unpack(">II", data[16:24])


class TVOSBannerAssetTests(unittest.TestCase):
    @unittest.skipUnless(OPENING_BNR.is_file(), "private Wii banner is not available")
    def test_generator_emits_real_wii_banner_brandassets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "Assets.xcassets"
            completed = subprocess.run(
                [sys.executable, str(GENERATOR), str(OPENING_BNR), str(output)],
                capture_output=True,
                text=True,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            contents = json.loads(
                (output / "App Icon.brandassets/Contents.json").read_text()
            )
            self.assertEqual(
                [asset["role"] for asset in contents["assets"]],
                ["primary-app-icon", "primary-app-icon", "top-shelf-image"],
            )
            self.assertEqual(
                png_size(
                    output
                    / "App Icon.brandassets/App Icon - Small.imagestack"
                    "/Layer.imagestacklayer/Content.imageset/icon-small.png"
                ),
                (400, 240),
            )
            self.assertEqual(
                png_size(
                    output
                    / "App Icon.brandassets/App Icon - Large.imagestack"
                    "/Layer.imagestacklayer/Content.imageset/icon-large.png"
                ),
                (1280, 768),
            )
            self.assertEqual(
                png_size(
                    output
                    / "App Icon.brandassets/Top Shelf Image.imageset/top-shelf.png"
                ),
                (1920, 720),
            )

    def test_generator_rejects_non_banner_input(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            input_path = Path(temporary) / "not-a-banner.bin"
            output = Path(temporary) / "Assets.xcassets"
            input_path.write_bytes(b"not a Wii banner")
            completed = subprocess.run(
                [sys.executable, str(GENERATOR), str(input_path), str(output)],
                capture_output=True,
                text=True,
            )
            self.assertNotEqual(completed.returncode, 0)
            self.assertIn("opening.bnr does not contain its U8 archive", completed.stderr)


if __name__ == "__main__":
    unittest.main()
