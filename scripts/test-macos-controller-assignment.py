#!/usr/bin/env python3
"""Exercise the prepared runtime's actual assignment functions with SDL stubs."""
from pathlib import Path
import subprocess, tempfile, sys
root=Path(sys.argv[1] if len(sys.argv)>1 else 'build/self-build-macos-source')
src=(root/'aurora-main/lib/dolphin/pad/pad.cpp').read_text()
def function(signature):
    start=src.index(signature); end=src.index('{',start)+1; depth=1
    while depth:
        depth+=(src[end]=='{')-(src[end]=='}');end+=1
    return src[start:end]
code=r'''
#include <cassert>
#include <cstdint>
#define PAD_MAX_CONTROLLERS 4
using u32=uint32_t; using Sint32=int32_t;
struct SDL_Gamepad { int player=-1; };
struct Controller { SDL_Gamepad *m_controller; int m_index; int cached=-1; };
SDL_Gamepad devices[2]; Controller controllers[2]={{&devices[0],0,-1},{&devices[1],1,-1}};
int saved[4]={-1,-1,-1,-1};
Controller *__PADGetControllerForIndex(u32 i){return i<2?&controllers[i]:nullptr;}
namespace aurora::input {
int player_index(int i){return devices[i].player>=0?devices[i].player:controllers[i].cached;}
Controller *get_controller_for_player(u32 port){for(auto &c:controllers)if(player_index(c.m_index)==int(port))return &c;return nullptr;}
void set_player_index(int i,int p){devices[i].player=p;controllers[i].cached=p;}
void persist_controller_for_player(int port,const Controller *c){saved[port]=c?c->m_index:-1;}
}
'''
code+=function('void PADSetPortForIndex(')+function('void PADClearPort(')
code+=r'''
int main(){
 using namespace aurora::input;
 set_player_index(0,0); // cached assignment survives an SDL index reset
 devices[0].player=-1;
 PADSetPortForIndex(0,1);
 assert(player_index(0)==1 && saved[0]==-1 && saved[1]==0);
 set_player_index(1,0);
 PADSetPortForIndex(0,0); // displace a controller without a stale cached port
 assert(player_index(0)==0 && player_index(1)==-1);
 PADClearPort(0);
 assert(player_index(0)==-1 && get_controller_for_player(0)==nullptr && saved[0]==-1);
 PADSetPortForIndex(1,3);
 assert(player_index(1)==3 && saved[3]==1);
}
'''
with tempfile.TemporaryDirectory() as d:
    source=Path(d)/'test.cpp';source.write_text(code);exe=Path(d)/'test'
    subprocess.run(['clang++','-std=c++20','-Wall','-Wextra','-Werror',str(source),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True)
print('PASS: assignment, displaced controller, cached-index fallback, unassignment, player 4')
