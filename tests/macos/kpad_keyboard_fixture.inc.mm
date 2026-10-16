// Compile the production KPAD bridge in the native panel fixture. Only the
// host keyboard, guest memory and Bluetooth device boundary are simulated;
// the native UI actions and both guest APIs are real code. PAD storage is the
// existing in-memory panel fixture; this does not claim disk persistence.
#include "hle_stubs.h"
#include <SDL3/SDL_events.h>
#include <SDL3/SDL_timer.h>
#include <bit>
static std::array<bool, SDL_SCANCODE_COUNT> testHeldKeys{};
static uint64_t testKeyboardTime = 1'000'000'000;
static bool testKeyboardFocus = true;
static bool testInputBlocked = false;
static const bool* TestKeyboardState(int* count) { *count=testHeldKeys.size(); return testHeldKeys.data(); }
static SDL_Window* TestKeyboardFocus() { return testKeyboardFocus ? reinterpret_cast<SDL_Window*>(1) : nullptr; }
static uint64_t TestKeyboardTicks() { return testKeyboardTime; }
static bool TestKeyboardWatch(SDL_EventFilter, void*) { return true; }
#define SDL_GetKeyboardState TestKeyboardState
#define SDL_GetKeyboardFocus TestKeyboardFocus
#define SDL_GetTicksNS TestKeyboardTicks
#define SDL_AddEventWatch TestKeyboardWatch
#undef PPC_NATIVE_OVERRIDE
#define PPC_NATIVE_OVERRIDE(...)
#include "../../vendor/runtimes/macos/runtime/src/hle/input/kpad.cpp"
#undef SDL_GetKeyboardState
#undef SDL_GetKeyboardFocus
#undef SDL_GetTicksNS
#undef SDL_AddEventWatch

int g_gxFrameCount=0;
namespace InputBindings { bool InputBlocked() noexcept { return testInputBlocked; } }
namespace WiiRemoteInput {
static bool testRemote=false;
bool IsRemoteChannel(uint32_t) { return testRemote; }
bool ReadKpadSample(uint32_t, KpadSample& sample) {
 sample.hasClassic=true; sample.clHold=0x20; sample.clRStick[0]=0.5f; return true;
}
}
static std::array<uint8_t,4096> testGuestMemory{};
Memory::AccessViolation::AccessViolation(uint32_t address,size_t length,std::string_view reason)
 : std::runtime_error(std::string(reason)),address_(address),length_(length),reason_(reason) {}
uint8_t* Memory::GetPointer(uint32_t address,size_t size) {
 if(address+size>testGuestMemory.size()) throw AccessViolation(address,size,"fixture range");
 return testGuestMemory.data()+address;
}
uint8_t Memory::Read8(uint32_t a) { return *GetPointer(a,1); }
uint16_t Memory::Read16(uint32_t a) { return (Read8(a)<<8)|Read8(a+1); }
uint32_t Memory::Read32(uint32_t a) { return (uint32_t(Read16(a))<<16)|Read16(a+2); }
void Memory::Write8(uint32_t a,uint8_t v) { *GetPointer(a,1)=v; }
void Memory::Write16(uint32_t a,uint16_t v) { Write8(a,v>>8); Write8(a+1,v); }
void Memory::Write32(uint32_t a,uint32_t v) { Write16(a,v>>16); Write16(a+2,v); }
void Memory::WriteFloat32(uint32_t a,double v) { Write32(a,std::bit_cast<uint32_t>(float(v))); }
float Memory::ReadFloat32(uint32_t a) { return std::bit_cast<float>(Read32(a)); }

static void TestClassicKeyboard(KPControllerSettings* panel) {
 constexpr uint32_t status=0x100, unified=0x200;
 auto release=[] {
   testHeldKeys.fill(false); testKeyboardTime+=1'000'000'000;
   for(auto& value:g_pendingMappedKeys)value.store(false);
   for(auto& value:g_syntheticExpiryNs)value.store(0);
   KPAD__Read_HLE(0,0x100,1);
 };
 auto read=[&] {
   assert(KPAD__Read_HLE(0,status,1)==1);
   KPAD__GetUnifiedWpadStatus_HLE(0,unified,1);
 };
 auto hold=[&](int code) { release(); testHeldKeys[code]=true; read(); };
 auto tap=[](int code) {
   SDL_Event event{};event.type=SDL_EVENT_KEY_DOWN;event.key.scancode=SDL_Scancode(code);
   WatchKeyboardEvent(nullptr,&event);
 };
 auto classic=[&](uint32_t expected) {
   assert(Memory::Read32(status+0x60)==expected);
   assert(Memory::Read16(unified+0x2A)==expected);
 };
 auto event=[](unsigned short code) {
   return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0
     timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@""
     isARepeat:NO keyCode:code];
 };
 panel.selectedID=(SDL_JoystickID)-1;
 [panel resetKeyboard:nil];
 for(auto [code,expected] : {std::pair{SDL_SCANCODE_RETURN,0x10u}, {SDL_SCANCODE_BACKSPACE,0x40u},
   {SDL_SCANCODE_LCTRL,0x2000u},{SDL_SCANCODE_LALT,0x200u},{SDL_SCANCODE_LSHIFT,0x4u},
   {SDL_SCANCODE_SPACE,0x400u},{SDL_SCANCODE_UP,0x1u},{SDL_SCANCODE_DOWN,0x4000u},
   {SDL_SCANCODE_LEFT,0x2u},{SDL_SCANCODE_RIGHT,0x8000u},{SDL_SCANCODE_Q,0x8u},{SDL_SCANCODE_E,0x20u}}) {
   hold(code);classic(expected);
 }
 hold(SDL_SCANCODE_RETURN);assert(Memory::Read32(status)==0x800 && Memory::Read16(unified)==0x800);
 hold(SDL_SCANCODE_LCTRL);assert(Memory::ReadFloat32(status+0x7C)==1 && Memory::Read8(unified+0x34)==255);
 hold(SDL_SCANCODE_LALT);assert(Memory::ReadFloat32(status+0x80)==1 && Memory::Read8(unified+0x35)==255);
 for(auto [code,offset,value] : {std::tuple{SDL_SCANCODE_D,0x6Cu,1.f},{SDL_SCANCODE_A,0x6Cu,-1.f},
   {SDL_SCANCODE_W,0x70u,1.f},{SDL_SCANCODE_S,0x70u,-1.f},
   {SDL_SCANCODE_L,0x74u,1.f},{SDL_SCANCODE_J,0x74u,-1.f},
   {SDL_SCANCODE_I,0x78u,1.f},{SDL_SCANCODE_K,0x78u,-1.f}}) {
   hold(code);assert(Memory::ReadFloat32(status+offset)==value);
   assert(int16_t(Memory::Read16(unified+0x2C+(offset-0x6C)/2))==int16_t(value*511));
 }
 testHeldKeys[SDL_SCANCODE_I]=true;read();assert(Memory::ReadFloat32(status+0x78)==0);
 // Native Item remap -> actual guest Classic L, with no stale U=A alias.
 release();panel.keyboardCaptureKind=0;panel.keyboardCaptureIndex=6;
 [panel handleKeyboardEvent:event(32)];assert(testKeys[6].scancode==SDL_SCANCODE_U);
 hold(SDL_SCANCODE_U);classic(0x2000);assert(Memory::Read32(status)==0);
 NSButton* clear=[NSButton new];clear.tag=6;[panel clearKeyboard:clear];
 hold(SDL_SCANCODE_U);classic(0);
 // Independent trigger axis remains usable until that separate row is cleared.
 hold(SDL_SCANCODE_LCTRL);classic(0x2000);
 clear.tag=108;[panel clearKeyboard:clear];hold(SDL_SCANCODE_LCTRL);classic(0);
 panel.keyboardCaptureKind=1;panel.keyboardCaptureIndex=8;[panel handleKeyboardEvent:event(32)];
 hold(SDL_SCANCODE_U);classic(0x2000);assert(Memory::Read8(unified+0x34)==255);
 // Native steering remap changes both float KPAD and raw unified stick output.
 panel.keyboardCaptureKind=1;panel.keyboardCaptureIndex=0;[panel handleKeyboardEvent:event(3)];
 hold(SDL_SCANCODE_D);assert(Memory::ReadFloat32(status+0x6C)==0);
 hold(SDL_SCANCODE_F);assert(Memory::ReadFloat32(status+0x6C)==1 && Memory::Read16(unified+0x2C)==511);
 // Clear/reset and corrupted or mouse scancodes are bounded before indexing.
 for(int code : {PAD_KEY_INVALID,PAD_KEY_MOUSE_LEFT,int(SDL_SCANCODE_COUNT),100000}) {
   testKeys[0].scancode=code;testKeyAxes[0].scancode=code;release();read();classic(0);
 }
 [panel resetKeyboard:nil];hold(SDL_SCANCODE_U);classic(0);
 hold(SDL_SCANCODE_RETURN);classic(0x10);
 // Real native modifier capture reaches guest input. Shared keys intentionally
 // drive both actions until the other binding is explicitly cleared.
 panel.keyboardCaptureKind=0;panel.keyboardCaptureIndex=0;
 NSEvent* shift=[NSEvent keyEventWithType:NSEventTypeFlagsChanged location:NSZeroPoint
   modifierFlags:NSEventModifierFlagShift|NX_DEVICELSHIFTKEYMASK timestamp:0 windowNumber:0 context:nil
   characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:kVK_Shift];
 assert([panel handleKeyboardEvent:shift]);hold(SDL_SCANCODE_LSHIFT);classic(0x14);
 clear.tag=5;[panel clearKeyboard:clear];hold(SDL_SCANCODE_LSHIFT);classic(0x10);
 [panel resetKeyboard:nil];
 // Queued short taps work through each real guest API, even after physical up.
 release();tap(SDL_SCANCODE_RETURN);KPAD__Read_HLE(0,status,1);
 assert(Memory::Read32(status+0x64)==0x10 && Memory::Read32(status)==0x800);
 release();tap(SDL_SCANCODE_RETURN);KPAD__GetUnifiedWpadStatus_HLE(0,unified,1);
 assert(Memory::Read16(unified+0x2A)==0x10 && Memory::Read16(unified)==0x800);
 release();tap(SDL_SCANCODE_RETURN);clear.tag=0;[panel clearKeyboard:clear];read();classic(0);
 [panel resetKeyboard:nil];
 // Capture/focus loss discards pending taps and holds until a fresh press.
 for(bool focusLoss : {false,true}) {
   release();tap(SDL_SCANCODE_RETURN);testHeldKeys[SDL_SCANCODE_RETURN]=true;
   testInputBlocked=!focusLoss;testKeyboardFocus=!focusLoss;read();classic(0);
   testInputBlocked=false;testKeyboardFocus=true;read();classic(0);
   testHeldKeys[SDL_SCANCODE_RETURN]=false;testKeyboardTime+=1'000'000'000;read();classic(0);
   tap(SDL_SCANCODE_RETURN);testHeldKeys[SDL_SCANCODE_RETURN]=true;read();classic(0x10);
 }
 // Focus loss between guest polls still suppresses the held capture key.
 release();testHeldKeys[SDL_SCANCODE_RETURN]=true;
 SDL_Event lost{};lost.type=SDL_EVENT_WINDOW_FOCUS_LOST;WatchKeyboardEvent(nullptr,&lost);
 read();classic(0);testHeldKeys[SDL_SCANCODE_RETURN]=false;
 tap(SDL_SCANCODE_RETURN);read();classic(0x10);
 // Arbitrary F6 binding still receives queued presses alongside debug toggle.
 release();testKeys[0].scancode=SDL_SCANCODE_F6;tap(SDL_SCANCODE_F6);
 KPAD__Read_HLE(0,status,1);assert(Memory::Read32(status+0x60)==0x10);
 [panel resetKeyboard:nil];release();testKeyAxes[0].scancode=SDL_SCANCODE_F6;
 tap(SDL_SCANCODE_F6);read();assert(Memory::ReadFloat32(status+0x6C)==0.35f);
 assert(Memory::Read16(unified+0x2C)==178);
 testKeyboardTime+=1'000'000'000;read();assert(Memory::ReadFloat32(status+0x6C)==0);
 [panel resetKeyboard:nil];release();
 // Existing secondary keyboard join and real-Wii-remote routing keep priority.
 tap(SDL_SCANCODE_2);assert(KPAD_IsKeyboardChannelConnected(1));
 KPAD__Read_HLE(1,status,1);assert(Memory::Read32(status+0x60)==0x400);
 WiiRemoteInput::testRemote=true;testHeldKeys[SDL_SCANCODE_RETURN]=true;read();classic(0x20);
 WiiRemoteInput::testRemote=false;release();
 // An explicitly enabled synthetic RKG still takes precedence on channel zero
 // without replacing secondary keyboard input. This is invented fixture data.
 std::array<uint8_t,0x96> ghost{};
 std::memcpy(ghost.data(),"RKGD",4);ghost[0x0F]=14;
 ghost[0x89]=1;ghost[0x8B]=1;ghost[0x8D]=1;
 ghost[0x90]=4;ghost[0x91]=1;ghost[0x92]=0xF7;ghost[0x93]=1;ghost[0x95]=1;
 NSURL* ghostURL=[testRoot URLByAppendingPathComponent:@"synthetic-input.rkg"];
 assert([[NSData dataWithBytes:ghost.data() length:ghost.size()] writeToURL:ghostURL atomically:YES]);
 setenv("KARTPAD_RKG_INPUT_V2",ghostURL.fileSystemRepresentation,1);
 assert(Fixture().Arm());Fixture().Next();testHeldKeys[SDL_SCANCODE_RETURN]=true;read();classic(0x2000);
 assert(Memory::Read32(status)==0 && Memory::ReadFloat32(status+0x6C)==1);
 testHeldKeys[SDL_SCANCODE_R]=true;
 KPAD__Read_HLE(1,status,1);KPAD__GetUnifiedWpadStatus_HLE(1,unified,1);classic(0x10);
 Fixture().Disarm();unsetenv("KARTPAD_RKG_INPUT_V2");release();
 puts("PASS: native keyboard remap/clear/reset -> production KPAD and unified guest bytes; defaults, modifiers, axes, quick taps, capture suppression and remote priority");
}
