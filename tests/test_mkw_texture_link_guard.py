from __future__ import annotations

import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SCRIPT = REPO / 'scripts/inject-mkw-texture-link-guard.py'
SPEC = importlib.util.spec_from_file_location('texture_guard', SCRIPT)
GUARD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUARD)

# Synthetic traversal surrounding the exact injection anchors. It is not a
# copy of a translated function and contains no game assets.
FUNCTION = GUARD.SIGNATURE + '''
    [[maybe_unused]] const uint32_t r23 = ctx->gpr[3];
    const uint32_t r31 = ctx->gpr[4];
    const uint32_t count = MemoryInline::FlatRead32(r31);
    uint32_t r28 = 0, r0 = 0, r3 = 0;
    result = 0;
    goto next;
link:
    r3 = r31 + MemoryInline::FlatRead32(r31 + 8u + r28 * 8u);
''' + GUARD.ENTRY + '''
    if (matches(r3 + r0)) {
        if (found.size() < capacity) found.push_back(r3);
        ++result;
    }
}
''' + GUARD.NEXT_LINK + '''
}
next:
    if (r28 < count) goto link;
}
// RECOMP_GUEST_ABI synthetic fixture
'''


def graph(root: Path, paths: list[Path]) -> None:
    (root / 'shards.cmake').write_text('set(SOURCES\n' + ''.join(f'  "{p}"\n' for p in paths) + ')\n')


class TextureLinkGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.function = self.root / 'function.cpp'
        self.function.write_text(FUNCTION)

    def test_injects_once_and_preserves_other_functions(self):
        prefix = 'void unrelated() { int model_end = 0; }\n'
        self.function.write_text(prefix + FUNCTION)
        self.assertTrue(GUARD.inject(self.function))
        first = self.function.read_text()
        self.assertTrue(first.startswith(prefix))
        self.assertFalse(GUARD.inject(self.function))
        GUARD.verify(self.function)
        self.assertEqual(first, self.function.read_text())

    def test_rejects_partial_or_unexpected_guards_without_editing(self):
        GUARD.inject(self.function)
        guarded = self.function.read_text()
        variants = [FUNCTION, guarded.replace('0x34u', '4u'),
                    guarded.replace('goto loc_80228AD8;', 'return;'),
                    guarded.replace(GUARD.NEXT_LINK, ''), guarded + guarded,
                    guarded.replace(GUARD.MARKER, '// partial guard')]
        for source in variants:
            with self.subTest(source=source[:50]):
                self.function.write_text(source)
                with self.assertRaises(SystemExit): GUARD.verify(self.function)
                if source != FUNCTION:
                    with self.assertRaises(SystemExit): GUARD.inject(self.function)
                self.assertEqual(self.function.read_text(), source)

    def test_actual_compiled_shard_cannot_be_replaced_by_guarded_decoy(self):
        decoy = self.root / 'decoy.cpp'; decoy.write_text(FUNCTION); GUARD.inject(decoy)
        graph(self.root, [self.function])
        with self.assertRaises(SystemExit): GUARD.verify(GUARD.shard_definition(self.root))
        GUARD.inject(GUARD.shard_definition(self.root))
        GUARD.verify(self.function)
        graph(self.root, [self.function, decoy])
        with self.assertRaises(SystemExit): GUARD.shard_definition(self.root)
        nested = self.root / 'nested'; nested.mkdir(); graph(nested, [self.function])
        with self.assertRaises(SystemExit): GUARD.shard_definition(nested)

    def test_synthetic_traversal_reproduces_failure_and_keeps_valid_links(self):
        compiler = shutil.which(os.environ.get('CXX', 'clang++'))
        self.assertIsNotNone(compiler, 'C++ compiler is required for the traversal regression')
        harness = (REPO / 'tests/fixtures/texture_links/harness.cpp').read_text()
        for guarded in (False, True):
            if guarded: GUARD.inject(self.function)
            source = self.root / 'test.cpp'
            source.write_text(harness.replace('@FUNCTION@', self.function.read_text()))
            executable = self.root / 'test'
            compiled = subprocess.run([compiler, '-std=c++17', '-Wall', '-Wextra', '-Werror',
                                       '-fsanitize=address,undefined', '-fno-omit-frame-pointer',
                                       str(source), '-o', str(executable)], text=True, capture_output=True)
            self.assertEqual(compiled.returncode, 0, compiled.stderr)
            result = subprocess.run([str(executable)], text=True, capture_output=True)
            if guarded:
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn('texture-link traversal passed', result.stdout)
            else:
                self.assertNotEqual(result.returncode, 0)
                self.assertIn('guest read', result.stderr)

    def test_cached_builder_rejects_stale_standalone_or_compiled_texture_guard(self):
        sys.path.insert(0, str(REPO / 'builder'))
        from kartpad_builder.pipeline import BuildError, translate
        from kartpad_builder.profiles import Profile
        from test_retro_rel_report_guard import FUNCTION as REL_FUNCTION, GUARD as REL_GUARD
        functions = self.root / 'functions'; functions.mkdir()
        texture = functions / 'func_802289DC.cpp'; texture.write_text(FUNCTION); GUARD.inject(texture)
        rel = functions / 'func_8000A440.cpp'; rel.write_text(REL_FUNCTION); REL_GUARD.inject(rel)
        shards = self.root / 'build_shards'; shards.mkdir()
        compiled = shards / 'compiled.cpp'
        compiled.write_text(rel.read_text() + texture.read_text())
        (shards / 'shards.cmake').write_text(
            'set(MKW_BASE_FUNCTION_COUNT 2)\nset(MKW_RETRO_REWIND_FUNCTION_COUNT 1)\n'
            'set(MKW_HAVE_RETRO_REWIND_SHARDS ON)\nset(SOURCES\n' + f'  "{compiled}"\n)\n')
        profile = Profile(Path('synthetic.json'), {'translation': {
            'expectedGeneratedFunctions': 2, 'expectedBaseFunctions': 2, 'expectedRetroFunctions': 1,
            'injectors': [{'script': 'scripts/' + SCRIPT.name, 'function': texture.name}]}})
        translate(profile, REPO, self.root, self.root, 1, None)
        for stale in (texture, compiled):
            good = stale.read_text()
            stale.write_text(good.replace(GUARD.GUARD, GUARD.ENTRY))
            with self.assertRaises(BuildError): translate(profile, REPO, self.root, self.root, 1, None)
            stale.write_text(good)

    def test_all_translation_and_build_entrypoints_enforce_compiled_guard(self):
        profile = json.loads((REPO / 'builder/profiles/mkwii-rmcp01-rev0.json').read_text())
        self.assertIn({'function': 'func_802289DC.cpp', 'script': 'scripts/' + SCRIPT.name},
                      profile['translation']['injectors'])
        for path in (REPO / 'scripts').glob('*.sh'):
            source = path.read_text()
            if 'inject-retro-rel-report-guard.py' not in source: continue
            with self.subTest(script=path.name):
                self.assertEqual(source.count('inject-retro-rel-report-guard.py'), source.count(SCRIPT.name))
        for name in ('translate-base.sh', 'translate-online.sh', 'translate-retro-rewind.sh', 'generate-g8-full-title.sh'):
            source = (REPO / 'scripts' / name).read_text()
            self.assertLess(source.index('emit-build-shards'), source.index(SCRIPT.name + '" --inject-shards')
                            if SCRIPT.name + '" --inject-shards' in source else source.rindex('--inject-shards'))


if __name__ == '__main__':
    unittest.main()
