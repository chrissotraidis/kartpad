#!/usr/bin/env python3
"""Build Android's actual portable input/PAD modules against the pinned host SDL."""
import argparse,hashlib,json,shlex,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def block(text,prefix):
 start=text.index(prefix);end=text.index('\n\n',start)
 return dict(line.strip().split(' = ',1) for line in text[start:end].splitlines()[1:] if ' = ' in line)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('build',type=Path);p.add_argument('output',type=Path);p.add_argument('--sanitized-abseil-build',type=Path);args=p.parse_args()
 build,output=args.build.resolve(),args.output.resolve();output.parent.mkdir(parents=True,exist_ok=True)
 runtime=ROOT/'vendor/runtimes/android';aurora=runtime/'aurora-main'
 hle=(runtime/'runtime/src/hle/input/pad.cpp').read_text()
 start=hle.index('extern "C" uint32_t PAD__Read_HLE(')
 kernel=hle[start:hle.index('PPC_NATIVE_OVERRIDE(',start)]
 (output.parent/'controller-routing-kernel.hpp').write_text(kernel)
 ninja=(build/'build.ninja').read_text();flags=block(ninja,'build aurora-build/CMakeFiles/aurora_gx.dir/lib/gfx/common.cpp.o:')
 link=block(ninja,'build KartPadDual:')
 includes=[part for part in shlex.split(flags['INCLUDES']) if '/macos-source/aurora-main/include' not in part]
 libraries=[item for item in shlex.split(link['LINK_LIBRARIES']) if not Path(item).name.startswith(('libmkw_','libaurora_'))]
 sources=[ROOT/'prototypes/stabilization/android_controller_routing_probe.cpp',aurora/'lib/input.cpp',aurora/'lib/dolphin/pad/pad.cpp',aurora/'lib/dolphin/si/si.cpp',aurora/'lib/logging.cpp']
 command=['clang++',*shlex.split(flags['DEFINES']),*includes,*shlex.split(flags['FLAGS']),
          '-I'+str(aurora/'include'),'-I'+str(aurora/'lib'),'-I'+str(ROOT/'runtime/include'),'-I'+str(output.parent),
          *map(str,sources),*libraries,'-o',str(output)]
 # ASan changes Abseil's container ABI; every Abseil object must match.
 # SDL and the other pinned dependencies remain uninstrumented.
 if args.sanitized_abseil_build:
  command[1:1]=['-fsanitize=address,undefined','-fno-sanitize-recover=all']
  prefix='_deps/abseil-cpp-build/'
  command=[str(args.sanitized_abseil_build.resolve()/arg[len(prefix):]) if arg.startswith(prefix) else arg for arg in command]
 subprocess.run(command,cwd=build,check=True)
 files={str(path.relative_to(ROOT)):hashlib.sha256(path.read_bytes()).hexdigest() for path in sources}
 files['vendor/runtimes/android/runtime/src/hle/input/pad.cpp']=hashlib.sha256(hle.encode()).hexdigest()
 for path in [aurora/'include/aurora/input.hpp',aurora/'lib/input.hpp',ROOT/'runtime/include/kartpad/android/controller_mapping.hpp']:
  files[str(path.relative_to(ROOT))]=hashlib.sha256(path.read_bytes()).hexdigest()
 record={'scope':'actual maintained Android input/PAD modules and HLE read function; guest-memory and USB adapter service fixtures',
         'runtimeRevision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=runtime,text=True).strip(),
         'runtimeDirty':bool(subprocess.check_output(['git','status','--porcelain'],cwd=runtime,text=True).strip()),
         'sanitized':bool(args.sanitized_abseil_build),'sourceSha256':files,'kernelSha256':hashlib.sha256(kernel.encode()).hexdigest(),
         'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'command':command}
 output.with_suffix('.build.json').write_text(json.dumps(record,indent=2)+'\n')
 print('Built actual SDL routing probe')
if __name__=='__main__':main()
