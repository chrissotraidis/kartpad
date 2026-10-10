import sys,collections
import os
NDK=os.environ.get('ANDROID_NDK_ROOT', os.path.expanduser('~/Library/Android/sdk/ndk/29.0.14206865'))
sys.path.insert(0,NDK+'/simpleperf')
from simpleperf_report_lib import ReportLib
lib=ReportLib(); lib.SetRecordFile(sys.argv[1]); lib.SetSymfs(sys.argv[2]); tid=int(sys.argv[3])
c=collections.Counter(); n=0; k=0
while True:
    s=lib.GetNextSample()
    if s is None: break
    if s.tid!=tid: continue
    n+=1
    y=lib.GetSymbolOfCurrentSample()
    if '[kernel' not in y.dso_name and 'kallsyms' not in y.dso_name: continue
    k+=1
    cc=lib.GetCallChainOfCurrentSample()
    chain=[cc.entries[i].symbol.symbol_name for i in range(cc.nr) if 'kallsyms' not in cc.entries[i].symbol.dso_name and 'kernel' not in cc.entries[i].symbol.dso_name]
    key=' <- '.join(x.split('(')[0][:50] for x in chain[:4])
    c[key]+=1
print('kernel samples',k,'of',n)
for x,v in c.most_common(12): print(f'{v/n*100:5.2f}%  {x}')
