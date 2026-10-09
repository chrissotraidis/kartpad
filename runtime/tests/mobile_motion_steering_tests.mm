#include "../../apple/mobile/KartPadMotionSteering.h"

#include <cmath>
#include <cstdlib>
#include <iostream>
#include <stdexcept>

namespace {

void Require(bool condition, const char *message) {
  if (!condition) throw std::runtime_error(message);
}

void RequireNear(float actual, float expected, float tolerance,
                 const char *message) {
  Require(std::abs(actual - expected) <= tolerance, message);
}

void TestMotionMapping() {
  RequireNear(KartPadMotionSteeringValue(1.0, 1.0, 1.0f, NO), 0.0f, 0.0001f,
              "center did not map to neutral");
  RequireNear(KartPadMotionSteeringValue(1.03, 1.0, 1.0f, NO), 0.0f, 0.0001f,
              "dead zone was not retained");
  Require(KartPadMotionSteeringValue(1.35, 1.0, 1.0f, NO) > 0.4f,
          "positive tilt did not steer right");
  Require(KartPadMotionSteeringValue(0.65, 1.0, 1.0f, NO) < -0.4f,
          "negative tilt did not steer left");
  RequireNear(KartPadMotionSteeringValue(2.0, 1.0, 1.0f, NO), 1.0f, 0.0001f,
              "full lock did not clamp");
  RequireNear(KartPadMotionSteeringValue(1.35, 1.0, 1.0f, YES),
              -KartPadMotionSteeringValue(1.35, 1.0, 1.0f, NO), 0.0001f,
              "inversion changed magnitude");
  Require(KartPadMotionSteeringValue(-3.05, 3.05, 1.0f, NO) > 0.0f,
          "angle wrap crossed in the wrong direction");
  Require(KartPadMotionSteeringValue(1.25, 1.0, 2.0f, NO) >
              KartPadMotionSteeringValue(1.25, 1.0, 0.5f, NO),
          "sensitivity did not increase response");
  RequireNear(KartPadMotionSteeringValue(NAN, 0.0, 1.0f, NO), 0.0f, 0.0001f,
              "invalid sensor input was not neutral");
}

void TestShakeDetection() {
  constexpr double neverTriggered = -1.0;
  Require(KartPadShakeActionForSample(2.0, 0.0, false, neverTriggered) ==
              KartPadShakeAction::None,
          "resume in motion must wait for the device to settle");
  Require(KartPadShakeActionForSample(0.2, 1.0, true, neverTriggered) ==
              KartPadShakeAction::Rearm,
          "settled motion did not arm shake detection");
  Require(KartPadShakeActionForSample(0.8, 1.0, true, neverTriggered) ==
              KartPadShakeAction::None,
          "ordinary motion triggered a shake");
  Require(KartPadShakeActionForSample(1.5, 1.0, true, neverTriggered) ==
              KartPadShakeAction::Trigger,
          "deliberate shake did not trigger");
  Require(KartPadShakeActionForSample(1.5, 1.1, false, 1.0) ==
              KartPadShakeAction::None,
          "held acceleration retriggered before rearming");
  Require(KartPadShakeActionForSample(1.5, 1.2, true, 1.0) ==
              KartPadShakeAction::Disarm,
          "cooldown did not consume an early impulse");
  Require(KartPadShakeActionForSample(1.5, 1.5, true, 1.0) ==
              KartPadShakeAction::Trigger,
          "shake did not trigger after cooldown");
  Require(KartPadShakeActionForSample(NAN, 2.0, true, neverTriggered) ==
              KartPadShakeAction::None,
          "invalid acceleration changed detector state");
}

}  // namespace

int main() {
  @autoreleasepool {
    try {
      TestMotionMapping();
      TestShakeDetection();
      std::cout << "KartPad mobile motion-steering mapping passed\n";
      return EXIT_SUCCESS;
    } catch (const std::exception &error) {
      std::cerr << "KartPad mobile motion-steering mapping failed: "
                << error.what() << '\n';
      return EXIT_FAILURE;
    }
  }
}
