#import "KartPadPhysicalControllers.h"

#import "SunPadControllerSlots.h"
#import "SunPadDiagnostics.h"
#import "SunPadInputMixer.h"

#import <TargetConditionals.h>
#if TARGET_OS_TV
#import <CoreHaptics/CoreHaptics.h>
#endif
#import <GameController/GameController.h>

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

}  // namespace

SunPadInputState KartPadAdaptPhysicalControllerSample(
    const KartPadPhysicalControllerSample& sample,
    const SunPadControllerButtonMapping mapping) noexcept {
  SunPadInputState state{};
  state.connected = 1;
  state.buttons |= SunPadApplyControllerButtonMapping(mapping, sample.faceButtons);
  if (sample.menu) state.buttons |= SunPadButtonStart;
  if (sample.dpadUp) state.buttons |= SunPadButtonDpadUp;
  if (sample.dpadDown) state.buttons |= SunPadButtonDpadDown;
  if (sample.dpadLeft) state.buttons |= SunPadButtonDpadLeft;
  if (sample.dpadRight) state.buttons |= SunPadButtonDpadRight;
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
  if (state.triggerL > 30) state.buttons |= SunPadButtonL;
  if (physicalTriggerR > 30) state.buttons |= SunPadButtonR;
  return state;
}

@implementation KartPadPhysicalControllers {
  SunPadControllerSlots _slots;
  NSMutableDictionary<NSNumber *, GCController *> *_configuredControllers;
#if TARGET_OS_TV
  NSMutableDictionary<NSNumber *, CHHapticEngine *> *_hapticEngines;
  NSMutableDictionary<NSNumber *, id<CHHapticPatternPlayer>> *_rumblePlayers;
#endif
  std::mutex _stateMutex;
  std::array<SunPadInputState, SunPadControllerSlots::kMaxPlayers> _states;
  std::array<uint16_t, SunPadControllerSlots::kMaxPlayers> _latchedButtons;
#if TARGET_OS_TV
  std::array<BOOL, SunPadControllerSlots::kMaxPlayers> _rumbleActive;
#endif
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
#if TARGET_OS_TV
    _hapticEngines = [NSMutableDictionary dictionary];
    _rumblePlayers = [NSMutableDictionary dictionary];
#endif
    _states = {};
    _latchedButtons = {};
#if TARGET_OS_TV
    _rumbleActive = {};
#endif
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
    controller.extendedGamepad.valueChangedHandler = nil;
    controller.playerIndex = GCControllerPlayerIndexUnset;
  }
#if TARGET_OS_TV
  for (id<CHHapticPatternPlayer> player in _rumblePlayers.allValues) {
    [player stopAtTime:CHHapticTimeImmediate error:nil];
  }
#endif
  [_configuredControllers removeAllObjects];
#if TARGET_OS_TV
  [_hapticEngines removeAllObjects];
  [_rumblePlayers removeAllObjects];
#endif
  _slots = {};
#if TARGET_OS_TV
  _rumbleActive = {};
#endif
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

- (void)publishController:(GCController *)controller
                  gamepad:(GCExtendedGamepad *)gamepad {
  const int slot = _slots.SlotFor(ControllerInstanceID(controller));
  if (slot < 0 || slot >= static_cast<int>(SunPadControllerSlots::kMaxPlayers)) {
    return;
  }
  const SunPadInputState state = KartPadAdaptPhysicalControllerSample(
      SampleFromGamepad(gamepad), [SunPadControllerMappingStore mapping]);
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
  GCExtendedGamepad *gamepad = controller.extendedGamepad;
  if (gamepad == nil) return;
  __weak KartPadPhysicalControllers *weakSelf = self;
  __weak GCController *weakController = controller;
  gamepad.valueChangedHandler = ^(GCExtendedGamepad *pad,
                                  GCControllerElement *element) {
    (void)element;
    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadPhysicalControllers *strongSelf = weakSelf;
      GCController *strongController = weakController;
      if (strongSelf != nil && strongController != nil) {
        [strongSelf publishController:strongController gamepad:pad];
      }
    });
  };
  controller.playerIndex = PlayerIndexForSlot(slot);
  [self publishController:controller gamepad:gamepad];
}

- (void)reconcileControllers {
  NSArray<GCController *> *controllers = GCController.controllers;
  std::vector<uintptr_t> instances;
  for (GCController *controller in controllers) {
    if (controller.extendedGamepad != nil) {
      instances.push_back(ControllerInstanceID(controller));
    }
  }

  const SunPadControllerReconcileResult result = _slots.Reconcile(instances);
  for (const SunPadControllerSlotChange& change : result.removed) {
    NSNumber *key = @(change.instance);
    GCController *controller = _configuredControllers[key];
    controller.extendedGamepad.valueChangedHandler = nil;
    controller.playerIndex = GCControllerPlayerIndexUnset;
#if TARGET_OS_TV
    [_rumblePlayers[key] stopAtTime:CHHapticTimeImmediate error:nil];
#endif
    [_configuredControllers removeObjectForKey:key];
#if TARGET_OS_TV
    [_hapticEngines removeObjectForKey:key];
    [_rumblePlayers removeObjectForKey:key];
    _rumbleActive[change.slot] = NO;
#endif
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
    if (controller.extendedGamepad == nil) continue;
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

- (NSUInteger)connectedControllerCount {
  std::scoped_lock lock(_stateMutex);
  NSUInteger count = 0;
  for (const SunPadInputState& state : _states) {
    if (state.connected != 0) ++count;
  }
  return count;
}

- (BOOL)setRumbleForPlayer:(NSUInteger)player enabled:(BOOL)enabled {
#if TARGET_OS_TV
  __block BOOL handled = NO;
  void (^applyRumble)(void) = ^{
    if (!self->_started || player >= SunPadControllerSlots::kMaxPlayers) return;
    const uintptr_t instance = self->_slots.InstanceAt(player);
    if (instance == 0) return;
    GCController *controller = self->_configuredControllers[@(instance)];
    if (controller == nil || controller.haptics == nil) return;
    handled = YES;
    NSNumber *key = @(instance);
    if (enabled == self->_rumbleActive[player]) return;
    if (!enabled) {
      [self->_rumblePlayers[key] stopAtTime:CHHapticTimeImmediate error:nil];
      self->_rumbleActive[player] = NO;
      return;
    }

    NSError *error = nil;
    CHHapticEngine *engine = self->_hapticEngines[key];
    id<CHHapticPatternPlayer> playerObject = self->_rumblePlayers[key];
    if (engine != nil && playerObject != nil &&
        [engine startAndReturnError:&error] &&
        [playerObject startAtTime:CHHapticTimeImmediate error:&error]) {
      self->_rumbleActive[player] = YES;
      return;
    }
    [self->_rumblePlayers removeObjectForKey:key];
    [self->_hapticEngines removeObjectForKey:key];

    engine = [controller.haptics createEngineWithLocality:GCHapticsLocalityDefault];
    if (engine == nil || ![engine startAndReturnError:&error]) {
      SunPadLog(@"controller rumble unavailable for player=%lu: %@",
                static_cast<unsigned long>(player + 1),
                error.localizedDescription ?: @"no haptic engine");
      handled = NO;
      return;
    }
    engine.playsHapticsOnly = YES;
    NSArray<CHHapticEventParameter *> *parameters = @[
      [[CHHapticEventParameter alloc]
          initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0f],
      [[CHHapticEventParameter alloc]
          initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.1f],
    ];
    CHHapticEvent *event = [[CHHapticEvent alloc]
        initWithEventType:CHHapticEventTypeHapticContinuous
               parameters:parameters
             relativeTime:0.0
                 duration:GCHapticDurationInfinite];
    CHHapticPattern *pattern = [[CHHapticPattern alloc]
        initWithEvents:@[event] parameters:@[] error:&error];
    playerObject = pattern == nil
        ? nil : [engine createPlayerWithPattern:pattern error:&error];
    if (playerObject == nil ||
        ![playerObject startAtTime:CHHapticTimeImmediate error:&error]) {
      SunPadLog(@"controller rumble start failed for player=%lu: %@",
                static_cast<unsigned long>(player + 1),
                error.localizedDescription ?: @"unknown haptic error");
      handled = NO;
      return;
    }
    self->_hapticEngines[key] = engine;
    self->_rumblePlayers[key] = playerObject;
    self->_rumbleActive[player] = YES;
  };
  if (NSThread.isMainThread) {
    applyRumble();
  } else {
    dispatch_sync(dispatch_get_main_queue(), applyRumble);
  }
  return handled;
#else
  (void)player;
  (void)enabled;
  return NO;
#endif
}

@end

extern "C" bool KartPadMobileSetRumbleForPlayer(unsigned int player, bool enabled) {
  return [[KartPadPhysicalControllers sharedControllers]
      setRumbleForPlayer:player enabled:enabled ? YES : NO];
}
