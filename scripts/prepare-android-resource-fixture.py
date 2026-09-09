#!/usr/bin/env python3
"""Inject a disposable GPU oracle into a prepared Debug runtime, never normal builds.

Pass --remove after the root to restore the three original source files. The APK
must be labelled as a fixture, not installed on an owner's physical device.
"""
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()
repo = Path(__file__).resolve().parent.parent
aurora = root / 'aurora-main/lib/aurora.cpp'
main = root / 'src/main.cpp'
common = root / 'aurora-main/lib/gfx/common.cpp'
paths = (aurora, main, common)
backups = [p.with_name(p.name + '.resource-fixture-original') for p in paths]
if sys.argv[2:] == ['--remove']:
    assert all(p.is_file() for p in backups), 'Missing original-source backups'
    for path, backup in zip(paths, backups):
        path.write_bytes(backup.read_bytes())
        backup.unlink()
    print('Restored ordinary runtime source:', root)
    raise SystemExit(0)
assert len(sys.argv) == 2, 'Unexpected arguments'
assert not any(p.exists() for p in backups), 'Original-source backups already exist'
text = aurora.read_text()
assert 'KartPadAndroidResourceFixture' not in text, 'already instrumented'
declaration = '\nnamespace kartpad_resource_fixture { void before_encode(); }\n'
text = text.replace('namespace aurora {\nAuroraConfig g_config;', declaration + '\nnamespace aurora {\nAuroraConfig g_config;', 1)
needle = '    presentationJobs = encode_sealed_frame(sealedFrame, ctx);\n    publish_presentations'
assert text.count(needle) == 1
text = text.replace(needle, '    kartpad_resource_fixture::before_encode();\n'+needle)
fixture = (repo / 'scripts/fixtures/android-frame-resource.inc').read_text()
text += '\n// Explicitly injected local fixture.\nextern "C" bool KartPadAndroidNativeFrameOverlapExperiment();\n' + fixture
main_text = main.read_text()
needle = '        const AuroraInfo auroraInfo = aurora_initialize(0, nullptr, &auroraConfig);'
assert main_text.count(needle) == 1
main_text = 'extern "C" int KartPadAndroidResourceFixture();\n' + main_text.replace(needle, needle + '''
        const int fixtureResult = KartPadAndroidResourceFixture();
        if (fixtureResult >= 0) {
            aurora_shutdown();
            return fixtureResult;
        }
''')
for path, backup in zip(paths, backups):
    backup.write_bytes(path.read_bytes())
aurora.write_text(text)
main.write_text(main_text)
common.write_text(common.read_text() + '\nextern "C" size_t KartPadAndroidFixtureStagingSlot() { return aurora::gfx::currentStagingBuffer; }\n')
print('Injected local-only resource fixture:', root)
