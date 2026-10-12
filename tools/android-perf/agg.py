import sys,collections,re
import os
NDK=os.environ.get('ANDROID_NDK_ROOT', os.path.expanduser('~/Library/Android/sdk/ndk/29.0.14206865'))
sys.path.insert(0,NDK+'/simpleperf')
from simpleperf_report_lib import ReportLib
lib=ReportLib(); lib.SetRecordFile(sys.argv[1]); lib.SetSymfs(sys.argv[2])
tid=int(sys.argv[3])
selfc=collections.Counter(); caller=collections.Counter(); bucket=collections.Counter(); n=0
fp_caller=collections.Counter()
def B(s,d):
    if 'emutls' in s or 'pthread_getspecific' in s or s.startswith('CurrentCpuContext'): return 'TLS lookup'
    if re.search(r'Fp|Fmul|Fadd|Fsub|Fdiv|Fmadd|Fnm|Fmsub|Fcmp|CompareState|Scalar|Fctiw|Frsp|Fres|Frsqrte',s) and 'func_' not in s: return 'FP helpers'
    if s.startswith('func_'): return 'translated game code'
    if 'Dispatch' in s or 'Invoke' in s: return 'call dispatch'
    if s.startswith('GX') or 'gx' in s.lower() or 'aurora' in s or 'TexObj' in s or 'Texture' in s: return 'GX/graphics'
    if 'kallsyms' in d or s in('try_to_wake_up','handle_softirqs','writel'): return 'kernel'
    if 'Memory' in s or 'memcpy' in s or 'memcmp' in s or 'memmove' in s or 'memset' in s: return 'memory'
    if 'Psq' in s or 'Ps' in s[:3]: return 'paired-single'
    return 'other'
while True:
    s=lib.GetNextSample()
    if s is None: break
    if s.tid!=tid: continue
    n+=1
    sym=lib.GetSymbolOfCurrentSample(); name=sym.symbol_name; dso=sym.dso_name
    selfc[name]+=1; bucket[B(name,dso)]+=1
    cc=lib.GetCallChainOfCurrentSample()
    chain=[cc.entries[i].symbol.symbol_name for i in range(cc.nr)]
    if B(name,dso)=='TLS lookup':
        c=next((x for x in chain if B(x,'')!='TLS lookup'),'?'); caller[c]+=1
print('game-thread samples',n)
for k,v in bucket.most_common(): print(f'{v/n*100:5.1f}%  {k}')
print('--- TLS lookups by first non-TLS caller')
for k,v in caller.most_common(12): print(f'{v/n*100:5.1f}%  {k[:90]}')
print('--- top self symbols')
for k,v in selfc.most_common(30): print(f'{v/n*100:5.1f}%  {k[:90]}')

