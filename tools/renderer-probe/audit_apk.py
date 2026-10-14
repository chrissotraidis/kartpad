#!/usr/bin/env python3
"""Audit this synthetic diagnostic APK; this is not KartPad's game APK auditor."""
import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('apk', type=Path)
a = p.parse_args()
sdk = Path(os.environ.get('ANDROID_HOME', Path.home() / 'Library/Android/sdk'))
bt = sdk / 'build-tools/36.0.0'
badging = subprocess.check_output([bt/'aapt2', 'dump', 'badging', a.apk], text=True)
assert "name='dev.kartpad.rendererprobe' versionCode='3' versionName='0.3.0'" in badging
assert "native-code: 'arm64-v8a'" in badging
assert 'application-debuggable' not in badging and 'uses-permission' not in badging
subprocess.run([bt/'zipalign', '-c', '-P', '16', '4', a.apk], check=True)
cert = subprocess.check_output([bt/'apksigner', 'verify', '--print-certs', a.apk], text=True)
assert 'CN=Android Debug' not in cert
assert 'certificate SHA-256 digest: c1dbe0a0d72d830a5779476b346a750d0a37515adef992cad2f3863058f7f2f2' in cert
assert cert.count('certificate SHA-256 digest:') == 1
notices = {
    'assets/notices/LICENSE': ROOT/'LICENSE',
    'assets/notices/Aurora-MIT.txt': ROOT/'vendor/runtimes/android/aurora-main/LICENSE',
    'assets/notices/NDK-toolchain.txt': sdk/'ndk/29.0.14206865/NOTICE.toolchain',
}
for file in (ROOT/"tools/renderer-probe/licenses").glob("*.txt"):
    notices["assets/notices/"+file.name]=file
with zipfile.ZipFile(a.apk) as z:
    assert z.testzip() is None
    names=z.namelist()
    assert len(names)==len(set(names))
    assert all(not n.startswith('/') and '..' not in Path(n).parts for n in names)
    assert [n for n in names if n.endswith('.so')]==['lib/arm64-v8a/libkartpad_renderer_probe.so']
    assert set(n for n in names if n.startswith('assets/'))==set(notices)
    for n,path in notices.items(): assert z.read(n)==path.read_bytes(),n
    for n in names:
        assert not n.endswith(('.dat','.iso','.wbfs','.p12','.jks','.keystore','.pem','.key')),n
        b=z.read(n)
        for forbidden in (b'rksys.dat',b'RFL_DB.dat',b'SCGetProductSN_HLE',str(Path.home()).encode() + b'/',b'private/g8-full-translation'):
            assert forbidden not in b,(n,forbidden)
    native=z.read('lib/arm64-v8a/libkartpad_renderer_probe.so')
    assert native[:4]==b'\x7fELF' and native[4]==2 and int.from_bytes(native[18:20],'little')==183
    phoff=int.from_bytes(native[32:40],'little'); ents=int.from_bytes(native[54:56],'little'); count=int.from_bytes(native[56:58],'little')
    for i in range(count):
        hdr=native[phoff+i*ents:phoff+(i+1)*ents]
        if int.from_bytes(hdr[:4],'little')==1:
            assert int.from_bytes(hdr[48:56],'little')>=16384,'ELF load segment alignment'
print('PASS: separate package, no permissions, non-debuggable, approved signer, ARM64/16KiB alignment, exact notices, bounded content scan.')
print(hashlib.sha256(a.apk.read_bytes()).hexdigest(),a.apk.name,a.apk.stat().st_size)
