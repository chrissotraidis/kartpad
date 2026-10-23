"""Exercise source staging against real tiny local Git repositories, without network."""
from __future__ import annotations

import importlib.util
import hashlib
import json
import sys
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/stage-maintained-runtime.py"
SPEC = importlib.util.spec_from_file_location("maintained_runtime_staging", SCRIPT)
STAGING = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STAGING)


class MaintainedRuntimeStagingTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.repo = self.root / "kartpad"
        self.repo.mkdir()
        self.initialize(self.repo)
        self.source = self.repo / "vendor/runtimes/ios"
        self.source.mkdir(parents=True)
        self.initialize(self.source)
        self.write("runtime/CMakeLists.txt", "project(TinyRuntime)\n")
        self.write("runtime/src/main.cpp", "int main() { return 0; }\n")
        self.write("runtime/tools/generate.sh", "#!/bin/sh\nexit 0\n")
        (self.source / "runtime/tools/generate.sh").chmod(0o755)
        self.write("aurora-main/CMakeLists.txt", "project(TinyAurora)\n")
        self.write("aurora-main/lib/render.cpp", "void render() {}\n")
        self.write("LICENSE", "source license\n")
        self.git(self.source, "add", ".")
        self.git(self.source, "commit", "-qm", "Pinned runtime fixture")
        self.revision = self.git(self.source, "rev-parse", "HEAD")
        self.git(self.repo, "update-index", "--add", "--cacheinfo",
                 f"160000,{self.revision},vendor/runtimes/ios")
        self.destination = self.root / "prepared"

    @staticmethod
    def git(repo, *arguments):
        return subprocess.check_output(
            ["git", "-C", str(repo), *arguments], text=True,
            stderr=subprocess.PIPE,
        ).strip()

    def initialize(self, repo):
        self.git(repo, "init", "-q")
        self.git(repo, "config", "user.name", "Source staging test")
        self.git(repo, "config", "user.email", "test@example.invalid")
        self.git(repo, "config", "commit.gpgsign", "false")

    def write(self, relative, text):
        path = self.source / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def source_snapshot(self):
        """Capture source bytes, modes and index/HEAD to detect unintended writes."""
        return (
            self.git(self.source, "rev-parse", "HEAD"),
            self.git(self.source, "ls-files", "--stage"),
            {str(path.relative_to(self.source)): (path.read_bytes(), stat.S_IMODE(path.stat().st_mode))
             for tree in ("runtime", "aurora-main")
             for path in (self.source / tree).rglob("*") if path.is_file()},
            self.git(self.repo, "ls-files", "--stage"),
        )

    def prepare_for_verification(self, platform="ios"):
        STAGING.stage(self.repo, platform, self.destination)
        sys.path.insert(0, str(SCRIPT.parents[1] / "builder"))
        from kartpad_builder.release_header import render_retro_rewind_header
        profile = SCRIPT.parents[1] / "builder/profiles/mkwii-rmcp01-rev0.json"
        local_profile = self.repo / "builder/profiles/mkwii-rmcp01-rev0.json"
        local_profile.parent.mkdir(parents=True)
        local_profile.write_bytes(profile.read_bytes())
        generated = {
            STAGING.PROFILE_HEADER: render_retro_rewind_header(json.loads(profile.read_text())).encode(),
            STAGING.SSE2NEON_HEADER: b"local pinned header fixture",
        }
        for name, data in generated.items():
            path = self.destination / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
        override = patch.object(STAGING, "SSE2NEON_SHA256", hashlib.sha256(generated[STAGING.SSE2NEON_HEADER]).hexdigest())
        override.start()
        self.addCleanup(override.stop)

    def test_verify_accepts_matching_source_and_rejects_successive_source_edits(self):
        self.prepare_for_verification()
        self.assertEqual(STAGING.verify(self.repo, "ios", self.destination), self.revision)
        self.write("runtime/src/main.cpp", "changed maintained source")
        with self.assertRaisesRegex(ValueError, "prepare a fresh runtime source"):
            STAGING.verify(self.repo, "ios", self.destination)

    def test_verify_rejects_missing_modified_extra_source_and_mode(self):
        self.prepare_for_verification()
        path = self.destination / "src/main.cpp"
        original = path.read_bytes()
        for modification in ("missing", "content", "mode", "extra"):
            with self.subTest(modification=modification):
                if modification == "missing":
                    path.unlink()
                elif modification == "content":
                    path.write_text("changed staged source")
                elif modification == "mode":
                    path.chmod(0o755)
                else:
                    (self.destination / "src/untracked.cpp").write_text("extra compilation input")
                with self.assertRaisesRegex(ValueError, "prepare a fresh runtime source"):
                    STAGING.verify(self.repo, "ios", self.destination)
                path.write_bytes(original)
                path.chmod(0o644)
                (self.destination / "src/untracked.cpp").unlink(missing_ok=True)

    def test_verify_rejects_changed_generated_inputs_and_unpinned_head(self):
        self.prepare_for_verification()
        for name in (STAGING.PROFILE_HEADER, STAGING.SSE2NEON_HEADER):
            path = self.destination / name
            original = path.read_bytes()
            path.write_bytes(b"stale generated input")
            with self.assertRaisesRegex(ValueError, "prepare a fresh runtime source"):
                STAGING.verify(self.repo, "ios", self.destination)
            path.write_bytes(original)
        self.write("runtime/src/main.cpp", "committed change")
        self.git(self.source, "commit", "-qam", "Unpinned source")
        with self.assertRaisesRegex(ValueError, "update its KartPad gitlink deliberately"):
            STAGING.verify(self.repo, "ios", self.destination)

    def test_retry_verification_only_allows_missing_generated_headers(self):
        self.prepare_for_verification()
        (self.destination / STAGING.SSE2NEON_HEADER).unlink()
        self.assertEqual(STAGING.verify(self.repo, "ios", self.destination,
                                       allow_missing_generated=True), self.revision)
        with self.assertRaisesRegex(ValueError, "prepared source files differ"):
            STAGING.verify(self.repo, "ios", self.destination)
        (self.destination / "src/main.cpp").unlink()
        with self.assertRaisesRegex(ValueError, "prepared source files differ"):
            STAGING.verify(self.repo, "ios", self.destination, allow_missing_generated=True)

    def test_retry_verification_still_rejects_modified_generated_headers(self):
        self.prepare_for_verification()
        (self.destination / STAGING.SSE2NEON_HEADER).unlink()
        (self.destination / STAGING.PROFILE_HEADER).write_text("personal edit")
        with self.assertRaisesRegex(ValueError, "prepared release profile header differs"):
            STAGING.verify(self.repo, "ios", self.destination, allow_missing_generated=True)

    def test_verify_android_trace_matches_current_repo_header(self):
        android = self.source.with_name("android")
        self.source.rename(android)
        self.source = android
        self.git(self.repo, "update-index", "--add", "--cacheinfo", f"160000,{self.revision},vendor/runtimes/android")
        self.prepare_for_verification("android")
        source = self.repo / "runtime/include/kartpad/android/trace_scope.h"
        source.parent.mkdir(parents=True)
        source.write_text("current trace header")
        target = self.destination / STAGING.ANDROID_TRACE_HEADER
        target.write_bytes(source.read_bytes())
        STAGING.verify(self.repo, "android", self.destination)
        source.write_text("updated trace header")
        with self.assertRaisesRegex(ValueError, "Android trace header differs"):
            STAGING.verify(self.repo, "android", self.destination)

    def test_tracked_runtime_is_flattened_and_aurora_keeps_its_directory(self):
        before = self.source_snapshot()
        revision = STAGING.stage(self.repo, "ios", self.destination)
        self.assertEqual(revision, self.revision)
        actual = {str(path.relative_to(self.destination)) for path in self.destination.rglob("*") if path.is_file()}
        self.assertEqual(actual, {
            "CMakeLists.txt", "src/main.cpp", "tools/generate.sh",
            "aurora-main/CMakeLists.txt", "aurora-main/lib/render.cpp",
        })
        self.assertEqual((self.destination / "CMakeLists.txt").read_text(), "project(TinyRuntime)\n")
        self.assertEqual((self.destination / "aurora-main/lib/render.cpp").read_text(), "void render() {}\n")
        self.assertFalse((self.destination / "runtime").exists())
        self.assertEqual(before, self.source_snapshot())

    def test_dirty_tracked_bytes_and_executable_mode_are_preserved(self):
        self.write("runtime/src/main.cpp", "int main() { return 7; }\n")
        self.write("runtime/tools/generate.sh", "#!/bin/sh\nprintf changed\n")
        (self.source / "runtime/tools/generate.sh").chmod(0o751)
        before = self.source_snapshot()
        STAGING.stage(self.repo, "ios", self.destination)
        self.assertEqual((self.destination / "src/main.cpp").read_text(), "int main() { return 7; }\n")
        self.assertEqual((self.destination / "tools/generate.sh").read_bytes(),
                         (self.source / "runtime/tools/generate.sh").read_bytes())
        self.assertEqual(stat.S_IMODE((self.destination / "tools/generate.sh").stat().st_mode), 0o751)
        self.assertEqual(before, self.source_snapshot())

    def test_untracked_private_inputs_are_excluded(self):
        self.write("runtime/GameData/private.bin", "private game input\n")
        self.write("aurora-main/private-key.pem", "private signing input\n")
        self.write("runtime/.local-secret", "secret\n")
        before = self.source_snapshot()
        STAGING.stage(self.repo, "ios", self.destination)
        for relative in ("GameData", "aurora-main/private-key.pem", ".local-secret", ".git"):
            self.assertFalse((self.destination / relative).exists(), relative)
        self.assertEqual(before, self.source_snapshot())

    def test_existing_destination_is_rejected_without_changes(self):
        self.destination.mkdir()
        sentinel = self.destination / "keep.txt"
        sentinel.write_text("existing build\n")
        before = self.source_snapshot()
        with self.assertRaisesRegex(ValueError, "output already exists"):
            STAGING.stage(self.repo, "ios", self.destination)
        self.assertEqual(sentinel.read_text(), "existing build\n")
        self.assertEqual(list(self.destination.iterdir()), [sentinel])
        self.assertEqual(before, self.source_snapshot())

    def test_wrong_gitlink_head_is_rejected_without_changes(self):
        self.write("runtime/src/main.cpp", "int main() { return 2; }\n")
        self.git(self.source, "add", "runtime/src/main.cpp")
        self.git(self.source, "commit", "-qm", "Unpinned source revision")
        before = self.source_snapshot()
        with self.assertRaisesRegex(ValueError, "update its KartPad gitlink deliberately"):
            STAGING.stage(self.repo, "ios", self.destination)
        self.assertFalse(self.destination.exists())
        self.assertEqual(before, self.source_snapshot())

    def test_invalid_platform_is_rejected_without_changes(self):
        before = self.source_snapshot()
        with self.assertRaisesRegex(ValueError, "unsupported runtime platform"):
            STAGING.stage(self.repo, "../ios", self.destination)
        self.assertFalse(self.destination.exists())
        self.assertEqual(before, self.source_snapshot())


if __name__ == "__main__":
    unittest.main()
