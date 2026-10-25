#pragma once

#import <Foundation/Foundation.h>
#include "kartpad/network/private_wfc.h"
#include "kartpad/system/wii_country.h"

// Shared Apple preference. The runtime reads a launch-time copy so an active
// online session can never be redirected by editing the settings dialog.
static inline NSString *KartPadPrivateServerHost() {
  return [NSUserDefaults.standardUserDefaults stringForKey:@"KartPadPrivateWfcHost"] ?: @"";
}

static inline void KartPadApplyPrivateServerAtLaunch() {
  if (std::getenv(KartPad::Network::kPrivateWfcHostEnvironment)) return;
  NSString *host = KartPadPrivateServerHost();
  if (KartPad::Network::ValidPrivateWfcHost(host.UTF8String)) {
    setenv(KartPad::Network::kPrivateWfcHostEnvironment, host.UTF8String, 1);
  }
}

// The Wii console country (#511): a saved choice, else the device's region.
static inline void KartPadApplyCountryAtLaunch() {
  if (std::getenv(KartPad::System::kCountryEnvironment)) return;
  NSString *country = [NSUserDefaults.standardUserDefaults stringForKey:@"KartPadCountry"];
  if (!KartPad::System::FindWiiCountry(country.UTF8String ?: "")) {
    country = [NSLocale.currentLocale objectForKey:NSLocaleCountryCode];
  }
  if (KartPad::System::FindWiiCountry(country.UTF8String ?: "")) {
    setenv(KartPad::System::kCountryEnvironment, country.uppercaseString.UTF8String, 1);
  }
}
