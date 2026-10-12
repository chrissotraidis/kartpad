import re,pathlib,sys
root=pathlib.Path(sys.argv[1])/'build_shards'
pat=re.compile(r'^extern "C" void func_[0-9A-F]+\(CpuContext\* MKW_RESTRICT ctx\)\n\{\n',re.M)
files=n=0
for f in root.rglob('*.cpp'):
    s=f.read_text()
    t,k=pat.subn(lambda m: m.group(0)+'    KARTPAD_FLAT_FUNCTION_LOCALS\n',s)
    if k:
        f.write_text(t); files+=1; n+=k
print('functions',n,'files',files)
