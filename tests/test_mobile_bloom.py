"""Exercise bloom persistence and the game's actual renderer-path mask."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MobileBloomTests(unittest.TestCase):
    def test_persists_bloom_without_changing_other_settings_and_handles_failed_save(self):
        runtimes = Path(os.environ.get("KARTPAD_TEST_RUNTIME_ROOT", ROOT / "vendor/runtimes"))
        if not shutil.which("clang++"):
            self.skipTest("Requires clang++")
        for platform in ("ios", "android"):
            runtime = runtimes / platform / "runtime"
            if not (runtime / "third_party/toml11/toml.hpp").is_file():
                self.skipTest("Initialize the maintained mobile runtime submodules")
            with self.subTest(platform=platform), tempfile.TemporaryDirectory(prefix="kartpad-bloom-") as temporary:
                directory = Path(temporary)
                (directory / "portable.txt").touch()
                source = directory / "test.cpp"
                source.write_text(r'''
#include <cassert>
#include "kartpad/graphics/bloom_setting.hpp"
int main() {
  using namespace kartpad::graphics;
  RuntimeConfigFile::EnsureConfigFile();
  assert(!BloomDisabled());
  assert(RuntimeConfigFile::SetResolutionMultiplier(1.5f));
  assert(SetBloomDisabled(true));
  assert(BloomDisabled());
  assert(RuntimeGameGraphicsOptions::FilterScnRendererPathMask(0x3f) == 0x0f);
  RuntimeConfigFile::Reload();
  assert(RuntimeConfigFile::Get().disabledPostProcessingPaths == 0x10);
  assert(RuntimeConfigFile::Get().resolutionMultiplier == 1.5f);
  RuntimeGameGraphicsOptions::SetDisabledPostProcessingPaths(
      RuntimeConfigFile::Get().disabledPostProcessingPaths.value_or(0));
  assert(BloomDisabled());
  assert(SetBloomDisabled(false));
  assert(!BloomDisabled());
  assert(RuntimeGameGraphicsOptions::FilterScnRendererPathMask(0x3f) == 0x1f);
  RuntimeConfigFile::Reload();
  assert(RuntimeConfigFile::Get().disabledPostProcessingPaths == 0);
  assert(RuntimeConfigFile::Get().resolutionMultiplier == 1.5f);

  // A failed write must not silently change the live state or unrelated settings.
  const auto config = RuntimeConfigFile::ResolveConfigPath();
  std::filesystem::remove(config);
  std::filesystem::create_directory(config);
  assert(!SetBloomDisabled(true));
  assert(!BloomDisabled());
  assert(RuntimeGameGraphicsOptions::DisabledPostProcessingPaths() == 0);
  assert(RuntimeConfigFile::Get().disabledPostProcessingPaths == 0);
}
''')
                executable = directory / "test"
                build = subprocess.run([
                    "clang++", "-std=c++20", "-Wall", "-Wextra", "-Werror",
                    "-I", str(ROOT / "runtime/include"),
                    "-I", str(runtime / "include"),
                    "-isystem", str(runtime / "third_party/toml11"),
                    str(source), "-o", str(executable),
                ], capture_output=True, text=True)
                self.assertEqual(build.returncode, 0, build.stderr)
                run = subprocess.run([str(executable)], cwd=directory, capture_output=True, text=True)
                self.assertEqual(run.returncode, 0, run.stdout + run.stderr)


if __name__ == "__main__":
    unittest.main()
