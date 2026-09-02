#import <Foundation/Foundation.h>

#import "../mobile/KartPadClassicInput.h"
#import "../mobile/KartPadPhysicalControllers.h"
#import "../third_party/sunpad/SunPadInputState.h"
#import "../../runtime/include/kartpad_mobile_runtime_host.h"

#import <CommonCrypto/CommonDigest.h>

#include "kartpad_retro_rewind_release.h"

#include <algorithm>
#include <atomic>
#include <string>

namespace {

constexpr char kMainDolSHA256[] =
    "80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05";
constexpr char kStaticRelSHA256[] =
    "16d9d146112541fefea701ecb5bc1a496f9d50e4a752fbb5b6778e7c6399f67d";

std::atomic_bool gInstalled = false;
std::string gSelectedRuntimeProfile = "base";

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

bool ValidateFile(NSURL *url, NSString *expectedHash,
                  NSNumber *expectedBytes = nil) {
  BOOL isDirectory = NO;
  NSError *error = nil;
  if (![NSFileManager.defaultManager fileExistsAtPath:url.path
                                           isDirectory:&isDirectory] ||
      isDirectory) {
    NSLog(@"[KartPad] required game file is unavailable: %@ (%@)", url.path,
          error.localizedDescription);
    return false;
  }

  if (expectedBytes != nil) {
    NSNumber *actualBytes = nil;
    if (![url getResourceValue:&actualBytes
                        forKey:NSURLFileSizeKey
                         error:&error] ||
        actualBytes.unsignedLongLongValue != expectedBytes.unsignedLongLongValue) {
      NSLog(@"[KartPad] required game file size mismatch: %@ expected=%llu actual=%llu error=%@",
            url.path, expectedBytes.unsignedLongLongValue,
            actualBytes.unsignedLongLongValue, error.localizedDescription);
      return false;
    }
  }

  NSString *actualHash = SHA256ForURL(url, &error);
  if (actualHash == nil || ![actualHash isEqualToString:expectedHash]) {
    NSLog(@"[KartPad] required game file hash mismatch: %@ actual=%@ error=%@",
          url.path, actualHash, error.localizedDescription);
    return false;
  }
  return true;
}

bool ValidateTextFile(NSURL *url, NSString *expected) {
  NSError *error = nil;
  NSData *data = [NSData dataWithContentsOfURL:url
                                      options:NSDataReadingMappedIfSafe
                                        error:&error];
  NSData *withoutNewline = [expected dataUsingEncoding:NSUTF8StringEncoding];
  NSData *withNewline =
      [[expected stringByAppendingString:@"\n"]
          dataUsingEncoding:NSUTF8StringEncoding];
  if (data == nil ||
      (![data isEqualToData:withoutNewline] &&
       ![data isEqualToData:withNewline])) {
    NSLog(@"[KartPad] required Retro Rewind text mismatch: %@ error=%@",
          url.path, error.localizedDescription);
    return false;
  }
  return true;
}

NSString *ReadRuntimeProfile(NSURL *root) {
  NSURL *marker = [root URLByAppendingPathComponent:@"RuntimeProfile"];
  if (![NSFileManager.defaultManager fileExistsAtPath:marker.path]) {
    return @"base";
  }

  NSError *error = nil;
  NSData *data = [NSData dataWithContentsOfURL:marker
                                      options:NSDataReadingMappedIfSafe
                                        error:&error];
  NSData *base = [@"base\n" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *retroRewind =
      [@"retro_rewind\n" dataUsingEncoding:NSUTF8StringEncoding];
  if ([data isEqualToData:base]) return @"base";
  if ([data isEqualToData:retroRewind]) return @"retro_rewind";

  NSLog(@"[KartPad] invalid tvOS RuntimeProfile marker: %@ error=%@",
        marker.path, error.localizedDescription);
  return nil;
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

  NSString *selectedProfile = ReadRuntimeProfile(root);
  if (selectedProfile == nil) return false;
  const bool retroProfile = [selectedProfile isEqualToString:@"retro_rewind"];
  NSURL *retroRoot = nil;
  if (retroProfile) {
    retroRoot = [[root URLByAppendingPathComponent:@"RetroRewind"
                                       isDirectory:YES]
        URLByAppendingPathComponent:
            [NSString stringWithUTF8String:KARTPAD_RR_ROOT]
                          isDirectory:YES];
    if (!ValidateTextFile(
            [retroRoot URLByAppendingPathComponent:@"version.txt"],
            [NSString stringWithUTF8String:KARTPAD_RR_VERSION]) ||
        !ValidateFile(
            [retroRoot URLByAppendingPathComponent:
                          [NSString stringWithUTF8String:KARTPAD_RR_CODE_PUL_PATH]],
            [NSString stringWithUTF8String:KARTPAD_RR_CODE_PUL_SHA256],
            @(KARTPAD_RR_CODE_PUL_BYTES)) ||
        !ValidateFile(
            [retroRoot URLByAppendingPathComponent:
                          [NSString stringWithUTF8String:KARTPAD_RR_XML_PATH]],
            [NSString stringWithUTF8String:KARTPAD_RR_XML_SHA256],
            @(KARTPAD_RR_XML_BYTES))) {
      return false;
    }
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
  NSString *networkConfig =
      retroProfile ? @"enabled = true\n\n" : @"enabled = false\n\n";
  NSString *retroRootConfig = retroRoot == nil
      ? @""
      : [NSString stringWithFormat:@"retro_rewind_root = \"%@\"\n",
                                   retroRoot.path];
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
       "%@"
       "[paths]\n"
       "dvd_root = \"%@\"\n"
       "nand_root = \"%@\"\n"
       "%@",
      networkConfig, gameData.path, nand.path, retroRootConfig];
  NSURL *configURL = [root URLByAppendingPathComponent:@"Config.toml"];
  if (![config writeToURL:configURL
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:&error]) {
    NSLog(@"[KartPad] could not write tvOS runtime config: %@",
          error.localizedDescription);
    return false;
  }

  gSelectedRuntimeProfile = [selectedProfile UTF8String];
  NSLog(@"[KartPad] validated tvOS GameData at %@", gameData.path);
  return true;
}

extern "C" const char *KartPadMobileSelectedRuntimeProfile() {
  return gSelectedRuntimeProfile.c_str();
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
