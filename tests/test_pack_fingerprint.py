import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "builder"))
from kartpad_builder import pack_fingerprint  # noqa: E402


class PackFingerprintTests(unittest.TestCase):
    """Synthetic repository and staged runtime; the real inputs have the same layout."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.repo, self.runtime = root / "kartpad", root / "staged-runtime"
        files = {
            self.repo / "android/app/src/main/cpp/translated-definitions.txt": "KARTPAD_ANDROID_COMBINED_FENV=1\n",
            self.repo / "android/app/src/main/cpp/CMakeLists.txt": "add_subdirectory(runtime)\n",
            self.repo / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt": "class A\n",
            self.repo / "scripts/build-ios-device-game-app.sh": "cmake\n",
            self.repo / "builder/profiles/mkwii-rmcp01-rev0.json": '{"retroRewind": {"version": "6.12.8"}}\n',
            self.repo / "runtime/include/kartpad/semantics/ppc.h": "inline int f() { return 1; }\n",
            self.repo / "version.json": '{"version": "0.7.0", "build": 250}\n',
            self.runtime / "include/game_pack.h": "#define KARTPAD_GAME_PACK_ABI 3u\n",
            self.runtime / "src/memory.h": "struct Memory { int page; };\n",
            self.runtime / "src/memory.cpp": "int Memory_page() { return 0; }\n",
            self.runtime / "third_party/sse2neon/sse2neon.h": "// neon\n",
            self.runtime / "aurora-main/include/aurora/aurora.h": "struct Aurora {};\n",
            self.runtime / "aurora-main/lib/kartpad_android_trace_scope.h": "// app-only copy\n",
            self.runtime / "game_pack/CMakeLists.txt": "add_library(kartpad_game SHARED)\n",
            self.runtime / "game_pack/pack_info.cpp": "const int info = 3;\n",
            self.runtime / "cmake/PublicProducts.cmake": "target_compile_definitions(x PRIVATE MKW_HOST_ARM64=1)\n",
            self.runtime / "CMakeLists.txt": "project(runtime)\n",
        }
        for path, text in files.items():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        translator = mock.patch.object(pack_fingerprint, "_translator", return_value=b"a" * 40)
        translator.start()
        self.addCleanup(translator.stop)
        self.base = self.value()

    def value(self, platform="android"):
        return pack_fingerprint.fingerprint(self.repo, platform, self.runtime)

    def edit(self, path, text):
        path.write_text(text)
        return self.value()

    def test_is_lowercase_hex_sha256(self):
        self.assertRegex(self.base, r"^[0-9a-f]{64}$")

    def test_1_app_only_changes_keep_the_pack(self):
        self.assertEqual(self.edit(self.runtime / "src/memory.cpp", "int Memory_page() { return 1; }\n"), self.base)
        self.assertEqual(self.edit(self.repo / "android/app/src/main/java/dev/kartpad/android/KartPadActivity.kt",
                                   "class B\n"), self.base)
        self.assertEqual(self.edit(self.repo / "version.json", '{"version": "0.7.1", "build": 251}\n'), self.base)
        self.assertEqual(self.edit(self.runtime / "aurora-main/lib/kartpad_android_trace_scope.h", "// x\n"), self.base)

    def test_2_a_header_change_needs_a_new_pack(self):
        self.assertNotEqual(self.edit(self.runtime / "src/memory.h", "struct Memory { long page; };\n"), self.base)

    def test_3_a_definition_change_needs_a_new_pack(self):
        self.assertNotEqual(self.edit(self.repo / "android/app/src/main/cpp/translated-definitions.txt",
                                      "KARTPAD_ANDROID_COMBINED_FENV=0\n"), self.base)

    def test_3_an_app_side_define_in_the_runtime_cmake_needs_a_new_pack(self):
        self.assertNotEqual(self.edit(self.runtime / "cmake/PublicProducts.cmake",
                                      "target_compile_definitions(x PRIVATE MKW_HOST_ARM64=2)\n"), self.base)

    def test_translation_inputs_need_a_new_pack(self):
        self.assertNotEqual(self.edit(self.repo / "builder/profiles/mkwii-rmcp01-rev0.json",
                                      '{"retroRewind": {"version": "6.12.9"}}\n'), self.base)
        with mock.patch.object(pack_fingerprint, "_translator", return_value=b"b" * 40):
            self.assertNotEqual(self.value(), self.base)

    def test_windows_line_endings_give_the_same_value(self):
        path = self.runtime / "src/memory.h"
        path.write_bytes(path.read_bytes().replace(b"\n", b"\r\n"))
        self.assertEqual(self.value(), self.base)

    def test_platforms_differ(self):
        self.assertNotEqual(self.value("ios"), self.base)
        self.assertEqual(pack_fingerprint.definitions(self.repo, "android"), ["KARTPAD_ANDROID_COMBINED_FENV=1"])


if __name__ == "__main__":
    unittest.main()
