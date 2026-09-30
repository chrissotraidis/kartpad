import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "builder"))
from kartpad_builder import game_pack  # noqa: E402
from kartpad_builder.errors import BuildError  # noqa: E402


class Arm64NdkTests(unittest.TestCase):
    """Linux arm64: the NDK layout assembled from the NDK's portable parts and LLVM."""

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        root = Path(self.temporary.name)
        self.ndk = root / "android-ndk-r29"
        prebuilt = self.ndk / "toolchains/llvm/prebuilt/linux-x86_64"
        for path in ("build/cmake", "meta", "sysroot/usr/lib", "lib/clang/21/lib/linux/aarch64"):
            (self.ndk / path if not path.startswith(("sysroot", "lib")) else prebuilt / path).mkdir(parents=True)
        (self.ndk / "source.properties").write_text("Pkg.Revision = 29.0.14206865\n")
        (self.ndk / "build/cmake/android.toolchain.cmake").write_text("# toolchain\n")
        self.llvm = root / "LLVM-21.1.8-Linux-ARM64"
        (self.llvm / "lib/clang/21/include").mkdir(parents=True)
        (self.llvm / "bin").mkdir()
        for name in ("clang", "clang++", *game_pack.LLVM_TOOLS):
            (self.llvm / "bin" / name).write_text("")
        self.shim = root / "work/ndk-linux-arm64"
        linker_ok = mock.patch.object(game_pack.subprocess, "run",
                                      return_value=subprocess.CompletedProcess([], 0, "LLD 21.1.8", ""))
        linker_ok.start()
        self.addCleanup(linker_ok.stop)

    def test_layout_uses_compiler_headers_and_ndk_runtime(self):
        ndk = game_pack.arm64_ndk(self.ndk, self.llvm, self.shim)
        prebuilt = ndk / "toolchains/llvm/prebuilt/linux-x86_64"
        self.assertTrue((ndk / "build/cmake/android.toolchain.cmake").is_file())
        self.assertEqual((prebuilt / "lib/clang/21/include").resolve(), (self.llvm / "lib/clang/21/include").resolve())
        self.assertTrue((prebuilt / "lib/clang/21/lib/linux/aarch64").is_dir())
        self.assertTrue((prebuilt / "sysroot/usr/lib").is_dir())
        wrapper = (prebuilt / "bin/clang++").read_text()
        for flag in ("-rtlib=compiler-rt", "-unwindlib=libunwind", "-fuse-ld=lld", str(self.llvm / "bin/clang++")):
            self.assertIn(flag, wrapper)
        self.assertTrue(os.access(prebuilt / "bin/clang", os.X_OK))
        self.assertEqual(game_pack._ndk_tool(ndk, "llvm-nm").resolve(), (self.llvm / "bin/llvm-nm").resolve()) \
            if game_pack.platform.system() == "Linux" else None
        game_pack.arm64_ndk(self.ndk, self.llvm, self.shim)  # rebuilding is safe

    def test_mismatched_llvm_is_refused(self):
        (self.llvm / "lib/clang/21").rename(self.llvm / "lib/clang/22")
        with self.assertRaisesRegex(BuildError, "does not match the NDK's clang"):
            game_pack.arm64_ndk(self.ndk, self.llvm, self.shim)

    def test_missing_libxml2_says_what_to_install(self):
        missing = subprocess.CompletedProcess([], 127, "", "ld.lld: error while loading shared libraries: "
                                              "libxml2.so.2: cannot open shared object file")
        with mock.patch.object(game_pack.subprocess, "run", return_value=missing), \
                self.assertRaisesRegex(BuildError, "sudo apt install libxml2"):
            game_pack.arm64_ndk(self.ndk, self.llvm, self.shim)


if __name__ == "__main__":
    unittest.main()
