"""Compile production routing decisions; actual SDL integration has a separate probe."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / 'vendor/runtimes/android'


def function(text, signature):
    start = text.index(signature)
    brace = text.index('{', start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (text[end] == '{') - (text[end] == '}')
        end += 1
    return text[start:end]


class AndroidControllerRouting(unittest.TestCase):
    def compile_run(self, source):
        with tempfile.TemporaryDirectory() as directory:
            cpp, exe = Path(directory) / 'probe.cpp', Path(directory) / 'probe'
            cpp.write_text(source)
            build = subprocess.run([os.environ.get('CXX', 'clang++'), '-std=c++20', '-pthread',
                                    '-fsanitize=address,undefined', '-fno-sanitize-recover=all',
                                    str(cpp), '-o', str(exe)], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            result = subprocess.run([str(exe)], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_explicit_port_choice_and_ownership(self):
        text = (RUNTIME / 'aurora-main/lib/input.cpp').read_text()
        self.compile_run(r'''
#include <algorithm>
#include <array>
#include <cassert>
#include <cstdint>
#include <map>
#include <mutex>
constexpr int PAD_MAX_CONTROLLERS=4;
struct GameController {void* m_controller; int m_playerIndex; int identity=0;};
enum class PortPreferenceState {Unset,None,Controller};
struct ControllerIdentity {int id=0;};
struct Preference {PortPreferenceState state=PortPreferenceState::Unset; ControllerIdentity identity;};
std::array<Preference,4> g_portPreferences;
std::map<int,GameController> g_GameControllers;
std::mutex g_standardGamepadBridgeMutex;
enum class IdentityMatch {None,Fallback,Exact};
IdentityMatch identity_match(const ControllerIdentity& s,const ControllerIdentity& c) {
  return s.id!=0 && s.id==c.id ? IdentityMatch::Exact : IdentityMatch::None;}
ControllerIdentity controller_identity(const GameController& c) {return {c.identity};}
''' + function(text, 'bool port_reserved(uint32_t port)') + '\n' +
            function(text, 'static GameController* resolve_standard_gamepad(') + '\n' +
            function(text, 'uint32_t standard_gamepad_assigned_mask()') + r'''
int main() {
  int handle=1;
  g_GameControllers[10]={&handle,-1};
  assert(resolve_standard_gamepad(0,true)==&g_GameControllers[10]);
  assert(!resolve_standard_gamepad(0,false));
  assert(!resolve_standard_gamepad(1,true));
  // Player 1's empty choice is "Automatic", and a saved controller that is not
  // connected does not hold the port: the lone controller still plays.
  for(auto state:{PortPreferenceState::None,PortPreferenceState::Controller}) {
    g_portPreferences[0]={state,{7}};
    assert(resolve_standard_gamepad(0,true)==&g_GameControllers[10]);
  }
  // The saved controller is connected: Player 1 waits for it.
  g_GameControllers[10].identity=7;
  assert(!resolve_standard_gamepad(0,true));
  assert(port_reserved(0));
  g_GameControllers[10].identity=0;
  g_portPreferences[1].state=PortPreferenceState::None;
  assert(port_reserved(1) && !port_reserved(2));
  g_portPreferences[1].state=PortPreferenceState::Unset;
  g_portPreferences[0].state=PortPreferenceState::Unset;
  g_GameControllers[20]={&handle,-1};
  assert(!resolve_standard_gamepad(0,true));
  g_GameControllers[20].m_playerIndex=3;
  assert(resolve_standard_gamepad(3,false)==&g_GameControllers[20]);
  assert(standard_gamepad_assigned_mask()==8);
  g_GameControllers[10].m_playerIndex=0;
  assert(standard_gamepad_assigned_mask()==9);
  g_GameControllers[30]={nullptr,1};
  g_GameControllers[40]={&handle,4};
  assert(standard_gamepad_assigned_mask()==9);
  g_GameControllers.clear();
  assert(standard_gamepad_assigned_mask()==0);
}
''')

    def test_connected_controllers_never_stay_without_a_player(self):
        # #378: a saved or cleared Player 1 left a connected pad without a player,
        # so every button it sent was dropped.
        text = (RUNTIME / 'aurora-main/lib/input.cpp').read_text()
        self.compile_run(r'''
#include <algorithm>
#include <array>
#include <cassert>
#include <cstdint>
#include <map>
using Uint32=uint32_t;
constexpr int PAD_MAX_CONTROLLERS=4;
struct GameController {void* m_controller; int32_t m_playerIndex; int identity=0;};
enum class PortPreferenceState {Unset,None,Controller};
struct ControllerIdentity {int id=0;};
struct Preference {PortPreferenceState state=PortPreferenceState::Unset; ControllerIdentity identity;};
std::array<Preference,4> g_portPreferences;
std::map<Uint32,GameController> g_GameControllers;
enum class IdentityMatch {None,Fallback,Exact};
IdentityMatch identity_match(const ControllerIdentity& s,const ControllerIdentity& c) {
  return s.id!=0 && s.id==c.id ? IdentityMatch::Exact : IdentityMatch::None;}
ControllerIdentity controller_identity(const GameController& c) {return {c.identity};}
void ensure_port_preferences_loaded() {}
int32_t SDL_GetGamepadPlayerIndex(void*) {return -1;}
void SDL_SetGamepadPlayerIndex(void*,int32_t) {}
const char* SDL_GetGamepadName(void*) {return "pad";}
struct {template<class... A> void info(A&&...) {} template<class... A> void warn(A&&...) {}} Log;
void ensure_player_index(GameController& controller) noexcept;
''' + function(text, 'void assign_player_index(GameController& controller, int32_t port) {') + '\n' +
            function(text, 'int32_t effective_player_index(const GameController& controller) {') + '\n' +
            function(text, 'bool is_instance_claimed(') + '\n' +
            function(text, 'bool port_reserved(uint32_t port)') + '\n' +
            function(text, 'void assign_free_ports()') + '\n' +
            function(text, 'void apply_port_preferences() noexcept {') + '\n' +
            function(text, 'void ensure_player_index(GameController& controller) noexcept {') + r'''
int handles[3];
void reset(std::initializer_list<std::pair<Uint32,GameController>> pads) {
  g_GameControllers.clear();
  for(auto& p:pads) g_GameControllers[p.first]=p.second;
  g_portPreferences={};
}
int32_t player(Uint32 i) {return g_GameControllers[i].m_playerIndex;}
int main() {
  // Two pads, nothing saved: Player 1 and Player 2.
  reset({{1,{&handles[1],-1,11}},{2,{&handles[2],-1,22}}});
  apply_port_preferences();
  assert(player(1)==0 && player(2)==1);
  // A legacy empty Player 1 ("Automatic") no longer strips the pad on it.
  reset({{1,{&handles[1],0,11}},{2,{&handles[2],-1,22}}});
  g_portPreferences[0].state=PortPreferenceState::None;
  apply_port_preferences();
  assert(player(1)==0 && player(2)==1);
  // Player 1 saved for a controller that is not connected: the pads still play.
  reset({{1,{&handles[1],-1,11}},{2,{&handles[2],-1,22}}});
  g_portPreferences[0]={PortPreferenceState::Controller,{99}};
  apply_port_preferences();
  assert(player(1)==0 && player(2)==1);
  // The saved controller is connected: it takes Player 1 and the other pad moves on.
  reset({{1,{&handles[1],0,11}},{2,{&handles[2],1,22}}});
  g_portPreferences[0]={PortPreferenceState::Controller,{22}};
  apply_port_preferences();
  assert(player(2)==0 && player(1)==1);
  // "No controller" on Player 2 is respected while other players are free.
  reset({{1,{&handles[1],-1,11}},{2,{&handles[2],-1,22}}});
  g_portPreferences[1].state=PortPreferenceState::None;
  apply_port_preferences();
  assert(player(1)==0 && player(2)==2);
}
''')

    def test_legacy_settings_share_assignment_service(self):
        text = (RUNTIME / 'aurora-main/lib/dolphin/pad/pad.cpp').read_text()
        self.compile_run(r'''
#include <cassert>
#include <cstdint>
using u32=uint32_t;
struct Controller {uint32_t m_index;};
Controller selected{73};
const Controller* __PADGetControllerForIndex(u32 index) {return index==2?&selected:nullptr;}
namespace aurora::input {
unsigned calls=0,instance=0,player=0,cleared=0;
bool assign_standard_gamepad(uint32_t i,uint32_t p) {++calls;instance=i;player=p;return true;}
bool clear_standard_gamepad_player(uint32_t p) {cleared=p;return true;}
}
''' + function(text, 'void PADSetPortForIndex(') + '\n' + function(text, 'void PADClearPort(') + r'''
int main() {
  PADSetPortForIndex(9,1);assert(aurora::input::calls==0);
  PADSetPortForIndex(2,3);
  assert(aurora::input::calls==1 && aurora::input::instance==73 && aurora::input::player==3);
  PADClearPort(3);assert(aurora::input::cleared==3);
}
''')

    def test_guest_route_preserves_keyboard_and_adapter(self):
        text = (RUNTIME / 'runtime/src/hle/input/pad.cpp').read_text()
        self.compile_run(r'''
#include <array>
#include <cassert>
#include <cstdint>
#define __ANDROID__ 1
constexpr unsigned PAD_CHANMAX=4,PAD_CHAN0_BIT=0x80000000;
constexpr int PAD_ERR_NONE=0,PAD_ERR_NO_CONTROLLER=-1;
struct PADStatus {unsigned button=0;int err=0;};
namespace Memory {struct AccessViolation {};}
namespace PadStatusContract {constexpr unsigned kGuestStatusSize=12;}
std::array<PADStatus,4> output{};
unsigned writes=0;
void WritePadStatus(uint32_t a,const PADStatus& s) {output.at((a-0x1000)/12)=s;++writes;}
uint32_t PADRead(PADStatus* s) {for(unsigned i=0;i<4;++i)s[i]={i+1,0};return 0xf0000000;}
bool blocked=false;
// These independent upstream services are neutral in this routing test.
// Their expression behavior is covered by the upstream input-expression suite.
namespace InputBindings {
bool InputBlocked() {return blocked;}
void Apply(PADStatus*) {}
}
namespace WiiRemoteInput {
void Poll() {}
void HideRemotesFromPad(PADStatus*,unsigned) {}
}
void FillTriggersHeldByButtons(PADStatus*) {}
namespace aurora::input {unsigned owners=0;uint32_t standard_gamepad_assigned_mask(){return owners;}}
namespace Wup028Adapter {
bool present=false;
bool Read(std::array<PADStatus,4>& s) {
  for(auto& p:s)p.err=PAD_ERR_NO_CONTROLLER;
  if(present)s[0]={32,0};return present;
}
}
''' + function(text, 'extern "C" uint32_t PAD__Read_HLE(') + r'''
int main() {
  assert(PAD__Read_HLE(0)==0 && writes==0);
  for(unsigned mask=0;mask<16;++mask) {
    aurora::input::owners=mask;
    unsigned expected=0xf0000000;
    for(unsigned p=0;p<4;++p)if(mask&(1u<<p))expected&=~(PAD_CHAN0_BIT>>p);
    assert(PAD__Read_HLE(0x1000)==expected);
    for(unsigned p=0;p<4;++p) {
      bool owned=mask&(1u<<p);
      assert(output[p].err==(owned?-1:0));
      assert(output[p].button==(owned?0:p+1));
    }
  }
  Wup028Adapter::present=true;
  assert(PAD__Read_HLE(0x1000)==PAD_CHAN0_BIT);
  assert(output[0].err==0 && output[0].button==32);
  blocked=true;
  assert(PAD__Read_HLE(0x1000)==0 && output[0].err==-1);
}
''')


if __name__ == '__main__':
    unittest.main()
