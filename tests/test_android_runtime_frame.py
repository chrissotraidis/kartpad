from __future__ import annotations

import importlib.util
import struct
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
CHECKER = REPO / "scripts/check-android-runtime-frame.py"
SPEC = importlib.util.spec_from_file_location("android_runtime_frame", CHECKER)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def frame(width: int, height: int, pixel) -> bytes:
    body = bytearray()
    for y_position in range(height):
        for x_position in range(width):
            body.extend((*pixel(x_position, y_position), 255))
    return struct.pack("<4I", width, height, 1, 0) + body


class AndroidRuntimeFrameTests(unittest.TestCase):
    def test_varied_landscape_frame_passes(self) -> None:
        raw = frame(
            320,
            180,
            lambda x, y: ((x * 7) % 256, (y * 11) % 256, ((x + y) * 5) % 256),
        )

        result = MODULE.analyze(raw)

        self.assertGreaterEqual(result["quantized_colors"], 32)
        self.assertGreaterEqual(result["luma_span"], 60)

    def test_solid_or_portrait_frame_fails(self) -> None:
        with self.assertRaisesRegex(ValueError, "diversity"):
            MODULE.analyze(frame(320, 180, lambda _x, _y: (0, 0, 0)))
        with self.assertRaisesRegex(ValueError, "landscape"):
            MODULE.analyze(frame(180, 320, lambda _x, _y: (255, 255, 255)))


if __name__ == "__main__":
    unittest.main()
