#import <Foundation/Foundation.h>

#import "../mobile/KartPadClassicInput.h"
#import "../mobile/KartPadPhysicalControllers.h"
#import "../third_party/sunpad/SunPadInputState.h"
#import "../../runtime/include/kartpad_mobile_runtime_host.h"

#import <CommonCrypto/CommonDigest.h>

#include <algorithm>
#include <atomic>

namespace {

constexpr char kMainDolSHA256[] =
    "80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05";
constexpr char kStaticRelSHA256[] =
    "16d9d146112541fefea701ecb5bc1a496f9d50e4a752fbb5b6778e7c6399f67d";

std::atomic_bool gInstalled = false;

NSString *SHA256ForURL(NSURL *url, NSError **error) {
  NSData *data = [NSData dataWithContentsOfURL:url
                                      options:NSDataReadingMappedIfSafe
                                        error:error];
  if (data == nil) return nil;

  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, static_cast<CC_LONG>(data.length), digest);
  NSMutableString *hex =
      [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (unsigned char byte : digest) {
    [hex appendFormat:@"%02x", byte];
  }
  return hex;
}

bool ValidateFile(NSURL *url, NSString *expectedHash) {
  NSNumber *regular = nil;
  NSError *error = nil;
  if (![url getResourceValue:&regular
                      forKey:NSURLIsRegularFileKey
                       error:&error] ||
      !regular.boolValue) {
    NSLog(@"[KartPad] required game file is unavailable: %@ (%@)", url.path,
          error.localizedDescription);
    return false;
  }

  NSString *actualHash = SHA256ForURL(url, &error);
  if (actualHash == nil || ![actualHash isEqualToString:expectedHash]) {
    NSLog(@"[KartPad] required game file hash mismatch: %@ actual=%@ error=%@",
          url.path, actualHash, error.localizedDescription);
    return false;
  }
  return true;
}

NSURL *KartPadCachesURL() {
  NSURL *cachesURL = [NSFileManager.defaultManager
      URLsForDirectory:NSCachesDirectory
             inDomains:NSUserDomainMask].firstObject;
  return [cachesURL URLByAppendingPathComponent:@"KartPad" isDirectory:YES];
}

}  // namespace

extern "C" bool KartPadMobileEnsureGameDataAvailable() {
  NSURL *root = KartPadCachesURL();
  if (root == nil) {
    NSLog(@"[KartPad] tvOS caches directory is unavailable");
    return false;
  }

  NSURL *gameData =
      [root URLByAppendingPathComponent:@"GameData" isDirectory:YES];
  NSError *error = nil;
  if (![NSFileManager.defaultManager createDirectoryAtURL:gameData
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error]) {
    NSLog(@"[KartPad] could not create tvOS GameData directory: %@",
          error.localizedDescription);
    return false;
  }
  NSURL *mainDol = [gameData URLByAppendingPathComponent:@"sys/main.dol"];
  NSURL *staticRel =
      [gameData URLByAppendingPathComponent:@"files/rel/StaticR.rel"];
  if (!ValidateFile(mainDol, @(kMainDolSHA256)) ||
      !ValidateFile(staticRel, @(kStaticRelSHA256))) {
    return false;
  }

  NSURL *nand = [root URLByAppendingPathComponent:@"NAND" isDirectory:YES];
  if (![NSFileManager.defaultManager createDirectoryAtURL:nand
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error]) {
    NSLog(@"[KartPad] could not create tvOS NAND directory: %@",
          error.localizedDescription);
    return false;
  }
  NSString *config = [NSString stringWithFormat:
      @"[video]\n"
       "widescreen = true\n"
       "resolution_multiplier = 1.0\n"
       "graphics_api = \"auto\"\n"
       "skip_unready_pipelines = true\n"
       "disable_copy_filter = true\n"
       "show_fps = false\n\n"
       "[audio]\n"
       "volume = 1.0\n"
       "muted = false\n\n"
       "[network]\n"
       "enabled = false\n\n"
       "[paths]\n"
       "dvd_root = \"%@\"\n"
       "nand_root = \"%@\"\n",
      gameData.path, nand.path];
  NSURL *configURL = [root URLByAppendingPathComponent:@"Config.toml"];
  if (![config writeToURL:configURL
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:&error]) {
    NSLog(@"[KartPad] could not write tvOS runtime config: %@",
          error.localizedDescription);
    return false;
  }

  NSLog(@"[KartPad] validated tvOS GameData at %@", gameData.path);
  return true;
}

extern "C" const char *KartPadMobileSelectedRuntimeProfile() {
  return "base";
}

extern "C" void KartPadMobileRuntimeHostInstall(void *sdlWindow) {
  if (sdlWindow == nullptr) {
    NSLog(@"[KartPad] refusing tvOS controller host without an SDL window");
    return;
  }
  [[KartPadPhysicalControllers sharedControllers] start];
  gInstalled.store(true, std::memory_order_release);
}

extern "C" void KartPadMobileRuntimeHostUninstall() {
  gInstalled.store(false, std::memory_order_release);
  [[KartPadPhysicalControllers sharedControllers] stop];
}

extern "C" bool KartPadMobileReadRuntimeSettings(
    KartPadMobileRuntimeSettings *settings) {
  if (settings == nullptr) return false;
  settings->aspectRatioMode = 1;
  settings->resolutionScale = 1.0f;
  settings->showFps = 0;
  return true;
}

extern "C" bool KartPadMobileReadClassicInput(
    KartPadMobileClassicInputSnapshot *snapshot) {
  return KartPadMobileReadClassicInputForPlayer(0, snapshot);
}

extern "C" bool KartPadMobileReadClassicInputForPlayer(
    unsigned int player, KartPadMobileClassicInputSnapshot *snapshot) {
  if (snapshot == nullptr || player >= 4 ||
      !gInstalled.load(std::memory_order_acquire)) {
    return false;
  }

  SunPadInputState source{};
  if (![[KartPadPhysicalControllers sharedControllers] consumePlayer:player
                                                               state:&source]) {
    *snapshot = {};
    return false;
  }
  const KartPadClassicInputState adapted =
      kartpad::mobile::AdaptSunPadInput(source);
  snapshot->buttons = adapted.buttons;
  snapshot->leftStickX =
      std::clamp(static_cast<float>(adapted.leftStickX) / 127.0f, -1.0f, 1.0f);
  snapshot->leftStickY =
      std::clamp(static_cast<float>(adapted.leftStickY) / 127.0f, -1.0f, 1.0f);
  snapshot->connected = adapted.connected ? 1 : 0;
  return adapted.connected;
}
