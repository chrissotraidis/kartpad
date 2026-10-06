"""Native replay format, checksums and save preservation for Original ghost imports."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class GhostNativeImport(unittest.TestCase):
    def test_native_input_table_and_save_preservation(self):
        compiler = os.environ.get("CXX", "clang++")
        if not shutil.which(compiler):
            self.skipTest("Requires a C++20 compiler")
        with tempfile.TemporaryDirectory() as temporary:
            executable = Path(temporary) / "ghost-import"
            build = subprocess.run([compiler, "-std=c++20", "-Wall", "-Wextra", "-Werror",
                "-I", str(ROOT / "runtime/include"),
                str(ROOT / "runtime/tests/ghost_transfer_tests.cpp"), "-o", str(executable)],
                capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(executable)], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
