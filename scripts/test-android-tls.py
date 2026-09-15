#!/usr/bin/env python3
"""Compare scalar results across dynamically loaded API-29 TLS variants."""
import argparse
import os
from pathlib import Path
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--runtime-source', required=True, type=Path, help='Verified prepared Android runtime')
p.add_argument('--serial', required=True, help='Explicit authorized ADB target')
p.add_argument('--output', type=Path, default=Path('build/tls-tests'))
a = p.parse_args()
r = Path(__file__).resolve().parents[1]
o = a.output.resolve()
o.mkdir(parents=True, exist_ok=True)
sdk = Path(os.environ.get('ANDROID_SDK_ROOT', str(Path.home() / 'Library/Android/sdk')))
c = sdk / 'ndk/29.0.14206865/toolchains/llvm/prebuilt/darwin-x86_64/bin/aarch64-linux-android29-clang++'
flags = [str(c), '-std=c++20', '-O2', '-fPIC', '-fvisibility=hidden', '-fno-fast-math',
         '-ffp-contract=off', '-fno-slp-vectorize', '-DKARTPAD_ANDROID_COMBINED_FENV=1',
         '-I'+str(r/'runtime/include'), '-I'+str(a.runtime_source.resolve()/'include')]
for mode, flag in [('emulated', '-femulated-tls'), ('native', '-fno-emulated-tls')]:
    subprocess.run(flags + [flag, '-shared', '-static-libstdc++',
        str(r/'runtime/tests/android_tls_digest.cpp'), str(r/'runtime/tests/android_tls_case.cpp'),
        str(r/'runtime/src/android/scalar_fenv.cpp'), '-o', str(o/(mode+'.so'))], check=True)
subprocess.run([str(c), '-static-libstdc++', str(r/'runtime/tests/android_tls_loader.cpp'),
                '-ldl', '-o', str(o/'loader')], check=True)
adb = [str(sdk/'platform-tools/adb'), '-s', a.serial]
target = '/data/local/tmp/kartpad-tls-tests'
subprocess.run(adb+['shell', 'mkdir', '-p', target], check=True)
for name in ['loader', 'emulated.so', 'native.so']:
    subprocess.run(adb+['push', str(o/name), target+'/'+name], check=True)
results = []
for mode in ['emulated', 'native']:
    result = subprocess.check_output(adb+['shell', target+'/loader', target+'/'+mode+'.so'], text=True)
    (o/(mode+'.txt')).write_text(result)
    lines = sorted(result.strip().splitlines())
    if len(lines) != 2 or any(not s.startswith('PASS 224000 cases digest=') for s in lines):
        raise SystemExit('Missing expected test results: '+result)
    results.append(lines)
if results[0] != results[1]:
    raise SystemExit('TLS variants changed scalar results: '+repr(results))
print('PASS: 448000 cases match across emulated/native shared libraries, including nested scopes and two OS threads.')
print('\n'.join(results[0]))
