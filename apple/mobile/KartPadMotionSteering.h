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
 * another impulse is ignored until motion settles below the rearm threshold.
 * triggerAcceleration is the Shake Sensitivity level's threshold in g. */
KartPadShakeAction KartPadShakeActionForSample(
    double accelerationMagnitude, double timestamp, bool armed,
    double lastTriggerTimestamp, double triggerAcceleration = 1.35) noexcept;

/* Shake Sensitivity levels, the same four as Android: Low, Standard, High,
 * Very High. Out-of-range levels are clamped. */
constexpr NSInteger KartPadShakeSensitivityLevels = 4;
double KartPadShakeTriggerAcceleration(NSInteger level) noexcept;
NSString *KartPadShakeSensitivityName(NSInteger level);

@interface KartPadMotionSteering : NSObject

+ (instancetype)sharedSteering;

@property(nonatomic, assign, getter=isEnabled) BOOL enabled;
@property(nonatomic, assign, getter=isInverted) BOOL inverted;
@property(nonatomic, assign) float sensitivity;
@property(nonatomic, assign, getter=isShakeTricksEnabled)
    BOOL shakeTricksEnabled;
/** Shake still presses D-pad Up while a controller is connected (clip-on controllers). */
@property(nonatomic, assign) BOOL shakeWithController;
/** 0 Low, 1 Standard (default), 2 High, 3 Very High: higher needs a lighter shake. */
@property(nonatomic, assign) NSInteger shakeSensitivity;
@property(nonatomic, readonly, getter=isSensorAvailable) BOOL sensorAvailable;
@property(nonatomic, readonly) float currentSteering;

- (BOOL)consumeShakeTrick;
- (void)start;
- (void)stop;
- (void)recenter;

@end

NS_ASSUME_NONNULL_END
