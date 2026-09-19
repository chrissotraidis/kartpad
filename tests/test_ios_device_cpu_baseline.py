"""Device ISA selection and actual Apple compiler regression; no game build."""
from pathlib import Path
import platform
import subprocess
import tempfile
from runtime_sources import runtime_source, assert_runtime_staging, PLATFORMS
import unittest

ROOT = Path(__file__).resolve().parents[1]



class DeviceCpuBaselineTests(unittest.TestCase):
    def test_platform_selection(self):
        # Evaluate the maintained target-options branch with a synthetic sink.
        postimage = runtime_source("ios", "runtime/cmake/PublicProducts.cmake")
        branch = postimage[postimage.index('        if(CMAKE_SYSTEM_NAME'):]
        branch = branch[:branch.index('        endif()') + len('        endif()')]
        fixture = ('function(target_compile_options)\n'
                   'message(STATUS "SELECTED=${ARGV}")\nendfunction()\n' + branch)
        for system, sdk, generic in [('iOS', 'iphoneos', True),
                                    ('iOS', '/SDKs/iPhoneOS26.5.sdk', True),
                                    ('iOS', 'iphonesimulator', False),
                                    ('iOS', '/SDKs/iPhoneSimulator26.5.sdk', False),
                                    ('Darwin', 'macosx', False),
                                    ('tvOS', 'appletvos', True)]:
            with self.subTest(system=system, sdk=sdk), tempfile.TemporaryDirectory() as d:
                script = Path(d) / 'selection.cmake'
                script.write_text(fixture)
                result = subprocess.run(['cmake', '-DCMAKE_SYSTEM_NAME=' + system,
                                         '-DCMAKE_OSX_SYSROOT=' + sdk, '-P', str(script)],
                                        capture_output=True, text=True, check=True)
                self.assertIn('-mcpu=generic' if generic else '-mcpu=apple-m2', result.stdout)
                self.assertEqual('-Xclang -target-feature -Xclang -rcpc' in result.stdout, generic)

    def test_android_runtime_does_not_select_apple_cpu_flags(self):
        source = runtime_source("android", "runtime/cmake/PublicProducts.cmake")
        branch = source[source.index('        if(CMAKE_SYSTEM_NAME'):]
        branch = branch[:branch.index('        endif()') + len('        endif()')]
        with tempfile.TemporaryDirectory() as d:
            script = Path(d) / "android.cmake"
            script.write_text('set(CMAKE_SYSTEM_NAME Android)\nset(APPLE FALSE)\n'
                              'function(target_compile_options)\nmessage(FATAL_ERROR "Apple CPU flags on Android")\nendfunction()\n' + branch)
            subprocess.run(['cmake', '-P', str(script)], capture_output=True, text=True, check=True)

    def test_preparation_selects_maintained_platform_source(self):
        for platform in PLATFORMS:
            assert_runtime_staging(self, platform)

    def test_device_builder_refuses_old_prepared_source(self):
        with tempfile.TemporaryDirectory() as d:
            prepared = Path(d) / 'source'
            (prepared / 'cmake').mkdir(parents=True)
            (prepared / 'CMakeLists.txt').touch()
            (prepared / 'cmake/PublicProducts.cmake').write_text('# MKW_KARTPAD_REPO_ROOT\n')
            result = subprocess.run(['bash', str(ROOT / 'scripts/build-ios-device-game-app.sh'),
                                     str(prepared), str(Path(d) / 'unused-build')],
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 1)
            self.assertIn('prepared source files differ', result.stderr)
            self.assertIn('prepare a fresh runtime source', result.stderr)
            self.assertFalse((Path(d) / 'unused-build').exists())

    @unittest.skipUnless(platform.system() == 'Darwin', 'requires Apple clang')
    def test_actual_acquire_instruction(self):
        source = 'unsigned char acquire(const unsigned char *p) { return __atomic_load_n(p, __ATOMIC_ACQUIRE); }\n'
        sdk = subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-path'], text=True).strip()
        common = ['xcrun', 'clang', '-target', 'arm64-apple-ios16.0', '-isysroot', sdk, '-O2']
        for flags, expected in [(['-mcpu=apple-m2'], 'ldaprb'),
                                (['-mcpu=generic', '-Xclang', '-target-feature', '-Xclang', '-rcpc'], 'ldarb')]:
            with tempfile.TemporaryDirectory() as d:
                obj = Path(d) / 'acquire.o'
                subprocess.run(common + flags + ['-c', '-x', 'c', '-', '-o', str(obj)],
                               input=source, capture_output=True, text=True, check=True)
                assembly = subprocess.check_output(['xcrun', 'llvm-objdump', '-d', str(obj)], text=True)
            self.assertRegex(assembly, r'\b' + expected + r'\b')
            if expected == 'ldarb':
                self.assertNotRegex(assembly, r'\bldapr\w*\b')
        rejected = subprocess.run(common + ['-mcpu=apple-a10', '-c', '-x', 'assembler', '-', '-o', '/dev/null'],
                                  input='ldaprb w8, [x8]\n', capture_output=True, text=True)
        self.assertNotEqual(rejected.returncode, 0)
        self.assertIn('instruction requires: rcpc', rejected.stderr)


if __name__ == '__main__':
    unittest.main()
