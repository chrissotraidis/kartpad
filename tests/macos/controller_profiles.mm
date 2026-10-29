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
static std::array<std::array<PADKeyButtonBinding,12>,4> testPortKeys;
static std::array<std::array<PADKeyAxisBinding,10>,4> testPortKeyAxes;
static auto &testKeys=testPortKeys[0];
static auto &testKeyAxes=testPortKeyAxes[0];
static std::array<bool,4> testKeyboardActive;
static bool testKeyboardLoaded=true;
static int testKeyboardSaves=0;
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
PADKeyButtonBinding *PADGetKeyButtonBindings(u32 p,u32 *count){
 if(!testKeyboardLoaded){
   // Model Aurora's first read replacing in-memory values with saved mappings.
   for(auto &b:testPortKeys[p])b.scancode=SDL_SCANCODE_F;
   for(auto &b:testPortKeyAxes[p])b.scancode=SDL_SCANCODE_G;
   testKeyboardLoaded=true;
 }
 *count=12;return testPortKeys[p].data();
}
PADKeyAxisBinding *PADGetKeyAxisBindings(u32 p,u32 *count){*count=10;return testPortKeyAxes[p].data();}
#define BOOL KPPadBOOL
BOOL PADSetKeyButtonBinding(u32 p,PADKeyButtonBinding m){for(auto &b:testPortKeys[p])if(b.padButton==m.padButton){b=m;return TRUE;}return FALSE;}
BOOL PADSetKeyAxisBinding(u32 p,PADKeyAxisBinding m){for(auto &b:testPortKeyAxes[p])if(b.padAxis==m.padAxis){b=m;return TRUE;}return FALSE;}
void PADClearKeyBindings(u32 p){for(auto &b:testPortKeys[p])b.scancode=PAD_KEY_INVALID;for(auto &b:testPortKeyAxes[p])b.scancode=PAD_KEY_INVALID;testKeyboardActive[p]=false;}
void PADSetKeyboardActive(u32 p,BOOL active){testKeyboardActive[p]=active;}
void PADSerializeMappings(){++testKeyboardSaves;}
#undef BOOL
}
namespace Wup028Adapter { void SetPortAssignment(uint32_t,int){} }
#include "kpad_keyboard_fixture.inc.mm"
static void TestModifierCapture(KPControllerSettings* panel) {
 auto flagsEvent=[](unsigned short code, NSEventModifierFlags flags) {
   return [NSEvent keyEventWithType:NSEventTypeFlagsChanged location:NSZeroPoint modifierFlags:flags
     timestamp:0 windowNumber:0 context:nil characters:@"" charactersIgnoringModifiers:@""
     isARepeat:NO keyCode:code];
 };
 auto arm=[&] { panel.keyboardCaptureKind=0;panel.keyboardCaptureIndex=0; };
 // Use real FlagsChanged events, not artificial modifier KeyDown events.
 for(auto [key,sc,own,other,aggregate] : {
   std::tuple{kVK_Shift,SDL_SCANCODE_LSHIFT,NX_DEVICELSHIFTKEYMASK,NX_DEVICERSHIFTKEYMASK,NSEventModifierFlagShift},
   {kVK_RightShift,SDL_SCANCODE_RSHIFT,NX_DEVICERSHIFTKEYMASK,NX_DEVICELSHIFTKEYMASK,NSEventModifierFlagShift},
   {kVK_Control,SDL_SCANCODE_LCTRL,NX_DEVICELCTLKEYMASK,NX_DEVICERCTLKEYMASK,NSEventModifierFlagControl},
   {kVK_RightControl,SDL_SCANCODE_RCTRL,NX_DEVICERCTLKEYMASK,NX_DEVICELCTLKEYMASK,NSEventModifierFlagControl},
   {kVK_Option,SDL_SCANCODE_LALT,NX_DEVICELALTKEYMASK,NX_DEVICERALTKEYMASK,NSEventModifierFlagOption},
   {kVK_RightOption,SDL_SCANCODE_RALT,NX_DEVICERALTKEYMASK,NX_DEVICELALTKEYMASK,NSEventModifierFlagOption}}) {
   arm();int saves=testKeyboardSaves,previous=testKeys[0].scancode;
   assert(![panel handleKeyboardEvent:flagsEvent(key,0)]); // release
   assert(![panel handleKeyboardEvent:flagsEvent(key,aggregate|other)]); // other side still held
   assert(testKeys[0].scancode==previous && testKeyboardSaves==saves && panel.keyboardCaptureKind==0);
   assert([panel handleKeyboardEvent:flagsEvent(key,aggregate|own)]);
   assert(testKeys[0].scancode==sc && testKeyboardSaves==saves+1 && panel.keyboardCaptureKind==-1);
   assert(![panel handleKeyboardEvent:flagsEvent(key,0)]); // no active capture
   arm();assert([panel handleKeyboardEvent:flagsEvent(key,aggregate)]); // SDL's aggregate-only fallback
   assert(testKeys[0].scancode==sc);
 }
 // Axes share the same press-only capture, including modifier keys.
 panel.keyboardCaptureKind=1;panel.keyboardCaptureIndex=8;
 assert([panel handleKeyboardEvent:flagsEvent(kVK_RightControl,NSEventModifierFlagControl|NX_DEVICERCTLKEYMASK)]);
 assert(testKeyAxes[8].scancode==SDL_SCANCODE_RCTRL);
 arm();int saves=testKeyboardSaves,previous=testKeys[0].scancode;
 for(auto key : {kVK_Command,kVK_RightCommand}) {
   assert(![panel handleKeyboardEvent:flagsEvent(key,NSEventModifierFlagCommand)]);
   assert(![panel handleKeyboardEvent:flagsEvent(key,0)]);
 }
 assert(![panel handleKeyboardEvent:flagsEvent(kVK_Shift,NSEventModifierFlagCommand|NSEventModifierFlagShift|NX_DEVICELSHIFTKEYMASK)]);
 NSEvent* commandQ=[NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
   modifierFlags:NSEventModifierFlagCommand timestamp:0 windowNumber:0 context:nil
   characters:@"q" charactersIgnoringModifiers:@"q" isARepeat:NO keyCode:kVK_ANSI_Q];
 assert(![panel handleKeyboardEvent:commandQ]);
 assert(testKeys[0].scancode==previous && testKeyboardSaves==saves && panel.keyboardCaptureKind==0);
 [panel cancelCapture];
 // Drive the registered local monitor through AppKit as well: a FlagsChanged
 // event must actually reach capture, rather than only passing direct calls.
 [NSApplication sharedApplication];[NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
 panel.selectedID=(SDL_JoystickID)-1;[panel prepareInPanel:nil];arm();
 [NSApp sendEvent:flagsEvent(kVK_Shift,NSEventModifierFlagShift|NX_DEVICELSHIFTKEYMASK)];
 assert(testKeys[0].scancode==SDL_SCANCODE_LSHIFT && panel.keyboardCaptureKind==-1);
 auto close=[NSNotification notificationWithName:NSWindowWillCloseNotification object:nil];
 [panel windowWillClose:close];[panel activateInput];arm();
 [NSApp sendEvent:flagsEvent(kVK_RightShift,NSEventModifierFlagShift|NX_DEVICERSHIFTKEYMASK)];
 assert(testKeys[0].scancode==SDL_SCANCODE_RSHIFT && panel.keyboardCaptureKind==-1);
 [panel windowWillClose:close];
 puts("PASS: real FlagsChanged modifier capture, left/right press/release, opposite-side holds, axes, Command passthrough and registered local monitor");
}
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
 int savesBeforeInvalid=testKeyboardSaves;
 arm();[second handleKeyboardEvent:event(65535,@"a")];assert(testKeys[0].scancode==previous);
 [second handleKeyboardEvent:event(12,@"a",YES)];assert(testKeys[0].scancode==previous);
 assert(second.keyboardCaptureKind==0);[second cancel:nil];
 assert(testKeyboardSaves==savesBeforeInvalid);
 assert(KPMacPhysicalScancode(10,false)==SDL_SCANCODE_NONUSBACKSLASH);
 assert(KPMacPhysicalScancode(50,false)==SDL_SCANCODE_GRAVE);
 assert(KPMacPhysicalScancode(10,true)==SDL_SCANCODE_GRAVE);
 assert(KPMacPhysicalScancode(50,true)==SDL_SCANCODE_NONUSBACKSLASH);
 assert(KPMacPhysicalScancode(65535,false)==SDL_SCANCODE_UNKNOWN);
 int savesBeforeRemap=testKeyboardSaves;
 arm();[second handleKeyboardEvent:event(36,@"\r")];
 assert(testKeys[0].scancode==SDL_SCANCODE_RETURN && testKeyboardSaves==savesBeforeRemap+1);
 second.keyboardCaptureKind=1;second.keyboardCaptureIndex=0;
 [second handleKeyboardEvent:event(12,@"a")];assert(testKeyAxes[0].scancode==SDL_SCANCODE_Q);
 assert(testKeyboardSaves==savesBeforeRemap+2);
 NSButton *clearButton=[NSButton new];clearButton.tag=0;
 [second clearKeyboard:clearButton];assert(testKeys[0].scancode==PAD_KEY_INVALID);
 clearButton.tag=100;[second clearKeyboard:clearButton];assert(testKeyAxes[0].scancode==PAD_KEY_INVALID);
 assert(testKeyboardSaves==savesBeforeRemap+4);
 puts("PASS: keyboard cancel/Escape/close/reopen/deactivation, alternate layouts, special keys, ISO, repeat and invalid-key handling");
 uint32_t controllerBefore=testButtons[0].nativeButton;
 assert(PADSetKeyButtonBinding(0,{SDL_SCANCODE_F,KPButtons[0]}));
 assert(testKeys[0].scancode==SDL_SCANCODE_F && testButtons[0].nativeButton==controllerBefore);
 assert(PADSetKeyAxisBinding(0,{SDL_SCANCODE_G,(PADAxis)PAD_AXIS_LEFT_X_POS,0}));
 assert(testKeyAxes[0].scancode==SDL_SCANCODE_G);
 PADClearKeyBindings(0); assert(testKeys[0].scancode==PAD_KEY_INVALID);
 // Use the actual shared default helper through the UI action. The PAD fixture
 // checks orchestration; real Aurora save/load and app relaunch are separate checks.
 constexpr int expectedKeys[]={SDL_SCANCODE_RETURN,SDL_SCANCODE_BACKSPACE,
   SDL_SCANCODE_Q,SDL_SCANCODE_E,SDL_SCANCODE_SPACE,SDL_SCANCODE_LSHIFT,
   SDL_SCANCODE_LCTRL,SDL_SCANCODE_LALT,SDL_SCANCODE_UP,SDL_SCANCODE_DOWN,
   SDL_SCANCODE_LEFT,SDL_SCANCODE_RIGHT};
 constexpr int expectedAxes[]={SDL_SCANCODE_D,SDL_SCANCODE_A,SDL_SCANCODE_W,
   SDL_SCANCODE_S,SDL_SCANCODE_L,SDL_SCANCODE_J,SDL_SCANCODE_I,SDL_SCANCODE_K,
   SDL_SCANCODE_LCTRL,SDL_SCANCODE_LALT};
 for(int port=1;port<4;++port) {
   for(int i=0;i<12;++i)testPortKeys[port][i]={SDL_SCANCODE_F,KPButtons[i]};
   for(int i=0;i<10;++i)testPortKeyAxes[port][i]={SDL_SCANCODE_G,(PADAxis)i,0};
   testKeyboardActive[port]=(port==2);
 }
 const auto buttonsBeforeReset=testButtons, alternatesBeforeReset=testAlternates;
 const auto zonesBeforeReset=testZones;
 NSDictionary *profilesBeforeReset=[second.profiles copy];
 auto checkDefaults=[&] {
   for(int i=0;i<12;++i)assert(testKeys[i].padButton==KPButtons[i] && testKeys[i].scancode==expectedKeys[i]);
   for(int i=0;i<10;++i)assert(testKeyAxes[i].padAxis==(PADAxis)i && testKeyAxes[i].scancode==expectedAxes[i]);
   assert(testKeyboardActive[0]);
   for(int port=1;port<4;++port) {
     for(auto b:testPortKeys[port])assert(b.scancode==SDL_SCANCODE_F);
     for(auto b:testPortKeyAxes[port])assert(b.scancode==SDL_SCANCODE_G);
     assert(testKeyboardActive[port]==(port==2));
   }
   for(int i=0;i<12;++i) {
     assert(testButtons[i].nativeButton==buttonsBeforeReset[i].nativeButton);
     assert(testAlternates[i].nativeButton==alternatesBeforeReset[i].nativeButton);
   }
   assert(testZones.useDeadzones==zonesBeforeReset.useDeadzones && testZones.emulateTriggers==zonesBeforeReset.emulateTriggers);
   assert(testZones.stickDeadZone==zonesBeforeReset.stickDeadZone && testZones.substickDeadZone==zonesBeforeReset.substickDeadZone);
   assert(testZones.leftTriggerActivationZone==zonesBeforeReset.leftTriggerActivationZone && testZones.rightTriggerActivationZone==zonesBeforeReset.rightTriggerActivationZone);
   assert([second.profiles isEqual:profilesBeforeReset]);
   assert(second.capture==-1 && !second.armed && second.keyboardCaptureKind==-1 && second.keyboardCaptureIndex==-1);
 };
 int savesBeforeReset=testKeyboardSaves;
 testKeyboardLoaded=false; // persisted edits must load before resetting
 second.capture=2;second.armed=YES;arm();
 [second resetKeyboard:nil];checkDefaults();assert(testKeyboardSaves==savesBeforeReset+1);
 [second save:nil];checkDefaults(); // immediate Save Profile must not clear defaults
 testKeys[0].scancode=SDL_SCANCODE_F;testKeyAxes[0].scancode=PAD_KEY_INVALID;
 second.selectedID=id;second.capture=3;second.armed=YES;
 [second resetKeyboard:nil];checkDefaults();assert(testKeyboardSaves==savesBeforeReset+2);
 [second resetKeyboard:nil];checkDefaults();assert(testKeyboardSaves==savesBeforeReset+3);
 puts("PASS: remap/clear serialization, concrete keyboard defaults, lazy-load ordering, reset then Save, capture cancellation, other ports and controller profiles preserved");
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
 TestModifierCapture(second);
 TestClassicKeyboard(second);
 assert([KPControllerDiagnostics() containsString:@"Profile test; gamepad=yes; opened=yes"]);
 SDL_CloseGamepad(testPad);testPad=nullptr;
 // A recognized but unopened controller must remain visible in diagnostics.
 NSString *unopened=KPControllerDiagnostics();
 assert([unopened containsString:@"Detected controllers: 0"]);
 assert([unopened containsString:@"Profile test; gamepad=yes; opened=no"]);
 assert(SDL_GetGamepadFromID(id)==nullptr); // reporting must not open it
 SDL_VirtualJoystickDesc rawDesc{};SDL_INIT_INTERFACE(&rawDesc);
 rawDesc.type=SDL_JOYSTICK_TYPE_FLIGHT_STICK;rawDesc.naxes=2;rawDesc.nbuttons=2;
 rawDesc.name="Raw\ncontroller test";
 SDL_JoystickID rawID=SDL_AttachVirtualJoystick(&rawDesc);assert(rawID);
 assert(!SDL_IsGamepad(rawID));
 assert([KPControllerDiagnostics() containsString:@"Raw controller test; gamepad=no; opened=no"]);
 SDL_DetachVirtualJoystick(rawID);SDL_DetachVirtualJoystick(id);
 NSString *detached=KPControllerDiagnostics();
 assert(![detached containsString:@"Profile test"] && ![detached containsString:@"Raw controller test"]);
 SDL_Quit();
 [[NSFileManager defaultManager] removeItemAtURL:testRoot error:nil];
 puts("PASS: profile round trip, legacy secondary bindings, dead zones, shared bindings, A OR RT via virtual SDL input, clear, corrupt-file preservation, Xbox labels");
}}
