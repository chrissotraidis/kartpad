"""Interrupted runtime preparation must recover before fingerprinting or compiling."""
import hashlib
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "builder"))
from kartpad_builder import game_pack, runtime_stage
from kartpad_builder.errors import BuildError

REPO = Path(__file__).resolve().parents[1]


class RuntimeRetryTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.runtime = self.root / "runtime"
        self.runtime.mkdir()
        self.cached = self.root / "sse2neon.h"
        self.cached.write_bytes(b"// pinned dependency fixture\n")
        self.digest = hashlib.sha256(self.cached.read_bytes()).hexdigest()
        patch = mock.patch.object(runtime_stage, "SSE2NEON_SHA256", self.digest)
        patch.start()
        self.addCleanup(patch.stop)

    def extras(self):
        with mock.patch.object(runtime_stage, "_sse2neon", return_value=self.cached):
            runtime_stage.stage_extras(REPO, self.runtime)

    def test_valid_runtime_needs_no_download_or_rewrite(self):
        self.extras()
        before = {p: (p.read_bytes(), p.stat().st_mtime_ns)
                  for p in self.runtime.rglob("*") if p.is_file()}
        with mock.patch.object(runtime_stage, "_sse2neon", side_effect=AssertionError("unneeded download")):
            runtime_stage.stage_extras(REPO, self.runtime)
        self.assertEqual(before, {p: (p.read_bytes(), p.stat().st_mtime_ns) for p in before})

    def test_missing_dependency_is_restored_without_changing_source(self):
        source = self.runtime / "local.cpp"
        source.write_bytes(b"// retained local edit\n")
        with mock.patch.object(runtime_stage, "_sse2neon", side_effect=OSError("download interrupted")):
            with self.assertRaisesRegex(OSError, "download interrupted"):
                runtime_stage.stage_extras(REPO, self.runtime)
        self.extras()
        self.assertEqual((self.runtime / "third_party/sse2neon/sse2neon.h").read_bytes(), self.cached.read_bytes())
        self.assertEqual(source.read_bytes(), b"// retained local edit\n")

    def test_modified_generated_files_are_preserved_and_rejected(self):
        for relative in ("third_party/sse2neon/sse2neon.h",
                         "third_party/kartpad-profile/kartpad_retro_rewind_release.h"):
            with self.subTest(relative=relative):
                target = self.runtime / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(b"// user edit\n")
                with mock.patch.object(runtime_stage, "_sse2neon", side_effect=AssertionError("unneeded download")):
                    with self.assertRaisesRegex(BuildError, "differs"):
                        runtime_stage.stage_extras(REPO, self.runtime)
                self.assertEqual(target.read_bytes(), b"// user edit\n")
                target.rename(target.with_suffix(".saved"))

    def test_generated_symlink_is_preserved_and_rejected(self):
        target = self.runtime / "third_party/sse2neon/sse2neon.h"
        target.parent.mkdir(parents=True)
        target.symlink_to(self.cached)
        with self.assertRaisesRegex(BuildError, "symlink"):
            self.extras()
        self.assertTrue(target.is_symlink())

    def test_symlinked_dependency_folder_is_not_written(self):
        elsewhere = self.root / "elsewhere"
        elsewhere.mkdir()
        (self.runtime / "third_party").symlink_to(elsewhere, target_is_directory=True)
        with self.assertRaisesRegex(BuildError, "symlink"):
            self.extras()
        self.assertEqual(list(elsewhere.iterdir()), [])

    def test_missing_profile_is_restored_without_redownloading_dependency(self):
        self.extras()
        header = self.runtime / "third_party/kartpad-profile/kartpad_retro_rewind_release.h"
        header.rename(header.with_suffix(".saved"))
        with mock.patch.object(runtime_stage, "_sse2neon", side_effect=AssertionError("unneeded download")):
            runtime_stage.stage_extras(REPO, self.runtime)
        self.assertEqual(header.read_bytes(), header.with_suffix(".saved").read_bytes())

    def test_previous_windows_profile_line_endings_are_preserved(self):
        self.extras()
        header = self.runtime / "third_party/kartpad-profile/kartpad_retro_rewind_release.h"
        windows = header.read_bytes().replace(b"\n", b"\r\n")
        header.write_bytes(windows)
        with mock.patch.object(runtime_stage, "_sse2neon", side_effect=AssertionError("unneeded download")):
            runtime_stage.stage_extras(REPO, self.runtime)
        self.assertEqual(header.read_bytes(), windows)

    def test_failed_download_does_not_publish_a_partial_header(self):
        with mock.patch.object(runtime_stage, "_sse2neon", side_effect=OSError("download interrupted")):
            with self.assertRaises(OSError):
                runtime_stage.stage_extras(REPO, self.runtime)
        self.assertEqual(list(self.runtime.iterdir()), [])

    def test_both_builders_restore_header_before_fingerprint(self):
        class ReachedFingerprint(Exception):
            pass

        for name, builder in (("android", game_pack.build_android_pack), ("ios", game_pack.build_ios_pack)):
            with self.subTest(platform=name):
                workspace = self.root / name
                runtime = workspace / f"{name}-runtime"
                runtime.mkdir(parents=True)
                def fingerprint(repo, platform, prepared):
                    self.assertEqual((prepared / "third_party/sse2neon/sse2neon.h").read_bytes(),
                                     self.cached.read_bytes())
                    raise ReachedFingerprint()

                with mock.patch.object(game_pack, "host_ndk"), \
                     mock.patch.object(game_pack, "_ios_llvm", return_value=None), \
                     mock.patch.object(game_pack, "_workspace", return_value=workspace), \
                     mock.patch.object(game_pack, "_translated", return_value=(workspace, workspace / "translation", game_pack.ProgressLog(workspace / "progress.jsonl"))), \
                     mock.patch.object(runtime_stage, "_sse2neon", return_value=self.cached), \
                     mock.patch.object(game_pack.pack_fingerprint, "fingerprint", side_effect=fingerprint):
                    with self.assertRaises(ReachedFingerprint):
                        builder(repo=REPO, profile=None, image=self.root / "disc", image_sha256="a" * 64,
                                app=self.root / "app", output=self.root / "result", work_root=self.root)


if __name__ == "__main__":
    unittest.main()
