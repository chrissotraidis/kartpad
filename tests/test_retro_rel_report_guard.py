from __future__ import annotations

import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from runtime_sources import runtime_source, assert_runtime_staging, PLATFORMS
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'scripts/inject-retro-rel-report-guard.py'
FIXTURES = REPO / 'tests/fixtures/rel_report'
FUNCTION = (FIXTURES / 'function.cpp').read_text()
SPEC = importlib.util.spec_from_file_location('rel_guard', SCRIPT)
GUARD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUARD)
sys.path.insert(0, str(REPO / 'builder'))
from kartpad_builder.pipeline import BuildError, translate
from kartpad_builder.profiles import Profile


def helper_source() -> str:
    source = runtime_source("ios", "runtime/src/recomp_mod_loader.cpp")
    return re.search(r'bool TryGetRelReportSectionTable\([^;\n]+\) noexcept \{.*?\n\}', source, re.S).group()


def write_graph(root: Path, sources: list[Path]) -> None:
    (root / 'shards.cmake').write_text(
        'set(MKW_BASE_FUNCTION_COUNT 1)\nset(MKW_RETRO_REWIND_FUNCTION_COUNT 1)\n'
        'set(MKW_HAVE_RETRO_REWIND_SHARDS ON)\nset(MKW_BASE_COMMON_SHARDS\n' +
        ''.join(f'  "{p}"\n' for p in sources) + ')\n')


class RelReportGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.function = self.root / 'func_8000A440.cpp'
        self.function.write_text(FUNCTION)

    def test_injects_same_transformation_into_standalone_and_aggregate(self):
        prefix = '// Another function may read r28 too.\nvoid unrelated() {\n' + GUARD.HEADER_ENTRY + '\n}\n'
        shard = self.root / 'shard.cpp'
        shard.write_text(prefix + FUNCTION + '\n// trailing source\n')
        self.assertTrue(GUARD.inject(self.function))
        self.assertTrue(GUARD.inject(shard))
        self.assertEqual(shard.read_text(), prefix + self.function.read_text() + '\n// trailing source\n')
        for path in (self.function, shard):
            before = path.read_bytes()
            self.assertFalse(GUARD.inject(path))
            GUARD.verify(path)
            self.assertEqual(path.read_bytes(), before)
            self.assertIn(GUARD.LOOP_ENTRY, path.read_text())

    def test_rejects_unsafe_guards_without_mutating_source(self):
        GUARD.inject(self.function)
        good = self.function.read_text()
        variants = {
            'stale': FUNCTION,
            'missing-loop': good.replace(GUARD.LOOP_ENTRY, ''),
            'early-return': good.replace('goto loc_8000A51C;', 'return;'),
            'missing-include': good.replace('#include "recomp_mod_loader.h"', ''),
            'unchecked-table': good.replace(GUARD.LOOP_ENTRY, GUARD.TABLE_ENTRY),
            'read-before-guard': good.replace(GUARD.GUARD, GUARD.HEADER_ENTRY + '\n' + GUARD.GUARD),
            'missing-cleanup': good.replace('ctx->lr = r0;', ''),
            'duplicate': good + good,
        }
        for name, source in variants.items():
            with self.subTest(name=name):
                self.function.write_text(source)
                with self.assertRaises(SystemExit):
                    GUARD.verify(self.function)
                if name != 'stale':
                    with self.assertRaises(SystemExit):
                        GUARD.inject(self.function)
                self.assertEqual(self.function.read_text(), source)

    def test_graph_selects_actual_compiled_source_not_guarded_decoy(self):
        decoy = self.root / 'decoy.cpp'
        decoy.write_text(FUNCTION)
        GUARD.inject(decoy)
        write_graph(self.root, [self.function])
        with self.assertRaises(SystemExit):
            GUARD.verify(GUARD.shard_definition(self.root))
        GUARD.inject(self.function)
        GUARD.verify(GUARD.shard_definition(self.root))
        write_graph(self.root, [self.function, decoy])
        with self.assertRaises(SystemExit):
            GUARD.shard_definition(self.root)
        write_graph(self.root, [])
        with self.assertRaises(SystemExit):
            GUARD.shard_definition(self.root)
        write_graph(self.root, [self.root / 'missing.cpp'])
        with self.assertRaises(OSError):
            GUARD.shard_definition(self.root)

    def test_graph_rejects_report_outside_the_output_tree(self):
        nested = self.root / 'shards'
        nested.mkdir()
        write_graph(nested, [self.function])
        with self.assertRaises(SystemExit):
            GUARD.shard_definition(nested)
        self.assertEqual(self.function.read_text(), FUNCTION)

    def test_cached_builder_rejects_stale_shard_even_with_guarded_standalone(self):
        functions = self.root / 'functions'
        functions.mkdir()
        standalone = functions / self.function.name
        standalone.write_text(FUNCTION)
        GUARD.inject(standalone)
        shards = self.root / 'build_shards'
        shards.mkdir()
        compiled = shards / 'shard.cpp'
        compiled.write_text(FUNCTION)
        write_graph(shards, [compiled])
        profile = Profile(Path('synthetic.json'), {'translation': {
            'expectedGeneratedFunctions': 1, 'expectedBaseFunctions': 1, 'expectedRetroFunctions': 1}})
        with self.assertRaises(BuildError):
            translate(profile, REPO, self.root, self.root, 1, None)
        GUARD.inject(compiled)
        translate(profile, REPO, self.root, self.root, 1, None)

    def test_pinned_6128_builder_accepts_current_mod_count_and_rejects_stale_count(self):
        data = json.loads((REPO / 'builder/profiles/mkwii-rmcp01-rev0.json').read_text())
        self.assertEqual(data['retroRewind']['version'], '6.12.8')
        self.assertEqual(data['translation']['expectedRetroFunctions'], 4102)
        # Keep the real mod-count pin; one guarded fixture stands in for the base graph.
        data['translation']['expectedGeneratedFunctions'] = 1
        data['translation']['expectedBaseFunctions'] = 1
        profile = Profile(Path('fixture.json'), data)
        functions = self.root / 'functions'
        functions.mkdir()
        standalone = functions / 'func_8000A440.cpp'
        standalone.write_text(FUNCTION)
        GUARD.inject(standalone)
        shards = self.root / 'build_shards'
        shards.mkdir()
        compiled = shards / 'shard.cpp'
        compiled.write_text(standalone.read_text())
        write_graph(shards, [compiled])
        graph = shards / 'shards.cmake'
        template = graph.read_text()
        for count in (4188, 4095, 4100, 4101, 4102, 4103):
            with self.subTest(mod_functions=count):
                graph.write_text(template.replace('MKW_RETRO_REWIND_FUNCTION_COUNT 1)',
                                                  f'MKW_RETRO_REWIND_FUNCTION_COUNT {count})'))
                if count == 4102:
                    translate(profile, REPO, self.root, self.root, 1, None)
                else:
                    with self.assertRaisesRegex(BuildError, 'cached translation failed profile validation'):
                        translate(profile, REPO, self.root, self.root, 1, None)

    def test_fresh_builder_guards_cached_bundle_output_after_emission(self):
        profile = Profile(Path('synthetic.json'), {'game': {'region': 'P'}, 'translation': {
            'expectedGeneratedFunctions': 1, 'expectedBaseFunctions': 1, 'expectedRetroFunctions': 1,
            'entryPoints': ['0x800060A4'], 'injectors': [
                {'script': 'scripts/inject-retro-rel-report-guard.py', 'function': 'func_8000A440.cpp'}]}})
        output = self.root / 'translation'
        standalone = output / 'functions/func_8000A440.cpp'
        compiled = output / 'build_shards/shard.cpp'
        retro = SimpleNamespace(code_pul=self.root / 'code', root=self.root, payload=self.root / 'payload')

        def run(command):
            if command[0] == str(SCRIPT):
                subprocess.run(command, check=True, capture_output=True)
            elif 'translate-recursive' in command:
                standalone.parent.mkdir(parents=True)
                standalone.write_text(FUNCTION)
            elif 'generate-data-init' in command:
                (output / 'data_sections_init_blobs.S').write_text('.globl _kData_fixture')
            elif 'emit-build-shards' in command:
                # The emitter chooses the unmodified cached source bundle even
                # though the standalone injector already succeeded.
                GUARD.verify(standalone)
                compiled.parent.mkdir()
                compiled.write_text(FUNCTION)
                write_graph(compiled.parent, [compiled])

        with patch('kartpad_builder.pipeline.write_translator_manifest'), patch('kartpad_builder.pipeline.run', side_effect=run):
            translate(profile, REPO, self.root, output, 1, retro)
        GUARD.verify(standalone)
        GUARD.verify(compiled)
        self.assertEqual(standalone.read_text(), compiled.read_text())

    def test_build_and_translation_entry_points_enforce_the_compiled_guard(self):
        for name in ('build-android-game-app.sh', 'build-ios-game-app.sh',
                     'build-ios-device-game-app.sh', 'build-tvos-game-app.sh',
                     'prepare-ios-game-runtime.sh', 'prepare-g7-game-runtime.sh'):
            source = (REPO / 'scripts' / name).read_text()
            with self.subTest(name=name):
                self.assertIn('inject-retro-rel-report-guard.py" --verify', source)
                self.assertIn('inject-retro-rel-report-guard.py" --verify-shards', source)
        for name in ('translate-base.sh', 'translate-online.sh', 'translate-retro-rewind.sh', 'generate-g8-full-title.sh'):
            source = (REPO / 'scripts' / name).read_text()
            with self.subTest(name=name):
                self.assertLess(source.index('emit-build-shards'), source.index('--inject-shards'))
                self.assertIn('--verify-shards', source)
        for name in ('prepare-ios-game-runtime.sh', 'prepare-g7-game-runtime.sh'):
            assert_runtime_staging(self, "macos" if "g7" in name else "ios")
        for name in ('prepare-android-game-runtime.sh', 'prepare-tvos-game-runtime.sh'):
            self.assertIn('prepare-ios-game-runtime.sh', (REPO / 'scripts' / name).read_text())

    def test_helper_is_present_in_every_maintained_runtime(self):
        for platform in PLATFORMS:
            with self.subTest(platform=platform):
                self.assertIn(helper_source(), runtime_source(platform, "runtime/src/recomp_mod_loader.cpp"))
                self.assertIn("TryGetRelReportSectionTable", runtime_source(platform, "runtime/include/recomp_mod_loader.h"))



class CompiledRelReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temp.cleanup)
        cls.root = Path(cls.temp.name)
        (cls.root / 'recomp_mod_loader.h').write_text('// declaration provided by harness\n')
        function = cls.root / 'function.cpp'
        function.write_text(FUNCTION)
        GUARD.inject(function)
        cls.good = function.read_text()
        cls.compile('guarded', cls.good)
        cls.compile('unguarded', FUNCTION)
        cls.compile('missing-loop', cls.good.replace(GUARD.LOOP_ENTRY, ''))
        cls.compile('early-return', cls.good.replace('goto loc_8000A51C;', 'return;'))

    @classmethod
    def compile(cls, name, function):
        source = (FIXTURES / 'harness.cpp').read_text().replace('@HELPER@', helper_source()).replace('@FUNCTION@', function)
        path = cls.root / (name + '.cpp')
        path.write_text(source)
        subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++17', '-Wall', '-Wextra',
                        '-Wno-unused-label', '-Werror', '-fsanitize=address,undefined',
                        '-I', str(cls.root), str(path), '-o', str(cls.root / name)],
                       check=True, capture_output=True, text=True)

    def run_case(self, binary, case):
        return subprocess.run([str(self.root / binary), case], capture_output=True, text=True)

    def test_bounded_pointer_checks_and_preserved_report_behavior(self):
        for case in ('valid', 'empty', 'header-null', 'header-unmapped', 'header-unaligned',
                     'header-end', 'header-wrap', 'read-failure', 'table-null', 'table-unaligned',
                     'table-end', 'table-wrap', 'count-overflow', 'last-entry'):
            with self.subTest(case=case):
                result = self.run_case('guarded', case)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_negative_controls_detect_original_fault_and_broken_shard_repair(self):
        for binary, case, failure in (
            ('unguarded', 'header-null', 'unchecked REL read'),
            ('unguarded', 'table-null', 'unchecked REL read'),
            ('missing-loop', 'empty', 'unchecked REL read'),
            ('missing-loop', 'valid', 'section iteration count'),
            ('early-return', 'header-null', 'stack/link restoration'),
        ):
            with self.subTest(binary=binary, case=case):
                result = self.run_case(binary, case)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(failure, result.stderr)


if __name__ == '__main__':
    unittest.main()
