import sys,collections,subprocess
import os
NDK=os.environ.get('ANDROID_NDK_ROOT', os.path.expanduser('~/Library/Android/sdk/ndk/29.0.14206865'))
sys.path.insert(0,NDK+'/simpleperf')
from simpleperf_report_lib import ReportLib
data,symfs,tid,sym,lib_path=sys.argv[1],sys.argv[2],int(sys.argv[3]),sys.argv[4],sys.argv[5]
lib=ReportLib(); lib.SetRecordFile(data); lib.SetSymfs(symfs)
c=collections.Counter(); n=0
while True:
    s=lib.GetNextSample()
    if s is None: break
    if s.tid!=tid: continue
    n+=1
    y=lib.GetSymbolOfCurrentSample()
    if y.symbol_name.startswith(sym): c[y.vaddr_in_file]+=1
tot=sum(c.values()); print('function samples',tot,'of',n)
addrs=list(c)
out=subprocess.run([NDK+'/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-addr2line','-f','-i','-C','-e',lib_path]+[hex(a) for a in addrs],capture_output=True,text=True).stdout
# group output per address: each address yields pairs (func,line) until next; use --output-style? simpler: run per address
byfunc=collections.Counter(); byline=collections.Counter()
for a in addrs:
    o=subprocess.run([NDK+'/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-addr2line','-f','-i','-C','-e',lib_path,hex(a)],capture_output=True,text=True).stdout.strip().split('\n')
    inner_f=o[0].split('(')[0]; inner_l=o[1].split('/')[-1] if len(o)>1 else '?'
    byfunc[inner_f]+=c[a]; byline[inner_f+' @ '+inner_l]+=c[a]
for k,v in byfunc.most_common(15): print(f'{v/tot*100:5.1f}%  {k[:100]}')
print('---')
for k,v in byline.most_common(15): print(f'{v/tot*100:5.1f}%  {k[:120]}')

