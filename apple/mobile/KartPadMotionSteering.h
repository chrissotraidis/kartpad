#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/* Converts a calibrated device angle into a normalized Classic-stick value.
 * The dead zone is removed continuously, then full lock is clamped. */
float KartPadMotionSteeringValue(double angle, double center,
                                 float sensitivity, BOOL inverted) noexcept;

enum class KartPadShakeAction {
  None,
  Rearm,
  Disarm,
  Trigger,
};

/* Classifies one gravity-removed acceleration sample. A trigger is edge-based:
 * another impulse is ignored until motion settles below the rearm threshold. */
KartPadShakeAction KartPadShakeActionForSample(
    double accelerationMagnitude, double timestamp, bool armed,
    double lastTriggerTimestamp) noexcept;

@interface KartPadMotionSteering : NSObject

+ (instancetype)sharedSteering;

@property(nonatomic, assign, getter=isEnabled) BOOL enabled;
@property(nonatomic, assign, getter=isInverted) BOOL inverted;
@property(nonatomic, assign) float sensitivity;
@property(nonatomic, assign, getter=isShakeTricksEnabled)
    BOOL shakeTricksEnabled;
/** Shake still presses D-pad Up while a controller is connected (clip-on controllers). */
@property(nonatomic, assign) BOOL shakeWithController;
@property(nonatomic, readonly, getter=isSensorAvailable) BOOL sensorAvailable;
@property(nonatomic, readonly) float currentSteering;

- (BOOL)consumeShakeTrick;
- (void)start;
- (void)stop;
- (void)recenter;

@end

NS_ASSUME_NONNULL_END
