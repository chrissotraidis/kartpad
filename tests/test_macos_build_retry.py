'''Run the Mac build orchestration with tiny source/compiler fixtures, no game data.'''
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

REPO = Path(__file__).resolve().parents[1]
PIN = "44b9fa3dec3a52ea473246e04b9f692a4e5b0ed654299eef7fe7ec3049e223e0"


class MacBuildRetryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name).resolve()
        self.repo = self.root / "repo"
        self.repo.mkdir()
        self.git(self.repo, "init", "-q")
        self.work = self.repo / "work"
        self.translation = self.repo / "private/self-build/retro-rewind/translation"
        self.write("private/self-build/retro-rewind/translation/build_shards/shards.cmake", "# translation fixture\n")
        self.write("scripts/inject-retro-rel-report-guard.py", "# verified separately\n")
        self.write("scripts/inject-mkw-texture-link-guard.py", "# verified separately\n")
        for name in ("prepare-g7-game-runtime.sh", "stage-maintained-runtime.py",
                     "build-macos-app.sh", "build-padmint-macos.sh"):
            shutil.copy2(REPO / "scripts" / name, self.repo / "scripts" / name)
        for module in (REPO / "builder/kartpad_builder").glob("*.py"):
            target = self.repo / "builder/kartpad_builder" / module.name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(module, target)
        self.write("builder/profiles/mkwii-rmcp01-rev0.json",
                   (REPO / "builder/profiles/mkwii-rmcp01-rev0.json").read_text())
        # Fixture dependency bytes replace the public pin in the isolated copies;
        # the production verifier and retry code run without mocking either.
        header = b"// pinned fixture header\n"
        digest = hashlib.sha256(header).hexdigest()
        for relative in ("scripts/stage-maintained-runtime.py", "builder/kartpad_builder/runtime_stage.py"):
            path = self.repo / relative
            path.write_text(path.read_text().replace(PIN, digest))
        self.write(f"build/dependency-cache/sse2neon-{digest}.h", header.decode())
        self.write("build/dependency-cache/dawn-darwin-arm64-v20260603.191052.tar.gz", "fixture")
        vendor = self.repo / "vendor/runtimes/macos"
        vendor.mkdir(parents=True)
        self.git(vendor, "init", "-q")
        self.write("vendor/runtimes/macos/runtime/CMakeLists.txt", "# maintained fixture\n")
        self.write("vendor/runtimes/macos/aurora-main/CMakeLists.txt", "# aurora fixture\n")
        self.git(vendor, "add", ".")
        self.git(vendor, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                 "-c", "commit.gpgsign=false", "commit", "-qm", "Fixture runtime")
        revision = self.git(vendor, "rev-parse", "HEAD").strip()
        self.git(self.repo, "update-index", "--add", "--cacheinfo",
                 f"160000,{revision},vendor/runtimes/macos")
        self.bin = self.repo / "bin"
        self.bin.mkdir()
        self.executable("bin/python3", f"#!/bin/sh\nexec '{sys.executable}' \"$@\"\n")
        self.executable("bin/uname", '#!/bin/sh\nif [ "$1" = -s ]; then echo Darwin; else echo arm64; fi\n')
        self.executable("bin/cmake", f"#!{sys.executable}\n" + r'''
import pathlib, sys
args = sys.argv[1:]
if args[0] == '-S':
    source, build = pathlib.Path(args[1]), pathlib.Path(args[3])
    build.mkdir(parents=True, exist_ok=True)
    (build / 'CMakeCache.txt').write_text('CMAKE_HOME_DIRECTORY:INTERNAL=' + str(source) + '\n')
    cached = build / 'compiled.o'
    if not cached.exists():
        cached.write_text('expensive object cache')
else:
    build = pathlib.Path(args[1])
    (build / 'KartPadDual').write_text('fixture executable')
''')
        self.executable("scripts/package-macos-runtime.sh", r'''#!/bin/bash
set -eu
[[ ! -e "$2" ]]
mkdir -p "$2/Contents/MacOS"
cp "$1/$3" "$2/Contents/MacOS/KartPad"
''')
        self.executable("scripts/audit-macos-package.sh", '#!/bin/sh\ntest -f "$1/Contents/MacOS/KartPad"\n')
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ.get("PATH", ""))

    @staticmethod
    def git(repo, *args):
        return subprocess.check_output(["git", "-C", str(repo), *args], text=True, stderr=subprocess.PIPE)

    def write(self, relative, text):
        path = self.repo / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def executable(self, relative, text):
        self.write(relative, text).chmod(0o755)

    def run_script(self, name, *args):
        return subprocess.run(["/bin/bash", str(self.repo / "scripts" / name), *map(str, args)],
                              cwd=self.repo, env=self.env, text=True, capture_output=True)

    def prepare(self, work=None):
        work = work or self.work
        return self.run_script("prepare-g7-game-runtime.sh", self.translation,
                               work / "macos-source", work / "macos-build", "dual")

    def recipe_compile(self, output):
        recipe = json.loads((REPO / "padmint.json").read_text())
        compile_step = next(step for step in recipe["targets"]["macos"]["steps"]
                            if step["stage"] == "compile")
        values = {"repo": self.repo, "work": self.work, "output": output}
        return subprocess.run([arg.format(**values) for arg in compile_step["command"]],
                              cwd=self.repo, env=self.env, text=True, capture_output=True)

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    @unittest.skipUnless(Path("/usr/bin/ditto").is_file(), "real macOS ZIP packaging")
    def test_repeat_build_reuses_cache_and_preserves_previous_artifacts(self):
        old_app = self.work / "KartPad.app/keep.txt"
        old_app.parent.mkdir(parents=True)
        old_app.write_text("previous personal app")
        first = self.repo / "runs/first/personal.zip"
        second = self.repo / "runs/second/personal.zip"
        self.assert_success(self.recipe_compile(first))
        cached = self.work / "macos-build/compiled.o"
        source = self.work / "macos-source/CMakeLists.txt"
        snapshot = (first.read_bytes(), cached.stat().st_mtime_ns, source.stat().st_mtime_ns)
        self.assert_success(self.recipe_compile(second))
        self.assertEqual(snapshot, (first.read_bytes(), cached.stat().st_mtime_ns, source.stat().st_mtime_ns))
        self.assertEqual(old_app.read_text(), "previous personal app")
        for output in (first, second):
            with zipfile.ZipFile(output) as archive:
                self.assertEqual(archive.read("KartPad.app/Contents/MacOS/KartPad"), b"fixture executable")
        collision = self.recipe_compile(first)
        self.assertNotEqual(collision.returncode, 0)
        self.assertIn("already exists", collision.stderr)
        self.assertEqual(first.read_bytes(), snapshot[0])

    def test_retry_restores_missing_generated_header_without_replacing_source_or_cache(self):
        self.assert_success(self.prepare())
        source = self.work / "macos-source/CMakeLists.txt"
        cached = self.work / "macos-build/compiled.o"
        before = (source.stat().st_mtime_ns, cached.stat().st_mtime_ns)
        header = self.work / "macos-source/third_party/sse2neon/sse2neon.h"
        expected = header.read_bytes()
        header.unlink()
        self.assert_success(self.prepare())
        self.assertEqual(header.read_bytes(), expected)
        self.assertEqual(before, (source.stat().st_mtime_ns, cached.stat().st_mtime_ns))

    def test_edited_source_is_preserved_and_rejected_before_compile(self):
        self.assert_success(self.prepare())
        source = self.work / "macos-source/CMakeLists.txt"
        source.write_text("personal edit")
        before = source.stat().st_mtime_ns
        result = self.prepare()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("prepared source differs", result.stderr)
        self.assertEqual((source.read_text(), source.stat().st_mtime_ns), ("personal edit", before))

    def test_build_cache_for_different_source_is_preserved_and_rejected(self):
        self.assert_success(self.prepare())
        cache = self.work / "macos-build/CMakeCache.txt"
        cache.write_text("CMAKE_HOME_DIRECTORY:INTERNAL=/somewhere/else\n")
        before = cache.read_bytes()
        result = self.prepare()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not belong to this runtime source", result.stderr)
        self.assertEqual(cache.read_bytes(), before)

    def test_unowned_source_and_build_directories_are_preserved(self):
        for name in ("macos-source", "macos-build"):
            with self.subTest(directory=name):
                work = self.repo / name
                directory = work / name
                directory.mkdir(parents=True)
                sentinel = directory / "keep.txt"
                sentinel.write_text("personal files")
                result = self.prepare(work)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(list(directory.iterdir()), [sentinel])
                self.assertEqual(sentinel.read_text(), "personal files")

    def test_symlink_source_and_build_roots_are_refused(self):
        outside = self.repo / "outside"
        outside.mkdir()
        for name in ("macos-source", "macos-build"):
            with self.subTest(directory=name):
                work = self.repo / name
                work.mkdir()
                (work / name).symlink_to(outside, target_is_directory=True)
                result = self.prepare(work)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("must not be symlinks", result.stderr)
                self.assertEqual(list(outside.iterdir()), [])

    def test_existing_app_and_dangling_output_symlinks_are_refused(self):
        for name in ("KartPad.app", "personal.zip"):
            with self.subTest(output=name):
                folder = self.repo / ("collision-" + name)
                folder.mkdir()
                link = folder / name
                link.symlink_to(folder / "does-not-exist")
                result = self.run_script("build-padmint-macos.sh", self.translation, self.work,
                                         folder / "personal.zip")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("already exists", result.stderr)
                self.assertTrue(link.is_symlink())
                self.assertFalse(self.work.exists())


if __name__ == "__main__":
    unittest.main()
