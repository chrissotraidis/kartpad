// Included by KartPadMacShell.mm so all native shell targets share this UI.
#include <SDL3/SDL.h>
#include <SDL3/SDL_scancode.h>
#include <iterator>
#import <Carbon/Carbon.h>
#include "../third_party/sdl/scancodes_darwin.h"

static SDL_Scancode KPMacPhysicalScancode(unsigned short keyCode, bool isoKeyboard) {
  // Match SDL Cocoa, including the hardware ISO grave/non-US key swap.
  if (isoKeyboard && (keyCode == 10 || keyCode == 50)) keyCode = 60 - keyCode;
  return keyCode < std::size(darwin_scancode_table)
      ? darwin_scancode_table[keyCode] : SDL_SCANCODE_UNKNOWN;
}
#define BOOL KPPadBOOL
#include <dolphin/pad.h>
#undef BOOL
#include "wup028_adapter.h"
#include <array>
#include <dolphin/controller_binding.h>

static constexpr std::array<PADButton, 12> KPButtons = {
  PAD_BUTTON_A, PAD_BUTTON_B, PAD_BUTTON_X, PAD_BUTTON_Y, PAD_BUTTON_START,
  PAD_TRIGGER_Z, PAD_TRIGGER_L, PAD_TRIGGER_R, PAD_BUTTON_UP, PAD_BUTTON_DOWN,
  PAD_BUTTON_LEFT, PAD_BUTTON_RIGHT};
static NSArray<NSString *> *KPActions() {
  return @[@"Accelerate / Select", @"Brake / Back", @"X", @"Y", @"Pause",
           @"Rear view (Z)", @"Item (L)", @"Drift (R)", @"Trick / D-pad Up",
           @"D-pad Down", @"D-pad Left", @"D-pad Right"];
}
static NSString *KPButtonLabel(SDL_Gamepad *pad, int button) {
  if ((uint32_t)button == kartpad::binding::LeftTrigger) return @"LT / L2";
  if ((uint32_t)button == kartpad::binding::RightTrigger) return @"RT / R2";
  if (button < 0 || button >= SDL_GAMEPAD_BUTTON_COUNT) return @"Unbound";
  const auto type = pad ? SDL_GetGamepadType(pad) : SDL_GAMEPAD_TYPE_STANDARD;
  if (button < 4) {
    if (type == SDL_GAMEPAD_TYPE_PS3 || type == SDL_GAMEPAD_TYPE_PS4 || type == SDL_GAMEPAD_TYPE_PS5)
      return @[@"Cross", @"Circle", @"Square", @"Triangle"][button];
    if (type == SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_PRO || type == SDL_GAMEPAD_TYPE_NINTENDO_SWITCH_JOYCON_PAIR)
      return @[@"B", @"A", @"Y", @"X"][button];
    return @[@"A", @"B", @"X", @"Y"][button];
  }
  bool ps = type == SDL_GAMEPAD_TYPE_PS3 || type == SDL_GAMEPAD_TYPE_PS4 || type == SDL_GAMEPAD_TYPE_PS5;
  switch (button) {
    case SDL_GAMEPAD_BUTTON_BACK: return ps ? @"Share / Select" : @"View";
    case SDL_GAMEPAD_BUTTON_START: return ps ? @"Options" : @"Menu";
    case SDL_GAMEPAD_BUTTON_LEFT_SHOULDER: return ps ? @"L1" : @"LB";
    case SDL_GAMEPAD_BUTTON_RIGHT_SHOULDER: return ps ? @"R1" : @"RB";
    case SDL_GAMEPAD_BUTTON_DPAD_UP: return @"D-pad Up";
    case SDL_GAMEPAD_BUTTON_DPAD_DOWN: return @"D-pad Down";
    case SDL_GAMEPAD_BUTTON_DPAD_LEFT: return @"D-pad Left";
    case SDL_GAMEPAD_BUTTON_DPAD_RIGHT: return @"D-pad Right";
    case SDL_GAMEPAD_BUTTON_GUIDE: return @"Guide";
    case SDL_GAMEPAD_BUTTON_LEFT_STICK: return @"Left stick click";
    case SDL_GAMEPAD_BUTTON_RIGHT_STICK: return @"Right stick click";
    default: {
      const char *name = SDL_GetGamepadStringForButton((SDL_GamepadButton)button);
      return name ? [NSString stringWithUTF8String:name] : @"Unknown";
    }
  }
}
static NSString *KPProfileKey(SDL_Gamepad *pad) {
  char guid[33]{};
  SDL_GUIDToString(SDL_GetJoystickGUID(SDL_GetGamepadJoystick(pad)), guid, sizeof(guid));
  // Serial improves identity for identical models; hash it rather than storing it.
  const char *serial = SDL_GetGamepadSerial(pad);
  NSString *identity = [NSString stringWithFormat:@"%s:%s", guid, serial ?: ""];
  NSData *data = [identity dataUsingEncoding:NSUTF8StringEncoding];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *key = [NSMutableString string];
  for (auto byte : digest) [key appendFormat:@"%02x", byte];
  return key;
}

@interface KPControllerSettings : NSObject <NSWindowDelegate>
@property NSPanel *panel;
@property NSView *content;
@property NSPopUpButton *devices;
@property NSPopUpButton *player;
@property NSTextField *status;
@property NSTextField *feedback;
@property NSTextField *profileLabel;
@property NSMutableArray<NSButton *> *bindings;
@property NSMutableArray<NSButton *> *altBindings;
@property BOOL captureAlternate;
@property NSMutableArray<NSTextField *> *lights;
@property NSMutableArray<NSLevelIndicator *> *axes;
@property NSMutableArray<NSSlider *> *zones;
@property NSMutableDictionary *profiles;
@property NSMutableDictionary<NSNumber *, NSString *> *applied;
@property SDL_JoystickID selectedID;
@property NSInteger capture;
@property BOOL armed;
@property BOOL dirty;
@property BOOL profileReadFailed;
@property NSString *previousBackgroundHint;
@property BOOL backgroundHintOwned;
@property NSMutableArray<NSButton *> *keyboardButtons;
@property NSMutableArray<NSButton *> *keyboardAxes;
@property NSInteger keyboardCaptureKind;
@property NSInteger keyboardCaptureIndex;
@property id keyboardMonitor;
@property NSMutableArray<NSView *> *controllerOnlyViews;
@property NSView *mappingHint;
@property NSMutableArray<NSView *> *keyboardOnlyViews;
@end

@implementation KPControllerSettings
- (instancetype)init {
  if ((self = [super init])) {
    _capture = -1;
    _keyboardCaptureKind = -1;
    _keyboardCaptureIndex = -1;
    _applied = [NSMutableDictionary dictionary];
    _profiles = [NSMutableDictionary dictionary];
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:[self profileURL]
                                         options:0
                                           error:&readError];
    if (data) {
      NSError *error = nil;
      id object = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
      if ([object isKindOfClass:NSDictionary.class] && [object[@"version"] isEqual:@1] &&
          [object[@"devices"] isKindOfClass:NSDictionary.class]) {
        _profiles = object[@"devices"];
        AppendSessionLine(@"controllerProfiles=loaded-v1");
      } else {
        AppendSessionLine(@"controllerProfiles=invalid; existing file preserved");
        _profileReadFailed = YES;
        _status = [NSTextField labelWithString:@"Controller profiles could not be read. Restore the file before saving changes."];
      }
    } else if (readError && readError.code != NSFileReadNoSuchFileError) {
      AppendSessionLine(@"controllerProfiles=read-failed; existing file preserved");
      _profileReadFailed = YES;
      _status = [NSTextField labelWithString:@"Controller profiles could not be read. Restore the file before saving changes."];
    }
  }
  return self;
}
- (NSURL *)profileURL {
  return [ApplicationSupportURL() URLByAppendingPathComponent:@"ControllerProfiles.json"];
}
- (SDL_Gamepad *)selectedPad { return SDL_GetGamepadFromID(self.selectedID); }
- (BOOL)keyboardSelected { return self.selectedID == (SDL_JoystickID)-1; }
- (int)port {
  for (int port = 0; port < 4; ++port) {
    int index = PADGetIndexForPort(port);
    if (index >= 0 && PADGetSDLGamepadForIndex(index) == [self selectedPad]) return port;
  }
  return -1;
}
- (NSTextField *)label:(NSString *)text frame:(NSRect)frame {
  NSTextField *label = [NSTextField labelWithString:text];
  label.frame = frame;
  [self.content addSubview:label];
  return label;
}
- (NSButton *)button:(NSString *)title action:(SEL)action frame:(NSRect)frame {
  NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
  button.frame = frame;
  [self.content addSubview:button];
  return button;
}
- (void)prepareInPanel:(NSPanel *)panel {
  self.panel = panel;
  if (!self.content) {
    self.content = [[NSView alloc] initWithFrame:NSMakeRect(0,0,760,740)];
    self.content.autoresizingMask = NSViewWidthSizable;
    self.devices = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(20,690,510,28) pullsDown:NO];
    self.devices.target = self; self.devices.action = @selector(selectDevice:);
    [self.content addSubview:self.devices];
    self.player = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(550,690,210,28) pullsDown:NO];
    [self.player addItemsWithTitles:@[@"Unassigned", @"Player 1", @"Player 2", @"Player 3", @"Player 4"]];
    self.player.target = self; self.player.action = @selector(assign:);
    [self.content addSubview:self.player];
    self.profileLabel = [self label:@"" frame:NSMakeRect(20,662,740,20)];
    [self label:@"Live input — buttons and raw SDL axes" frame:NSMakeRect(20,636,740,20)];
    self.lights = [NSMutableArray array];
    for (int i = 0; i < 15; ++i) {
      NSTextField *light = [self label:@"" frame:NSMakeRect(20+(i%5)*148,608-(i/5)*25,145,22)];
      light.alignment = NSTextAlignmentCenter; light.drawsBackground = YES;
      [self.lights addObject:light];
    }
    self.axes = [NSMutableArray array];
    NSArray *names = @[@"Left X", @"Left Y", @"Right X", @"Right Y", @"LT / L2", @"RT / R2"];
    for (int i = 0; i < 6; ++i) {
      CGFloat x = 20+(i%3)*248, y = 522-(i/3)*32;
      [self label:names[i] frame:NSMakeRect(x,y,80,20)];
      NSLevelIndicator *level = [[NSLevelIndicator alloc] initWithFrame:NSMakeRect(x+80,y,152,18)];
      level.accessibilityLabel = names[i];
      level.levelIndicatorStyle = NSLevelIndicatorStyleContinuousCapacity;
      level.minValue = i < 4 ? -32768 : 0; level.maxValue = 32767;
      level.warningValue = 32768; level.criticalValue = 32768;
      [self.content addSubview:level]; [self.axes addObject:level];
    }
    self.feedback = [self label:@"" frame:NSMakeRect(20,454,740,28)];
    self.feedback.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.bindings = [NSMutableArray array];
    self.altBindings = [NSMutableArray array];
    self.keyboardAxes = [NSMutableArray array];
    self.controllerOnlyViews = [NSMutableArray array];
    self.keyboardOnlyViews = [NSMutableArray array];
    for (int i = 0; i < 12; ++i) {
      CGFloat x = 20+(i/6)*370, y = 418-(i%6)*34;
      [self label:KPActions()[i] frame:NSMakeRect(x,y,150,22)];
      NSButton *button = [self button:@"" action:@selector(remap:) frame:NSMakeRect(x+150,y-2,78,26)];
      button.tag = i; [self.bindings addObject:button];
      button.accessibilityLabel = [KPActions()[i] stringByAppendingString:@" — primary binding"];
      NSButton *alt = [self button:@"+ Add" action:@selector(remap:) frame:NSMakeRect(x+232,y-2,75,26)];
      alt.tag = i + 12; [self.altBindings addObject:alt];
      alt.accessibilityLabel = [KPActions()[i] stringByAppendingString:@" — alternative binding"];
      alt.toolTip = @"Either binding activates this action. Click to add or replace the alternative.";
      NSButton *clear = [self button:@"Clear" action:@selector(clear:) frame:NSMakeRect(x+311,y-2,49,26)];
      clear.tag = i; clear.toolTip = @"Clear both bindings. Item / Drift then use the default analogue trigger.";
    }
    NSTextField *axisHeading=[self label:@"Keyboard axes" frame:NSMakeRect(20,218,180,22)];
    [self.keyboardOnlyViews addObject:axisHeading];
    NSArray *axisNames=@[@"Left X +",@"Left X −",@"Left Y +",@"Left Y −",@"Right X +",@"Right X −",@"Right Y +",@"Right Y −",@"Left trigger",@"Right trigger"];
    for(int i=0;i<PAD_AXIS_COUNT;++i) {
      CGFloat x=200+(i%2)*280,y=218-(i/2)*30;
      NSTextField *axisLabel=[self label:axisNames[i] frame:NSMakeRect(x,y,90,22)];
      [self.keyboardOnlyViews addObject:axisLabel];
      NSButton *key=[self button:@"Unbound" action:@selector(remap:) frame:NSMakeRect(x+92,y-2,100,26)];
      key.tag=100+i; [self.keyboardAxes addObject:key];
      [self.keyboardOnlyViews addObject:key];
      NSButton *clear=[self button:@"Clear" action:@selector(clear:) frame:NSMakeRect(x+196,y-2,50,26)]; clear.tag=100+i; [self.keyboardOnlyViews addObject:clear];
    }
    self.mappingHint=[self label:@"Two bindings per action: either works. Click + Add, release controls, then press a button or pull a trigger."
      frame:NSMakeRect(20,218,740,22)];
    self.zones = [NSMutableArray array];
    NSArray *zoneNames = @[@"Steering dead zone", @"Right stick dead zone", @"Trigger threshold"];
    for (int i = 0; i < 3; ++i) {
      CGFloat x = 20+i*248;
      NSTextField *zoneLabel=[self label:zoneNames[i] frame:NSMakeRect(x,187,240,20)];
      [self.controllerOnlyViews addObject:zoneLabel];
      NSSlider *slider = [NSSlider sliderWithValue:0.24 minValue:0 maxValue:i==2?0.99:0.5 target:self action:@selector(changeZone:)];
      slider.accessibilityLabel = zoneNames[i];
      slider.frame = NSMakeRect(x,157,225,24); slider.tag = i; slider.continuous = NO;
      [self.content addSubview:slider]; [self.zones addObject:slider]; [self.controllerOnlyViews addObject:slider];
    }
    NSString *initial = self.status.stringValue ?: @"Changes apply immediately. Save Profile keeps them between launches.";
    self.status = [self label:initial frame:NSMakeRect(20,72,740,70)];
    self.status.maximumNumberOfLines = 3;
    [self button:@"Reset to Default" action:@selector(reset:) frame:NSMakeRect(20,24,145,32)];
    [self button:@"Cancel Remapping" action:@selector(cancel:) frame:NSMakeRect(175,24,165,32)].keyEquivalent = @"\033";
    [self button:@"Save Profile" action:@selector(save:) frame:NSMakeRect(620,24,140,32)];
    [self button:@"Reset Keyboard Defaults" action:@selector(resetKeyboard:) frame:NSMakeRect(345,24,180,32)];
    self.keyboardMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
      if(self.keyboardCaptureKind>=0) { [self handleKeyboardEvent:event]; return nil; }
      return event;
    }];
  }
}
- (void)activateInput {
  if(!self.keyboardMonitor) self.keyboardMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent *(NSEvent *event) {
    if(self.keyboardCaptureKind>=0) { [self handleKeyboardEvent:event]; return nil; }
    return event;
  }];
  if (!self.backgroundHintOwned) {
    const char *hint=SDL_GetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS);
    self.previousBackgroundHint=hint ? [NSString stringWithUTF8String:hint] : nil;
    self.backgroundHintOwned=YES;
  }
  // AppKit panels are not SDL windows. SDL otherwise discards every input
  // update while this panel has keyboard focus, even though KartPad is active.
  SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
  [self tick];
}
- (void)cancelCapture {
  self.capture = -1; self.armed = NO;
  self.keyboardCaptureKind = -1; self.keyboardCaptureIndex = -1;
  if ([self keyboardSelected]) [self refreshKeyboardLabels];
}
- (void)windowDidResignKey:(NSNotification *)notification {
  (void)notification; [self cancelCapture];
}
- (void)windowWillClose:(NSNotification *)notification {
  (void)notification; [self cancelCapture];
  if(self.backgroundHintOwned) {
    if(self.previousBackgroundHint) SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS,self.previousBackgroundHint.UTF8String);
    else SDL_ResetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS);
    self.backgroundHintOwned=NO;
  }
  if (self.dirty) [self save:nil];
  if(self.keyboardMonitor) { [NSEvent removeMonitor:self.keyboardMonitor]; self.keyboardMonitor=nil; }
}
- (void)selectDevice:(id)sender {
  (void)sender;
  [self cancelCapture];
  self.selectedID = [self.devices.selectedItem.representedObject isEqual:@"keyboard"] ? (SDL_JoystickID)-1 : [self.devices.selectedItem.representedObject unsignedIntValue];
}
- (void)assign:(id)sender {
  (void)sender;
  SDL_Gamepad *pad = [self selectedPad]; if (!pad) return;
  int old = [self port], port = (int)self.player.indexOfSelectedItem-1;
  if (old >= 0) PADClearPort(old);
  if (port >= 0) {
    Wup028Adapter::SetPortAssignment(port, -1);
    RuntimeConfigFile::SetGameCubeAdapterPort(port, -1);
    for (unsigned i = 0; i < PADCount(); ++i)
      if (PADGetSDLGamepadForIndex(i) == pad) { PADSetPortForIndex(i, port); break; }
  }
  [self.applied removeObjectForKey:@(self.selectedID)]; self.capture = -1;
  AppendSessionLine([NSString stringWithFormat:@"controllerAssignment=player-%d", port+1]);
}
- (void)remember {
  int port = [self port]; SDL_Gamepad *pad = [self selectedPad]; if (port < 0 || !pad) return;
  unsigned count = 0; PADButtonMapping *bindings = PADGetButtonMappings(port, &count);
  if (!bindings || count != 12) return;
  NSMutableArray *values = [NSMutableArray array];
  for (auto action : KPButtons) {
    uint32_t value = PAD_NATIVE_BUTTON_INVALID;
    for (unsigned j=0;j<count;++j) if(bindings[j].padButton==action) value=bindings[j].nativeButton;
    [values addObject:@(value)];
  }
  NSMutableArray *alternates = [NSMutableArray array];
  unsigned altCount=0; auto *alt=PADGetAltButtonMappings(port,&altCount);
  for(auto action:KPButtons) {
    uint32_t value=PAD_NATIVE_BUTTON_INVALID;
    for(unsigned j=0;j<altCount;++j)if(alt[j].padButton==action)value=alt[j].nativeButton;
    [alternates addObject:@(value)];
  }
  PADDeadZones *zones = PADGetDeadZones(port);
  if (!zones) return;
  self.profiles[KPProfileKey(pad)] = [@{@"buttons":values, @"alternates":alternates, @"stick":@(zones->stickDeadZone),
    @"substick":@(zones->substickDeadZone), @"trigger":@(zones->leftTriggerActivationZone), @"rightTrigger":@(zones->rightTriggerActivationZone),
    @"useDeadzones":@(zones->useDeadzones), @"emulateTriggers":@(zones->emulateTriggers)} mutableCopy];
  self.dirty = YES;
}
- (void)bind:(uint32_t)value {
  int port = [self port]; if (port < 0 || self.capture < 0 || !kartpad::binding::valid(value)) return;
  unsigned count=0, altCount=0;
  auto *mappings=PADGetButtonMappings(port,&count);
  auto *alternates=PADGetAltButtonMappings(port,&altCount);
  bool shared=false;
  for (unsigned i=0;i<count;++i)
    if(value!=PAD_NATIVE_BUTTON_INVALID && mappings[i].nativeButton==value && mappings[i].padButton!=KPButtons[self.capture]) shared=true;
  for (unsigned i=0;i<altCount;++i)
    if(value!=PAD_NATIVE_BUTTON_INVALID && alternates[i].nativeButton==value && alternates[i].padButton!=KPButtons[self.capture]) shared=true;
  if(self.captureAlternate) PADSetAltButtonMapping(port,{value,KPButtons[self.capture]});
  else PADSetButtonMapping(port,{value,KPButtons[self.capture]});
  self.capture = -1; [self remember];
  self.status.stringValue = shared ? @"Binding updated. This control is also bound to another action; both will activate. Clear the other binding if unintended. Save Profile to keep changes." : @"Binding updated. Either binding activates the action. Save Profile to keep your changes.";
}
- (NSString *)keyName:(int)scancode {
  if (scancode < 0) return @"Unbound";
  const char *name = SDL_GetScancodeName((SDL_Scancode)scancode);
  return name && *name ? [NSString stringWithUTF8String:name] : [NSString stringWithFormat:@"Key %d",scancode];
}
- (void)refreshKeyboardLabels {
  unsigned count=0; auto *buttons=PADGetKeyButtonBindings(0,&count);
  for (int i=0;i<12;++i) {
    int sc=-1; if(buttons && count==PAD_BUTTON_COUNT) for(unsigned j=0;j<count;++j) if(buttons[j].padButton==KPButtons[i]) sc=buttons[j].scancode;
    self.bindings[i].title=(self.keyboardCaptureKind==0 && self.keyboardCaptureIndex==i) ? @"Press…" : [self keyName:sc];
    self.altBindings[i].hidden=YES; self.bindings[i].enabled=YES;
  }
  unsigned axes=0; auto *mapping=PADGetKeyAxisBindings(0,&axes);
  for (int i=0;i<PAD_AXIS_COUNT;++i) {
    int sc=-1; if(mapping && axes==PAD_AXIS_COUNT) for(unsigned j=0;j<axes;++j) if(mapping[j].padAxis==(PADAxis)(PAD_AXIS_LEFT_X_POS+i)) sc=mapping[j].scancode;
    self.keyboardAxes[i].title=(self.keyboardCaptureKind==1 && self.keyboardCaptureIndex==i) ? @"Press…" : [self keyName:sc];
    self.keyboardAxes[i].enabled=YES;
  }
}
- (void)captureKeyboard:(NSButton *)sender {
  [self cancelCapture];
  self.keyboardCaptureKind=sender.tag>=100 ? 1 : 0;
  self.keyboardCaptureIndex=sender.tag>=100 ? sender.tag-100 : sender.tag;
  self.status.stringValue=@"Press a keyboard key. Controller input will not be captured.";
  [self refreshKeyboardLabels];
}
- (void)clearKeyboard:(NSButton *)sender {
  if(sender.tag>=100) PADSetKeyAxisBinding(0,{PAD_KEY_INVALID,(PADAxis)(PAD_AXIS_LEFT_X_POS+sender.tag-100),0});
  else PADSetKeyButtonBinding(0,{PAD_KEY_INVALID,KPButtons[sender.tag]});
  self.keyboardCaptureKind=-1; self.keyboardCaptureIndex=-1; [self refreshKeyboardLabels];
  self.status.stringValue=@"Keyboard binding cleared. Changes are saved by Aurora when KartPad exits.";
}
- (SDL_Scancode)scancodeForPhysicalKeyCode:(NSUInteger)keyCode {
  return KPMacPhysicalScancode((unsigned short)keyCode,
                               KBGetLayoutType(LMGetKbdType()) == kKeyboardISO);
}
- (void)resetKeyboard:(id)sender {
  (void)sender; PADClearKeyBindings(0); PADSetKeyboardActive(0,TRUE);
  self.keyboardCaptureKind=-1; self.keyboardCaptureIndex=-1; [self refreshKeyboardLabels];
  self.status.stringValue=@"Keyboard defaults restored. Changes are saved by Aurora when KartPad exits.";
}
- (void)handleKeyboardEvent:(NSEvent *)event {
  if(self.keyboardCaptureKind<0 || event.type!=NSEventTypeKeyDown || event.isARepeat) return;
  // Escape cancels before the local monitor can consume it as a binding.
  if (event.keyCode == kVK_Escape) { [self cancel:nil]; return; }
  int sc = KPMacPhysicalScancode(event.keyCode, KBGetLayoutType(LMGetKbdType()) == kKeyboardISO);
  if(sc<=SDL_SCANCODE_UNKNOWN) return;
  if(self.keyboardCaptureKind==0) PADSetKeyButtonBinding(0,{sc,KPButtons[self.keyboardCaptureIndex]});
  else PADSetKeyAxisBinding(0,{sc,(PADAxis)(PAD_AXIS_LEFT_X_POS+self.keyboardCaptureIndex),0});
  PADSetKeyboardActive(0,TRUE); self.keyboardCaptureKind=-1; self.keyboardCaptureIndex=-1;
  self.status.stringValue=@"Keyboard binding updated. Changes are saved by Aurora when KartPad exits.";
  [self refreshKeyboardLabels];
}
- (void)remap:(NSButton *)sender {
  if([self keyboardSelected]) { [self captureKeyboard:sender]; return; }
  if ([self port] < 0) { self.status.stringValue=@"Assign this controller to a player before editing mappings."; return; }
  self.capture = sender.tag % 12; self.captureAlternate = sender.tag >= 12; self.armed = NO;
  self.status.stringValue = [NSString stringWithFormat:@"Release all buttons and triggers, then press a button or pull a trigger for %@.", KPActions()[self.capture]];
}
- (void)clear:(NSButton *)sender {
  if([self keyboardSelected]) { [self clearKeyboard:sender]; return; }
  int port=[self port]; if(port<0)return;
  PADSetAltButtonMapping(port,{PAD_NATIVE_BUTTON_INVALID,KPButtons[sender.tag]});
  self.capture=sender.tag; self.captureAlternate=NO; [self bind:PAD_NATIVE_BUTTON_INVALID];
}
- (void)cancel:(id)sender { (void)sender; [self cancelCapture]; self.status.stringValue=@"Remapping cancelled."; }
- (void)reset:(id)sender {
  (void)sender; int port=[self port]; if(port<0)return;
  PADRestoreDefaultMapping(port);
  [self remember]; self.capture=-1;
  self.status.stringValue=@"Default buttons restored. Analogue settings are preserved.";
}
- (void)changeZone:(NSSlider *)slider {
  int port=[self port]; if(port<0)return;
  auto *zones=PADGetDeadZones(port); if(!zones)return;
  int value=(int)std::lround(slider.doubleValue*32767);
  zones->useDeadzones=true;
  if(slider.tag==0) zones->stickDeadZone=value;
  if(slider.tag==1) zones->substickDeadZone=value;
  if(slider.tag==2) zones->leftTriggerActivationZone=zones->rightTriggerActivationZone=value;
  [self remember];
  self.status.stringValue=[NSString stringWithFormat:@"%@ set to %.0f%%. Save Profile to keep your changes.",
    @[@"Steering dead zone",@"Right stick dead zone",@"Trigger threshold"][slider.tag],slider.doubleValue*100];
}
- (void)save:(id)sender {
  (void)sender;
  if (self.profileReadFailed) { self.status.stringValue=@"The existing profiles file is invalid. Restore or rename ControllerProfiles.json before saving; it has been preserved."; return; }
  NSError *error=nil;
  NSData *data=[NSJSONSerialization dataWithJSONObject:@{@"version":@1,@"devices":self.profiles}
    options:NSJSONWritingPrettyPrinted error:&error];
  if (!data || ![data writeToURL:[self profileURL] options:NSDataWritingAtomic error:&error]) {
    self.status.stringValue=@"Could not save controller profiles. Check that KartPad’s Application Support folder is writable.";
    AppendSessionLine(@"controllerProfiles=save-failed"); return;
  }
  self.dirty=NO; self.status.stringValue=@"Controller profiles saved.";
  AppendSessionLine(@"controllerProfiles=saved-v1");
}
- (void)applyProfile:(NSDictionary *)profile port:(int)port {
  if (![profile isKindOfClass:NSDictionary.class]) return;
  NSArray *buttons=profile[@"buttons"];
  if (![buttons isKindOfClass:NSArray.class] || buttons.count!=12) return;
  for (id value in buttons) if (![value isKindOfClass:NSNumber.class] ||
    !kartpad::binding::valid([value unsignedIntValue])) return;
  unsigned count=0; PADGetButtonMappings(port,&count); if(count!=12)return;
  for(int i=0;i<12;++i) {
    PADSetButtonMapping(port,{[buttons[i] unsignedIntValue],KPButtons[i]});
    NSArray *alternates=profile[@"alternates"];
    uint32_t alt=PAD_NATIVE_BUTTON_INVALID;
    if([alternates isKindOfClass:NSArray.class] && alternates.count==12 &&
       [alternates[i] isKindOfClass:NSNumber.class] && kartpad::binding::valid([alternates[i] unsignedIntValue]))
      alt=[alternates[i] unsignedIntValue];
    PADSetAltButtonMapping(port,{alt,KPButtons[i]});
  }
  auto *zones=PADGetDeadZones(port);
  if(zones) {
    zones->useDeadzones=[profile[@"useDeadzones"] isKindOfClass:NSNumber.class] ? [profile[@"useDeadzones"] boolValue] : true;
    if([profile[@"emulateTriggers"] isKindOfClass:NSNumber.class]) zones->emulateTriggers=[profile[@"emulateTriggers"] boolValue];
    if([profile[@"stick"] isKindOfClass:NSNumber.class]) zones->stickDeadZone=std::clamp([profile[@"stick"] intValue],0,16383);
    if([profile[@"substick"] isKindOfClass:NSNumber.class]) zones->substickDeadZone=std::clamp([profile[@"substick"] intValue],0,16383);
    if([profile[@"trigger"] isKindOfClass:NSNumber.class]) zones->leftTriggerActivationZone=zones->rightTriggerActivationZone=std::clamp([profile[@"trigger"] intValue],0,32766);
    if([profile[@"rightTrigger"] isKindOfClass:NSNumber.class]) zones->rightTriggerActivationZone=std::clamp([profile[@"rightTrigger"] intValue],0,32766);
  }
}
- (void)tick {
  NSMutableArray *ids=[NSMutableArray array];
  int rawCount=0; SDL_JoystickID *raw=SDL_GetJoysticks(&rawCount);
  for(int i=0;i<rawCount;++i) [ids addObject:@(raw[i])]; SDL_free(raw);
  for (NSNumber *idNumber in self.applied.allKeys) if(![ids containsObject:idNumber]) [self.applied removeObjectForKey:idNumber];
  for(int port=0;port<4;++port) {
    int index=PADGetIndexForPort(port); if(index<0)continue;
    SDL_Gamepad *pad=PADGetSDLGamepadForIndex(index); if(!pad)continue;
    NSNumber *identifier=@(SDL_GetGamepadID(pad));
    NSString *stamp=[NSString stringWithFormat:@"%@:%d",KPProfileKey(pad),port];
    if(![self.applied[identifier] isEqual:stamp]) {
      [self applyProfile:self.profiles[KPProfileKey(pad)] port:port];
      self.applied[identifier]=stamp;
      AppendSessionLine([NSString stringWithFormat:@"controllerReady=player-%d; profile=%@",port+1,
        self.profiles[KPProfileKey(pad)] ? @"custom" : @"existing/default"]);
    }
  }
  if(!self.panel.visible)return;
  SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, NSApp.active ? "1" : "0");
  [ids insertObject:@"keyboard" atIndex:0];
  NSArray *old=[self.devices.itemArray valueForKey:@"representedObject"];
  if(![old isEqual:ids]) {
    [self.devices removeAllItems];
    [self.devices addItemWithTitle:@"Keyboard"];
    self.devices.lastItem.representedObject=@"keyboard";
    for(NSNumber *number in ids) {
      if([number isKindOfClass:NSString.class]) continue;
      const char *name=SDL_GetJoystickNameForID(number.unsignedIntValue);
      if(name && strcmp(name,"Controller")==0 && SDL_GetGamepadTypeForID(number.unsignedIntValue)==SDL_GAMEPAD_TYPE_XBOXONE)name="Xbox One Controller";
      [self.devices addItemWithTitle:[NSString stringWithFormat:@"%s — Connected%@",name ?: "Unknown controller",
        SDL_IsGamepad(number.unsignedIntValue) ? @"" : @" (raw joystick)"]];
      self.devices.lastItem.representedObject=number;
    }
    if(self.selectedID!=(SDL_JoystickID)-1 && ![ids containsObject:@(self.selectedID)]) { self.selectedID=(SDL_JoystickID)-1; self.capture=-1; }
    for(NSMenuItem *item in self.devices.itemArray) if(([item.representedObject isEqual:@"keyboard"] && self.keyboardSelected) || [item.representedObject unsignedIntValue]==self.selectedID) [self.devices selectItem:item];
  }
  if(self.keyboardSelected) { [self refreshKeyboardLabels]; self.profileLabel.stringValue=@"Keyboard · built-in keyboard bindings"; self.player.enabled=NO; self.mappingHint.hidden=YES; self.status.hidden=YES; for(NSView *view in self.controllerOnlyViews) view.hidden=YES; for(NSView *view in self.keyboardOnlyViews) view.hidden=NO; for(NSButton *button in self.bindings) button.enabled=YES; return; }
  self.mappingHint.hidden=NO; self.status.hidden=NO; self.status.frame=NSMakeRect(20,72,740,70); self.status.maximumNumberOfLines=3; for(NSView *view in self.controllerOnlyViews) view.hidden=NO; for(NSView *view in self.keyboardOnlyViews) view.hidden=YES;
  for(NSButton *button in self.altBindings) button.hidden=NO;
  SDL_Gamepad *pad=[self selectedPad]; int port=[self port];
  [self.player selectItemAtIndex:port+1]; self.player.enabled=pad!=nullptr;
  self.profileLabel.stringValue=pad ? [NSString stringWithFormat:@"%@ · %@ · %@",
    [NSString stringWithUTF8String:SDL_GetGamepadStringForType(SDL_GetGamepadType(pad)) ?: "generic"],
    port<0 ? @"Unassigned" : [NSString stringWithFormat:@"Player %d",port+1],
    self.profiles[KPProfileKey(pad)] ? @"Custom profile" : @"Existing / default profile"] :
    (ids.count ? @"SDL sees a raw joystick. Open Advanced → Controller Compatibility Tools to create an SDL mapping." : @"No controllers detected by SDL. Connect a controller and this list will update automatically.");
  bool any=false; int pressed=-1;
  for(int i=0;i<15;++i) {
    bool down=pad && SDL_GetGamepadButton(pad,(SDL_GamepadButton)i);
    any|=down; if(down)pressed=i;
    self.lights[i].stringValue=KPButtonLabel(pad,i);
    self.lights[i].backgroundColor=down ? NSColor.controlAccentColor : NSColor.controlBackgroundColor;
    self.lights[i].textColor=down ? NSColor.whiteColor : NSColor.labelColor;
  }
  // Capture also supports paddles and other buttons not in the compact tester.
  for(int i=15;pad && i<SDL_GAMEPAD_BUTTON_COUNT;++i) if(SDL_GetGamepadButton(pad,(SDL_GamepadButton)i)) {any=true;pressed=i;}
  NSMutableString *rawText=[NSMutableString stringWithFormat:@"SDL button: %@  axes:",pressed<0?@"none":[@(pressed) stringValue]];
  for(int i=0;i<6;++i) {
    int value=pad ? SDL_GetGamepadAxis(pad,(SDL_GamepadAxis)i) : 0;
    self.axes[i].doubleValue=value; [rawText appendFormat:@" %d:%d",i,value];
  }
  // SDL triggers are axes, not gamepad button events. Use the same threshold
  // as the runtime, but require a full release before arming capture.
  auto *captureZones=port>=0?PADGetDeadZones(port):nullptr;
  bool triggersReleased=true;
  for(int t=0;pad && t<2;++t) {
    int threshold=captureZones ? (t==0?captureZones->leftTriggerActivationZone:captureZones->rightTriggerActivationZone) : 16384;
    int axis=SDL_GetGamepadAxis(pad,t==0?SDL_GAMEPAD_AXIS_LEFT_TRIGGER:SDL_GAMEPAD_AXIS_RIGHT_TRIGGER);
    if(axis > 2000)triggersReleased=false;
    if(axis >= std::max(2001,threshold)) {any=true;pressed=(int)(t==0?kartpad::binding::LeftTrigger:kartpad::binding::RightTrigger);}
  }
  self.feedback.stringValue=rawText;
  if(self.capture>=0) { if(!any && triggersReleased)self.armed=YES; if(any && self.armed) { self.armed=NO; [self bind:pressed]; } }
  unsigned count=0; auto *bindings=port>=0?PADGetButtonMappings(port,&count):nullptr;
  unsigned altCount=0;auto *alt=port>=0?PADGetAltButtonMappings(port,&altCount):nullptr;
  for(int i=0;i<12;++i) {
    uint32_t value=PAD_NATIVE_BUTTON_INVALID;
    for(unsigned j=0;j<count;++j)if(bindings[j].padButton==KPButtons[i])value=bindings[j].nativeButton;
    self.bindings[i].title=self.capture==i && !self.captureAlternate ? @"Press…" :
      (value==PAD_NATIVE_BUTTON_INVALID && (i==6||i==7) ? (i==6?@"LT (analogue)":@"RT (analogue)") : KPButtonLabel(pad,(int)value));
    self.bindings[i].enabled=port>=0;
    uint32_t alternative=PAD_NATIVE_BUTTON_INVALID;
    for(unsigned j=0;j<altCount;++j)if(alt[j].padButton==KPButtons[i])alternative=alt[j].nativeButton;
    self.altBindings[i].title=self.capture==i && self.captureAlternate ? @"Press…" :
      (alternative==PAD_NATIVE_BUTTON_INVALID ? @"+ Add" : KPButtonLabel(pad,(int)alternative));
    self.altBindings[i].enabled=port>=0;
  }
  auto *zones=port>=0?PADGetDeadZones(port):nullptr;
  for(int i=0;i<3;++i) {
    self.zones[i].enabled=zones!=nullptr;
    if(zones)self.zones[i].doubleValue=(i==0?zones->stickDeadZone:i==1?zones->substickDeadZone:zones->leftTriggerActivationZone)/32767.0;
  }
}
@end
static KPControllerSettings *KPControllers() {
  static KPControllerSettings *controller;
  if(!controller)controller=[KPControllerSettings new];
  return controller;
}
extern "C" void KartPadControllersTick() { @autoreleasepool { [KPControllers() tick]; } }
extern "C" bool KartPadControllersVisible() { return KPControllers().panel.visible; }

static NSString *KPControllerDiagnostics() {
  NSMutableString *text = [NSMutableString stringWithFormat:@"Controller subsystem: %@\nDetected controllers: %u\n",
    (SDL_WasInit(SDL_INIT_GAMEPAD) & SDL_INIT_GAMEPAD) ? @"initialized" : @"not initialized", PADCount()];
  for (unsigned i=0;i<PADCount();++i) {
    SDL_Gamepad *pad=PADGetSDLGamepadForIndex(i); if(!pad)continue;
    int port=-1;
    for(int p=0;p<4;++p)if(PADGetIndexForPort(p)==(int)i)port=p;
    [text appendFormat:@"Controller %u: %s; type=%s; assignment=%@; profile=%@\n", i,
      SDL_GetGamepadName(pad) ?: "Unknown", SDL_GetGamepadStringForType(SDL_GetGamepadType(pad)) ?: "generic",
      port<0?@"Unassigned":[NSString stringWithFormat:@"Player %d",port+1],
      KPControllers().profiles[KPProfileKey(pad)] ? @"custom" : @"existing/default"];
  }
  return text;
}
