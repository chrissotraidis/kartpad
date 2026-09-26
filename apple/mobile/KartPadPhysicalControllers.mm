#import "KartPadPhysicalControllers.h"

#import "SunPadControllerSlots.h"
#import "SunPadDiagnostics.h"
#import "SunPadInputMixer.h"

#import <GameController/GameController.h>
#import <TargetConditionals.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <mutex>
#include <vector>

namespace {

uintptr_t ControllerInstanceID(GCController *controller) {
  return reinterpret_cast<uintptr_t>((__bridge void *)controller);
}

GCControllerPlayerIndex PlayerIndexForSlot(const std::size_t slot) {
  switch (slot) {
    case 0: return GCControllerPlayerIndex1;
    case 1: return GCControllerPlayerIndex2;
    case 2: return GCControllerPlayerIndex3;
    case 3: return GCControllerPlayerIndex4;
    default: return GCControllerPlayerIndexUnset;
  }
}

SunPadPhysicalControllerButton PressedFaceButtons(GCExtendedGamepad *pad) {
  uint8_t buttons = 0;
  if (pad.buttonA.isPressed) buttons |= SunPadPhysicalControllerButtonA;
  if (pad.buttonB.isPressed) buttons |= SunPadPhysicalControllerButtonB;
  if (pad.buttonX.isPressed) buttons |= SunPadPhysicalControllerButtonX;
  if (pad.buttonY.isPressed) buttons |= SunPadPhysicalControllerButtonY;
  if (pad.leftShoulder.isPressed) {
    buttons |= SunPadPhysicalControllerButtonLeftShoulder;
  }
  return static_cast<SunPadPhysicalControllerButton>(buttons);
}

KartPadPhysicalControllerSample SampleFromGamepad(GCExtendedGamepad *gamepad) {
  KartPadPhysicalControllerSample sample;
  sample.faceButtons = PressedFaceButtons(gamepad);
  sample.menu = gamepad.buttonMenu.isPressed;
  sample.dpadUp = gamepad.dpad.up.isPressed;
  sample.dpadDown = gamepad.dpad.down.isPressed;
  sample.dpadLeft = gamepad.dpad.left.isPressed;
  sample.dpadRight = gamepad.dpad.right.isPressed;
  sample.rightShoulder = gamepad.rightShoulder.isPressed;
  sample.leftX = gamepad.leftThumbstick.xAxis.value;
  sample.leftY = gamepad.leftThumbstick.yAxis.value;
  sample.rightX = gamepad.rightThumbstick.xAxis.value;
  sample.rightY = gamepad.rightThumbstick.yAxis.value;
  sample.leftTrigger = gamepad.leftTrigger.value;
  sample.rightTrigger = gamepad.rightTrigger.value;
  return sample;
}

// A single Joy-Con (and other small controllers) has no extended profile. Its
// micro profile provides the stick as a direction pad plus A, X and Menu; any
// other buttons appear only in the physical profile under standard names.
BOOL UsesMicroProfile(GCController *controller) {
#if TARGET_OS_TV
  (void)controller;
  return NO;  // The Siri Remote is also a micro gamepad and has its own input path.
#else
  return controller.extendedGamepad == nil && controller.microGamepad != nil;
#endif
}

BOOL IsSupportedController(GCController *controller) {
  return controller.extendedGamepad != nil || UsesMicroProfile(controller);
}

BOOL ProfileButtonPressed(GCPhysicalInputProfile *profile, NSString *name) {
  return profile.buttons[name].isPressed;
}

KartPadPhysicalControllerSample SampleFromMicroGamepad(GCController *controller) {
  GCMicroGamepad *micro = controller.microGamepad;
  GCPhysicalInputProfile *profile = controller.physicalInputProfile;
  KartPadPhysicalControllerSample sample;
  uint8_t buttons = 0;
  if (micro.buttonA.isPressed) buttons |= SunPadPhysicalControllerButtonA;
  if (micro.buttonX.isPressed || ProfileButtonPressed(profile, GCInputButtonB)) {
    buttons |= SunPadPhysicalControllerButtonB;
  }
  if (ProfileButtonPressed(profile, GCInputLeftShoulder) ||
      ProfileButtonPressed(profile, GCInputRightShoulder) ||
      ProfileButtonPressed(profile, GCInputButtonY)) {
    buttons |= SunPadPhysicalControllerButtonLeftShoulder;
  }
  sample.faceButtons = static_cast<SunPadPhysicalControllerButton>(buttons);
  sample.menu = micro.buttonMenu.isPressed ||
      ProfileButtonPressed(profile, GCInputButtonMenu) ||
      ProfileButtonPressed(profile, GCInputButtonOptions);
  sample.dpadUp = micro.dpad.up.isPressed;
  sample.dpadDown = micro.dpad.down.isPressed;
  sample.dpadLeft = micro.dpad.left.isPressed;
  sample.dpadRight = micro.dpad.right.isPressed;
  sample.leftX = micro.dpad.xAxis.value;
  sample.leftY = micro.dpad.yAxis.value;
  return sample;
}

KartPadPhysicalControllerSample SampleFromController(GCController *controller) {
  GCExtendedGamepad *gamepad = controller.extendedGamepad;
  return gamepad != nil ? SampleFromGamepad(gamepad)
                        : SampleFromMicroGamepad(controller);
}

void ClearControllerHandlers(GCController *controller) {
  controller.extendedGamepad.valueChangedHandler = nil;
  if (UsesMicroProfile(controller)) {
    controller.physicalInputProfile.valueDidChangeHandler = nil;
  }
}

}  // namespace

SunPadInputState KartPadAdaptPhysicalControllerSample(
    const KartPadPhysicalControllerSample& sample,
    const SunPadControllerButtonMapping mapping) noexcept {
  SunPadInputState state{};
  state.connected = 1;
  uint16_t physical = sample.faceButtons;
  if (sample.dpadUp) physical |= SunPadPhysicalControllerButtonDpadUp;
  if (sample.dpadDown) physical |= SunPadPhysicalControllerButtonDpadDown;
  if (sample.dpadLeft) physical |= SunPadPhysicalControllerButtonDpadLeft;
  if (sample.dpadRight) physical |= SunPadPhysicalControllerButtonDpadRight;
  if (sample.rightShoulder) physical |= SunPadPhysicalControllerButtonRightShoulder;
  if (std::lround(std::clamp(sample.leftTrigger, 0.0f, 1.0f) * 255.0f) > 30) physical |= SunPadPhysicalControllerButtonLeftTrigger;
  if (std::lround(std::clamp(sample.rightTrigger, 0.0f, 1.0f) * 255.0f) > 30) physical |= SunPadPhysicalControllerButtonRightTrigger;
  state.buttons |= SunPadApplyControllerButtonMapping(mapping, (SunPadPhysicalControllerButton)physical);
  if (sample.menu) state.buttons |= SunPadButtonStart;
  state.stickX = static_cast<int8_t>(std::lround(
      std::clamp(sample.leftX, -1.0f, 1.0f) * 127.0f));
  state.stickY = static_cast<int8_t>(std::lround(
      std::clamp(sample.leftY, -1.0f, 1.0f) * 127.0f));
  state.cStickX = static_cast<int8_t>(std::lround(
      std::clamp(sample.rightX, -1.0f, 1.0f) * 127.0f));
  state.cStickY = static_cast<int8_t>(std::lround(
      std::clamp(sample.rightY, -1.0f, 1.0f) * 127.0f));
  state.triggerL = static_cast<uint8_t>(std::lround(
      std::clamp(sample.leftTrigger, 0.0f, 1.0f) * 255.0f));
  const uint8_t physicalTriggerR = static_cast<uint8_t>(std::lround(
      std::clamp(sample.rightTrigger, 0.0f, 1.0f) * 255.0f));
  state.triggerR = SunPadControllerRightTriggerPressure(
      physicalTriggerR, sample.rightShoulder);

  return state;
}

@implementation KartPadPhysicalControllers {
  SunPadControllerSlots _slots;
  NSMutableDictionary<NSNumber *, GCController *> *_configuredControllers;
  std::mutex _stateMutex;
  std::array<SunPadInputState, SunPadControllerSlots::kMaxPlayers> _states;
  std::array<uint16_t, SunPadControllerSlots::kMaxPlayers> _latchedButtons;
  BOOL _started;
}

+ (instancetype)sharedControllers {
  static KartPadPhysicalControllers *controllers = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    controllers = [[KartPadPhysicalControllers alloc] init];
  });
  return controllers;
}

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    _configuredControllers = [NSMutableDictionary dictionary];
    _states = {};
    _latchedButtons = {};
  }
  return self;
}

- (void)start {
  if (_started) return;
  _started = YES;
  NSNotificationCenter *notifications = NSNotificationCenter.defaultCenter;
  [notifications addObserver:self
                    selector:@selector(controllerConnectionChanged:)
                        name:GCControllerDidConnectNotification
                      object:nil];
  [notifications addObserver:self
                    selector:@selector(controllerConnectionChanged:)
                        name:GCControllerDidDisconnectNotification
                      object:nil];
  [self reconcileControllers];
}

- (void)stop {
  if (!_started) return;
  _started = NO;
  [NSNotificationCenter.defaultCenter removeObserver:self];
  for (GCController *controller in _configuredControllers.allValues) {
    ClearControllerHandlers(controller);
    controller.playerIndex = GCControllerPlayerIndexUnset;
  }
  [_configuredControllers removeAllObjects];
  _slots = {};
  {
    std::scoped_lock lock(_stateMutex);
    _states = {};
    _latchedButtons = {};
  }
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:NO];
}

- (void)controllerConnectionChanged:(NSNotification *)notification {
  (void)notification;
  [self reconcileControllers];
}

- (void)publishController:(GCController *)controller {
  const int slot = _slots.SlotFor(ControllerInstanceID(controller));
  if (slot < 0 || slot >= static_cast<int>(SunPadControllerSlots::kMaxPlayers)) {
    return;
  }
  const SunPadInputState state = KartPadAdaptPhysicalControllerSample(
      SampleFromController(controller), [SunPadControllerMappingStore mapping]);
  {
    std::scoped_lock lock(_stateMutex);
    const std::size_t index = static_cast<std::size_t>(slot);
    _latchedButtons[index] |= state.buttons & ~_states[index].buttons;
    _states[index] = state;
  }
  if (slot == 0) {
    [[SunPadInputMixer sharedMixer] setInputState:state fromTouch:NO];
  }
}

- (void)configureController:(GCController *)controller
                       slot:(const std::size_t)slot {
  if (!IsSupportedController(controller)) return;
  controller.handlerQueue = dispatch_get_main_queue();
  __weak KartPadPhysicalControllers *weakSelf = self;
  __weak GCController *weakController = controller;
  // Sample inside the event callback. Deferring the read again can turn a
  // quick press/release into two released samples before the game polls.
  void (^publish)(void) = ^{
    KartPadPhysicalControllers *strongSelf = weakSelf;
    GCController *strongController = weakController;
    if (strongSelf != nil && strongController != nil) {
      [strongSelf publishController:strongController];
    }
  };
  if (GCExtendedGamepad *gamepad = controller.extendedGamepad) {
    gamepad.valueChangedHandler = ^(GCExtendedGamepad *, GCControllerElement *) {
      publish();
    };
  } else {
    controller.physicalInputProfile.valueDidChangeHandler =
        ^(GCPhysicalInputProfile *, GCControllerElement *) {
          publish();
        };
  }
  controller.playerIndex = PlayerIndexForSlot(slot);
  [self publishController:controller];
}

- (void)reconcileControllers {
  [self reconcileControllerList:GCController.controllers];
}

- (void)reconcileControllerList:(NSArray<GCController *> *)controllers {
  std::vector<uintptr_t> instances;
  for (GCController *controller in controllers) {
    if (IsSupportedController(controller)) {
      instances.push_back(ControllerInstanceID(controller));
    }
  }

  const SunPadControllerReconcileResult result = _slots.Reconcile(instances);
  for (const SunPadControllerSlotChange& change : result.removed) {
    NSNumber *key = @(change.instance);
    GCController *controller = _configuredControllers[key];
    ClearControllerHandlers(controller);
    controller.playerIndex = GCControllerPlayerIndexUnset;
    [_configuredControllers removeObjectForKey:key];
    {
      std::scoped_lock lock(_stateMutex);
      _states[change.slot] = {};
      _latchedButtons[change.slot] = 0;
    }
    if (change.slot == 0) {
      [[SunPadInputMixer sharedMixer] clearInputFromTouch:NO];
    }
    SunPadLog(@"controller removed slot=%lu", (unsigned long)change.slot + 1);
  }

  for (GCController *controller in controllers) {
    if (!IsSupportedController(controller)) continue;
    const uintptr_t instance = ControllerInstanceID(controller);
    const int slot = _slots.SlotFor(instance);
    if (slot < 0) continue;
    NSNumber *key = @(instance);
    if (_configuredControllers[key] != controller) {
      _configuredControllers[key] = controller;
      [self configureController:controller slot:static_cast<std::size_t>(slot)];
      SunPadLog(@"controller assigned slot=%d vendor=%@", slot + 1,
                controller.vendorName != nil ? controller.vendorName : @"unknown");
    }
  }
}

- (BOOL)consumePlayer:(NSUInteger)player state:(SunPadInputState *)state {
  if (state == nullptr || player >= SunPadControllerSlots::kMaxPlayers) {
    return NO;
  }
  std::scoped_lock lock(_stateMutex);
  *state = _states[player];
  state->buttons |= _latchedButtons[player];
  _latchedButtons[player] = 0;
  return state->connected != 0;
}

- (BOOL)isPlayerConnected:(NSUInteger)player {
  if (player >= SunPadControllerSlots::kMaxPlayers) return NO;
  std::scoped_lock lock(_stateMutex);
  return _states[player].connected != 0;
}

- (NSArray<NSString *> *)playerDescriptions {
  NSAssert(NSThread.isMainThread, @"Controller descriptions require the main thread");
  NSMutableArray<NSString *> *players = [NSMutableArray array];
  for (std::size_t slot = 0; slot < SunPadControllerSlots::kMaxPlayers; ++slot) {
    GCController *controller = _configuredControllers[@(_slots.InstanceAt(slot))];
    NSString *name = controller.vendorName ?: @"Controller";
    [players addObject:[NSString stringWithFormat:@"Player %lu: %@",
        (unsigned long)slot + 1, controller ? name : @"Not connected"]];
  }
  return players;
}

- (NSUInteger)connectedControllerCount {
  std::scoped_lock lock(_stateMutex);
  NSUInteger count = 0;
  for (const SunPadInputState& state : _states) {
    if (state.connected != 0) ++count;
  }
  return count;
}

@end
