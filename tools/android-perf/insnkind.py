import sys,collections,subprocess,struct,re
import os
NDK=os.environ.get('ANDROID_NDK_ROOT', os.path.expanduser('~/Library/Android/sdk/ndk/29.0.14206865'))
sys.path.insert(0,NDK+'/simpleperf')
from simpleperf_report_lib import ReportLib
data,symfs,tid,so=sys.argv[1],sys.argv[2],int(sys.argv[3]),sys.argv[4]
lib=ReportLib(); lib.SetRecordFile(data); lib.SetSymfs(symfs)
c=collections.Counter(); n=0
while True:
    s=lib.GetNextSample()
    if s is None: break
    if s.tid!=tid: continue
    n+=1; y=lib.GetSymbolOfCurrentSample()
    if y.symbol_name.startswith('func_'): c[y.vaddr_in_file]+=1
# map vaddr -> file offset via program headers
b=open(so,'rb').read()
phoff=struct.unpack_from('<Q',b,0x20)[0]; phentsize,phnum=struct.unpack_from('<HH',b,0x36)
loads=[]
for i in range(phnum):
    p_type,p_flags,p_offset,p_vaddr,p_paddr,p_filesz=struct.unpack_from('<IIQQQQ',b,phoff+i*phentsize)
    if p_type==1: loads.append((p_vaddr,p_offset,p_filesz))
def off(v):
    for va,of,sz in loads:
        if va<=v<va+sz: return of+(v-va)
addrs=list(c); words=[]
for a in addrs:
    o=off(a); words.append(struct.unpack_from('<I',b,o)[0])
B=NDK+'/toolchains/llvm/prebuilt/darwin-x86_64/bin/'
open('/tmp/kartpad-perf-insn.s','w').write(''.join('.inst 0x%08x\n'%w for w in words))
subprocess.run([B+'clang','--target=aarch64-linux-android28','-c','/tmp/kartpad-perf-insn.s','-o','/tmp/kartpad-perf-insn.o'],check=True)
out=subprocess.run([B+'llvm-objdump','-d','--no-show-raw-insn','/tmp/kartpad-perf-insn.o'],capture_output=True,text=True).stdout
lines=[l.split(':',1)[1].strip() for l in out.split('\n') if re.match(r'^\s+[0-9a-f]+:',l)]
assert len(lines)==len(addrs),(len(lines),len(addrs))
def kind(t):
    op=t.split()[0]
    if op in('rev','rev16','rev32'): return 'byte swap'
    if op.startswith('fcvt') : return 'fp convert (fcvt)'
    if op in('bl','blr','br','ret','b') : return 'call/branch'
    if op.startswith('b.') or op in('cbz','cbnz','tbz','tbnz'): return 'conditional branch'
    if op[0]=='f' or op in('fmov',) : return 'fp arithmetic'
    if op.startswith(('ld','st')):
        if re.search(r'\[x\d+, [xw]\d+', t): return 'mem reg-offset (guest RAM)'
        if 'sp' in t.split(',')[-1] or '[sp' in t: return 'mem stack'
        return 'mem imm-offset (ctx/struct)'
    if op in('mrs','msr'): return 'system reg'
    return 'integer/other'
k=collections.Counter(); ops=collections.Counter()
for a,t in zip(addrs,lines):
    k[kind(t)]+=c[a]; ops[t.split()[0]]+=c[a]
tot=sum(c.values())
print('translated-code samples',tot,'of game-thread',n)
for x,v in k.most_common(): print(f'{v/tot*100:5.1f}%  {x}')
print('top opcodes:', ', '.join(f'{o} {v/tot*100:.1f}%' for o,v in ops.most_common(18)))

