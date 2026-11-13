#pragma once

#import <Foundation/Foundation.h>

#import "SunPadControllerMapping.h"
#import "SunPadInputState.h"

NS_ASSUME_NONNULL_BEGIN

// Posted on the main thread after a reconcile changes which controller holds a
// player slot.
extern NSNotificationName const KartPadPhysicalControllersDidChangeNotification;

struct KartPadPhysicalControllerSample {
  SunPadPhysicalControllerButton faceButtons =
      static_cast<SunPadPhysicalControllerButton>(0);
  bool menu = false;
  bool dpadUp = false;
  bool dpadDown = false;
  bool dpadLeft = false;
  bool dpadRight = false;
  bool rightShoulder = false;
  float leftX = 0.0f;
  float leftY = 0.0f;
  float rightX = 0.0f;
  float rightY = 0.0f;
  float leftTrigger = 0.0f;
  float rightTrigger = 0.0f;
};

SunPadInputState KartPadAdaptPhysicalControllerSample(
    const KartPadPhysicalControllerSample& sample,
    SunPadControllerButtonMapping mapping) noexcept;

@interface KartPadPhysicalControllers : NSObject

+ (instancetype)sharedControllers;

- (void)start;
- (void)stop;
- (void)reconcileControllers;
- (BOOL)consumePlayer:(NSUInteger)player state:(SunPadInputState *)state;
- (BOOL)isPlayerConnected:(NSUInteger)player;
- (NSArray<NSString *> *)playerDescriptions;
- (NSUInteger)connectedControllerCount;
// Whether player 1, whom the touch controls share, has a controller. A pad in
// a later slot does not count. Main thread.
- (BOOL)touchPlayerHasController;

@end

NS_ASSUME_NONNULL_END
