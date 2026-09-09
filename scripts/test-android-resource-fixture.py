#!/usr/bin/env python3
"""Run the explicitly instrumented APK on an emulator and verify GPU outputs.

Usage: script ADB EMULATOR_SERIAL OUTPUT_DIRECTORY
Requires Pillow. Force-stops only dev.kartpad.android on the named emulator;
always disables both diagnostic properties afterward. Never accepts a phone.
"""
from pathlib import Path
from PIL import Image, ImageChops
import hashlib
import io
import json
import re
import subprocess
import sys
import time

adb, serial, destination = sys.argv[1:]
assert serial.startswith('emulator-'), 'Only disposable emulators are allowed'
out = Path(destination)
out.mkdir(parents=True, exist_ok=False)
base = [adb, '-s', serial]
package = 'dev.kartpad.android'

def run(*args):
    return subprocess.check_output(base + list(args), timeout=35)

def private(path):
    return run('exec-out', 'run-as', package, 'cat', path)

def validate_colors(image, colors):
    # Ignore the dividing edge and outside edges; require every interior pixel.
    for half, color in enumerate(colors):
        region = image.crop((image.width*(half*2+0.2)//4, image.height//4,
                             image.width*(half*2+1.8)//4, 3*image.height//4))
        expected = Image.new('RGB', region.size, color)
        assert ImageChops.difference(region, expected).getbbox() is None, (
            'Expected actual colored draws; blank or mixed-frame output is invalid', half, color)

def decode_rgba8(data):
    assert len(data) == 64*64*4, ('Invalid EFB readback size', len(data))
    image = Image.new('RGB', (64,64))
    for y in range(64):
        for x in range(64):
            tile=((y//4)*16+x//4)*64
            pixel=(y%4)*4+x%4
            image.putpixel((x,y),(data[tile+2*pixel+1],data[tile+32+2*pixel],data[tile+33+2*pixel]))
    return image

result = {'serial': serial, 'pairs_per_mode': 6, 'outputs': []}
try:
    for mode, switch in [('serial','0'),('overlap','1')]:
        run('shell','am','force-stop',package)
        run('shell','setprop','debug.kartpad.native_overlap',switch)
        run('shell','setprop','debug.kartpad.resource_fixture','1' if mode=='serial' else '2')
        for pair in range(6):
            for suffix in ['A.bmp','B.rgba8']:
                run('shell','run-as',package,'rm','-f',f'files/resource-{mode}-{pair}-{suffix}')
        old = set(run('shell','run-as',package,'ls','-1','files/KartPad/Logs').decode().splitlines())
        run('shell','am','start','-n',package+'/.KartPadActivity')
        deadline=time.monotonic()+45
        console=b''
        while time.monotonic()<deadline:
            names=run('shell','run-as',package,'ls','-1t','files/KartPad/Logs').decode().splitlines()
            fresh=[n for n in names if n.startswith('base_') and n not in old]
            if fresh:
                console=private('files/KartPad/Logs/'+fresh[0]+'/console.log')
                if b'RESOURCE_FIXTURE PASS' in console or b'RESOURCE_FIXTURE FAIL' in console:
                    break
            time.sleep(.5)
        (out/(mode+'-console.log')).write_bytes(console)
        assert f'RESOURCE_FIXTURE PASS mode={mode} pairs=6'.encode() in console, 'Fixture incomplete'
        assert b'[3]' not in console and b'[4]' not in console, 'Renderer error in fixture console'
        assert b'validation-and-robustness' in console, 'Enable Renderer Validation in the chooser first'
        assert console.count(b'B-recorded-before-A-encode') == (6 if mode=='overlap' else 0)
        slots=re.findall(rb'A-slot=(\d+) B-slot=(\d+)',console)
        assert len(slots)==6 and {a for a,b in slots}=={b'0',b'1',b'2'}, ('Missing staging-slot coverage',slots)
        assert all(a!=b for a,b in slots), ('A/B staging slot collision',slots)
        result[mode+'_slots']=[list(map(int,pair)) for pair in slots]
        for pair in range(6):
            for suffix in ['A.bmp','B.rgba8']:
                name=f'resource-{mode}-{pair}-{suffix}'
                data=private('files/'+name)
                (out/name).write_bytes(data)
                if suffix=='A.bmp':
                    assert ('Captured rendered frame to' in console.decode() and name.encode() in console), 'Missing current capture confirmation'
                image=(Image.open(io.BytesIO(data)).convert('RGB') if suffix=='A.bmp'
                       else decode_rgba8(data))
                validate_colors(image, [(0,255,0),(255,0,0)] if suffix=='A.bmp'
                                else [(255,255,0),(0,0,255)])
                image.save(out/(name+'.png'))
                if mode=='overlap':
                    baseline=(out/name.replace('overlap','serial')).read_bytes()
                    assert data == baseline, ('Serialized and overlap output differ', name)
                result['outputs'].append({'file':name,'sha256':hashlib.sha256(data).hexdigest()})
        print(mode, 'six colored A captures and B EFB readbacks verified', flush=True)
    result['result']='PASS: actual forced-overlap pixels and EFB bytes match serialized execution'
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(result['result'])
finally:
    run('shell','setprop','debug.kartpad.native_overlap','0')
    run('shell','setprop','debug.kartpad.resource_fixture','0')
    run('shell','am','force-stop',package)
