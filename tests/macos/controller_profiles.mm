#import <AppKit/AppKit.h>
#import <CommonCrypto/CommonDigest.h>
#include <filesystem>
#include <algorithm>
#include <cmath>
#include "runtime_config.h"
static NSURL *testRoot;
static NSURL *ApplicationSupportURL() { return testRoot; }
static void AppendSessionLine(NSString *) {}
#include "KartPadControllers.inc.mm"
#include <cassert>
static SDL_Gamepad *testPad;
static int testPort=0;
static std::array<PADButtonMapping,12> testButtons;
static std::array<PADButtonMapping,12> testAlternates;
static PADDeadZones testZones{true,true,8000,9000,30000,31000};
static std::array<PADKeyButtonBinding,12> testKeys;
static std::array<PADKeyAxisBinding,10> testKeyAxes;
extern "C" {
u32 PADCount(){return testPad ? 1:0;}
s32 PADGetIndexForPort(u32 p){return (int)p==testPort ? 0:-1;}
SDL_Gamepad *PADGetSDLGamepadForIndex(u32){return testPad;}
void PADClearPort(u32){testPort=-1;}
void PADSetPortForIndex(u32,u32 port){testPort=port;}
PADButtonMapping *PADGetButtonMappings(u32,u32 *count){*count=12;return testButtons.data();}
PADButtonMapping *PADGetAltButtonMappings(u32,u32 *count){*count=12;return testAlternates.data();}
PADDeadZones *PADGetDeadZones(u32){return &testZones;}
void PADSetButtonMapping(u32,PADButtonMapping m){for(auto &b:testButtons)if(b.padButton==m.padButton)b=m;}
void PADSetAltButtonMapping(u32,PADButtonMapping m){for(auto &b:testAlternates)if(b.padButton==m.padButton)b=m;}
void PADRestoreDefaultMapping(u32){}
PADKeyButtonBinding *PADGetKeyButtonBindings(u32,u32 *count){*count=12;return testKeys.data();}
PADKeyAxisBinding *PADGetKeyAxisBindings(u32,u32 *count){*count=10;return testKeyAxes.data();}
#define BOOL KPPadBOOL
BOOL PADSetKeyButtonBinding(u32,PADKeyButtonBinding m){for(auto &b:testKeys)if(b.padButton==m.padButton){b=m;return TRUE;}return FALSE;}
BOOL PADSetKeyAxisBinding(u32,PADKeyAxisBinding m){for(auto &b:testKeyAxes)if(b.padAxis==m.padAxis){b=m;return TRUE;}return FALSE;}
void PADClearKeyBindings(u32){for(auto &b:testKeys)b.scancode=PAD_KEY_INVALID;for(auto &b:testKeyAxes)b.scancode=PAD_KEY_INVALID;}
void PADSetKeyboardActive(u32,BOOL){}
#undef BOOL
}
namespace Wup028Adapter { void SetPortAssignment(uint32_t,int){} }
int main(){@autoreleasepool {
 char path[]="/tmp/kartpad-profile-test-XXXXXX";assert(mkdtemp(path));
 testRoot=[NSURL fileURLWithPath:@(path)];
 assert(SDL_Init(SDL_INIT_GAMEPAD));
 SDL_VirtualJoystickDesc desc{};SDL_INIT_INTERFACE(&desc);desc.type=SDL_JOYSTICK_TYPE_GAMEPAD;
 desc.nbuttons=SDL_GAMEPAD_BUTTON_COUNT;desc.naxes=SDL_GAMEPAD_AXIS_COUNT;desc.name="Profile test";
 SDL_JoystickID id=SDL_AttachVirtualJoystick(&desc);assert(id);
 testPad=SDL_OpenGamepad(id);assert(testPad);
 for(int i=0;i<12;++i){testButtons[i]={uint32_t(i),KPButtons[i]};testAlternates[i]={PAD_NATIVE_BUTTON_INVALID,KPButtons[i]};}
 testAlternates[0].nativeButton=SDL_GAMEPAD_BUTTON_MISC1;
 KPControllerSettings *first=[KPControllerSettings new];first.selectedID=id;
 [first remember];[first save:nil];assert(!first.dirty);
 auto key=KPProfileKey(testPad);assert(key.length==64);
 testButtons[0].nativeButton=19;testZones.stickDeadZone=0;
 KPControllerSettings *second=[KPControllerSettings new];
 [second applyProfile:second.profiles[key] port:0];
 assert(testButtons[0].nativeButton==0);assert(testAlternates[0].nativeButton==SDL_GAMEPAD_BUTTON_MISC1);
 assert(testZones.stickDeadZone==8000 && testZones.substickDeadZone==9000);
 assert(testZones.leftTriggerActivationZone==30000 && testZones.rightTriggerActivationZone==31000);
 for(int i=0;i<12;++i)testKeys[i]={PAD_KEY_INVALID,KPButtons[i]};
 for(int i=0;i<10;++i)testKeyAxes[i]={PAD_KEY_INVALID,(PADAxis)i,0};
 second.selectedID=(SDL_JoystickID)-1; [second refreshKeyboardLabels];

 auto event=[](unsigned short code, NSString *text, BOOL repeat=NO) {
   return [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint modifierFlags:0
     timestamp:0 windowNumber:0 context:nil characters:text charactersIgnoringModifiers:text
     isARepeat:repeat keyCode:code];
 };
 auto arm=[&] { second.keyboardCaptureKind=0;second.keyboardCaptureIndex=0; };
 auto unchanged=[&] {
   assert(second.capture==-1 && second.keyboardCaptureKind==-1 && second.keyboardCaptureIndex==-1);
   [second handleKeyboardEvent:event(12,@"a")];assert(testKeys[0].scancode==PAD_KEY_INVALID);
 };
 arm();second.capture=2;[second cancel:nil];unchanged();
 auto close=[NSNotification notificationWithName:NSWindowWillCloseNotification object:nil];
 arm();[second windowWillClose:close];[second activateInput];unchanged();
 [second windowWillClose:close]; // restore background-input hint and remove the monitor
 arm();[second windowDidResignKey:[NSNotification notificationWithName:NSWindowDidResignKeyNotification object:nil]];unchanged();
 arm();[second cancelCapture];unchanged(); // shared tab-deactivation path
 arm();[second handleKeyboardEvent:event(53,@"\033")];unchanged();
 assert(!second.keyboardMonitor);

 // Layout text must not change the physical key being bound.
 for (auto code : {0, 6, 12, 16}) {
   for (NSString *text in @[@"a",@"q",@"y",@"z",@"A",@"\u0444",@""]) {
     arm();[second handleKeyboardEvent:event(code,text)];
     assert(testKeys[0].scancode==KPMacPhysicalScancode(code,false));
   }
 }
 // Arrow, function, keypad, Return, Tab and distinct delete/backspace keys.
 for (auto pair : {std::pair<int,int>{123,SDL_SCANCODE_LEFT}, {126,SDL_SCANCODE_UP},
                   {122,SDL_SCANCODE_F1}, {82,SDL_SCANCODE_KP_0}, {29,SDL_SCANCODE_0},
                   {36,SDL_SCANCODE_RETURN}, {76,SDL_SCANCODE_KP_ENTER}, {48,SDL_SCANCODE_TAB},
                   {51,SDL_SCANCODE_BACKSPACE}, {117,SDL_SCANCODE_DELETE},
                   {93,SDL_SCANCODE_INTERNATIONAL3}, {104,SDL_SCANCODE_LANG1}}) {
   arm();[second handleKeyboardEvent:event(pair.first,@"")];assert(testKeys[0].scancode==pair.second);
 }
 int previous=testKeys[0].scancode;
 arm();[second handleKeyboardEvent:event(65535,@"a")];assert(testKeys[0].scancode==previous);
 [second handleKeyboardEvent:event(12,@"a",YES)];assert(testKeys[0].scancode==previous);
 assert(second.keyboardCaptureKind==0);[second cancel:nil];
 assert(KPMacPhysicalScancode(10,false)==SDL_SCANCODE_NONUSBACKSLASH);
 assert(KPMacPhysicalScancode(50,false)==SDL_SCANCODE_GRAVE);
 assert(KPMacPhysicalScancode(10,true)==SDL_SCANCODE_GRAVE);
 assert(KPMacPhysicalScancode(50,true)==SDL_SCANCODE_NONUSBACKSLASH);
 assert(KPMacPhysicalScancode(65535,false)==SDL_SCANCODE_UNKNOWN);
 second.keyboardCaptureKind=1;second.keyboardCaptureIndex=0;
 [second handleKeyboardEvent:event(12,@"a")];assert(testKeyAxes[0].scancode==SDL_SCANCODE_Q);
 puts("PASS: keyboard cancel/Escape/close/reopen/deactivation, alternate layouts, special keys, ISO, repeat and invalid-key handling");
 uint32_t controllerBefore=testButtons[0].nativeButton;
 assert(PADSetKeyButtonBinding(0,{SDL_SCANCODE_F,KPButtons[0]}));
 assert(testKeys[0].scancode==SDL_SCANCODE_F && testButtons[0].nativeButton==controllerBefore);
 assert(PADSetKeyAxisBinding(0,{SDL_SCANCODE_G,(PADAxis)PAD_AXIS_LEFT_X_POS,0}));
 assert(testKeyAxes[0].scancode==SDL_SCANCODE_G);
 PADClearKeyBindings(0); assert(testKeys[0].scancode==PAD_KEY_INVALID);
 assert([second scancodeForPhysicalKeyCode:12]==SDL_SCANCODE_Q); // physical key, independent of layout character
 assert([second scancodeForPhysicalKeyCode:76]==SDL_SCANCODE_KP_ENTER);
 assert([second scancodeForPhysicalKeyCode:122]==SDL_SCANCODE_F1);
 second.keyboardCaptureKind=0; second.keyboardCaptureIndex=0; [second cancel:nil];
 assert(second.keyboardCaptureKind==-1 && second.keyboardCaptureIndex==-1);
 second.keyboardCaptureKind=1; second.keyboardCaptureIndex=2; [second windowWillClose:nil];
 assert(second.keyboardCaptureKind==-1 && second.keyboardCaptureIndex==-1);
 second.selectedID=id;second.capture=0;
 [second bind:1];assert(second.capture==-1 && testButtons[0].nativeButton==1); // shared binding allowed
 second.capture=0;
 [second bind:PAD_NATIVE_BUTTON_INVALID];assert(second.capture==-1 && testButtons[0].nativeButton==PAD_NATIVE_BUTTON_INVALID);
 NSMutableDictionary *bad=[second.profiles[key] mutableCopy];bad[@"buttons"]=@[@999];
 [second applyProfile:bad port:0];assert(testButtons[0].nativeButton==PAD_NATIVE_BUTTON_INVALID);
 // A OR RT round trips independently and uses the runtime's real SDL predicate.
 second.capture=0;second.captureAlternate=NO;[second bind:SDL_GAMEPAD_BUTTON_SOUTH];
 second.capture=0;second.captureAlternate=YES;[second bind:kartpad::binding::RightTrigger];
 assert(testButtons[0].nativeButton==SDL_GAMEPAD_BUTTON_SOUTH);
 assert(testAlternates[0].nativeButton==kartpad::binding::RightTrigger);
 [second save:nil];
 KPControllerSettings *reloaded=[KPControllerSettings new];
 testAlternates[0].nativeButton=PAD_NATIVE_BUTTON_INVALID;
 [reloaded applyProfile:reloaded.profiles[key] port:0];
 assert(testAlternates[0].nativeButton==kartpad::binding::RightTrigger);
 auto *joy=SDL_GetGamepadJoystick(testPad);
 auto active=[] { return kartpad::binding::pressed(testPad,testButtons[0].nativeButton,10000,10000) ||
                          kartpad::binding::pressed(testPad,testAlternates[0].nativeButton,10000,10000); };
 SDL_SetJoystickVirtualAxis(joy,SDL_GAMEPAD_AXIS_RIGHT_TRIGGER,-32768);SDL_UpdateJoysticks();
 assert(!active());
 SDL_SetJoystickVirtualButton(joy,SDL_GAMEPAD_BUTTON_SOUTH,true);SDL_UpdateJoysticks();assert(active());
 SDL_SetJoystickVirtualButton(joy,SDL_GAMEPAD_BUTTON_SOUTH,false);
 SDL_SetJoystickVirtualAxis(joy,SDL_GAMEPAD_AXIS_RIGHT_TRIGGER,32767);SDL_UpdateJoysticks();assert(active());
 SDL_SetJoystickVirtualAxis(joy,SDL_GAMEPAD_AXIS_RIGHT_TRIGGER,-32768);SDL_UpdateJoysticks();assert(!active());
 assert(!kartpad::binding::pressed(testPad,kartpad::binding::RightTrigger,0,0));
 auto maskExplicitTriggerAxes=[](PADStatus &status,bool leftMapped,bool rightMapped){
     if(leftMapped)status.triggerLeft=0;if(rightMapped)status.triggerRight=0;
 };
 PADStatus triggerStatus{}; triggerStatus.triggerLeft=120; triggerStatus.triggerRight=120;
 maskExplicitTriggerAxes(triggerStatus,false,true);
 assert(triggerStatus.triggerLeft==120 && triggerStatus.triggerRight==0);
 triggerStatus.triggerLeft=120; triggerStatus.triggerRight=120;
 maskExplicitTriggerAxes(triggerStatus,false,false);
 assert(triggerStatus.triggerLeft==120 && triggerStatus.triggerRight==120);
 // Accelerate=A + RT and Drift=RB: RT must not leak through GameCube R;
 // RB remains the only Drift source, and LT stays unrelated.
 triggerStatus.triggerLeft=120; triggerStatus.triggerRight=120;
 maskExplicitTriggerAxes(triggerStatus,true,true);
 assert(triggerStatus.triggerLeft==0 && triggerStatus.triggerRight==0);
 NSData *invalid=[@"invalid json" dataUsingEncoding:NSUTF8StringEncoding];
 assert([invalid writeToURL:[first profileURL] atomically:YES]);
 KPControllerSettings *third=[KPControllerSettings new];assert(third.profileReadFailed);
 [third save:nil];assert([[NSData dataWithContentsOfURL:[third profileURL]] isEqual:invalid]);
 [[NSFileManager defaultManager] removeItemAtURL:[third profileURL] error:nil];
 assert([[NSFileManager defaultManager] createDirectoryAtURL:[third profileURL]
                              withIntermediateDirectories:NO
                                            attributes:nil
                                                error:nil]);
 KPControllerSettings *unreadable=[KPControllerSettings new];assert(unreadable.profileReadFailed);
 [unreadable save:nil];
 BOOL isDirectory=NO;
 assert([[NSFileManager defaultManager] fileExistsAtPath:third.profileURL.path isDirectory:&isDirectory] && isDirectory);
 assert([KPControllerDiagnostics() containsString:@"Detected controllers: 1"]);
 assert([KPButtonLabel(nullptr,SDL_GAMEPAD_BUTTON_START) isEqual:@"Menu"]);
 assert([KPButtonLabel(nullptr,SDL_GAMEPAD_BUTTON_LEFT_SHOULDER) isEqual:@"LB"]);
 SDL_CloseGamepad(testPad);testPad=nullptr;SDL_DetachVirtualJoystick(id);SDL_Quit();
 [[NSFileManager defaultManager] removeItemAtURL:testRoot error:nil];
 puts("PASS: profile round trip, legacy secondary bindings, dead zones, shared bindings, A OR RT via virtual SDL input, clear, corrupt-file preservation, Xbox labels");
}}
