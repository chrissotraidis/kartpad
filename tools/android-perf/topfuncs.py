import sys,collections
import os
NDK=os.environ.get('ANDROID_NDK_ROOT', os.path.expanduser('~/Library/Android/sdk/ndk/29.0.14206865'))
sys.path.insert(0,NDK+'/simpleperf')
from simpleperf_report_lib import ReportLib
lib=ReportLib(); lib.SetRecordFile(sys.argv[1]); lib.SetSymfs(sys.argv[2]); tid=int(sys.argv[3])
c=collections.Counter(); n=0
while True:
    s=lib.GetNextSample()
    if s is None: break
    if s.tid!=tid: continue
    n+=1; name=lib.GetSymbolOfCurrentSample().symbol_name
    if name.startswith('func_'): c[name.split('(')[0]]+=1
tot=sum(c.values()); print('translated',tot,'of',n, f'{tot/n*100:.1f}%', 'functions', len(c))
acc=0
for i,(k,v) in enumerate(c.most_common(40)):
    acc+=v; print(f'{v/n*100:5.2f}% cum {acc/n*100:5.1f}%  {k}')

