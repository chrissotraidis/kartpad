#!/usr/bin/env python3
"""Run actual SwiftShader/availability branches; force-setting twice is invalid."""
import subprocess,sys,tempfile
from pathlib import Path

def probe(path):
 text=Path(path).read_text()
 a=text.index('    if (IsSwiftshader()) {',text.index('void PhysicalDevice::SetupBackendDeviceToggles'))
 b=text.index('    if (IsIntelMesa())',a)
 c=text.index('    // Use ExtendedDynamicState by default',b)
 d=text.index('\n}',c)
 return text[a:b]+text[c:d]

for name,path,expected in [('before',sys.argv[1],False),('after',sys.argv[2],True)]:
 source=r'''
#include <cassert>
struct Toggle { enum {VulkanDirectVariableAccessTransformHandle,VulkanUseExtendedDynamicState}; };
struct DeviceExt {enum {ExtendedDynamicState};};
constexpr int VK_FALSE=0,VK_TRUE=1;
struct Info {bool extension;struct {int extendedDynamicState;} extendedDynamicStateFeatures;
 bool HasExt(int)const{return extension;}} info;
bool swiftshader;
bool IsSwiftshader(){return swiftshader;}
const Info& GetDeviceInfo(){return info;}
struct Toggles {int forced=0;bool value=true;
 void Default(int toggle,bool enabled){if(toggle==Toggle::VulkanUseExtendedDynamicState&&!forced)value=enabled;}
 void ForceSet(int toggle,bool enabled){assert(toggle==Toggle::VulkanUseExtendedDynamicState);assert(forced++==0);value=enabled;}
};
void configure(Toggles* deviceToggles){
''' + probe(path) + r'''
}
int main(){for(bool swift:{false,true})for(bool ext:{false,true})for(int feature:{0,1}){
 swiftshader=swift;info={ext,{feature}};Toggles t;configure(&t);
 assert(!t.value);assert(t.forced==((swift||!ext||!feature)?1:0));
}}
'''
 source=source.replace('#include <cassert>','#include <cassert>\n#include <initializer_list>')
 with tempfile.TemporaryDirectory() as d:
  cpp=Path(d)/'test.cpp';cpp.write_text(source);exe=Path(d)/'test'
  subprocess.run(['clang++','-std=c++20','-fsanitize=address,undefined',str(cpp),'-o',str(exe)],check=True)
  result=subprocess.run([str(exe)],capture_output=True,text=True)
  assert (result.returncode==0)==expected,(name,result.stderr)
  print(name, 'passes all eight cases' if expected else 'reproduces duplicate ForceSet assertion')
