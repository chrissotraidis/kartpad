import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "builder"))
from kartpad_builder import game_pack, ios_sdk  # noqa: E402
from kartpad_builder.errors import BuildError  # noqa: E402

REPO = Path(__file__).resolve().parents[1]

# Stands in for Apple's AvailabilityVersions script: version lists and --preprocess.
AVAILABILITY = """import sys
if sys.argv[1] == "--ios": print("15.0 16.0 16.0.1 17.3")
elif sys.argv[1] == "--macosx": print("10.9 10.15 14.3")
else: open(sys.argv[3], "w").write("/* " + sys.argv[2].replace(chr(92), "/").rsplit("/", 1)[-1] + " */\\n")
"""


class IosSdkTests(unittest.TestCase):
    """Synthetic open-source trees with the real layout; the real ones come from PadMint."""

    def test_blobs_from_any_translator_host_become_mach_o(self):
        mac = '.section __TEXT,__const\n\n// a\n.p2align 4\n.globl _kData_x\n_kData_x:\n.incbin "x.bin"\n\n'
        linux = ('.section .rodata,"a",@progbits\n\n// a\n.p2align 4\n.globl kData_x\n.globl _kData_x\n'
                 'kData_x:\n_kData_x:\n.incbin "x.bin"\n\n.section .note.GNU-stack,"",@progbits\n')
        windows = '.section .rdata,"dr"\n\n// a\n.p2align 4\n.globl kData_x\nkData_x:\n.incbin "x.bin"\n\n'
        with tempfile.TemporaryDirectory() as temporary:
            translation = Path(temporary) / "translation"
            mod = Path(temporary) / "mod/cpp/mod_blobs.S"
            (translation / "build_shards").mkdir(parents=True)
            mod.parent.mkdir(parents=True)
            (translation / "build_shards/shards.cmake").write_text(
                f'set(MKW_RETRO_EXTRA_SOURCES\n  "{mod.as_posix()}"\n  "{mod.with_suffix(".cpp").as_posix()}")\n')
            for text in (linux, windows, mac):
                (translation / "data_sections_init_blobs.S").write_text(text)
                mod.write_text(text)
                game_pack.mach_o_blobs(translation)
                self.assertEqual((translation / "data_sections_init_blobs.S").read_text(), mac)
                self.assertEqual(mod.read_text(), mac)

    def test_install_defines_resolve_only_named_directives(self):
        text = ("#ifdef XNU_PLATFORM_iPhoneOS\n#ifndef __OPEN_SOURCE__ /* x */\n"
                "#if defined(MODULES_SUPPORTED) && defined(__arm64__)\n#elif XNU_PLATFORM_iPhoneOS || KERNEL\n"
                "#if XNU_PLATFORM_MacOSX\nint XNU_PLATFORM_iPhoneOS;\n")
        self.assertEqual(ios_sdk._resolve_defines(text, ios_sdk.INSTALL_DEFINES["xnu"]).split("\n"), [
            "#if 1", "#if 0 /* x */", "#if 1 && defined(__arm64__)", "#elif 1 || KERNEL",
            "#if XNU_PLATFORM_MacOSX", "int XNU_PLATFORM_iPhoneOS;", ""])

    def test_libc_install_blocks_are_removed(self):
        text = "a\n//Begin-Libc\n#ifndef LIBC_ALIAS_X\n//End-Libc\nint x;\n//Begin-Libc\n#else\n#endif\n//End-Libc\nb\n"
        self.assertEqual(ios_sdk._strip_libc_blocks(text), "a\nint x;\nb\n")

    def test_stubs_name_the_apps_thread_locals(self):
        with tempfile.TemporaryDirectory() as temporary:
            sdk = Path(temporary)
            ios_sdk.write_stubs(sdk, ["_g_b", "_g_a"])
            system = (sdk / "usr/lib/libSystem.tbd").read_text()
            self.assertIn("install-name:    '/usr/lib/libSystem.B.dylib'", system)
            self.assertIn("symbols:         [ 'dyld_stub_binder' ]", system)
            self.assertIn("thread-local-symbols: [ '_g_a', '_g_b' ]", system)
            self.assertNotIn("exports", (sdk / "usr/lib/libc++.tbd").read_text())

    def test_libcxx_site_configuration_is_complete(self):
        template = ("#cmakedefine _LIBCPP_ABI_VERSION @_LIBCPP_ABI_VERSION@\n#cmakedefine01 _LIBCPP_HAS_THREADS\n"
                    "#cmakedefine _LIBCPP_NO_VCRUNTIME\n#cmakedefine _LIBCPP_PSTL_BACKEND_LIBDISPATCH\n"
                    "#cmakedefine _LIBCPP_HARDENING_MODE_DEFAULT @_LIBCPP_HARDENING_MODE_DEFAULT@\n"
                    "@_LIBCPP_ABI_DEFINES@\n")
        self.assertEqual(ios_sdk._config_site(template).split("\n"), [
            "#define _LIBCPP_ABI_VERSION 1", "#define _LIBCPP_HAS_THREADS 1", "/* #undef _LIBCPP_NO_VCRUNTIME */",
            "#define _LIBCPP_PSTL_BACKEND_LIBDISPATCH", "#define _LIBCPP_HARDENING_MODE_DEFAULT 2", "", ""])

    def test_missing_sources_name_what_padmint_installs(self):
        with self.assertRaisesRegex(BuildError, "PADMINT_APPLE_XNU"):
            ios_sdk.source_roots({})

    def test_assembles_every_header_with_its_origin_and_license(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            roots = {name: root / name for name in ios_sdk.SOURCES}
            for source, folder, _target, names in ios_sdk.HEADERS:
                for name in (["_a.h"] if names == "*" else names.split()):
                    path = roots[source] / folder / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    notice = "Apple Public Source License Version 2.0" if source != "libc" else "plain"
                    path.write_text(f"/* {notice} */\n#ifdef XNU_PLATFORM_iPhoneOS\nint {name[:-2]};\n#endif\n")
            (roots["availability"] / "templates").mkdir(parents=True)
            (roots["availability"] / "availability").write_text(AVAILABILITY)
            (roots["libcxx"] / "include/__algorithm").mkdir(parents=True)
            (roots["libcxx"] / "include/vector").write_text("// vector\n")
            (roots["libcxx"] / "include/__algorithm/sort.h").write_text("// sort\n")
            (roots["libcxx"] / "include/CMakeLists.txt").write_text("not a header\n")
            (roots["libcxx"] / "include/__config_site.in").write_text("#cmakedefine01 _LIBCPP_HAS_THREADS\n")
            (roots["libcxx"] / "vendor/llvm").mkdir(parents=True)
            (roots["libcxx"] / "vendor/llvm/default_assertion_handler.in").write_text("// handler\n")
            sdk = ios_sdk.assemble(REPO, root / "sdk", roots)

            include = sdk / "usr/include"
            self.assertIn("#if 1", (include / "sys/cdefs.h").read_text())
            self.assertEqual((include / "Availability.h").read_text(), "/* Availability.h */\n")
            aliasing = (include / "sys/_symbol_aliasing.h").read_text()
            self.assertIn("__DARWIN_ALIAS_STARTING_IPHONE___IPHONE_16_0(x) x", aliasing)
            self.assertNotIn("16_0_1", aliasing)
            self.assertIn("__DARWIN_ALIAS_STARTING_MAC___MAC_10_15(x) x", aliasing)
            self.assertTrue((include / "math.h").is_file() and (include / "TargetConditionals.h").is_file())
            self.assertEqual((include / "c++/v1/__config_site").read_text(), "#define _LIBCPP_HAS_THREADS 1\n")
            self.assertTrue((include / "c++/v1/__algorithm/sort.h").is_file())
            self.assertFalse((include / "c++/v1/CMakeLists.txt").exists())
            self.assertIn("'/usr/lib/libSystem.B.dylib'", (sdk / "usr/lib/libSystem.tbd").read_text())
            record = json.loads((sdk / "SOURCES.json").read_text())
            files = {item["file"]: item for item in record["files"]}
            written = {p.relative_to(sdk).as_posix() for p in sdk.rglob("*") if p.is_file()}
            self.assertEqual(written - set(files), {"SDKSettings.json", "SOURCES.json",
                                                     "usr/lib/libSystem.tbd", "usr/lib/libc++.tbd"})
            self.assertEqual(files["usr/include/sys/cdefs.h"]["license"], "APSL-2.0")
            self.assertEqual(files["usr/include/math.h"]["license"], "GPL-3.0-or-later")
            self.assertEqual(files["usr/include/c++/v1/vector"]["license"], "Apache-2.0 WITH LLVM-exception")


if __name__ == "__main__":
    unittest.main()
