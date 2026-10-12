import subprocess, sys, time, xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[2]/'build'/'perf'/'ui'; root.mkdir(parents=True, exist_ok=True)
adb=[str(Path.home()/'Library/Android/sdk/platform-tools/adb'),'-s',__import__('os').environ.get('KP_SERIAL','emulator-5554')]
def dump():
    subprocess.run(adb+['shell','uiautomator','dump','/sdcard/kp-window.xml'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    content=subprocess.check_output(adb+['shell','cat','/sdcard/kp-window.xml'])
    try:
        for n in ET.fromstring(content).iter('node'):
            if n.get('text') or n.get('content-desc'): print(repr(n.get('text')), repr(n.get('content-desc')), n.get('bounds'), n.get('resource-id'))
    except ET.ParseError: print('no window dump')
args=sys.argv[1:]
while args:
    a=args.pop(0)
    if a=='dump': dump()
    elif a=='tap': x,y=args.pop(0),args.pop(0); subprocess.run(adb+['shell','input','tap',x,y],check=True)
    elif a=='key': subprocess.run(adb+['shell','input','keyevent',args.pop(0)],check=True)
    elif a=='text': subprocess.run(adb+['shell','input','text',args.pop(0)],check=True)
    elif a=='shot': (root/(args.pop(0)+'.png')).write_bytes(subprocess.check_output(adb+['exec-out','screencap','-p']))
    elif a in ('A','B','START'):
        import os; x,y=({'A':(2050,577),'B':(1870,677),'START':(2065,225)} if os.environ.get('KP_SERIAL','').startswith('4718') else {'A':(2205,603),'B':(1990,705),'START':(2203,266)})[a]; subprocess.run(adb+['shell','input','touchscreen','swipe',str(x),str(y),str(x),str(y),'600'],check=True); time.sleep(1.5)
    elif a.startswith('w'): time.sleep(float(a[1:]))
    elif a=='swipe': subprocess.run(adb+['shell','input','touchscreen','swipe',*[args.pop(0) for _ in range(5)]],check=True)
