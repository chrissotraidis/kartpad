#import "../mobile/KartPadPrivateServerSettings.h"
#import "kartpad_mobile_runtime_host.h"

#import "KartPadClassicInput.h"
#import "KartPadDiscExtractor.h"
#import "KartPadMenuButton.h"
#import "KartPadFloatingStick.h"
#import "KartPadMotionSteering.h"
#import "KartPadPhysicalControllers.h"
#import "KartPadRetroRewindInstaller.h"
#import "KartPadDiagnosticContext.h"
#import "KartPadMiiManager.h"
#import "SunPadDiagnostics.h"
#import "KartPadSystemDiagnostics.h"
#import "SunPadGameOverlay.h"
#import "SunPadInputMixer.h"
#import "SunPadSettings.h"
#include "audio_backend.h"

#import <SDL3/SDL_properties.h>
#import <SDL3/SDL_video.h>
#import <CommonCrypto/CommonDigest.h>
#import <QuartzCore/QuartzCore.h>
#import <TargetConditionals.h>
#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

#include <algorithm>
#include <cmath>
#include <array>
#include <chrono>

#include "kartpad/input/auto_accelerate.h"

extern "C" int g_gxFrameCount;
#include <atomic>
static NSString *const kKartPadAutoAccelerateKey = @"KartPadAutoAccelerate";
static BOOL KartPadAutoAccelerateEnabled() {
  NSNumber *saved = [NSUserDefaults.standardUserDefaults objectForKey:kKartPadAutoAccelerateKey];
  return saved == nil || saved.boolValue;
}

// Controller auto-accelerate is separate from the touch A lock and off by default.
static NSString *const kKartPadControllerAutoAccelerateKey = @"KartPadControllerAutoAccelerate";
static std::atomic<bool> gKartPadControllerAutoAccelerate{
    [NSUserDefaults.standardUserDefaults boolForKey:kKartPadControllerAutoAccelerateKey]};
static std::array<kartpad::input::AutoAccelerateLatch, 4> gKartPadControllerAccelerateLatches;

static std::atomic<float> gKartPadFpsScale{1.0f};
extern "C" float KartPadMobileFpsOverlayScale(){return gKartPadFpsScale.load(std::memory_order_relaxed);}

@interface KartPadRuntimeOverlayHost : NSObject <SunPadGameOverlayDelegate,
                                                 UIDocumentPickerDelegate>
- (instancetype)initWithSDLWindow:(SDL_Window *)window;
- (void)uninstall;
- (void)reattachOverlayIfNeeded;
- (void)runMainMenu;
- (void)showReportPreview;
@end

@interface KartPadGameOverlay : SunPadGameOverlay <SFSafariViewControllerDelegate>
@property(nonatomic, strong) NSURL *reportDraftURL;
- (void)presentReportBrowserURL:(NSURL *)url;
@property(nonatomic, strong) KartPadFloatingStickView *kartPadMoveStick;
@property(nonatomic, copy) void (^multiplayerRequested)(void);
@property(nonatomic, copy) void (^mainMenuRequested)(void);
@property(nonatomic, copy) void (^motionSteeringRequested)(void);
@property(nonatomic, copy) void (^miiManagerRequested)(void);
@property(nonatomic, copy) void (^ghostManagerRequested)(void);
@property(nonatomic, copy) void (^saveManagerRequested)(void);
@property(nonatomic, copy) void (^buttonMappingRequested)(void);
@property(nonatomic, copy) void (^retroManagerRequested)(void);
@property(nonatomic, copy) void (^wiimoteRequested)(void);
@property(nonatomic, weak) UIButton *kartPadGasButton;
@property(nonatomic, strong) UIColor *kartPadGasRestColor;
@property(nonatomic, assign) NSUInteger kartPadGasHoldGeneration;
@property(nonatomic, assign) BOOL kartPadGasPressed;
@property(nonatomic, assign) BOOL kartPadGasLocked;
@property(nonatomic, assign) BOOL kartPadGasHoldSelfTestStarted;
@property(nonatomic, assign) BOOL kartPadGasInputSelfTestStarted;
@property(nonatomic, assign) BOOL kartPadModalInputSelfTestStarted;
@property(nonatomic, assign) BOOL kartPadEditorUITestStarted;
@property(nonatomic, weak) UIButton *kartPadVisibilityButton;
@property(nonatomic, copy) NSString *kartPadSelectedControlIdentifier;
- (void)resetKartPadControlAppearance;
@end

// KartPad keeps SunPad's pinned implementation byte-identical. This narrow
// declaration lets the owning subclass replace Sunshine's analog FLUDD
// pressure semantics with Mario Kart Wii's ordinary digital Classic R button.
@interface SunPadGameOverlay (KartPadControlHooks)
- (SunPadStickView *)makeStick;
- (void)stickChanged:(SunPadStickView *)stick x:(float)x y:(float)y;
- (void)rPressureChanged:(uint8_t)pressure fullPress:(BOOL)fullPress;
- (void)clearTouchInput;
- (void)buttonDown:(UIButton *)button;
- (void)buttonUp:(UIButton *)button;
- (UIView *)settingsRowWithTitle:(NSString *)title control:(UIView *)control;
- (void)endLayoutEditing;
- (void)finishLayoutEditing;
- (void)refreshMenuButton;
- (void)buildSettingsPanel;
- (void)resetLayout;
- (void)toggleSettingsPanel;
- (void)selectControlForEditing:(UIView *)control;
- (void)reportProblem;
- (void)createDiagnosticReportFromPrompt:(UIAlertController *)prompt
                              openGitHub:(BOOL)openGitHub;
- (void)chooseReportDestinationWithID:(NSString *)reportID
                               answers:(NSDictionary<NSString *, NSString *> *)answers;
- (void)openGitHubReportWithID:(NSString *)reportID
                       answers:(NSDictionary<NSString *, NSString *> *)answers
                      upstream:(BOOL)upstream;
@end

namespace {

KartPadRuntimeOverlayHost *gRuntimeOverlayHost = nil;
BOOL gKartPadRetroRewindSelected = NO;
BOOL gKartPadMainMenuRequested = NO;
NSString *const kKartPadRequestedRuntimeProfileKey =
    @"KartPadRequestedRuntimeProfile";
NSString *const kKartPadHiddenTouchControlsKey =
    @"KartPadHiddenTouchControls";

void KartPadSeedTouchLayoutDefaults(BOOL force) {
  BOOL tablet = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  BOOL changed = NO;
  if (force || [defaults dictionaryForKey:@"SunPadControlOrigins"] == nil) {
    // iPad layout accepted by the maintainer on the physical iPad, 2026-09-07.
    NSDictionary *origins = tablet ? @{
      @"move": NSStringFromCGPoint(CGPointMake(0.14756954612005857, 0.91391391391391397)),
      @"c": NSStringFromCGPoint(CGPointMake(0.90377745241581253, 0.87147147147147153)),
      @"X": NSStringFromCGPoint(CGPointMake(0.1290190336749634, 0.66706706706706709)),
      @"Y": NSStringFromCGPoint(CGPointMake(0.062562225475841865, 0.6820520520520521)),
      @"A": NSStringFromCGPoint(CGPointMake(0.90181551976573948, 0.74799799799799804)),
      @"B": NSStringFromCGPoint(CGPointMake(0.82915080527086371, 0.81399399399399397)),
      @"R": NSStringFromCGPoint(CGPointMake(0.80767935578330885, 0.72758758758758757)),
      @"L": NSStringFromCGPoint(CGPointMake(0.91096632503660335, 0.64904904904904903)),
      @"Z": NSStringFromCGPoint(CGPointMake(0.83304538799414352, 0.65063063063063065)),
      @"Start": NSStringFromCGPoint(CGPointMake(0.95537335285505121, 0.57607607607607603)),
    } : @{
      @"L" : NSStringFromCGPoint(CGPointMake(0.93580568318565682,
                                               0.42246621616846858)),
      @"R" : NSStringFromCGPoint(CGPointMake(0.8208055524263117,
                                               0.5224662162495497)),
      @"X" : NSStringFromCGPoint(CGPointMake(0.12563888892222205,
                                               0.53485360360900902)),
      @"Y" : NSStringFromCGPoint(CGPointMake(0.055472222222222207,
                                               0.56739864864054057)),
      @"Z" : NSStringFromCGPoint(CGPointMake(0.84591666666666665,
                                               0.3783220720432432)),
    };
    [defaults setObject:origins forKey:@"SunPadControlOrigins"];
    changed = YES;
  }
  if (force || [defaults objectForKey:kKartPadHiddenTouchControlsKey] == nil) {
    [defaults setObject:@[@"ExperimentalDPad"] forKey:kKartPadHiddenTouchControlsKey];
    changed = YES;
  }
  if (force || [defaults dictionaryForKey:@"SunPadControlSizeScales"] == nil) {
    NSDictionary<NSString *, NSNumber *> *scales = tablet ? @{
      @"A": @1.2150695323944092,
      @"B": @1.2253857851028442,
      @"L": @0.9791940450668335,
      @"R": @0.6000000238418579,
      @"X": @1.257727861404419,
      @"Y": @1.3797838687896729,
      @"Z": @1.2058641910552979,
    } : @{@"L": @0.9791940450668335, @"R": @0.6000000238418579};
    [defaults setObject:scales forKey:@"SunPadControlSizeScales"];
    SunPadSettings *settings = SunPadSettings.sharedSettings;
    for (NSString *identifier in scales) {
      [settings setSizeScale:scales[identifier].doubleValue forControl:identifier];
    }
    changed = YES;
  }
  if (force || [defaults objectForKey:@"SunPadExperimentalDPadOrigin"] == nil) {
    [defaults setObject:NSStringFromCGPoint(
        CGPointMake(0.084500001609325415, 0.34521396397747761))
                 forKey:@"SunPadExperimentalDPadOrigin"];
    changed = YES;
  }
  if (force || [defaults objectForKey:@"SunPadExperimentalDPadScale"] == nil) {
    [defaults setDouble:0.7827200293540955
                 forKey:@"SunPadExperimentalDPadScale"];
    changed = YES;
  }
  if (changed) [defaults synchronize];
}

NSSet<NSString *> *KartPadHiddenTouchControls() {
  NSArray<NSString *> *saved = [NSUserDefaults.standardUserDefaults
      stringArrayForKey:kKartPadHiddenTouchControlsKey];
  return [NSSet setWithArray:saved ?: @[]];
}

NSString *KartPadVisibilityIdentifier(UIView *control) {
  NSString *identifier = control.accessibilityIdentifier;
  if ([identifier hasPrefix:@"D_"]) return @"ExperimentalDPad";
  return identifier;
}

BOOL KartPadViewIsEffectivelyHidden(UIView *view) {
  for (UIView *candidate = view; candidate != nil;
       candidate = candidate.superview) {
    if (candidate.hidden || candidate.alpha < 0.01) return YES;
  }
  return NO;
}

UIViewController *KartPadVisibleViewController(UIWindow *window) {
  UIViewController *controller = window.rootViewController;
  while (controller.presentedViewController != nil) {
    controller = controller.presentedViewController;
  }
  return controller;
}

UIScrollView *KartPadScrollableSettingsView(UIView *root) {
  if ([root isKindOfClass:UIScrollView.class]) {
    UIScrollView *scroll = (UIScrollView *)root;
    if (scroll.contentSize.height > CGRectGetHeight(scroll.bounds) + 1.0) {
      return scroll;
    }
  }
  for (UIView *child in root.subviews) {
    UIScrollView *found = KartPadScrollableSettingsView(child);
    if (found != nil) return found;
  }
  return nil;
}

UIView *KartPadSubviewWithAccessibilityLabel(UIView *root, NSString *label,
                                              Class viewClass) {
  if ([root isKindOfClass:viewClass] &&
      [root.accessibilityLabel isEqualToString:label]) {
    return root;
  }
  for (UIView *child in root.subviews) {
    UIView *found = KartPadSubviewWithAccessibilityLabel(child, label,
                                                          viewClass);
    if (found != nil) return found;
  }
  return nil;
}

NSString *KartPadSupportRoot() {
  return [[NSHomeDirectory() stringByAppendingPathComponent:
      @"Library/Application Support"] stringByAppendingPathComponent:@"KartPad"];
}

NSURL *KartPadDocumentsRoot(NSError **error) {
  NSURL *documents = [NSFileManager.defaultManager
      URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
  if (documents == nil) return nil;
  if (![NSFileManager.defaultManager createDirectoryAtURL:documents
                              withIntermediateDirectories:YES attributes:nil
                                                   error:error]) {
    return nil;
  }
  return documents;
}

NSString *KartPadDocumentsFolderScanDetail(NSError *error) {
  NSString *device = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
      ? @"iPad" : @"iPhone";
  NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
  if (bundleIdentifier.length == 0) bundleIdentifier = @"unknown";
  NSString *reason = error == nil
      ? @"No compatible WBFS, ISO, or extracted DATA folder was found."
      : [NSString stringWithFormat:@"KartPad could not read this folder: %@",
                                   error.localizedDescription];
  return [NSString stringWithFormat:
      @"%@\n\nKartPad can scan only this signed app's own On My %@ folder. "
       "If a signer changes the bundle identifier or its protection suffix, "
       "iOS creates a different folder. Move the game into the newly installed "
       "KartPad folder or choose it directly from Files.\n\nSigned app ID: %@",
      reason, device, bundleIdentifier];
}

NSString *KartPadRemovalMarkerPath() {
  return [KartPadSupportRoot() stringByAppendingPathComponent:
      @"RemoveGameDataOnNextLaunch"];
}

BOOL KartPadRetroVersionIsValid(NSString *version) {
  NSArray<NSString *> *parts = [version componentsSeparatedByString:@"."];
  if (parts.count < 2 || parts.count > 4) return NO;
  NSCharacterSet *nonDigits = NSCharacterSet.decimalDigitCharacterSet.invertedSet;
  for (NSString *part in parts) {
    if (part.length == 0 || [part rangeOfCharacterFromSet:nonDigits].location !=
                                NSNotFound) {
      return NO;
    }
  }
  return YES;
}

NSString *KartPadLatestRetroVersionFromManifest(NSData *data) {
  if (data.length == 0 || data.length > 512 * 1024) return nil;
  NSString *text = [[NSString alloc] initWithData:data
                                         encoding:NSUTF8StringEncoding];
  if (text == nil) return nil;
  NSString *latest = nil;
  NSCharacterSet *whitespace = NSCharacterSet.whitespaceCharacterSet;
  for (NSString *line in
       [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
    NSString *trimmed = [line
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) continue;
    NSString *version = nil;
    for (NSString *token in
         [trimmed componentsSeparatedByCharactersInSet:whitespace]) {
      if (token.length > 0) {
        version = token;
        break;
      }
    }
    if (!KartPadRetroVersionIsValid(version)) return nil;
    if (latest == nil ||
        [latest compare:version options:NSNumericSearch] == NSOrderedAscending) {
      latest = version;
    }
  }
  return latest;
}

NSString *KartPadSHA256ForFile(NSString *path, NSError **error) {
  NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe
                                         error:error];
  if (data == nil || data.length > UINT32_MAX) {
    return nil;
  }
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *result =
      [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; ++index) {
    [result appendFormat:@"%02x", digest[index]];
  }
  return result;
}

NSString *KartPadResolvedExtractedRoot(NSURL *selectedURL) {
  NSFileManager *files = NSFileManager.defaultManager;
  NSArray<NSString *> *candidates = @[
    selectedURL.path,
    [selectedURL.path stringByAppendingPathComponent:@"DATA"],
    [selectedURL.path stringByAppendingPathComponent:@"GameData"],
  ];
  for (NSString *candidate in candidates) {
    BOOL directory = NO;
    if ([files fileExistsAtPath:[candidate stringByAppendingPathComponent:@"files"]
                    isDirectory:&directory] && directory &&
        [files fileExistsAtPath:[candidate stringByAppendingPathComponent:@"sys/fst.bin"]]) {
      return candidate;
    }
  }
  return nil;
}

BOOL KartPadURLIsSupportedDiscImage(NSURL *url) {
  if (url == nil || !url.isFileURL) return NO;
  NSString *extension = url.pathExtension.lowercaseString;
  return [extension isEqualToString:@"wbfs"] ||
         [extension isEqualToString:@"iso"];
}

NSArray<UTType *> *KartPadGameDataContentTypes() {
  // File providers disagree about ISO/WBFS identifiers. Include both broad
  // bases and the system disk-image/folder types, then rely on KartPad's
  // extension, disc-header, revision, and extracted-tree validation.
  return @[UTTypeItem, UTTypeData, UTTypeDiskImage, UTTypeFolder];
}

NSArray<NSURL *> *KartPadGameDataRootsInDocuments(NSError **error) {
  NSURL *documents = KartPadDocumentsRoot(error);
  if (documents == nil) return @[];
  NSArray<NSURL *> *entries = [NSFileManager.defaultManager
      contentsOfDirectoryAtURL:documents
    includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                       options:NSDirectoryEnumerationSkipsHiddenFiles error:error];
  if (entries == nil) return @[];
  NSMutableArray<NSURL *> *roots = [NSMutableArray array];
  for (NSURL *entry in entries) {
    // Check the user-visible extension first. Some Files providers report disc
    // images as packages/directories even though their bytes are readable as a
    // normal file. The extractor remains the authority after selection.
    if (KartPadURLIsSupportedDiscImage(entry)) {
      [roots addObject:entry];
      continue;
    }
    NSNumber *directory = nil;
    [entry getResourceValue:&directory forKey:NSURLIsDirectoryKey error:nil];
    if (directory.boolValue && KartPadResolvedExtractedRoot(entry) != nil) {
      [roots addObject:entry];
    }
  }
  [roots sortUsingComparator:^NSComparisonResult(NSURL *left, NSURL *right) {
    return [left.lastPathComponent localizedStandardCompare:right.lastPathComponent];
  }];
  return roots;
}

NSString *KartPadValidateExtractedRoot(NSString *root, NSError **error) {
  if (root.length == 0) {
    return @"Choose an extracted Mario Kart Wii DATA folder containing files/ and sys/.";
  }
  NSArray<NSString *> *required = @[
    @"sys/boot.bin", @"sys/bi2.bin", @"sys/apploader.img", @"sys/fst.bin",
    @"sys/main.dol", @"files/rel/StaticR.rel",
  ];
  NSFileManager *files = NSFileManager.defaultManager;
  for (NSString *relative in required) {
    if (![files fileExistsAtPath:[root stringByAppendingPathComponent:relative]]) {
      return [NSString stringWithFormat:@"The extracted game data is incomplete (missing %@).",
                                        relative];
    }
  }

  NSData *boot = [NSData dataWithContentsOfFile:
      [root stringByAppendingPathComponent:@"sys/boot.bin"] options:0 error:error];
  if (boot == nil) {
    return @"KartPad could not read sys/boot.bin.";
  }
  if (boot.length < 0x20) {
    return @"The selected sys/boot.bin is truncated.";
  }
  const uint8_t *bytes = static_cast<const uint8_t *>(boot.bytes);
  if (memcmp(bytes, "RMCP01", 6) != 0 || bytes[6] != 0 || bytes[7] != 0) {
    return @"KartPad currently supports RMCP01 (PAL), disc 0, revision 0 only.";
  }
  const uint32_t magic = (static_cast<uint32_t>(bytes[0x18]) << 24) |
                         (static_cast<uint32_t>(bytes[0x19]) << 16) |
                         (static_cast<uint32_t>(bytes[0x1A]) << 8) |
                         static_cast<uint32_t>(bytes[0x1B]);
  if (magic != 0x5D1C9EA3u) {
    return @"The selected folder does not contain a valid extracted Wii disc header.";
  }

  NSString *dolHash = KartPadSHA256ForFile(
      [root stringByAppendingPathComponent:@"sys/main.dol"], error);
  if (dolHash == nil) {
    return @"KartPad could not hash sys/main.dol.";
  }
  if (![dolHash isEqualToString:
      @"80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"]) {
    return @"This game data is modified (for example Wiimmfi-patched or pre-patched). Please use a clean RMCP01 dump.";
  }
  NSString *relHash = KartPadSHA256ForFile(
      [root stringByAppendingPathComponent:@"files/rel/StaticR.rel"], error);
  if (relHash == nil) {
    return @"KartPad could not hash files/rel/StaticR.rel.";
  }
  if (![relHash isEqualToString:
      @"16d9d146112541fefea701ecb5bc1a496f9d50e4a752fbb5b6778e7c6399f67d"]) {
    return @"This game data is modified (for example Wiimmfi-patched or pre-patched). Please use a clean RMCP01 dump.";
  }
  return nil;
}

BOOL KartPadEnsureRelativeRuntimePath(NSString *key, NSString *value,
                                     NSError **error) {
  NSString *configPath = [KartPadSupportRoot() stringByAppendingPathComponent:@"Config.toml"];
  NSError *readError = nil;
  NSString *config = [NSString stringWithContentsOfFile:configPath
                                               encoding:NSUTF8StringEncoding
                                                  error:&readError];
  if (config == nil) {
    if ([NSFileManager.defaultManager fileExistsAtPath:configPath]) {
      if (error != nullptr) {
        *error = readError;
      }
      return NO;
    }
    config = @"";
  }
  NSString *linePattern = [NSString stringWithFormat:
      @"(?m)^\\s*#?\\s*%@\\s*=.*$",
      [NSRegularExpression escapedPatternForString:key]];
  NSRegularExpression *pathLine = [NSRegularExpression
      regularExpressionWithPattern:linePattern
                           options:0 error:error];
  if (pathLine == nil) {
    return NO;
  }
  NSRange whole = NSMakeRange(0, config.length);
  config = [pathLine stringByReplacingMatchesInString:config options:0 range:whole
                                          withTemplate:@""];
  NSRegularExpression *paths = [NSRegularExpression
      regularExpressionWithPattern:@"(?m)^\\s*\\[paths\\]\\s*$"
                           options:0 error:error];
  if (paths == nil) {
    return NO;
  }
  NSTextCheckingResult *match =
      [paths firstMatchInString:config options:0 range:NSMakeRange(0, config.length)];
  if (match != nil) {
    NSUInteger insertion = NSMaxRange(match.range);
    config = [config stringByReplacingCharactersInRange:NSMakeRange(insertion, 0)
                                              withString:[NSString stringWithFormat:
                                                  @"\n%@ = \"%@\"", key, value]];
  } else {
    config = [config stringByAppendingFormat:
        @"\n\n[paths]\n%@ = \"%@\"\n", key, value];
  }
  return [config writeToFile:configPath atomically:YES
                    encoding:NSUTF8StringEncoding error:error];
}

BOOL KartPadEnsureRelativeDvdRoot(NSError **error) {
  return KartPadEnsureRelativeRuntimePath(@"dvd_root", @"GameData", error);
}

BOOL KartPadEnsureRelativeRetroRewindRoot(NSError **error) {
  return KartPadEnsureRelativeRuntimePath(
      @"retro_rewind_root", @"RetroRewind/RetroRewind6", error);
}

BOOL KartPadInstalledRetroRewindIsValid() {
  if (![KartPadRetroRewindInstaller isInstalled]) return NO;
  NSError *error = nil;
  return KartPadEnsureRelativeRetroRewindRoot(&error) && error == nil;
}

void KartPadRemoveStaleImportDirectories(NSString *supportRoot) {
  NSFileManager *files = NSFileManager.defaultManager;
  NSArray<NSString *> *entries =
      [files contentsOfDirectoryAtPath:supportRoot error:nil];
  for (NSString *entry in entries) {
    if ([entry hasPrefix:@"GameData.import-"]) {
      [files removeItemAtPath:[supportRoot stringByAppendingPathComponent:entry]
                        error:nil];
    }
  }
}

NSError *KartPadGameDataError(NSInteger code, NSString *message) {
  return [NSError errorWithDomain:@"dev.kartpad.gamedata" code:code userInfo:@{
    NSLocalizedDescriptionKey: message,
  }];
}

NSError *KartPadApplyScheduledGameDataRemoval() {
  NSFileManager *files = NSFileManager.defaultManager;
  NSString *marker = KartPadRemovalMarkerPath();
  if (![files fileExistsAtPath:marker]) {
    return nil;
  }

  NSString *supportRoot = KartPadSupportRoot();
  NSArray<NSString *> *entries =
      [files contentsOfDirectoryAtPath:supportRoot error:nil] ?: @[];
  for (NSString *entry in entries) {
    if ([entry isEqualToString:@"GameData"] ||
        [entry hasPrefix:@"GameData.import-"] ||
        [entry hasPrefix:@"GameData.rollback-"]) {
      NSError *error = nil;
      if (![files removeItemAtPath:[supportRoot stringByAppendingPathComponent:entry]
                            error:&error]) {
        return error ?: KartPadGameDataError(4, @"Could not remove stored game data.");
      }
    }
  }
  NSError *markerError = nil;
  if (![files removeItemAtPath:marker error:&markerError]) {
    return markerError ?: KartPadGameDataError(5, @"Could not finish game-data removal.");
  }

  SunPadSettings *settings = SunPadSettings.sharedSettings;
  settings.retainedGameDataPath = nil;
  settings.extractedGameRoot = nil;
  [settings synchronize];
  return nil;
}

void KartPadRecoverInterruptedImport(NSString *supportRoot) {
  NSFileManager *files = NSFileManager.defaultManager;
  NSString *dataDirectory = [supportRoot stringByAppendingPathComponent:@"GameData"];
  NSArray<NSString *> *entries =
      [files contentsOfDirectoryAtPath:supportRoot error:nil] ?: @[];
  NSMutableArray<NSString *> *rollbacks = [NSMutableArray array];
  for (NSString *entry in entries) {
    if ([entry hasPrefix:@"GameData.rollback-"]) {
      [rollbacks addObject:entry];
    }
  }
  [rollbacks sortUsingSelector:@selector(compare:)];
  if (![files fileExistsAtPath:dataDirectory] && rollbacks.count == 1) {
    NSString *rollback = [supportRoot stringByAppendingPathComponent:rollbacks.firstObject];
    [files moveItemAtPath:rollback toPath:dataDirectory error:nil];
  }
  KartPadRemoveStaleImportDirectories(supportRoot);
}

void KartPadRemoveRollbackDirectories(NSString *supportRoot) {
  NSFileManager *files = NSFileManager.defaultManager;
  NSArray<NSString *> *entries =
      [files contentsOfDirectoryAtPath:supportRoot error:nil] ?: @[];
  for (NSString *entry in entries) {
    if ([entry hasPrefix:@"GameData.rollback-"]) {
      [files removeItemAtPath:[supportRoot stringByAppendingPathComponent:entry]
                        error:nil];
    }
  }
}

BOOL KartPadInstalledGameDataIsValid() {
  NSString *supportRoot = KartPadSupportRoot();
  KartPadRecoverInterruptedImport(supportRoot);
  NSString *dataDirectory = [supportRoot stringByAppendingPathComponent:@"GameData"];
  NSError *error = nil;
  if (KartPadValidateExtractedRoot(dataDirectory, &error) != nil || error != nil) {
    return NO;
  }
  if (!KartPadEnsureRelativeDvdRoot(&error) || error != nil) {
    return NO;
  }
  KartPadRemoveRollbackDirectories(supportRoot);
  return YES;
}

NSError *KartPadPerformGameDataImport(NSURL *url,
                                      KartPadDiscExtractionProgress progress) {
  BOOL securityScoped = [url startAccessingSecurityScopedResource];
  NSError *workError = nil;
  NSString *supportRoot = KartPadSupportRoot();
  NSString *staging = [supportRoot stringByAppendingPathComponent:
      [NSString stringWithFormat:@"GameData.import-%@", NSUUID.UUID.UUIDString]];
  NSFileManager *files = NSFileManager.defaultManager;
  [files createDirectoryAtPath:supportRoot withIntermediateDirectories:YES
                     attributes:@{NSFileProtectionKey:
                         NSFileProtectionCompleteUntilFirstUserAuthentication}
                          error:&workError];
  if (workError == nil) {
    KartPadRecoverInterruptedImport(supportRoot);
    if (KartPadURLIsSupportedDiscImage(url)) {
      [KartPadDiscExtractor extractImageAtPath:url.path toDirectory:staging
                                      progress:progress error:&workError];
    } else {
      NSString *sourceRoot = KartPadResolvedExtractedRoot(url);
      NSString *validationError = KartPadValidateExtractedRoot(sourceRoot, &workError);
      if (validationError != nil && workError == nil) {
        workError = KartPadGameDataError(1, validationError);
      }
      if (workError == nil) {
        [files copyItemAtPath:sourceRoot toPath:staging error:&workError];
      }
    }
  }
  if (securityScoped) {
    [url stopAccessingSecurityScopedResource];
  }

  if (workError == nil) {
    NSString *validationError = KartPadValidateExtractedRoot(staging, &workError);
    if (validationError != nil && workError == nil) {
      workError = KartPadGameDataError(1, validationError);
    }
  }

  if (workError == nil && !KartPadEnsureRelativeDvdRoot(&workError)) {
    workError = workError ?: KartPadGameDataError(2, @"Could not update Config.toml.");
  }

  NSString *dataDirectory = [supportRoot stringByAppendingPathComponent:@"GameData"];
  NSString *rollback = [supportRoot stringByAppendingPathComponent:
      [NSString stringWithFormat:@"GameData.rollback-%@", NSUUID.UUID.UUIDString]];
  BOOL movedExisting = NO;
  if (workError == nil && [files fileExistsAtPath:dataDirectory]) {
    movedExisting = [files moveItemAtPath:dataDirectory toPath:rollback error:&workError];
  }
#if TARGET_OS_SIMULATOR
  if (workError == nil &&
      [NSProcessInfo.processInfo.environment[@"KARTPAD_IMPORT_FORCE_SWAP_FAILURE"] boolValue]) {
    workError = KartPadGameDataError(3, @"Injected Simulator swap failure.");
  }
#endif
  if (workError == nil) {
    [files moveItemAtPath:staging toPath:dataDirectory error:&workError];
  }
  if (workError != nil && movedExisting && ![files fileExistsAtPath:dataDirectory]) {
    [files moveItemAtPath:rollback toPath:dataDirectory error:nil];
  } else if (workError == nil && movedExisting) {
    [files removeItemAtPath:rollback error:nil];
  }
  if (workError != nil) {
    [files removeItemAtPath:staging error:nil];
    return workError;
  }

  NSURL *dataURL = [NSURL fileURLWithPath:dataDirectory isDirectory:YES];
  [dataURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
  [files setAttributes:@{NSFileProtectionKey:
      NSFileProtectionCompleteUntilFirstUserAuthentication}
             ofItemAtPath:dataDirectory error:nil];
  KartPadRemoveRollbackDirectories(supportRoot);
  SunPadSettings *settings = SunPadSettings.sharedSettings;
  settings.retainedGameDataPath = nil;
  settings.extractedGameRoot = dataDirectory;
  [settings synchronize];
  return nil;
}

}  // namespace

// Shared by the cold-start chooser and the suspended-game menu. Preferences
// never alter the live runtime; switching games keeps the existing restart gate.
static NSString *const kKartPadDarkModeKey = @"KartPadLauncherDarkMode";
static NSString *const kKartPadPreferredGameKey = @"KartPadPreferredGame";

@interface KartPadFirstLaunchViewController : UIViewController
@property(nonatomic, copy) void (^modeSelected)(BOOL retroRewind);
@property(nonatomic, assign) BOOL resumingGame;
@property(nonatomic, assign) BOOL currentRetroRewind;
@property(nonatomic, assign) BOOL gameDataReady;
@property(nonatomic, strong) NSLayoutConstraint *contentWidthConstraint;
@property(nonatomic, strong) UIStackView *content;
@property(nonatomic, strong) UIStackView *header;
@property(nonatomic, strong) UIStackView *footer;
@property(nonatomic, strong) NSMutableArray<UIStackView *> *rows;
@property(nonatomic, strong) NSMutableArray<UIView *> *rowSurfaces;
@property(nonatomic, strong) NSMutableArray<UILabel *> *cardTitles;
@property(nonatomic, strong) NSMutableArray<UILabel *> *secondaryLabels;
@property(nonatomic, strong) NSMutableArray<UILabel *> *primaryLabels;
@property(nonatomic, strong) NSMutableArray<UIView *> *dividers;
@property(nonatomic, strong) NSMutableArray<UIButton *> *actionButtons;
@property(nonatomic, strong) UIButton *themeButton;
@property(nonatomic) BOOL darkMode;
@property(nonatomic, strong) UIButton *preferenceButton;
@property(nonatomic, strong) UIImageView *checker;
@end

@implementation KartPadFirstLaunchViewController

- (UIColor *)racingRed {
  return self.darkMode ? [UIColor colorWithRed:1 green:0.20 blue:0.26 alpha:1]
                            : [UIColor colorWithRed:0.80 green:0.035 blue:0.12 alpha:1];
}

- (UILabel *)label:(NSString *)text style:(UIFontTextStyle)style secondary:(BOOL)secondary {
  UILabel *label = [UILabel new];
  label.text = text;
  label.font = [UIFont preferredFontForTextStyle:style];
  label.adjustsFontForContentSizeCategory = YES;
  label.textColor = secondary ? UIColor.secondaryLabelColor : UIColor.labelColor;
  label.numberOfLines = 0;
  [(secondary ? self.secondaryLabels : self.primaryLabels) addObject:label];
  return label;
}

- (UIButton *)link:(NSString *)title symbol:(NSString *)symbol action:(void (^)(void))action {
  UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
  configuration.title = title;
  configuration.image = symbol.length ? [UIImage systemImageNamed:symbol] : nil;
  configuration.imagePadding = 8;
  configuration.baseForegroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
    return traits.userInterfaceStyle == UIUserInterfaceStyleDark
        ? [UIColor colorWithRed:1 green:0.20 blue:0.26 alpha:1]
        : [UIColor colorWithRed:0.80 green:0.035 blue:0.12 alpha:1];
  }];
  configuration.contentInsets = NSDirectionalEdgeInsetsMake(10, 0, 10, 4);
  UIButton *button = [UIButton buttonWithConfiguration:configuration primaryAction:
      [UIAction actionWithHandler:^(__kindof UIAction *event) { action(); }]];
  [button.heightAnchor constraintGreaterThanOrEqualToConstant:44].active = YES;
  return button;
}

- (void)openGuide:(NSString *)path {
  NSURL *url = [NSURL URLWithString:[@"https://github.com/chrissotraidis/kartpad/"
      stringByAppendingString:path]];
  __weak KartPadFirstLaunchViewController *weakSelf = self;
  [UIApplication.sharedApplication openURL:url options:@{} completionHandler:^(BOOL opened) {
    if (opened) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Could Not Open GitHub"
        message:@"Please try again when a browser is available. Setup and troubleshooting guides are in the chrissotraidis/kartpad repository on GitHub."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
    [weakSelf presentViewController:alert animated:YES completion:nil];
  }];
}

- (void)closeSetupHelp {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showSetupHelp {
  UIViewController *help = [UIViewController new];
  help.title = @"Getting Started";
  help.view.backgroundColor = self.view.backgroundColor;
  help.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeSetupHelp)];
  UILabel *importTitle = [self label:@"1. Import Mario Kart Wii" style:UIFontTextStyleTitle2 secondary:NO];
  UILabel *importBody = [self label:
      @"Use your own PAL (Europe) ISO or WBFS: RMCP01, revision 0. An extracted DATA folder also works. RVZ files must be converted before importing."
      style:UIFontTextStyleBody secondary:YES];
  UILabel *retroTitle = [self label:@"2. Add Retro Rewind, if you want it" style:UIFontTextStyleTitle2 secondary:NO];
  UILabel *retroBody = [self label:[NSString stringWithFormat:
      @"Import Mario Kart Wii first, then choose Retro Rewind. KartPad can download and install the official %@ pack. You do not need to import a second disc.",
      KartPadRetroRewindInstaller.requiredVersion] style:UIFontTextStyleBody secondary:YES];
  UILabel *supportTitle = [self label:@"Stuck on a step?" style:UIFontTextStyleTitle2 secondary:NO];
  UILabel *supportBody = [self label:
      @"The GitHub guides cover supported files, free space, installation and common problems. If you report an issue, include your KartPad version, device, and the exact message you see."
      style:UIFontTextStyleBody secondary:YES];
  for (UILabel *title in @[importTitle, retroTitle, supportTitle]) title.accessibilityTraits |= UIAccessibilityTraitHeader;
  __weak KartPadFirstLaunchViewController *weakSelf = self;
  UIButton *setup = [self link:@"Setup Guide on GitHub" symbol:@"book.closed" action:^{
    [weakSelf openGuide:@"blob/main/docs/INSTALL_IPA.md"];
  }];
  UIButton *troubleshooting = [self link:@"Troubleshooting on GitHub" symbol:@"wrench.and.screwdriver" action:^{
    [weakSelf openGuide:@"blob/main/docs/SUPPORT.md"];
  }];
  UILabel *version = [self label:[NSString stringWithFormat:@"KartPad %@ · Build %@",
      [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"",
      [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @""]
      style:UIFontTextStyleCaption1 secondary:YES];
  UIStackView *content = [[UIStackView alloc] initWithArrangedSubviews:
      @[importTitle, importBody, retroTitle, retroBody, supportTitle, supportBody, setup, troubleshooting, version]];
  content.axis = UILayoutConstraintAxisVertical;
  content.spacing = 12;
  [content setCustomSpacing:28 afterView:importBody];
  [content setCustomSpacing:28 afterView:retroBody];
  content.translatesAutoresizingMaskIntoConstraints = NO;
  UIScrollView *scroll = [UIScrollView new];
  scroll.translatesAutoresizingMaskIntoConstraints = NO;
  [help.view addSubview:scroll];
  [scroll addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [scroll.leadingAnchor constraintEqualToAnchor:help.view.safeAreaLayoutGuide.leadingAnchor],
    [scroll.trailingAnchor constraintEqualToAnchor:help.view.safeAreaLayoutGuide.trailingAnchor],
    [scroll.topAnchor constraintEqualToAnchor:help.view.safeAreaLayoutGuide.topAnchor],
    [scroll.bottomAnchor constraintEqualToAnchor:help.view.safeAreaLayoutGuide.bottomAnchor],
    [content.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:24],
    [content.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-24],
    [content.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:24],
    [content.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-24],
    [content.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-48],
  ]];
  UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:help];
  navigation.overrideUserInterfaceStyle = self.overrideUserInterfaceStyle;
  navigation.modalPresentationStyle = UIModalPresentationFormSheet;
  navigation.preferredContentSize = CGSizeMake(620, 640);
  [self presentViewController:navigation animated:YES completion:nil];
}


- (UIView *)divider {
  UIView *line = [UIView new];
  [line.heightAnchor constraintEqualToConstant:1].active = YES;
  [self.dividers addObject:line];
  return line;
}

- (void)updatePreferenceTitle {
  NSString *value = [NSUserDefaults.standardUserDefaults stringForKey:kKartPadPreferredGameKey];
  NSString *title = [value isEqualToString:@"base"] ? @"Mario Kart Wii"
      : ([value isEqualToString:@"retro_rewind"] ? @"Retro Rewind" : @"Ask every time");
  UIButtonConfiguration *configuration = self.preferenceButton.configuration;
  configuration.title = title;
  self.preferenceButton.configuration = configuration;
  self.preferenceButton.accessibilityLabel = @"Game on launch";
  self.preferenceButton.accessibilityValue = title;
}

- (void)showLaunchPreference {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"On Launch"
      message:@"Choose a game to open automatically. You can always return here from the in-game menu."
      preferredStyle:UIAlertControllerStyleActionSheet];
  NSArray<NSString *> *titles = @[@"Ask every time", @"Mario Kart Wii", @"Retro Rewind"];
  NSArray<NSString *> *values = @[@"ask", @"base", @"retro_rewind"];
  __weak KartPadFirstLaunchViewController *weakSelf = self;
  for (NSUInteger i = 0; i < titles.count; ++i) {
    NSString *value = values[i];
    [alert addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {
      [NSUserDefaults.standardUserDefaults setObject:value forKey:kKartPadPreferredGameKey];
      [weakSelf updatePreferenceTitle];
    }]];
  }
  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  alert.popoverPresentationController.sourceView = self.preferenceButton;
  alert.popoverPresentationController.sourceRect = self.preferenceButton.bounds;
  [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyTheme {
  BOOL dark = self.darkMode;
  self.overrideUserInterfaceStyle = dark ? UIUserInterfaceStyleDark : UIUserInterfaceStyleLight;
  self.view.backgroundColor = dark ? [UIColor colorWithWhite:0.065 alpha:1]
                                  : [UIColor colorWithRed:0.985 green:0.975 blue:0.95 alpha:1];
  UIColor *foreground = dark ? [UIColor colorWithWhite:0.97 alpha:1]
                            : [UIColor colorWithRed:0.045 green:0.065 blue:0.10 alpha:1];
  UIColor *secondary = dark ? [UIColor colorWithWhite:0.66 alpha:1]
                           : [UIColor colorWithWhite:0.37 alpha:1];
  for (UILabel *label in self.primaryLabels) label.textColor = foreground;
  for (UILabel *label in self.secondaryLabels) label.textColor = secondary;
  for (UIView *line in self.dividers) line.backgroundColor = [foreground colorWithAlphaComponent:0.15];
  for (NSUInteger i = 0; i < self.rowSurfaces.count; ++i) {
    BOOL current = self.resumingGame && self.currentRetroRewind == (i == 1);
    self.rowSurfaces[i].backgroundColor = current
        ? [[self racingRed] colorWithAlphaComponent:dark ? 0.10 : 0.065] : UIColor.clearColor;
    UIButton *button = self.actionButtons[i];
    UIButtonConfiguration *config = button.configuration;
    config.baseBackgroundColor = i == 1
        ? [UIColor colorWithRed:0.08 green:0.36 blue:0.80 alpha:1]
        : [UIColor colorWithRed:0.89 green:0.025 blue:0.10 alpha:1];
    config.baseForegroundColor = UIColor.whiteColor;
    button.configuration = config;
  }
  UIButtonConfiguration *theme = self.themeButton.configuration;
  theme.image = [UIImage systemImageNamed:dark ? @"moon.fill" : @"sun.max.fill"];
  theme.baseForegroundColor = foreground;
  theme.baseBackgroundColor = [foreground colorWithAlphaComponent:0.08];
  self.themeButton.configuration = theme;
  self.themeButton.accessibilityLabel = dark ? @"Switch to light mode" : @"Switch to dark mode";
  self.themeButton.accessibilityValue = dark ? @"Dark mode" : @"Light mode";
  self.checker.tintColor = dark ? UIColor.whiteColor : UIColor.blackColor;
  self.checker.alpha = dark ? 1.0 : 0.65;
}

- (void)themeChanged:(UIButton *)sender {
  self.darkMode = !self.darkMode;
  [NSUserDefaults.standardUserDefaults setBool:self.darkMode forKey:kKartPadDarkModeKey];
  [self applyTheme];
}

- (UIView *)gameCard:(BOOL)retro installedVersion:(NSString *)installedVersion {
  BOOL current = self.resumingGame && self.currentRetroRewind == retro;
  BOOL ready = self.gameDataReady && (!retro || installedVersion.length > 0);
  NSString *status = current ? @"Paused" : (self.resumingGame ? @"Next launch"
      : (ready ? @"Ready to play" : (retro && !self.gameDataReady ? @"Import Mario Kart Wii first" : @"Setup needed")));
  UILabel *title = [self label:retro ? @"Retro Rewind" : @"Mario Kart Wii" style:UIFontTextStyleTitle2 secondary:NO];
  title.accessibilityTraits |= UIAccessibilityTraitHeader;
  [self.cardTitles addObject:title];
  UILabel *badge = [self label:status style:UIFontTextStyleFootnote secondary:YES];
  UIStackView *text = [[UIStackView alloc] initWithArrangedSubviews:@[title, badge]];
  text.axis = UILayoutConstraintAxisVertical;
  text.spacing = 4;
  UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:retro ? @"gobackward" : @"flag.checkered"]];
  icon.tintColor = retro ? [UIColor colorWithRed:1 green:0.68 blue:0.08 alpha:1]
                        : [UIColor colorWithRed:0.10 green:0.52 blue:1 alpha:1];
  icon.contentMode = UIViewContentModeScaleAspectFit;
  icon.isAccessibilityElement = NO;
  [NSLayoutConstraint activateConstraints:@[[icon.widthAnchor constraintEqualToConstant:36],
      [icon.heightAnchor constraintEqualToConstant:36]]];
  UIStackView *identity = [[UIStackView alloc] initWithArrangedSubviews:@[icon, text]];
  identity.axis = UILayoutConstraintAxisHorizontal;
  identity.alignment = UIStackViewAlignmentCenter;
  identity.spacing = 18;
  NSString *actionTitle = current ? @"Resume Game" : (self.resumingGame ? @"Use on Next Launch"
      : (ready ? @"Play Game" : (retro ? @"Set Up Game" : @"Import Game")));
  UIButtonConfiguration *configuration = [UIButtonConfiguration filledButtonConfiguration];
  configuration.title = actionTitle;
  configuration.image = [UIImage systemImageNamed:@"arrow.right"];
  configuration.imagePlacement = NSDirectionalRectEdgeTrailing;
  configuration.imagePadding = 12;
  configuration.cornerStyle = UIButtonConfigurationCornerStyleMedium;
  configuration.contentInsets = NSDirectionalEdgeInsetsMake(14, 18, 14, 18);
  __weak KartPadFirstLaunchViewController *weakSelf = self;
  UIButton *action = [UIButton buttonWithConfiguration:configuration primaryAction:
      [UIAction actionWithHandler:^(__kindof UIAction *event) {
    if (weakSelf.modeSelected) weakSelf.modeSelected(retro);
  }]];
  action.configurationUpdateHandler = ^(UIButton *button) {
    if (UIAccessibilityIsReduceMotionEnabled()) return;
    [UIView animateWithDuration:0.12 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
      button.transform = button.highlighted ? CGAffineTransformMakeScale(0.97, 0.97) : CGAffineTransformIdentity;
    } completion:nil];
  };
  action.accessibilityIdentifier = retro ? @"kartpad.mode.retro-rewind" : @"kartpad.mode.original";
  action.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", actionTitle, title.text];
  action.accessibilityHint = [NSString stringWithFormat:@"%@. %@", status, retro
      ? (installedVersion.length ? [NSString stringWithFormat:@"Installed pack %@", installedVersion] : @"Optional official pack, downloaded in the app")
      : (self.gameDataReady ? @"Game data imported" : @"PAL Europe ISO or WBFS, RMCP01 revision zero")];
  [action.heightAnchor constraintGreaterThanOrEqualToConstant:48].active = YES;
  [action.widthAnchor constraintGreaterThanOrEqualToConstant:190].active = YES;
  [action setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [self.actionButtons addObject:action];
  UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[identity, action]];
  row.axis = UILayoutConstraintAxisHorizontal;
  row.alignment = UIStackViewAlignmentCenter;
  row.spacing = 16;
  row.translatesAutoresizingMaskIntoConstraints = NO;
  [self.rows addObject:row];
  UIView *surface = [UIView new];
  surface.layer.cornerRadius = 14;
  [surface addSubview:row];
  [self.rowSurfaces addObject:surface];
  [NSLayoutConstraint activateConstraints:@[
    [row.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor constant:18],
    [row.trailingAnchor constraintEqualToAnchor:surface.trailingAnchor constant:-18],
    [row.topAnchor constraintEqualToAnchor:surface.topAnchor constant:16],
    [row.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-16],
  ]];
  if (current) {
    UIView *indicator = [UIView new];
    indicator.backgroundColor = [UIColor colorWithRed:1 green:0.15 blue:0.23 alpha:1];
    indicator.layer.cornerRadius = 2;
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    [surface addSubview:indicator];
    [NSLayoutConstraint activateConstraints:@[
      [indicator.widthAnchor constraintEqualToConstant:4],
      [indicator.leadingAnchor constraintEqualToAnchor:surface.leadingAnchor],
      [indicator.topAnchor constraintEqualToAnchor:surface.topAnchor constant:8],
      [indicator.bottomAnchor constraintEqualToAnchor:surface.bottomAnchor constant:-8],
    ]];
  }
  return surface;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.rows = [NSMutableArray array];
  self.rowSurfaces = [NSMutableArray array];
  self.actionButtons = [NSMutableArray array];
  self.primaryLabels = [NSMutableArray array];
  self.secondaryLabels = [NSMutableArray array];
  self.cardTitles = [NSMutableArray array];
  self.dividers = [NSMutableArray array];
  UIButtonConfiguration *themeConfiguration = [UIButtonConfiguration filledButtonConfiguration];
  themeConfiguration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
  self.themeButton = [UIButton buttonWithConfiguration:themeConfiguration primaryAction:nil];
  id savedTheme = [NSUserDefaults.standardUserDefaults objectForKey:kKartPadDarkModeKey];
  self.darkMode = savedTheme == nil || [savedTheme boolValue];
  self.themeButton.accessibilityIdentifier = @"kartpad.theme.dark";
  [self.themeButton.widthAnchor constraintEqualToConstant:48].active = YES;
  [self.themeButton.heightAnchor constraintEqualToConstant:48].active = YES;
  [self.themeButton addTarget:self action:@selector(themeChanged:) forControlEvents:UIControlEventTouchUpInside];
  UIImageView *mark = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"KartPadLogo"]];
  mark.contentMode = UIViewContentModeScaleAspectFit;
  mark.isAccessibilityElement = NO;
  [NSLayoutConstraint activateConstraints:@[[mark.widthAnchor constraintEqualToConstant:48],
      [mark.heightAnchor constraintEqualToConstant:48]]];
  UILabel *brand = [self label:@"KartPad" style:UIFontTextStyleTitle1 secondary:NO];
  brand.font = [UIFontMetrics.defaultMetrics scaledFontForFont:[UIFont systemFontOfSize:30 weight:UIFontWeightBold]];
  UIStackView *identity = [[UIStackView alloc] initWithArrangedSubviews:@[mark, brand]];
  identity.axis = UILayoutConstraintAxisHorizontal;
  identity.alignment = UIStackViewAlignmentCenter;
  identity.spacing = 12;
  __weak KartPadFirstLaunchViewController *weakSelf = self;
  UIButton *help = [self link:@"Help" symbol:nil action:^{ [weakSelf showSetupHelp]; }];
  help.accessibilityIdentifier = @"kartpad.setup.help";
  [help setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [identity setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  self.header = [[UIStackView alloc] initWithArrangedSubviews:@[identity, [UIView new], self.themeButton, help]];
  self.header.axis = UILayoutConstraintAxisHorizontal;
  self.header.alignment = UIStackViewAlignmentCenter;
  self.header.spacing = 20;
  UILabel *launch = [self label:@"On launch:" style:UIFontTextStyleFootnote secondary:YES];
  self.preferenceButton = [self link:@"Ask every time" symbol:@"chevron.down" action:^{ [weakSelf showLaunchPreference]; }];
  UIButtonConfiguration *pref = self.preferenceButton.configuration;
  pref.imagePlacement = NSDirectionalRectEdgeTrailing;
  pref.baseForegroundColor = UIColor.labelColor;
  self.preferenceButton.configuration = pref;
  self.preferenceButton.accessibilityIdentifier = @"kartpad.launch.preference";
  [self.preferenceButton.widthAnchor constraintGreaterThanOrEqualToConstant:150].active = YES;
  [self.preferenceButton setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [self updatePreferenceTitle];
  UIStackView *launchChoice = [[UIStackView alloc] initWithArrangedSubviews:@[launch, self.preferenceButton]];
  launchChoice.axis = UILayoutConstraintAxisHorizontal;
  launchChoice.alignment = UIStackViewAlignmentCenter;
  launchChoice.spacing = 10;
  [launchChoice setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [launchChoice setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  UILabel *returnHint = [self label:@"Return here anytime from the in-game menu."
      style:UIFontTextStyleFootnote secondary:YES];
  returnHint.textAlignment = NSTextAlignmentRight;
  [launch setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  [self.preferenceButton setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
  self.footer = [[UIStackView alloc] initWithArrangedSubviews:@[launchChoice, [UIView new], returnHint]];
  self.footer.axis = UILayoutConstraintAxisHorizontal;
  self.footer.alignment = UIStackViewAlignmentCenter;
  self.footer.spacing = 24;
  NSString *version = KartPadRetroRewindInstaller.installedVersion;
  self.content = [[UIStackView alloc] initWithArrangedSubviews:@[self.header,
      [self gameCard:NO installedVersion:version], [self divider],
      [self gameCard:YES installedVersion:version], [self divider], self.footer]];
  self.content.axis = UILayoutConstraintAxisVertical;
  self.content.spacing = 10;
  [self.content setCustomSpacing:24 afterView:self.header];
  self.content.translatesAutoresizingMaskIntoConstraints = NO;
  self.checker = [[UIImageView alloc] initWithImage:[[UIImage imageNamed:@"KartPadChecker"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]];
  self.checker.contentMode = UIViewContentModeScaleAspectFill;
  self.checker.clipsToBounds = YES;
  self.checker.translatesAutoresizingMaskIntoConstraints = NO;
  self.checker.isAccessibilityElement = NO;
  [self.view addSubview:self.checker];
  [NSLayoutConstraint activateConstraints:@[
    [self.checker.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [self.checker.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [self.checker.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    [self.checker.widthAnchor constraintEqualToConstant:70],
  ]];
  UIScrollView *scroll = [UIScrollView new];
  scroll.translatesAutoresizingMaskIntoConstraints = NO;
  scroll.alwaysBounceVertical = NO;
  [self.view addSubview:scroll];
  UIView *canvas = [UIView new];
  canvas.translatesAutoresizingMaskIntoConstraints = NO;
  [scroll addSubview:canvas];
  [canvas addSubview:self.content];
  self.contentWidthConstraint = [self.content.widthAnchor constraintEqualToConstant:700];
  NSLayoutConstraint *height = [canvas.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor];
  height.priority = UILayoutPriorityDefaultLow;
  [NSLayoutConstraint activateConstraints:@[
    [scroll.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
    [scroll.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
    [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
    [scroll.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    [canvas.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
    [canvas.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
    [canvas.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
    [canvas.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
    [canvas.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],
    [canvas.heightAnchor constraintGreaterThanOrEqualToAnchor:scroll.frameLayoutGuide.heightAnchor],
    [self.content.centerXAnchor constraintEqualToAnchor:canvas.centerXAnchor],
    [self.content.centerYAnchor constraintEqualToAnchor:canvas.centerYAnchor],
    [self.content.topAnchor constraintGreaterThanOrEqualToAnchor:canvas.topAnchor constant:12],
    [self.content.bottomAnchor constraintLessThanOrEqualToAnchor:canvas.bottomAnchor constant:-12],
    self.contentWidthConstraint, height,
  ]];
  [self applyTheme];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  UIEdgeInsets insets = self.view.safeAreaInsets;
  CGFloat available = CGRectGetWidth(self.view.bounds) - insets.left - insets.right - 32;
  self.contentWidthConstraint.constant = MIN(1040, MAX(0, available));
  BOOL largeText = UIContentSizeCategoryIsAccessibilityCategory(self.traitCollection.preferredContentSizeCategory);
  BOOL stacked = available < 600 || largeText;
  for (UIStackView *row in self.rows) {
    row.axis = stacked ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
    row.alignment = stacked ? UIStackViewAlignmentFill : UIStackViewAlignmentCenter;
  }
  self.header.axis = largeText ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
  self.footer.axis = stacked ? UILayoutConstraintAxisVertical : UILayoutConstraintAxisHorizontal;
  for (UILabel *title in self.cardTitles) {
    title.font = [UIFontMetrics.defaultMetrics scaledFontForFont:
        [UIFont systemFontOfSize:available > 850 ? 28 : 22 weight:UIFontWeightSemibold]];
  }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskLandscape;
}
@end

@interface KartPadFirstLaunchHost : NSObject <UIDocumentPickerDelegate,
                                               NSURLSessionDownloadDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) KartPadFirstLaunchViewController *root;
@property(nonatomic, strong) NSURLSession *retroDownloadSession;
@property(nonatomic, strong) NSURLSessionDownloadTask *retroDownloadTask;
@property(nonatomic, strong) NSURLSessionDataTask *retroVersionTask;
@property(nonatomic, strong) UIAlertController *retroProgressAlert;
@property(nonatomic, assign) BOOL finished;
@property(nonatomic, assign) BOOL succeeded;
@property(nonatomic, assign) BOOL selectedRetroRewind;
@property(nonatomic, assign) BOOL choosingRetroArchive;
@property(nonatomic, assign) BOOL choosingGameDataCopy;
@property(nonatomic, assign) BOOL receivedRetroDownload;
@property(nonatomic, assign) BOOL retroVersionChecked;
@property(nonatomic, assign) NSInteger lastRetroDownloadPercent;
- (BOOL)run;
- (void)showOptions;
- (void)presentGameDataPicker;
- (void)showRetroRewindOptions;
- (void)checkRetroRewindVersionAndContinue;
- (void)showRetroVersionCheckFailure:(NSString *)detail;
- (void)showKartPadUpdateRequiredForRetroVersion:(NSString *)latest;
@end

@implementation KartPadFirstLaunchHost

- (UIWindowScene *)availableWindowScene {
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if ([scene isKindOfClass:UIWindowScene.class]) {
      return (UIWindowScene *)scene;
    }
  }
  return nil;
}

- (void)showMessage:(NSString *)title
             detail:(NSString *)detail
         completion:(void (^)(void))completion {
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title message:detail
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *action) {
    (void)action;
    if (completion != nil) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.35 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), completion);
    }
  }]];
  [self.root presentViewController:alert animated:YES completion:nil];
}

- (void)showRetroVersionCheckFailure:(NSString *)detail {
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:@"Could Not Check for Updates"
                       message:detail
                preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Try Again"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [self checkRetroRewindVersionAndContinue];
    });
  }]];
  if (KartPadInstalledRetroRewindIsValid()) {
    [alert addAction:[UIAlertAction actionWithTitle:@"Launch Installed Version"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
      (void)action;
      self.retroVersionChecked = YES;
      [self completeSelectedMode];
    }]];
  }
  [alert addAction:[UIAlertAction actionWithTitle:@"Back"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
  [self.root presentViewController:alert animated:YES completion:nil];
}

- (void)showKartPadUpdateRequiredForRetroVersion:(NSString *)latest {
  NSString *message = [NSString stringWithFormat:
      @"Retro Rewind %@ was released after this KartPad build, which supports %@. Retro Rewind changed executable code that KartPad must translate ahead of time, so a matching KartPad release is required before installing the new pack or playing online. Original Mario Kart Wii remains available.",
      latest, KartPadRetroRewindInstaller.requiredVersion];
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:@"Retro Rewind Update Needed"
                       message:message
                preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"View KartPad Releases"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
    (void)action;
    NSURL *url = [NSURL URLWithString:
        @"https://github.com/chrissotraidis/kartpad/releases"];
    [UIApplication.sharedApplication openURL:url options:@{}
                            completionHandler:nil];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"Back"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
  [self.root presentViewController:alert animated:YES completion:nil];
}

- (void)checkRetroRewindVersionAndContinue {
  UIAlertController *progress = [UIAlertController
      alertControllerWithTitle:@"Checking Retro Rewind"
                       message:@"Checking the official current version…"
                preferredStyle:UIAlertControllerStyleAlert];
  [self.root presentViewController:progress animated:YES completion:nil];

  NSMutableURLRequest *request = [NSMutableURLRequest
      requestWithURL:KartPadRetroRewindInstaller.officialVersionManifestURL
         cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
     timeoutInterval:15.0];
  __weak KartPadFirstLaunchHost *weakSelf = self;
  NSURLSessionConfiguration *configuration =
      NSURLSessionConfiguration.ephemeralSessionConfiguration;
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
  self.retroVersionTask = [session
      dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    [session finishTasksAndInvalidate];
    NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class]
        ? (NSHTTPURLResponse *)response : nil;
    NSString *latest = error == nil && http.statusCode == 200
        ? KartPadLatestRetroVersionFromManifest(data) : nil;
    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadFirstLaunchHost *strongSelf = weakSelf;
      if (strongSelf == nil) return;
      strongSelf.retroVersionTask = nil;
      [progress dismissViewControllerAnimated:YES completion:^{
        if (latest == nil) {
          NSString *detail = error.localizedDescription ?:
              @"The official Retro Rewind version feed returned an invalid response. Online play requires the current release.";
          [strongSelf showRetroVersionCheckFailure:detail];
          return;
        }
        NSString *supported = KartPadRetroRewindInstaller.requiredVersion;
        if ([supported compare:latest options:NSNumericSearch] ==
            NSOrderedAscending) {
          [strongSelf showKartPadUpdateRequiredForRetroVersion:latest];
          return;
        }
        strongSelf.retroVersionChecked = YES;
        [strongSelf completeSelectedMode];
      }];
    });
  }];
  [self.retroVersionTask resume];
}

- (void)completeSelectedMode {
  if (!KartPadInstalledGameDataIsValid()) {
    [self showOptions];
    return;
  }
  if (self.selectedRetroRewind && !self.retroVersionChecked) {
    [self checkRetroRewindVersionAndContinue];
    return;
  }
  if (self.selectedRetroRewind && !KartPadInstalledRetroRewindIsValid()) {
    [self showRetroRewindOptions];
    return;
  }
  gKartPadRetroRewindSelected = self.selectedRetroRewind;
  self.succeeded = YES;
  self.finished = YES;
}

- (void)installRetroRewindArchive:(NSURL *)archiveURL
               deletingAfterwards:(BOOL)deleteAfterwards {
  UIAlertController *progress = self.retroProgressAlert;
  if (progress == nil) {
    progress = [UIAlertController
        alertControllerWithTitle:@"Installing Retro Rewind"
                         message:@"Verifying the selected ZIP…"
                  preferredStyle:UIAlertControllerStyleAlert];
    self.retroProgressAlert = progress;
    [self.root presentViewController:progress animated:YES completion:nil];
  }
  __weak KartPadFirstLaunchHost *weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *installError = nil;
    BOOL installed = [KartPadRetroRewindInstaller
        installArchiveAtURL:archiveURL
                   progress:^(NSString *status, double fraction) {
      dispatch_async(dispatch_get_main_queue(), ^{
        KartPadFirstLaunchHost *strongSelf = weakSelf;
        if (strongSelf.retroProgressAlert != nil) {
          strongSelf.retroProgressAlert.message = [NSString stringWithFormat:
              @"%@\n%.0f%%", status, fraction * 100.0];
        }
      });
    }
                      error:&installError];
    if (deleteAfterwards) {
      [NSFileManager.defaultManager removeItemAtURL:archiveURL error:nil];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadFirstLaunchHost *strongSelf = weakSelf;
      if (strongSelf == nil) return;
      [strongSelf.retroProgressAlert dismissViewControllerAnimated:YES completion:^{
        strongSelf.retroProgressAlert = nil;
        if (!installed) {
          [strongSelf showMessage:@"Retro Rewind Install Failed"
                           detail:installError.localizedDescription completion:^{
            [strongSelf showRetroRewindOptions];
          }];
          return;
        }
        [strongSelf completeSelectedMode];
      }];
    });
  });
}

- (void)chooseRetroRewindArchive {
  self.choosingRetroArchive = YES;
  self.choosingGameDataCopy = NO;
  UTType *zip = [UTType typeWithFilenameExtension:@"zip"];
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc]
          initForOpeningContentTypes:zip == nil ? @[UTTypeArchive] : @[zip]
                            asCopy:NO];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self.root presentViewController:picker animated:YES completion:nil];
}

- (void)startOfficialRetroRewindDownload {
  self.receivedRetroDownload = NO;
  self.lastRetroDownloadPercent = -1;
  UIAlertController *progress = [UIAlertController
      alertControllerWithTitle:[NSString stringWithFormat:
          @"Downloading Retro Rewind %@",
          KartPadRetroRewindInstaller.requiredVersion]
                       message:@"Starting the official full download…"
                preferredStyle:UIAlertControllerStyleAlert];
  self.retroProgressAlert = progress;
  __weak KartPadFirstLaunchHost *weakSelf = self;
  [progress addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                               style:UIAlertActionStyleCancel
                                             handler:^(UIAlertAction *action) {
    (void)action;
    KartPadFirstLaunchHost *strongSelf = weakSelf;
    [strongSelf.retroDownloadTask cancel];
    strongSelf.retroProgressAlert = nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [strongSelf showRetroRewindOptions];
    });
  }]];
  [self.root presentViewController:progress animated:YES completion:nil];
  NSURLSessionConfiguration *configuration =
      NSURLSessionConfiguration.defaultSessionConfiguration;
  configuration.allowsCellularAccess = YES;
  self.retroDownloadSession =
      [NSURLSession sessionWithConfiguration:configuration delegate:self
                               delegateQueue:NSOperationQueue.mainQueue];
  self.retroDownloadTask = [self.retroDownloadSession
      downloadTaskWithURL:KartPadRetroRewindInstaller.officialArchiveURL];
  [self.retroDownloadTask resume];
}

- (void)showRetroRewindOptions {
  const double gib = (double)KartPadRetroRewindInstaller.officialArchiveBytes /
                     (1024.0 * 1024.0 * 1024.0);
  UIAlertController *options = [UIAlertController
      alertControllerWithTitle:[NSString stringWithFormat:
          @"Retro Rewind %@ Required",
          KartPadRetroRewindInstaller.requiredVersion]
                       message:[NSString stringWithFormat:
          @"Retro Rewind is optional community content used for its extra tracks, characters, and Retro WFC online play. This KartPad build requires the matching official %.2f GiB full download.",
          gib]
                preferredStyle:UIAlertControllerStyleAlert];
  [options addAction:[UIAlertAction actionWithTitle:@"Download Official Pack"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [self startOfficialRetroRewindDownload];
    });
  }]];
  [options addAction:[UIAlertAction actionWithTitle:@"Choose Full-Download ZIP…"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [self chooseRetroRewindArchive];
    });
  }]];
  [options addAction:[UIAlertAction actionWithTitle:@"Back"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
  [self.root presentViewController:options animated:YES completion:nil];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
 totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  (void)session;
  (void)downloadTask;
  (void)bytesWritten;
  if (self.retroProgressAlert == nil) return;
  const int64_t expected = totalBytesExpectedToWrite > 0
      ? totalBytesExpectedToWrite
      : (int64_t)KartPadRetroRewindInstaller.officialArchiveBytes;
  const double fraction = expected > 0
      ? std::min(1.0, (double)totalBytesWritten / (double)expected) : 0.0;
  const NSInteger percent = (NSInteger)(100.0 * fraction);
  if (percent == self.lastRetroDownloadPercent) return;
  self.lastRetroDownloadPercent = percent;
  self.retroProgressAlert.message = [NSString stringWithFormat:
      @"Downloading the official full pack…\n%.0f%%",
      (double)percent];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didFinishDownloadingToURL:(NSURL *)location {
  (void)session;
  (void)downloadTask;
  NSString *temporaryName = [NSString stringWithFormat:
      @"KartPad-RetroRewind-%@-%@.zip",
      KartPadRetroRewindInstaller.requiredVersion, NSUUID.UUID.UUIDString];
  NSURL *temporaryURL = [NSURL fileURLWithPath:
      [NSTemporaryDirectory() stringByAppendingPathComponent:temporaryName]];
  NSError *moveError = nil;
  [NSFileManager.defaultManager moveItemAtURL:location toURL:temporaryURL
                                        error:&moveError];
  if (moveError != nil) {
    [self.retroProgressAlert dismissViewControllerAnimated:YES completion:^{
      self.retroProgressAlert = nil;
      [self showMessage:@"Retro Rewind Download Failed"
                 detail:moveError.localizedDescription completion:^{
        [self showRetroRewindOptions];
      }];
    }];
    return;
  }
  self.receivedRetroDownload = YES;
  self.retroProgressAlert.title = @"Installing Retro Rewind";
  self.retroProgressAlert.message = @"Verifying the official download…\n0%";
  [self installRetroRewindArchive:temporaryURL deletingAfterwards:YES];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
 didCompleteWithError:(NSError *)error {
  (void)task;
  [session finishTasksAndInvalidate];
  self.retroDownloadTask = nil;
  self.retroDownloadSession = nil;
  if (error == nil || self.receivedRetroDownload ||
      error.code == NSURLErrorCancelled) return;
  [self.retroProgressAlert dismissViewControllerAnimated:YES completion:^{
    self.retroProgressAlert = nil;
    [self showMessage:@"Retro Rewind Download Failed"
               detail:error.localizedDescription completion:^{
      [self showRetroRewindOptions];
    }];
  }];
}

- (void)startImport:(NSURL *)url deleteAfterwards:(BOOL)deleteAfterwards {
  UIAlertController *progress =
      [UIAlertController alertControllerWithTitle:@"Importing Game Data"
                                          message:@"Validating your selected game data…"
                                   preferredStyle:UIAlertControllerStyleAlert];
  [self.root presentViewController:progress animated:YES completion:nil];
  __weak KartPadFirstLaunchHost *weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *error = KartPadPerformGameDataImport(
        url, ^(NSString *status, double fraction) {
          progress.message = [NSString stringWithFormat:@"%@\n%.0f%%", status,
                                                       fraction * 100.0];
        });
    if (deleteAfterwards) {
      [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadFirstLaunchHost *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }
      [progress dismissViewControllerAnimated:YES completion:^{
        if (error != nil) {
          [strongSelf showMessage:@"Game Data Import Failed"
                           detail:error.localizedDescription completion:^{
            [strongSelf showOptions];
          }];
          return;
        }
        [strongSelf completeSelectedMode];
      }];
    });
  });
}

- (void)chooseDocumentsRoot {
  NSError *error = nil;
  NSArray<NSURL *> *roots = KartPadGameDataRootsInDocuments(&error);
  if (roots.count == 0) {
    NSLog(@"[KartPad] %@", KartPadDocumentsFolderScanDetail(error));
    [self presentGameDataPicker];
    return;
  }
  if (roots.count == 1) {
    [self startImport:roots.firstObject deleteAfterwards:NO];
    return;
  }
  UIAlertController *choices =
      [UIAlertController alertControllerWithTitle:@"Choose Game Data"
                                          message:@"Select your RMCP01 WBFS, ISO, or extracted DATA folder."
                                   preferredStyle:UIAlertControllerStyleAlert];
  for (NSURL *root in roots) {
    [choices addAction:[UIAlertAction actionWithTitle:root.lastPathComponent
                                                style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *action) {
      (void)action;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.35 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
      [self startImport:root deleteAfterwards:NO];
    });
    }]];
  }
  [choices addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self showOptions]; });
  }]];
  [self.root presentViewController:choices animated:YES completion:nil];
}

- (void)presentGameDataPicker {
  self.choosingGameDataCopy = YES;
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc]
          initForOpeningContentTypes:KartPadGameDataContentTypes() asCopy:YES];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [self.root presentViewController:picker animated:YES completion:nil];
}

- (void)showOptions {
  self.choosingRetroArchive = NO;
  self.choosingGameDataCopy = NO;
  UIAlertController *options =
      [UIAlertController alertControllerWithTitle:@"Game Data Required"
          message:@"First, import your own Mario Kart Wii game: PAL (Europe), RMCP01 revision 0.\n\nChoose an ISO, WBFS, or extracted DATA folder. RVZ files must be converted first. Retro Rewind is added after this step."
          preferredStyle:UIAlertControllerStyleAlert];
  [options addAction:[UIAlertAction actionWithTitle:@"Choose WBFS, ISO, or DATA Folder…"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [self presentGameDataPicker];
    });
  }]];
  [options addAction:[UIAlertAction actionWithTitle:@"Import from Extracted Folder…"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self chooseDocumentsRoot]; });
  }]];
  [options addAction:[UIAlertAction actionWithTitle:@"Back"
                                               style:UIAlertActionStyleCancel
                                             handler:nil]];
  [self.root presentViewController:options animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  (void)controller;
  NSURL *url = urls.firstObject;
  if (url != nil) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      if (self.choosingRetroArchive) {
        self.choosingRetroArchive = NO;
        [self installRetroRewindArchive:url deletingAfterwards:NO];
      } else {
        const BOOL deleteAfterwards = self.choosingGameDataCopy;
        self.choosingGameDataCopy = NO;
        [self startImport:url deleteAfterwards:deleteAfterwards];
      }
    });
  } else {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      if (self.choosingRetroArchive) {
        self.choosingRetroArchive = NO;
        [self showRetroRewindOptions];
      } else {
        self.choosingGameDataCopy = NO;
        [self showOptions];
      }
    });
  }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
  (void)controller;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               (int64_t)(0.35 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    if (self.choosingRetroArchive) {
      self.choosingRetroArchive = NO;
      [self showRetroRewindOptions];
    } else {
      self.choosingGameDataCopy = NO;
      [self showOptions];
    }
  });
}

- (BOOL)run {
  // Create the Files-visible app directory before first-launch UI is shown.
  // UIFileSharingEnabled and LSSupportsOpeningDocumentsInPlace expose this
  // Documents directory as On My iPhone/iPad -> KartPad.
  NSError *documentsError = nil;
  if (KartPadDocumentsRoot(&documentsError) == nil) {
    NSLog(@"[KartPad] could not prepare Files directory: %@",
          documentsError.localizedDescription);
  }
  NSError *removalError = KartPadApplyScheduledGameDataRemoval();
  if (removalError != nil) {
    NSLog(@"[KartPad] scheduled game-data removal failed: %@",
          removalError.localizedDescription);
  }
  const BOOL gameDataReady = removalError == nil && KartPadInstalledGameDataIsValid();
#if TARGET_OS_SIMULATOR
  NSString *testArchive = NSProcessInfo.processInfo.environment[
      @"KARTPAD_RETRO_REWIND_INSTALL_ARCHIVE"];
  if (testArchive.length > 0 && ![KartPadRetroRewindInstaller isInstalled]) {
    NSError *installError = nil;
    BOOL installed = [KartPadRetroRewindInstaller
        installArchiveAtURL:[NSURL fileURLWithPath:testArchive]
                   progress:^(NSString *status, double fraction) {
      NSLog(@"[KartPad] Simulator Retro Rewind install: %@ %.0f%%",
            status, fraction * 100.0);
    }
                      error:&installError];
    NSLog(@"[KartPad] Simulator Retro Rewind install %@%@",
          installed ? @"passed" : @"FAILED",
          installError == nil ? @"" :
              [NSString stringWithFormat:@": %@", installError.localizedDescription]);
  }
#endif
  UIWindowScene *scene = [self availableWindowScene];
  if (scene == nil) {
    NSLog(@"[KartPad] no UIWindowScene is available for first-launch import");
    return NO;
  }
  self.root = [[KartPadFirstLaunchViewController alloc] init];
  self.root.gameDataReady = gameDataReady;
  self.window = [[UIWindow alloc] initWithWindowScene:scene];
  self.window.windowLevel = UIWindowLevelAlert + 1.0;
  self.window.rootViewController = self.root;
  [self.window makeKeyAndVisible];
  __weak KartPadFirstLaunchHost *weakSelf = self;
  self.root.modeSelected = ^(BOOL retroRewind) {
    KartPadFirstLaunchHost *strongSelf = weakSelf;
    if (strongSelf == nil || strongSelf.finished) return;
    strongSelf.selectedRetroRewind = retroRewind;
    if (!gameDataReady) {
      [strongSelf showOptions];
      return;
    }
    [strongSelf completeSelectedMode];
  };
  NSString *requestedProfile = [NSUserDefaults.standardUserDefaults
      stringForKey:kKartPadRequestedRuntimeProfileKey];
  if (gameDataReady && [NSProcessInfo.processInfo.environment[@"KARTPAD_UI_PREVIEW"] isEqualToString:@"report"]) requestedProfile=@"base";
  if (requestedProfile.length == 0 && gameDataReady) {
    requestedProfile = [NSUserDefaults.standardUserDefaults stringForKey:kKartPadPreferredGameKey];
  }
  if ([requestedProfile isEqualToString:@"retro_rewind"] ||
      [requestedProfile isEqualToString:@"base"]) {
    [NSUserDefaults.standardUserDefaults
        removeObjectForKey:kKartPadRequestedRuntimeProfileKey];
    [NSUserDefaults.standardUserDefaults synchronize];
    dispatch_async(dispatch_get_main_queue(), ^{
      if (self.root.modeSelected != nil) {
        self.root.modeSelected([requestedProfile isEqualToString:@"retro_rewind"]);
      }
    });
  }
  if (removalError != nil) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self showMessage:@"Game Data Removal Failed"
                 detail:removalError.localizedDescription completion:^{
        self.finished = YES;
        self.succeeded = NO;
      }];
    });
  }
  while (!self.finished) {
    @autoreleasepool {
      [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
  }
  self.window.hidden = YES;
  self.window = nil;
  return self.succeeded;
}

@end

// A scrollable form stays usable in landscape and above the software keyboard.
@interface KartPadReportFormController : UIViewController
@property(nonatomic,copy) void (^submit)(NSDictionary *, BOOL);
@property(nonatomic,strong) NSArray<UITextField *> *fields;
@end
@implementation KartPadReportFormController
- (void)viewDidLoad {
  [super viewDidLoad]; self.title=@"Report a Problem"; self.view.backgroundColor=UIColor.systemBackgroundColor;
  self.navigationItem.leftBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
  UIScrollView *scroll=[UIScrollView new]; scroll.translatesAutoresizingMaskIntoConstraints=NO; scroll.keyboardDismissMode=UIScrollViewKeyboardDismissModeInteractive; [self.view addSubview:scroll];
  UIStackView *stack=[UIStackView new]; stack.axis=UILayoutConstraintAxisVertical; stack.spacing=16; stack.translatesAutoresizingMaskIntoConstraints=NO; [scroll addSubview:stack];
  UILabel *intro=[UILabel new]; intro.text=@"Describe what happened. Device details and recent logs are added for review. Nothing is uploaded automatically."; intro.numberOfLines=0; intro.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody]; intro.adjustsFontForContentSizeCategory=YES; [stack addArrangedSubview:intro];
  NSMutableArray *fields=[NSMutableArray array];
  NSArray *labels=@[@"What went wrong?",@"Course or menu, and what you were doing",@"How often does it happen?"];
  for(NSString *title in labels){ UILabel *label=[UILabel new];label.text=title;label.numberOfLines=0;label.font=[UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];[stack addArrangedSubview:label]; UITextField *field=[UITextField new];field.borderStyle=UITextBorderStyleRoundedRect;field.placeholder=title;field.accessibilityLabel=title;field.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];field.adjustsFontForContentSizeCategory=YES;[field.heightAnchor constraintGreaterThanOrEqualToConstant:44].active=YES;[stack addArrangedSubview:field];[fields addObject:field]; }
  self.fields=fields;
  NSArray *buttons=@[@"Save or Share Report…",@"Review & Continue to GitHub…",@"Reporting Guide"];
  SEL selectors[]={@selector(share),@selector(github),@selector(guide)};
  for(NSUInteger i=0;i<buttons.count;++i){UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];UIButtonConfiguration *config=i==1?UIButtonConfiguration.filledButtonConfiguration:UIButtonConfiguration.tintedButtonConfiguration;config.title=buttons[i];button.configuration=config;button.titleLabel.numberOfLines=0;[button.heightAnchor constraintGreaterThanOrEqualToConstant:48].active=YES;[button addTarget:self action:selectors[i] forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:button];}
  UILayoutGuide *safe=self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],[scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:self.view.keyboardLayoutGuide.topAnchor],[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:20],[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-20],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:16],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-20],[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-40]]];
}
- (void)cancel { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)finish:(BOOL)github { NSDictionary *answers=@{@"problem":self.fields[0].text?:@"",@"context":self.fields[1].text?:@"",@"frequency":self.fields[2].text?:@""};void (^submit)(NSDictionary *,BOOL)=self.submit;[self.view endEditing:YES];[self dismissViewControllerAnimated:YES completion:^{if(submit)submit(answers,github);}]; }
- (void)share {[self finish:NO];}
- (void)github {[self finish:YES];}
- (void)guide {[UIApplication.sharedApplication openURL:[NSURL URLWithString:@"https://github.com/chrissotraidis/kartpad/blob/main/docs/REPORTING.md"] options:@{} completionHandler:nil];}
@end

// The acknowledgment is deliberately local to one report and starts unchecked.
@interface KartPadReportReviewController : UIViewController
@property(nonatomic, strong) NSURL *reportURL;
@property(nonatomic, copy) void (^continueReport)(NSString *evidence);
@property(nonatomic, strong) UIButton *reviewButton;
@property(nonatomic, strong) UIButton *continueButton;
@end

@implementation KartPadReportReviewController
- (void)viewDidLoad {
  [super viewDidLoad];
  self.title = @"Review Diagnostic Log";
  self.view.backgroundColor = UIColor.systemBackgroundColor;
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
      initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
  UILabel *instructions = [[UILabel alloc] init];
  instructions.text = @"Review this log before posting publicly. GitHub needs you to attach the file manually. Add a screenshot for visual issues.";
  instructions.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
  instructions.adjustsFontForContentSizeCategory = YES;
  instructions.numberOfLines = 0;
  UITextView *log = [[UITextView alloc] init];
  log.editable = NO;
  log.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
  NSError *readError = nil;
  NSString *logText = self.reportURL ? [NSString stringWithContentsOfURL:self.reportURL encoding:NSUTF8StringEncoding error:&readError] : nil;
  const BOOL readable = logText != nil;
  log.text = logText;
  if (!readable) log.text = @"The saved log could not be read. Choose Continue Without a Log to describe the problem on GitHub.";
  log.accessibilityLabel = @"Diagnostic log";
  self.reviewButton = [UIButton buttonWithType:UIButtonTypeSystem];
  self.reviewButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeading;
  self.reviewButton.titleLabel.numberOfLines = 0;
  [self.reviewButton setTitle:@"☐ I reviewed this log for private information" forState:UIControlStateNormal];
  [self.reviewButton setTitle:@"☑ I reviewed this log for private information" forState:UIControlStateSelected];
  self.reviewButton.enabled = readable;
  self.reviewButton.accessibilityValue = @"Unchecked";
  [self.reviewButton addTarget:self action:@selector(toggleReview) forControlEvents:UIControlEventTouchUpInside];
  UIButton *share = [UIButton buttonWithType:UIButtonTypeSystem];
  [share setTitle:@"Save or Share Log…" forState:UIControlStateNormal];
  share.enabled = self.reportURL != nil;
  [share addTarget:self action:@selector(shareLog:) forControlEvents:UIControlEventTouchUpInside];
  self.continueButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.continueButton setTitle:@"Choose Project — I’ll Attach the Log" forState:UIControlStateNormal];
  self.continueButton.titleLabel.numberOfLines = 0;
  self.continueButton.enabled = NO;
  [self.continueButton addTarget:self action:@selector(continueWithLog) forControlEvents:UIControlEventTouchUpInside];
  UIButton *unable = [UIButton buttonWithType:UIButtonTypeSystem];
  [unable setTitle:@"Continue Without a Log" forState:UIControlStateNormal];
  [unable addTarget:self action:@selector(explainMissingLog) forControlEvents:UIControlEventTouchUpInside];
  UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[instructions, log, self.reviewButton, share, self.continueButton, unable]];
  stack.axis = UILayoutConstraintAxisVertical;
  stack.spacing = 12;
  stack.translatesAutoresizingMaskIntoConstraints = NO;
  UIScrollView *scroll = [[UIScrollView alloc] init];
  scroll.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:scroll];
  [scroll addSubview:stack];
  UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],
    [scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],
    [scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],
    [scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
    [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
    [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:12],
    [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-12],
    [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],
    [log.heightAnchor constraintEqualToConstant:220],
  ]];
}
- (void)cancel { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)toggleReview {
  self.reviewButton.selected = !self.reviewButton.selected;
  self.reviewButton.accessibilityValue = self.reviewButton.selected ? @"Checked" : @"Unchecked";
  self.continueButton.enabled = self.reviewButton.selected;
}
- (void)shareLog:(UIButton *)sender {
  UIActivityViewController *share = [[UIActivityViewController alloc] initWithActivityItems:@[self.reportURL] applicationActivities:nil];
  share.popoverPresentationController.sourceView = sender;
  share.popoverPresentationController.sourceRect = sender.bounds;
  [self presentViewController:share animated:YES completion:nil];
}
- (void)finishWithEvidence:(NSString *)evidence {
  void (^continuation)(NSString *) = self.continueReport;
  if (continuation) continuation(evidence);
}
- (void)continueWithLog {
  if (!self.reviewButton.selected) return;
  [self finishWithEvidence:[NSString stringWithFormat:@"I reviewed the diagnostic log for private information. I will attach %@ manually below; it has not been uploaded by KartPad. Add a screenshot for visual issues.", self.reportURL.lastPathComponent]];
}
- (void)explainMissingLog {
  [self finishWithEvidence:@"Diagnostic log not included yet. No log was uploaded by KartPad. I can add reviewed diagnostics or screenshots in the browser."];
}

@end

@implementation KartPadGameOverlay

- (instancetype)initWithFrame:(CGRect)frame {
  // Seed untouched layouts only; custom arrangements remain user-owned.
  KartPadSeedTouchLayoutDefaults(NO);
  return [super initWithFrame:frame];
}

- (SunPadStickView *)makeStick {
  if (self.kartPadMoveStick != nil) return [super makeStick];
  KartPadFloatingStickView *stick = [[KartPadFloatingStickView alloc]
      initWithFrame:CGRectMake(0, 0, 128, 128)];
  self.kartPadMoveStick = stick;
  __weak KartPadGameOverlay *weakSelf = self;
  __weak SunPadStickView *weakStick = stick;
  stick.valueChanged = ^(float x, float y) {
    SunPadStickView *strongStick = weakStick;
    if (strongStick != nil) [weakSelf stickChanged:strongStick x:x y:y];
  };
  return stick;
}

- (void)kartPadFinishLayoutEditing {
  [super finishLayoutEditing];
  [self toggleSettingsPanel];
}

- (void)endLayoutEditing {
  [super endLayoutEditing];
  self.kartPadSelectedControlIdentifier = nil;
}

- (void)kartPadToggleSelectedControlVisibility {
  NSString *identifier = self.kartPadSelectedControlIdentifier;
  if (identifier.length == 0) return;

  NSMutableSet<NSString *> *hidden =
      [KartPadHiddenTouchControls() mutableCopy];
  BOOL showing = [hidden containsObject:identifier];
  if (showing) {
    [hidden removeObject:identifier];
  } else {
    [hidden addObject:identifier];
  }
  NSArray<NSString *> *saved =
      [[hidden allObjects] sortedArrayUsingSelector:@selector(compare:)];
  [NSUserDefaults.standardUserDefaults setObject:saved
                                           forKey:kKartPadHiddenTouchControlsKey];
  [NSUserDefaults.standardUserDefaults synchronize];
  if (showing) {
    for (UIView *control in self.subviews) {
      if (![KartPadVisibilityIdentifier(control) isEqualToString:identifier]) {
        continue;
      }
      control.hidden = NO;
      control.userInteractionEnabled = YES;
      control.alpha = 1.0;
    }
  }
  [self setNeedsLayout];
  [self layoutIfNeeded];
}

- (void)buildSettingsPanel {
  [super buildSettingsPanel];
  // Resolution belongs in Display. Remove the inherited duplicate row while
  // retaining the pinned SunPad implementation and the user's saved scale.
  UIView *resolution = KartPadSubviewWithAccessibilityLabel(
      self, @"Render resolution", UISegmentedControl.class);
  UIView *row = resolution.superview;
  if ([row.superview isKindOfClass:UIStackView.class]) {
    UIStackView *stack = (UIStackView *)row.superview;
    [stack removeArrangedSubview:row];
    [row removeFromSuperview];
    UISwitch *autoAccelerate = [UISwitch new];
    autoAccelerate.on = KartPadAutoAccelerateEnabled();
    autoAccelerate.accessibilityLabel = @"Touch auto-accelerate";
    autoAccelerate.accessibilityHint = @"Hold touch A for one second to lock acceleration. Turn off for normal hold controls.";
    [autoAccelerate addTarget:self action:@selector(kartPadAutoAccelerateChanged:)
            forControlEvents:UIControlEventValueChanged];
    [stack insertArrangedSubview:[self settingsRowWithTitle:@"Touch auto-accelerate" control:autoAccelerate]
                         atIndex:MIN((NSUInteger)3, stack.arrangedSubviews.count)];
    UISwitch *controllerAutoAccelerate = [UISwitch new];
    controllerAutoAccelerate.on = gKartPadControllerAutoAccelerate.load();
    controllerAutoAccelerate.accessibilityLabel = @"Controller auto-accelerate";
    controllerAutoAccelerate.accessibilityHint = @"Hold controller A for one second to lock acceleration. Press A again to release.";
    [controllerAutoAccelerate addTarget:self action:@selector(kartPadControllerAutoAccelerateChanged:)
                       forControlEvents:UIControlEventValueChanged];
    [stack insertArrangedSubview:[self settingsRowWithTitle:@"Controller auto-accelerate"
                                                    control:controllerAutoAccelerate]
                         atIndex:MIN((NSUInteger)4, stack.arrangedSubviews.count)];
  }
}

- (void)kartPadConfigureTouchLayoutEditor {
  UIButton *done = (UIButton *)KartPadSubviewWithAccessibilityLabel(
      self, @"Finish moving touch controls", UIButton.class);
  if (done == nil) return;

  [done setTitle:@"Back" forState:UIControlStateNormal];
  done.accessibilityHint = @"Saves the layout and returns to touch control settings.";
  [done removeTarget:self action:@selector(finishLayoutEditing)
     forControlEvents:UIControlEventTouchUpInside];
  [done removeTarget:self action:@selector(kartPadFinishLayoutEditing)
     forControlEvents:UIControlEventTouchUpInside];
  [done addTarget:self action:@selector(kartPadFinishLayoutEditing)
   forControlEvents:UIControlEventTouchUpInside];

  UIStackView *stack = [done.superview isKindOfClass:UIStackView.class]
      ? (UIStackView *)done.superview : nil;
  if (self.kartPadVisibilityButton == nil && stack != nil) {
    UIButton *visibility = [UIButton buttonWithType:UIButtonTypeSystem];
    [visibility setTitle:@"Hide" forState:UIControlStateNormal];
    [visibility setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    visibility.titleLabel.font =
        [UIFont systemFontOfSize:15.0 weight:UIFontWeightSemibold];
    visibility.backgroundColor = [UIColor colorWithWhite:0.18 alpha:0.96];
    visibility.layer.cornerRadius = 10.0;
    visibility.accessibilityLabel = @"Hide selected touch control";
    visibility.enabled = NO;
    [visibility addTarget:self
                   action:@selector(kartPadToggleSelectedControlVisibility)
         forControlEvents:UIControlEventTouchUpInside];
    [stack insertArrangedSubview:visibility
                         atIndex:MAX((NSInteger)stack.arrangedSubviews.count - 1,
                                     0)];
    [visibility.widthAnchor constraintEqualToConstant:68.0].active = YES;
    [visibility.heightAnchor constraintEqualToConstant:40.0].active = YES;
    self.kartPadVisibilityButton = visibility;
  }

  NSSet<NSString *> *hidden = KartPadHiddenTouchControls();
  BOOL editing = !KartPadViewIsEffectivelyHidden(done);
  for (UIView *control in self.subviews) {
    NSString *identifier = KartPadVisibilityIdentifier(control);
    if (identifier.length == 0 || ![hidden containsObject:identifier]) continue;
    control.hidden = !editing;
    control.userInteractionEnabled = editing;
    if (editing) control.alpha = 0.35;
  }

  NSString *selected = self.kartPadSelectedControlIdentifier;
  BOOL selectedHidden = selected.length > 0 && [hidden containsObject:selected];
  [self.kartPadVisibilityButton
      setTitle:selectedHidden ? @"Show" : @"Hide"
      forState:UIControlStateNormal];
  self.kartPadVisibilityButton.accessibilityLabel = selectedHidden
      ? @"Show selected touch control" : @"Hide selected touch control";
  self.kartPadVisibilityButton.enabled = selected.length > 0;
}

- (void)selectControlForEditing:(UIView *)control {
  [super selectControlForEditing:control];
  self.kartPadSelectedControlIdentifier =
      KartPadVisibilityIdentifier(control);
  [self kartPadConfigureTouchLayoutEditor];
}

- (void)resetLayout {
  [super resetLayout];
  [NSUserDefaults.standardUserDefaults
      removeObjectForKey:kKartPadHiddenTouchControlsKey];
  KartPadSeedTouchLayoutDefaults(YES);
  for (UIView *control in self.subviews) {
    if (KartPadVisibilityIdentifier(control).length == 0) continue;
    control.hidden = NO;
    control.userInteractionEnabled = YES;
    control.alpha = 1.0;
  }
  self.kartPadSelectedControlIdentifier = nil;
  [self setNeedsLayout];
}

- (void)toggleSettingsPanel {
  // Opening or closing a touch-modal must never leave a gameplay control held.
  // Keep this in KartPad's owner layer so the pinned SunPad snapshot remains
  // byte-identical to its upstream reference.
  [self clearTouchInput];
  [self resetKartPadControlAppearance];
  [super toggleSettingsPanel];
}

- (void)setTouchControlsHidden:(BOOL)hidden animated:(BOOL)animated {
  if (hidden) {
    [self clearTouchInput];
    [self resetKartPadControlAppearance];
  }
  [super setTouchControlsHidden:hidden animated:animated];
}

- (void)refreshMenuButton {
  // SunPad rebuilds its source menu after any inherited setting changes. Run
  // the KartPad rewrite immediately so that refreshes cannot expose the
  // Sunshine-specific title or performance switches on either device idiom.
  [super refreshMenuButton];
  [self setNeedsLayout];
  [self layoutIfNeeded];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  self.kartPadMoveStick.floatingEnabled =
      ![SunPadSettings sharedSettings].editingControlLayout;
  UIButton *menuButton = nil;
  UIButton *leftShoulder = nil;
  UIButton *rightShoulder = nil;
  UIButton *gasButton = nil;
  for (UIView *candidate in self.subviews) {
    if (![candidate isKindOfClass:UIButton.class]) continue;
    UIButton *button = (UIButton *)candidate;
    if ([button.accessibilityLabel isEqualToString:@"Menu"]) menuButton = button;
    if ([button.accessibilityLabel isEqualToString:@"L"]) leftShoulder = button;
    if ([button.accessibilityLabel isEqualToString:@"R"]) rightShoulder = button;
    if ([button.accessibilityLabel isEqualToString:@"A"]) gasButton = button;
  }

  KartPadConfigureMenuButton(menuButton);

  // Mario Kart's Classic R input is a normal digital shoulder button. Match
  // L exactly and suppress SunPad's Sunshine-specific pressure-fill artwork.
  if (leftShoulder != nil && rightShoulder != nil) {
    rightShoulder.bounds = CGRectMake(0.0, 0.0,
                                      CGRectGetWidth(leftShoulder.bounds),
                                      CGRectGetHeight(leftShoulder.bounds));
    rightShoulder.layer.cornerRadius =
        MIN(CGRectGetWidth(rightShoulder.bounds),
            CGRectGetHeight(rightShoulder.bounds)) * 0.5;
    rightShoulder.accessibilityHint = @"Drift, hop, brake, or reverse.";
    rightShoulder.accessibilityValue = @"Not pressed";
    for (CALayer *layer in rightShoulder.layer.sublayers) {
      if ([layer isKindOfClass:CAShapeLayer.class]) layer.hidden = YES;
    }
  }

  if (gasButton != nil && self.kartPadGasButton != gasButton) {
    self.kartPadGasButton = gasButton;
    self.kartPadGasRestColor = gasButton.backgroundColor;
    gasButton.accessibilityHint = KartPadAutoAccelerateEnabled()
        ? @"Hold for one second to lock acceleration. Tap again to unlock."
        : @"Hold to accelerate. Release to stop accelerating.";
    [gasButton addTarget:self action:@selector(kartPadGasDown:)
         forControlEvents:UIControlEventTouchDown];
    [gasButton addTarget:self action:@selector(kartPadGasUp:)
         forControlEvents:UIControlEventTouchUpInside |
                          UIControlEventTouchUpOutside |
                          UIControlEventTouchCancel];
#if TARGET_OS_SIMULATOR
    if (!self.kartPadGasHoldSelfTestStarted &&
        NSProcessInfo.processInfo.environment[@"KARTPAD_TOUCH_HOLD_SELF_TEST"] != nil) {
      self.kartPadGasHoldSelfTestStarted = YES;
      dispatch_async(dispatch_get_main_queue(), ^{
        [gasButton sendActionsForControlEvents:UIControlEventTouchDown];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(30.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
          [gasButton sendActionsForControlEvents:UIControlEventTouchUpInside];
        });
      });
    }
    if (!self.kartPadGasInputSelfTestStarted &&
        NSProcessInfo.processInfo.environment[@"KARTPAD_TOUCH_INPUT_SELF_TEST"] != nil) {
      self.kartPadGasInputSelfTestStarted = YES;
      dispatch_async(dispatch_get_main_queue(), ^{
        [gasButton sendActionsForControlEvents:UIControlEventTouchDown];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(1.1 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
          const SunPadInputState held =
              [[SunPadInputMixer sharedMixer] consumeMergedState];
          const KartPadClassicInputState heldClassic =
              kartpad::mobile::AdaptSunPadInput(held);
          const BOOL heldPassed =
              (heldClassic.buttons & kartpad::mobile::kClassicButtonA) != 0;
          gasButton.accessibilityValue = heldPassed
              ? @"Acceleration held · input verified"
              : @"Acceleration hold input test failed";
          NSLog(@"[KartPad] touch A hold self-test: %@ (classic=%08x)",
                heldPassed ? @"held pass" : @"held FAIL", heldClassic.buttons);
          [gasButton sendActionsForControlEvents:UIControlEventTouchUpInside];
          dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                       (int64_t)(0.1 * NSEC_PER_SEC)),
                         dispatch_get_main_queue(), ^{
            const SunPadInputState locked =
                [[SunPadInputMixer sharedMixer] consumeMergedState];
            const KartPadClassicInputState lockedClassic =
                kartpad::mobile::AdaptSunPadInput(locked);
            const BOOL lockPassed =
                (lockedClassic.buttons & kartpad::mobile::kClassicButtonA) != 0;
            [gasButton sendActionsForControlEvents:UIControlEventTouchDown];
            [gasButton sendActionsForControlEvents:UIControlEventTouchUpInside];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                         (int64_t)(0.1 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
              const KartPadClassicInputState unlockedClassic =
                  kartpad::mobile::AdaptSunPadInput(
                      [[SunPadInputMixer sharedMixer] consumeMergedState]);
              const BOOL unlockPassed =
                  (unlockedClassic.buttons & kartpad::mobile::kClassicButtonA) == 0;
              gasButton.accessibilityHint = lockPassed && unlockPassed
                  ? @"Hold-to-lock and tap-to-unlock input self-test passed."
                  : @"Acceleration lock input self-test failed.";
              NSLog(@"[KartPad] touch A lock self-test: %@ (locked=%08x unlocked=%08x)",
                    lockPassed && unlockPassed ? @"pass" : @"FAIL",
                    lockedClassic.buttons, unlockedClassic.buttons);
            });
          });
        });
      });
    }
    if (!self.kartPadModalInputSelfTestStarted && menuButton != nil &&
        NSProcessInfo.processInfo.environment[@"KARTPAD_TOUCH_MODAL_SELF_TEST"] != nil) {
      self.kartPadModalInputSelfTestStarted = YES;
      dispatch_async(dispatch_get_main_queue(), ^{
        [gasButton sendActionsForControlEvents:UIControlEventTouchDown];
        const KartPadClassicInputState before = kartpad::mobile::AdaptSunPadInput(
            [[SunPadInputMixer sharedMixer] consumeMergedState]);
        [self toggleSettingsPanel];
        const KartPadClassicInputState after = kartpad::mobile::AdaptSunPadInput(
            [[SunPadInputMixer sharedMixer] consumeMergedState]);
        const BOOL passed =
            (before.buttons & kartpad::mobile::kClassicButtonA) != 0 &&
            (after.buttons & kartpad::mobile::kClassicButtonA) == 0;
        menuButton.accessibilityHint = passed
            ? @"Touch settings input-clear self-test passed."
            : @"Touch settings input-clear self-test failed.";
        NSLog(@"[KartPad] touch modal input self-test: %@ (before=%08x after=%08x)",
              passed ? @"pass" : @"FAIL", before.buttons, after.buttons);
        [self toggleSettingsPanel];
      });
    }
    if (!self.kartPadEditorUITestStarted && menuButton != nil &&
        NSProcessInfo.processInfo.environment[@"KARTPAD_TOUCH_EDITOR_UI_TEST"] != nil) {
      self.kartPadEditorUITestStarted = YES;
      NSString *mode =
          NSProcessInfo.processInfo.environment[@"KARTPAD_TOUCH_EDITOR_UI_TEST"];
      dispatch_async(dispatch_get_main_queue(), ^{
        [self toggleSettingsPanel];
        [self layoutIfNeeded];
        UIScrollView *scroll = KartPadScrollableSettingsView(self);
        if (scroll == nil) {
          menuButton.accessibilityHint =
              @"Touch editor lower-row test failed: settings scroll view missing.";
          NSLog(@"[KartPad] touch editor UI test: FAIL (scroll view missing)");
          return;
        }
        const CGFloat bottom = MAX(-scroll.adjustedContentInset.top,
            scroll.contentSize.height - CGRectGetHeight(scroll.bounds) +
                scroll.adjustedContentInset.bottom);
        [scroll setContentOffset:CGPointMake(scroll.contentOffset.x, bottom)
                       animated:NO];
        menuButton.accessibilityHint = @"Touch editor lower rows exposed.";
        NSLog(@"[KartPad] touch editor UI test: lower rows exposed (offset=%.1f)",
              bottom);
        if ([mode isEqualToString:@"move"]) {
          UISwitch *move = (UISwitch *)KartPadSubviewWithAccessibilityLabel(
              self, @"Move touch controls", UISwitch.class);
          if (move == nil) {
            NSLog(@"[KartPad] touch editor UI test: FAIL (move switch missing)");
            return;
          }
          [move setOn:YES animated:NO];
          [move sendActionsForControlEvents:UIControlEventValueChanged];
          UIButton *aButton = (UIButton *)KartPadSubviewWithAccessibilityLabel(
              self, @"A", UIButton.class);
          if (aButton != nil) [self selectControlForEditing:aButton];
          UISlider *aSize = (UISlider *)KartPadSubviewWithAccessibilityLabel(
              self, @"A size", UISlider.class);
          if (aSize != nil) {
            aSize.value = 1.25;
            [aSize sendActionsForControlEvents:UIControlEventValueChanged];
          }
          UIButton *done = (UIButton *)KartPadSubviewWithAccessibilityLabel(
              self, @"Finish moving touch controls", UIButton.class);
          const BOOL sizePersisted = std::fabs(
              [[SunPadSettings sharedSettings] sizeScaleForControl:@"A"] -
              1.25) < 0.001;
          const BOOL passed = done != nil && !done.hidden && aSize.enabled &&
                              sizePersisted;
          menuButton.accessibilityHint = passed
              ? @"Touch editor selected and resized A."
              : @"Touch editor move-mode test failed.";
          NSLog(@"[KartPad] touch editor UI test: move/resize %@ (A=%.2f)",
                passed ? @"pass" : @"FAIL",
                [[SunPadSettings sharedSettings] sizeScaleForControl:@"A"]);
        } else if ([mode isEqualToString:@"reset"]) {
          [[NSUserDefaults standardUserDefaults]
              setObject:@{@"A" : NSStringFromCGPoint(CGPointMake(0.5, 0.5))}
                 forKey:@"SunPadControlOrigins"];
          [[NSUserDefaults standardUserDefaults] synchronize];
          UIButton *reset = (UIButton *)KartPadSubviewWithAccessibilityLabel(
              self, @"Reset This Device Layout", UIButton.class);
          if (reset == nil) {
            NSLog(@"[KartPad] touch editor UI test: FAIL (reset button missing)");
            return;
          }
          [reset sendActionsForControlEvents:UIControlEventTouchUpInside];
          NSLog(@"[KartPad] touch editor UI test: reset confirmation opened");
        }
      });
    }
#endif
  }

  [self kartPadConfigureTouchLayoutEditor];

  UIMenu *sourceMenu = menuButton.menu;
  if (sourceMenu == nil ||
      [sourceMenu.identifier isEqualToString:@"dev.kartpad.menu"]) {
    return;
  }

  __weak KartPadGameOverlay *weakSelf = self;
  UIAction *multiplayer =
      [UIAction actionWithTitle:@"Multiplayer…"
                          image:[UIImage systemImageNamed:@"person.2.fill"]
                     identifier:@"dev.kartpad.multiplayer"
                        handler:^(__kindof UIAction *action) {
                          (void)action;
                          if (weakSelf.multiplayerRequested != nil) {
                            weakSelf.multiplayerRequested();
                          }
                        }];
  UIAction *motionSteering =
      [UIAction actionWithTitle:@"Motion Steering…"
                          image:[UIImage systemImageNamed:@"gyroscope"]
                     identifier:@"dev.kartpad.motion-steering"
                        handler:^(__kindof UIAction *action) {
                          (void)action;
                          if (weakSelf.motionSteeringRequested != nil) {
                            weakSelf.motionSteeringRequested();
                          }
                        }];
  UIAction *experimentalWiimote =
      [UIAction actionWithTitle:@"Experimental Wii Remote + Nunchuk…"
                          image:[UIImage systemImageNamed:@"antenna.radiowaves.left.and.right"]
                     identifier:@"dev.kartpad.experimental-wiimote"
                        handler:^(__kindof UIAction *action) {
                          (void)action;
                          if (weakSelf.wiimoteRequested != nil) {
                            weakSelf.wiimoteRequested();
                          }
                        }];
  UIAction *fpsCounter = nil;
  UIAction *controllerMapping = nil;
  UIAction *touchControlSettings = nil;
  UIAction *reportProblem = nil;
  UIMenu *aspectRatio = nil;
  UIMenu *renderResolution = nil;
  UIMenu *gameData = nil;
  for (UIMenuElement *element in sourceMenu.children) {
    if ([element isKindOfClass:UIAction.class]) {
      UIAction *action = (UIAction *)element;
      if ([action.title isEqualToString:@"Show FPS Counter"]) {
        fpsCounter = action;
        continue;
      }
      if ([action.title isEqualToString:@"Controller Button Mapping…"]) {
        controllerMapping = [UIAction actionWithTitle:action.title image:action.image identifier:action.identifier handler:^(__kindof UIAction *selection){if(weakSelf.buttonMappingRequested)weakSelf.buttonMappingRequested();}];
        continue;
      }
      if ([action.title isEqualToString:@"Touch Control Settings…"]) {
        touchControlSettings = action;
        continue;
      }
      if ([action.title isEqualToString:@"Report a Problem…"]) {
        reportProblem = action;
        continue;
      }
      if ([action.title hasPrefix:@"Experimental Performance Mode"] ||
          [action.title hasPrefix:@"Experimental 60 FPS"]) {
        // These are Sunshine-specific experiments inherited from SunPad.
        // Mario Kart Wii already uses its retail 60 FPS cadence, and neither
        // setting changes KartPad's ahead-of-time runtime.
        continue;
      }
    }

    if ([element isKindOfClass:UIMenu.class] &&
        [element.title isEqualToString:@"Render Resolution"]) {
      renderResolution = (UIMenu *)element;
      continue;
    }
    if ([element isKindOfClass:UIMenu.class] &&
        [element.title isEqualToString:@"Aspect Ratio"]) {
      aspectRatio = (UIMenu *)element;
      continue;
    }
    if ([element isKindOfClass:UIMenu.class] &&
        [element.title isEqualToString:@"Game Data & Saves"]) {
      UIMenu *dataMenu = (UIMenu *)element;
      NSMutableArray<UIMenuElement *> *dataItems = [NSMutableArray array];
      for (UIMenuElement *dataElement in dataMenu.children) {
        if ([dataElement isKindOfClass:UIAction.class] &&
            [dataElement.title isEqualToString:@"Import from SunPad Folder"]) {
          UIAction *sourceAction = (UIAction *)dataElement;
          UIAction *replacement =
              [UIAction actionWithTitle:@"Import from Extracted Folder…"
                                  image:sourceAction.image
                             identifier:sourceAction.identifier
                                handler:^(__kindof UIAction *action) {
            (void)action;
            [weakSelf.delegate gameOverlayRequestsGameDataFolderImport:weakSelf];
          }];
          replacement.attributes = sourceAction.attributes;
          replacement.state = sourceAction.state;
          replacement.discoverabilityTitle = sourceAction.discoverabilityTitle;
          [dataItems addObject:replacement];
        } else {
          if ([dataElement isKindOfClass:UIAction.class]) {
            UIAction *renamed = (UIAction *)dataElement;
            if ([renamed.title isEqualToString:@"Import or Reimport Game Data"]) renamed.title = @"Import or Reimport Wii Disc Image…";
            if ([renamed.title isEqualToString:@"Remove Stored Game Data"]) renamed.title = @"Remove Stored Game Data…";
          }
          [dataItems addObject:dataElement];
        }
      }
      UIAction *miiManager =
          [UIAction actionWithTitle:@"Player Identity…"
                              image:[UIImage systemImageNamed:@"person.crop.circle.badge.plus"]
                         identifier:@"dev.kartpad.manage-miis"
                            handler:^(__kindof UIAction *action) {
        (void)action;
        if (weakSelf.miiManagerRequested != nil) {
          weakSelf.miiManagerRequested();
        }
      }];
      [dataItems insertObject:miiManager atIndex:0];
      [dataItems insertObject:[UIAction actionWithTitle:@"Time Trial Ghosts (.rkg)…" image:[UIImage systemImageNamed:@"flag.checkered"] identifier:nil handler:^(__kindof UIAction *action) {
        if (weakSelf.ghostManagerRequested) weakSelf.ghostManagerRequested();
      }] atIndex:1];
      [dataItems insertObject:[UIAction actionWithTitle:@"Manage Saves…" image:[UIImage systemImageNamed:@"externaldrive"] identifier:nil handler:^(__kindof UIAction *action) { if (weakSelf.saveManagerRequested) weakSelf.saveManagerRequested(); }] atIndex:2];
      [dataItems insertObject:[UIAction actionWithTitle:@"Manage Retro Rewind…" image:[UIImage systemImageNamed:@"arrow.clockwise"] identifier:nil handler:^(__kindof UIAction *action) { if (weakSelf.retroManagerRequested) weakSelf.retroManagerRequested(); }] atIndex:3];
      gameData = [UIMenu menuWithTitle:dataMenu.title
                                 image:[UIImage systemImageNamed:@"externaldrive"]
                            identifier:dataMenu.identifier
                               options:dataMenu.options
                              children:dataItems];
      continue;
    }
  }

  NSMutableArray<UIMenuElement *> *controlItems = [NSMutableArray array];
  if (controllerMapping != nil) [controlItems addObject:controllerMapping];
  if (touchControlSettings != nil) [controlItems addObject:touchControlSettings];
  [controlItems addObject:[UIAction actionWithTitle:@"Controller Player Setup…" image:[UIImage systemImageNamed:@"gamecontroller"] identifier:nil handler:^(__kindof UIAction *action) { [weakSelf.delegate gameOverlayRequestsControllerMapping:weakSelf]; }]];
  [controlItems addObject:motionSteering];
  [controlItems addObject:experimentalWiimote];
  UIMenu *controls =
      [UIMenu menuWithTitle:@"Controls"
                      image:[UIImage systemImageNamed:@"gamecontroller"]
                 identifier:@"dev.kartpad.controls"
                    options:0
                   children:controlItems];

  NSMutableArray<UIMenuElement *> *displayItems = [NSMutableArray array];
  if (aspectRatio != nil) [displayItems addObject:aspectRatio];
  if (renderResolution != nil) [displayItems addObject:renderResolution];
  NSMutableArray *sizes=[NSMutableArray array];
  NSArray *sizeNames=@[@"Small",@"Medium",@"Large"];
  for (NSInteger index=0;index<3;++index) {
    UIAction *size=[UIAction actionWithTitle:sizeNames[index] image:nil identifier:nil handler:^(__kindof UIAction *action) {
      [NSUserDefaults.standardUserDefaults setInteger:index forKey:@"KartPadFPSCounterSize"];
      gKartPadFpsScale.store(index==0?1.0f:index==1?1.5f:2.0f,std::memory_order_relaxed);
      [weakSelf refreshMenuButton];
    }];
    size.state=[NSUserDefaults.standardUserDefaults integerForKey:@"KartPadFPSCounterSize"]==index ? UIMenuElementStateOn : UIMenuElementStateOff;
    [sizes addObject:size];
  }
  [displayItems addObject:[UIMenu menuWithTitle:@"FPS Counter Size" children:sizes]];
  UIMenu *display =
      [UIMenu menuWithTitle:@"Display"
                      image:[UIImage systemImageNamed:@"display"]
                 identifier:@"dev.kartpad.display"
                    options:0
                   children:displayItems];

  NSMutableArray<UIMenuElement *> *children = [NSMutableArray array];
  [children addObject:[UIAction actionWithTitle:@"Return to KartPad Menu"
      image:[UIImage systemImageNamed:@"house"] identifier:@"dev.kartpad.main-menu"
      handler:^(__kindof UIAction *action) {
    if (weakSelf.mainMenuRequested) weakSelf.mainMenuRequested();
  }]];
  [children addObject:multiplayer];
  if (fpsCounter != nil) [children addObject:fpsCounter];
  [children addObject:controls];
  [children addObject:display];
  if (gameData != nil) [children addObject:gameData];
  if (reportProblem != nil) [children addObject:reportProblem];
  if (KartPadSystemDiagnosticsIsCandidate()) {
    [children addObject:[UIAction actionWithTitle:@"Test Native Crash…"
        image:[UIImage systemImageNamed:@"exclamationmark.triangle"] identifier:nil
        handler:^(__kindof UIAction *action) {
      UIViewController *presenter = KartPadVisibleViewController(weakSelf.window);
      UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Test Native Crash?"
          message:@"This intentionally closes KartPad to test crash reporting. Finish your race first. Reopen KartPad afterward and export the test session. Unsaved progress may be lost."
          preferredStyle:UIAlertControllerStyleAlert];
      [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
      [confirm addAction:[UIAlertAction actionWithTitle:@"Crash Test" style:UIAlertActionStyleDestructive
          handler:^(UIAlertAction *action) { KartPadDiagnosticCrashProbe(); }]];
      [presenter presentViewController:confirm animated:YES completion:nil];
    }]];
  }

  menuButton.menu = [UIMenu menuWithTitle:@"KartPad"
                                    image:sourceMenu.image
                               identifier:@"dev.kartpad.menu"
                                  options:sourceMenu.options
                                 children:children];
}

- (void)reportProblem {
  UIViewController *presenter=KartPadVisibleViewController(self.window);if(!presenter)return;
  KartPadReportFormController *form=[KartPadReportFormController new];
  __weak KartPadGameOverlay *weakSelf=self;
  form.submit=^(NSDictionary *answers,BOOL github){[weakSelf createDiagnosticReportWithAnswers:answers openGitHub:github];};
  UINavigationController *navigation=[[UINavigationController alloc] initWithRootViewController:form];navigation.modalPresentationStyle=UIModalPresentationFormSheet;
  [presenter presentViewController:navigation animated:YES completion:nil];
}

- (void)createDiagnosticReportWithAnswers:(NSDictionary<NSString *,NSString *> *)answers openGitHub:(BOOL)openGitHub {
  NSString *reportID = [NSString stringWithFormat:@"KP-%@",
      [[[NSUUID UUID] UUIDString] substringToIndex:8]];
  NSString *technicalContext = [self.delegate gameOverlayDiagnosticContext:self];
  UIViewController *presenter = KartPadVisibleViewController(self.window);
  if (presenter == nil) return;
  UIAlertController *preparing = [UIAlertController alertControllerWithTitle:@"Preparing Report…"
      message:@"Collecting recent diagnostics. Nothing is uploaded."
      preferredStyle:UIAlertControllerStyleAlert];
  [presenter presentViewController:preparing animated:YES completion:^{
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
      SunPadLog(@"diagnostic report requested id=%@ destination=%@",
                reportID, openGitHub ? @"github" : @"share-sheet");
      NSError *error = nil;
      NSURL *reportURL = SunPadDiagnosticsReportURL(
          reportID, answers, technicalContext, &error);
      NSString *report = reportURL ? [NSString stringWithContentsOfURL:reportURL
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error] : nil;
      NSURL *kartPadReportURL = nil;
      if (report != nil) {
        report = [report stringByAppendingString:KartPadSystemDiagnosticsReport()];
        report = [report stringByReplacingOccurrencesOfString:
            @"SunPad Diagnostic Report v2" withString:@"KartPad Diagnostic Report v2"];
        report = [report stringByReplacingOccurrencesOfString:
            @"issuesURL=https://github.com/chrissotraidis/sunpad/issues"
                                                     withString:
            @"issuesURL=https://github.com/chrissotraidis/kartpad/issues"];
        report = [report stringByAppendingString:
            @"\nreportOrigin=KartPad (modified WiiCompiled platform integration)\n"
             "upstreamProject=https://github.com/patchzyy/Wiicompiled\n"];
        NSString *candidateBaseline = [NSBundle.mainBundle objectForInfoDictionaryKey:@"KartPadCandidateNativeBaseline"];
        NSString *candidateAdapter = [NSBundle.mainBundle objectForInfoDictionaryKey:@"KartPadCandidateReportingSHA256"];
        if (candidateBaseline.length > 0 && candidateAdapter.length > 0) {
          report = [report stringByAppendingFormat:
              @"candidateScope=reporting adapter rebuild; native baseline retained\nnativeBaseline=%@\nreportingAdapterSHA256=%@\n",
              candidateBaseline, candidateAdapter];
        }
        NSURL *destination = [reportURL.URLByDeletingLastPathComponent
            URLByAppendingPathComponent:@"Latest-KartPad-Diagnostic.log"];
        if ([report writeToURL:destination atomically:YES
                     encoding:NSUTF8StringEncoding error:&error]) {
          kartPadReportURL = destination;
        }
      }
      reportURL = kartPadReportURL;
      dispatch_async(dispatch_get_main_queue(), ^{
        [preparing dismissViewControllerAnimated:YES completion:^{
          if (reportURL == nil && !openGitHub) {
            UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:@"Diagnostic Report Unavailable"
                                                    message:error.localizedDescription ?: @"The report could not be prepared. Try again or report on GitHub without a log."
                                             preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                                      style:UIAlertActionStyleDefault
                                                    handler:nil]];
            [presenter presentViewController:alert animated:YES completion:nil];
            return;
          }

          if (openGitHub) {
            KartPadReportReviewController *review = [[KartPadReportReviewController alloc] init];
            review.reportURL = reportURL;
            __weak KartPadGameOverlay *weakSelf = self;
            review.continueReport = ^(NSString *evidence) {
              NSMutableDictionary *reviewedAnswers = [answers mutableCopy];
              reviewedAnswers[@"diagnostics"] = evidence;
              [weakSelf chooseReportDestinationWithID:reportID answers:reviewedAnswers];
            };
            UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:review];
            navigation.modalPresentationStyle = UIModalPresentationFormSheet;
            [presenter presentViewController:navigation animated:YES completion:nil];
            return;
          }

          UIActivityViewController *share =
              [[UIActivityViewController alloc] initWithActivityItems:@[reportURL]
                                               applicationActivities:nil];
          UIPopoverPresentationController *popover = share.popoverPresentationController;
          UIButton *menuButton = (UIButton *)KartPadSubviewWithAccessibilityLabel(
              self, @"Menu", UIButton.class);
          popover.sourceView = menuButton ?: self;
          popover.sourceRect = menuButton != nil ? menuButton.bounds : self.bounds;
          [presenter presentViewController:share animated:YES completion:nil];
        }];
      });
    });
  }];
}

- (void)chooseReportDestinationWithID:(NSString *)reportID
                               answers:(NSDictionary<NSString *, NSString *> *)answers {
  UIAlertController *choice = [UIAlertController alertControllerWithTitle:@"Where should this report go?"
      message:@"KartPad: device, controls, setup, or unsure. WiiCompiled: a known shared runtime issue. Search both trackers to find an existing report. Your description and reviewed log stay available."
      preferredStyle:UIAlertControllerStyleAlert];
  [choice addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  __weak KartPadGameOverlay *weakSelf = self;
  [choice addAction:[UIAlertAction actionWithTitle:@"KartPad" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [choice dismissViewControllerAnimated:YES completion:^{
      [weakSelf openGitHubReportWithID:reportID answers:answers upstream:NO];
    }];
  }]];
  [choice addAction:[UIAlertAction actionWithTitle:@"WiiCompiled" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [choice dismissViewControllerAnimated:YES completion:^{
      UIAlertController *kind = [UIAlertController alertControllerWithTitle:@"WiiCompiled Report"
          message:@"Choose a report type. Only confirm upstream checks you have actually tested."
          preferredStyle:UIAlertControllerStyleAlert];
      NSArray<NSString *> *titles = @[@"Crash or Freeze", @"Other Bug", @"Performance"];
      NSArray<NSString *> *templates = @[@"1-crash-report.yml", @"2-bug-report.yml", @"4-performance.yml"];
      for (NSUInteger index = 0; index < titles.count; ++index) {
        NSString *reportTemplate = templates[index];
        [kind addAction:[UIAlertAction actionWithTitle:titles[index] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
          NSMutableDictionary *typedAnswers = [answers mutableCopy];
          typedAnswers[@"upstreamTemplate"] = reportTemplate;
          [kind dismissViewControllerAnimated:YES completion:^{
            [weakSelf openGitHubReportWithID:reportID answers:typedAnswers upstream:YES];
          }];
        }]];
      }
      [kind addAction:[UIAlertAction actionWithTitle:@"Back" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [kind dismissViewControllerAnimated:YES completion:^{
          [weakSelf chooseReportDestinationWithID:reportID answers:answers];
        }];
      }]];
      [KartPadVisibleViewController(weakSelf.window) presentViewController:kind animated:YES completion:nil];
    }];
  }]];
  [choice addAction:[UIAlertAction actionWithTitle:@"Search Both Trackers" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [choice dismissViewControllerAnimated:YES completion:^{
      [weakSelf presentReportBrowserURL:[NSURL URLWithString:@"https://github.com/search?q=is%3Aissue+repo%3Achrissotraidis%2Fkartpad+repo%3Apatchzyy%2FWiicompiled&type=issues"]];
    }];
  }]];
  [KartPadVisibleViewController(self.window) presentViewController:choice animated:YES completion:nil];
}

- (void)openGitHubReportWithID:(NSString *)reportID
                       answers:(NSDictionary<NSString *, NSString *> *)answers
                      upstream:(BOOL)upstream {
  NSBundle *bundle = NSBundle.mainBundle;
  NSString *version = [bundle objectForInfoDictionaryKey:
      @"CFBundleShortVersionString"] ?: @"unknown";
  NSString *build = [bundle objectForInfoDictionaryKey:
      @"CFBundleVersion"] ?: @"unknown";
  UIDevice *device = UIDevice.currentDevice;
  // Device family and OS only: never include the user-assigned name or identifiers.
  NSString *platform = [NSString stringWithFormat:@"%@, %@ %@ (add exact model if known)",
      device.model, device.systemName, device.systemVersion];
  NSString *problem = answers[@"problem"].length > 0
      ? answers[@"problem"] : @"KartPad problem";
  if (problem.length > 100) problem = [problem substringToIndex:100];
  NSURLComponents *components = [NSURLComponents componentsWithString:
      @"https://github.com/chrissotraidis/kartpad/issues/new"];
  components.queryItems = @[
    [NSURLQueryItem queryItemWithName:@"template" value:@"bug_report.yml"],
    [NSURLQueryItem queryItemWithName:@"title"
                                value:[NSString stringWithFormat:@"[Bug]: %@", problem]],
    [NSURLQueryItem queryItemWithName:@"report-id" value:reportID],
    [NSURLQueryItem queryItemWithName:@"revision"
                                value:[NSString stringWithFormat:@"%@ (build %@)",
                                                                   version, build]],
    [NSURLQueryItem queryItemWithName:@"platform" value:platform],
    [NSURLQueryItem queryItemWithName:@"performance-profile"
                                value:[self.delegate gameOverlayPerformanceProfile:self]],
    [NSURLQueryItem queryItemWithName:@"summary" value:answers[@"problem"]],
    [NSURLQueryItem queryItemWithName:@"context" value:[NSString stringWithFormat:
        @"Report origin: KartPad (modified WiiCompiled platform integration).\n%@",
        answers[@"context"] ?: @""]],
    [NSURLQueryItem queryItemWithName:@"frequency" value:answers[@"frequency"]],
    [NSURLQueryItem queryItemWithName:@"diagnostics" value:answers[@"diagnostics"] ?: @"Diagnostic log not attached."],
  ];
  if (upstream) {
    NSString *reportTemplate = answers[@"upstreamTemplate"] ?: @"2-bug-report.yml";
    NSString *prefix = [reportTemplate isEqualToString:@"1-crash-report.yml"] ? @"Crash"
        : ([reportTemplate isEqualToString:@"4-performance.yml"] ? @"Perf" : @"Bug");
    components = [NSURLComponents componentsWithString:@"https://github.com/patchzyy/Wiicompiled/issues/new"];
    components.queryItems = @[
      [NSURLQueryItem queryItemWithName:@"template" value:reportTemplate],
      [NSURLQueryItem queryItemWithName:@"title" value:[NSString stringWithFormat:@"[%@] [KartPad] %@", prefix, problem]],
      [NSURLQueryItem queryItemWithName:@"version" value:[NSString stringWithFormat:
          @"KartPad %@ (build %@), modified WiiCompiled integration; not verified on latest stock WiiCompiled", version, build]],
      [NSURLQueryItem queryItemWithName:@"what" value:answers[@"problem"] ?: @""],
      [NSURLQueryItem queryItemWithName:@"doing" value:[NSString stringWithFormat:
          @"KartPad report %@. %@\nFrequency: %@\n%@", reportID, answers[@"problem"] ?: @"", answers[@"frequency"] ?: @"", answers[@"context"] ?: @""]],
      [NSURLQueryItem queryItemWithName:@"os" value:platform],
      [NSURLQueryItem queryItemWithName:@"gpu" value:@"Apple device, Metal; exact GPU not collected"],
      [NSURLQueryItem queryItemWithName:@"logs" value:answers[@"diagnostics"] ?: @"Diagnostic log not attached."],
    ];
  }
  NSURL *url = components.URL;
  if (url == nil) return;
  [self presentReportBrowserURL:url];
}

- (void)presentReportBrowserURL:(NSURL *)url {
  self.reportDraftURL = url;
  SFSafariViewController *browser = [[SFSafariViewController alloc] initWithURL:url];
  browser.delegate = self;
  [KartPadVisibleViewController(self.window) presentViewController:browser animated:YES completion:nil];
}

- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully {
  if (didLoadSuccessfully) return;
  NSURL *url = self.reportDraftURL;
  UIAlertController *failure = [UIAlertController alertControllerWithTitle:@"GitHub Could Not Be Loaded"
      message:@"Your report is still available. Retry, copy the draft link, or return to your report."
      preferredStyle:UIAlertControllerStyleAlert];
  __weak KartPadGameOverlay *weakSelf = self;
  [failure addAction:[UIAlertAction actionWithTitle:@"Retry" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [controller.presentingViewController dismissViewControllerAnimated:YES completion:^{ [weakSelf presentReportBrowserURL:url]; }];
  }]];
  [failure addAction:[UIAlertAction actionWithTitle:@"Copy Draft Link" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    UIPasteboard.generalPasteboard.URL = url;
  }]];
  [failure addAction:[UIAlertAction actionWithTitle:@"Back to Report" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
    [controller.presentingViewController dismissViewControllerAnimated:YES completion:nil];
  }]];
  [controller presentViewController:failure animated:YES completion:nil];
}

- (void)rPressureChanged:(uint8_t)pressure fullPress:(BOOL)fullPress {
  (void)fullPress;
  const BOOL pressed = pressure > 0;
  [super rPressureChanged:pressed ? 255 : 0 fullPress:pressed];
}

- (void)kartPadControllerAutoAccelerateChanged:(UISwitch *)sender {
  [NSUserDefaults.standardUserDefaults setBool:sender.on
                                        forKey:kKartPadControllerAutoAccelerateKey];
  gKartPadControllerAutoAccelerate.store(sender.on);
}

- (void)kartPadAutoAccelerateChanged:(UISwitch *)sender {
  [NSUserDefaults.standardUserDefaults setBool:sender.on forKey:kKartPadAutoAccelerateKey];
  ++self.kartPadGasHoldGeneration;
  if (!sender.on && self.kartPadGasLocked) {
    self.kartPadGasLocked = NO;
    if (!self.kartPadGasPressed) [super buttonUp:self.kartPadGasButton];
    self.kartPadGasButton.backgroundColor = self.kartPadGasRestColor;
    self.kartPadGasButton.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.36].CGColor;
    self.kartPadGasButton.layer.shadowOpacity = 0.0;
    self.kartPadGasButton.accessibilityValue = nil;
  }
  self.kartPadGasButton.accessibilityHint = sender.on
      ? @"Hold for one second to lock acceleration. Tap again to unlock."
      : @"Hold to accelerate. Release to stop accelerating.";
}

- (void)kartPadGasDown:(UIButton *)button {
  self.kartPadGasPressed = YES;
  const NSUInteger generation = ++self.kartPadGasHoldGeneration;
  if (self.kartPadGasLocked) {
    // The next ordinary tap releases a previously locked accelerator. The
    // inherited touch-up action clears A after this touch ends.
    self.kartPadGasLocked = NO;
    button.backgroundColor = self.kartPadGasRestColor;
    button.layer.borderColor =
        [UIColor colorWithWhite:1.0 alpha:0.36].CGColor;
    button.layer.shadowOpacity = 0.0;
    button.accessibilityValue = @"Unlocking acceleration";
    return;
  }
  if (!KartPadAutoAccelerateEnabled()) return;
  __weak KartPadGameOverlay *weakSelf = self;
  __weak UIButton *weakButton = button;
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
    KartPadGameOverlay *strongSelf = weakSelf;
    UIButton *strongButton = weakButton;
    if (strongSelf == nil || strongButton == nil ||
        !strongSelf.kartPadGasPressed || !KartPadAutoAccelerateEnabled() ||
        strongSelf.kartPadGasHoldGeneration != generation) {
      return;
    }
    strongSelf.kartPadGasLocked = YES;
    strongButton.backgroundColor =
        [UIColor colorWithRed:0.06 green:0.78 blue:0.92 alpha:0.98];
    strongButton.layer.borderColor = UIColor.whiteColor.CGColor;
    strongButton.layer.shadowColor =
        [UIColor colorWithRed:0.06 green:0.78 blue:0.92 alpha:1.0].CGColor;
    strongButton.layer.shadowOpacity = 0.9;
    strongButton.layer.shadowRadius = 9.0;
    strongButton.layer.shadowOffset = CGSizeZero;
    strongButton.accessibilityValue = @"Acceleration locked";
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleLight];
    [feedback impactOccurred];
  });
}

- (void)kartPadGasUp:(UIButton *)button {
  self.kartPadGasPressed = NO;
  ++self.kartPadGasHoldGeneration;
  if (self.kartPadGasLocked) {
    // SunPad's existing touch-up action clears A. Reassert it after all targets
    // for this UIKit event finish so the lock survives the finger lifting.
    __weak KartPadGameOverlay *weakSelf = self;
    __weak UIButton *weakButton = button;
    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadGameOverlay *strongSelf = weakSelf;
      UIButton *strongButton = weakButton;
      if (strongSelf == nil || strongButton == nil ||
          !strongSelf.kartPadGasLocked) {
        return;
      }
      [super buttonDown:strongButton];
      strongButton.transform = CGAffineTransformIdentity;
    });
    return;
  }
  button.backgroundColor = self.kartPadGasRestColor;
  button.layer.borderColor =
      [UIColor colorWithWhite:1.0 alpha:0.36].CGColor;
  button.layer.shadowOpacity = 0.0;
  button.accessibilityValue = nil;
}

- (void)resetKartPadControlAppearance {
  self.kartPadGasPressed = NO;
  self.kartPadGasLocked = NO;
  ++self.kartPadGasHoldGeneration;
  if (self.kartPadGasButton != nil) {
    self.kartPadGasButton.backgroundColor = self.kartPadGasRestColor;
    self.kartPadGasButton.layer.borderColor =
        [UIColor colorWithWhite:1.0 alpha:0.36].CGColor;
    self.kartPadGasButton.layer.shadowOpacity = 0.0;
    self.kartPadGasButton.accessibilityValue = nil;
  }
}

@end

@implementation KartPadRuntimeOverlayHost {
  __weak UIWindow *_window;
  SDL_Window *_sdlWindow;
  SunPadGameOverlay *_overlay;
  UIAlertController *_gameDataProgressAlert;
  BOOL _choosingMiiImport;
  BOOL _choosingGhostImport;
  NSString *_saveImportProfile;
  NSUInteger _ghostLicense;
}

- (instancetype)initWithSDLWindow:(SDL_Window *)window {
  self = [super init];
  if (self == nil || window == nullptr) {
    return nil;
  }

  NSInteger fpsSize=[NSUserDefaults.standardUserDefaults integerForKey:@"KartPadFPSCounterSize"];
  gKartPadFpsScale.store(fpsSize==0?1.0f:fpsSize==1?1.5f:2.0f,std::memory_order_relaxed);
  _sdlWindow = window;
  SDL_PropertiesID properties = SDL_GetWindowProperties(window);
  UIWindow *uiWindow = (__bridge UIWindow *)SDL_GetPointerProperty(
      properties, SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, nullptr);
  UIView *container = uiWindow.rootViewController.view;
  if (uiWindow == nil || container == nil) {
    NSLog(@"[KartPad] SDL UIKit window is unavailable for the touch overlay");
    return nil;
  }

  _window = uiWindow;
  KartPadGameOverlay *overlay =
      [[KartPadGameOverlay alloc] initWithFrame:container.bounds];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  overlay.multiplayerRequested = ^{
    [weakSelf showMultiplayerAccess];
  };
  overlay.mainMenuRequested = ^{
    gKartPadMainMenuRequested = YES;
  };
  overlay.motionSteeringRequested = ^{
    [weakSelf showMotionSteering];
  };
  overlay.ghostManagerRequested = ^{ [weakSelf showGhostManager]; };
  overlay.saveManagerRequested = ^{ [weakSelf showSaveManager]; };
  overlay.buttonMappingRequested = ^{ [weakSelf showControllerButtonMapping]; };
  overlay.retroManagerRequested = ^{ [weakSelf showRetroManager]; };
  overlay.miiManagerRequested = ^{
    [weakSelf showMiiManager];
  };
  NSString *preview=NSProcessInfo.processInfo.environment[@"KARTPAD_UI_PREVIEW"];
  (void)preview;
  overlay.wiimoteRequested = ^{
    [weakSelf showExperimentalWiimoteInfo];
  };
  _overlay = overlay;
  _overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                              UIViewAutoresizingFlexibleHeight;
  _overlay.backgroundColor = UIColor.clearColor;
  _overlay.delegate = self;
  [container addSubview:_overlay];
  [container bringSubviewToFront:_overlay];
  [[KartPadPhysicalControllers sharedControllers] start];
  [[KartPadMotionSteering sharedSteering] start];

  NSNotificationCenter *notifications = NSNotificationCenter.defaultCenter;
  [notifications addObserver:self
                     selector:@selector(applicationWillResignActive:)
                         name:UIApplicationWillResignActiveNotification
                       object:nil];
  [notifications addObserver:self
                     selector:@selector(applicationDidBecomeActive:)
                         name:UIApplicationDidBecomeActiveNotification
                       object:nil];
  [notifications addObserver:self
                     selector:@selector(userDidTakeScreenshot:)
                         name:UIApplicationUserDidTakeScreenshotNotification
                       object:nil];
  SunPadDiagnosticsStart();
  NSLog(@"[KartPad] exact SunPad runtime overlay installed");
  return self;
}

- (void)showReportPreview {
  [self reattachOverlayIfNeeded];
  SunPadLog(@"UI preview report requested window=%d main=%d",_overlay.window!=nil,NSThread.isMainThread);
  [_overlay reportProblem];
}

- (void)reattachOverlayIfNeeded {
  if (_overlay == nil || _sdlWindow == nullptr) return;
  SDL_PropertiesID properties = SDL_GetWindowProperties(_sdlWindow);
  UIWindow *window = (__bridge UIWindow *)SDL_GetPointerProperty(
      properties, SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER, nullptr);
  UIView *container = window.rootViewController.view;
  if (window == nil || container == nil) {
    NSLog(@"[KartPad] SDL UIKit window is unavailable during overlay recovery");
    return;
  }
  _window = window;
  if (_overlay.superview != container) {
    [_overlay removeFromSuperview];
    _overlay.frame = container.bounds;
    [container addSubview:_overlay];
    NSLog(@"[KartPad] touch overlay reattached after UIKit surface change");
  }
  _overlay.hidden = NO;
  _overlay.alpha = 1.0;
  [container bringSubviewToFront:_overlay];
  [_overlay setNeedsLayout];
  [_overlay layoutIfNeeded];
  UIButton *menuButton = KartPadFindMenuButton(_overlay);
  KartPadConfigureMenuButton(menuButton);
  menuButton.selected = NO;
  menuButton.highlighted = NO;
  menuButton.hidden = NO;
  menuButton.alpha = 1.0;
}

- (void)userDidTakeScreenshot:(NSNotification *)notification {
  (void)notification;
  // The screenshot notification arrives after capture. Reassert the app-owned
  // overlay immediately and once more on the next run-loop pass so UIKit's
  // transient screenshot/menu state cannot leave the persistent button hidden.
  [self reattachOverlayIfNeeded];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [weakSelf reattachOverlayIfNeeded];
  });
}

- (void)showMotionSteering {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  KartPadMotionSteering *motion = [KartPadMotionSteering sharedSteering];
  NSString *status = motion.sensorAvailable
      ? [NSString stringWithFormat:
            @"Tilt steering: %@. Shake tricks/wheelies: %@. Sensitivity: %.1fx. Physical controllers take priority.",
            motion.enabled ? @"On" : @"Off",
            motion.shakeTricksEnabled ? @"On" : @"Off", motion.sensitivity]
      : @"Motion data is unavailable on this device or Simulator. Touch and physical-controller steering remain available.";
  UIAlertController *sheet =
      [UIAlertController alertControllerWithTitle:@"Motion Steering"
                                          message:status
                                   preferredStyle:UIAlertControllerStyleActionSheet];
  if (motion.sensorAvailable) {
    [sheet addAction:[UIAlertAction
        actionWithTitle:motion.enabled ? @"Turn Off" : @"Turn On & Recenter"
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
      (void)action;
      motion.enabled = !motion.enabled;
      if (motion.enabled) [motion recenter];
    }]];
    if (motion.enabled) {
      [sheet addAction:[UIAlertAction actionWithTitle:@"Recenter Now"
                                               style:UIAlertActionStyleDefault
                                             handler:^(UIAlertAction *action) {
        (void)action;
        [motion recenter];
      }]];
    }
    [sheet addAction:[UIAlertAction
        actionWithTitle:motion.inverted ? @"Use Standard Direction" : @"Invert Direction"
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
      (void)action;
      motion.inverted = !motion.inverted;
    }]];
    [sheet addAction:[UIAlertAction
        actionWithTitle:motion.shakeTricksEnabled
            ? @"Disable Shake Tricks/Wheelies"
            : @"Enable Shake Tricks/Wheelies"
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
      (void)action;
      motion.shakeTricksEnabled = !motion.shakeTricksEnabled;
    }]];
    [sheet addAction:[UIAlertAction
        actionWithTitle:@"Cycle Sensitivity"
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
      (void)action;
      const float current = motion.sensitivity;
      motion.sensitivity = current < 0.75f ? 1.0f : (current < 1.5f ? 2.0f : 0.5f);
    }]];
  }
  [sheet addAction:[UIAlertAction actionWithTitle:@"Continue Playing"
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
  UIPopoverPresentationController *popover = sheet.popoverPresentationController;
  popover.sourceView = _overlay;
  popover.sourceRect = CGRectMake(CGRectGetMidX(_overlay.bounds),
                                  CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:sheet animated:YES completion:nil];
}

// UIAlertAction handlers run before UIKit finishes dismissing their alert.
// Present the next screen only after that transition completes.
- (void)presentOverlayAlert:(UIAlertController *)alert {
  UIPopoverPresentationController *popover = alert.popoverPresentationController;
  popover.sourceView = _overlay;
  popover.sourceRect = CGRectMake(CGRectGetMidX(_overlay.bounds),
      CGRectGetMidY(_overlay.bounds), 1, 1);
  dispatch_async(dispatch_get_main_queue(), ^{
    UIViewController *presenter = KartPadVisibleViewController(self->_window);
    if (presenter == nil) return;
    void (^present)(void) = ^{
      dispatch_async(dispatch_get_main_queue(), ^{
        [KartPadVisibleViewController(self->_window)
            presentViewController:alert animated:YES completion:nil];
      });
    };
    if ([presenter isKindOfClass:UIAlertController.class]) {
      if (presenter.isBeingDismissed && presenter.transitionCoordinator) {
        [presenter.transitionCoordinator animateAlongsideTransition:nil
            completion:^(id<UIViewControllerTransitionCoordinatorContext> context) { present(); }];
      } else {
        [presenter dismissViewControllerAnimated:YES completion:present];
      }
    } else {
      present();
    }
  });
}

- (void)showMultiplayerMessage:(NSString *)title message:(NSString *)message {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
      message:message preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:alert];
}

- (void)runMainMenu {
  // Called by the guest's event pump, after the menu action has returned.
  // This keeps the current guest stack suspended while UIKit stays responsive.
  gKartPadMainMenuRequested = NO;
  [(KartPadGameOverlay *)_overlay resetKartPadControlAppearance];
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  [[KartPadMotionSteering sharedSteering] stop];
  AudioBackend::Instance().SetPausedForHost(true);
  __block BOOL finished = NO;
  KartPadFirstLaunchViewController *root = [[KartPadFirstLaunchViewController alloc] init];
  root.resumingGame = YES;
  root.gameDataReady = YES;
  root.currentRetroRewind = gKartPadRetroRewindSelected;
  UIWindow *home = [[UIWindow alloc] initWithWindowScene:_window.windowScene];
  home.windowLevel = UIWindowLevelAlert + 1;
  home.rootViewController = root;
  __weak KartPadFirstLaunchViewController *weakRoot = root;
  root.modeSelected = ^(BOOL retroRewind) {
    if (retroRewind == gKartPadRetroRewindSelected) {
      finished = YES;
      return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Switch on Next Launch"
        message:@"Close KartPad from the app switcher and reopen it to start the other game. Your saved progress and control layout are kept. Unsaved race progress is not carried over."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Use on Next Launch"
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [NSUserDefaults.standardUserDefaults setObject:retroRewind ? @"retro_rewind" : @"base"
          forKey:kKartPadRequestedRuntimeProfileKey];
      [NSUserDefaults.standardUserDefaults synchronize];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [weakRoot presentViewController:alert animated:YES completion:nil];
  };
  [home makeKeyAndVisible];
  const int pausedFrame = g_gxFrameCount;
  NSLog(@"[KartPad] main menu opened; current game suspended at frame %d", pausedFrame);
  while (!finished) {
    @autoreleasepool {
      [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode
          beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
  }
  home.hidden = YES;
  root.modeSelected = nil;
  [_window makeKeyAndVisible];
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  for (NSUInteger player = 0; player < 4; ++player) {
    SunPadInputState ignored{};
    [[KartPadPhysicalControllers sharedControllers] consumePlayer:player state:&ignored];
  }
  [[KartPadMotionSteering sharedSteering] start];
  AudioBackend::Instance().SetPausedForHost(false);
  NSLog(@"[KartPad] current game resumed from main menu; frame %d -> %d", pausedFrame, g_gxFrameCount);
}

- (void)showPrivateServerSettings {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *editor = [UIAlertController alertControllerWithTitle:@"Private Wii Server"
      message:@"Experimental Wii server (unencrypted), not another iPad's address. Restart to apply; blank restores default."
      preferredStyle:UIAlertControllerStyleAlert];
  [editor addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.placeholder = @"Server hostname or IPv4 address";
    field.text = KartPadPrivateServerHost();
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.keyboardType = UIKeyboardTypeURL;
    field.accessibilityLabel = @"Private Wii server address";
  }];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [editor addAction:[UIAlertAction actionWithTitle:@"Save"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    NSString *host = [editor.textFields.firstObject.text
        stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (host.length == 0) {
      [NSUserDefaults.standardUserDefaults removeObjectForKey:@"KartPadPrivateWfcHost"];
      [weakSelf showMultiplayerMessage:@"Default Service Selected"
          message:@"Fully close and reopen KartPad to restore the default online service. Original Mario Kart Wii's original service is closed; Retro Rewind uses Retro WFC."];
      return;
    }
    if (!KartPad::Network::ValidPrivateWfcHost(host.UTF8String ?: "")) {
      [weakSelf showMultiplayerMessage:@"Invalid Server Address"
          message:@"Enter a hostname or IPv4 address only, without a URL scheme, path, port, or spaces."];
      return;
    }
    [NSUserDefaults.standardUserDefaults setObject:host forKey:@"KartPadPrivateWfcHost"];
    [weakSelf showMultiplayerMessage:@"Private Server Saved"
        message:@"Fully close and reopen KartPad to apply this experimental override. A compatible server must already be running. This does not create a room or restore vanilla Nintendo WFC; server login and races remain unverified."];
  }]];
  [editor addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:editor];
}

- (void)showMultiplayerAccess {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  NSString *profile = gKartPadRetroRewindSelected ? @"Retro Rewind" : @"Mario Kart Wii";
  NSString *server = KartPadPrivateServerHost();
  NSString *message = [NSString stringWithFormat:@"%@\n%@", profile,
      !gKartPadRetroRewindSelected
          ? @"Local split-screen available. Original Nintendo WFC is closed; private online rooms are not available in this build."
          : (server.length ? @"Experimental server override configured; restart after changes."
              : @"Online: Retro WFC.")];
  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Multiplayer"
      message:message preferredStyle:UIAlertControllerStyleAlert];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [sheet addAction:[UIAlertAction actionWithTitle:@"Local Players & Controllers…"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [weakSelf gameOverlayRequestsControllerMapping:nil];
  }]];
  if (gKartPadRetroRewindSelected) {
    [sheet addAction:[UIAlertAction actionWithTitle:@"Retro WFC Friend Rooms…"
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [weakSelf showMultiplayerMessage:@"Retro WFC Friend Rooms"
          message:@"Retro Rewind uses Retro WFC. Connect there in the game, then open Friends and exchange friend codes with players using the same Retro Rewind version. The host creates a room; friends join from their roster.\n\nThis is Retro Rewind's in-game service. A custom server override may prevent connection. Native KartPad host/join rooms are not implemented yet."];
    }]];
  }
  [sheet addAction:[UIAlertAction actionWithTitle:@"Experimental Server Settings…"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [weakSelf showPrivateServerSettings];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Back" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:sheet];
}

- (void)uninstall {
  [NSNotificationCenter.defaultCenter removeObserver:self];
  [[KartPadPhysicalControllers sharedControllers] stop];
  [[KartPadMotionSteering sharedSteering] stop];
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  if ([_overlay isKindOfClass:KartPadGameOverlay.class]) {
    [(KartPadGameOverlay *)_overlay resetKartPadControlAppearance];
  }
  _overlay.delegate = nil;
  [_overlay removeFromSuperview];
  _overlay = nil;
}

- (void)applicationWillResignActive:(NSNotification *)notification {
  (void)notification;
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  if ([_overlay isKindOfClass:KartPadGameOverlay.class]) {
    [(KartPadGameOverlay *)_overlay resetKartPadControlAppearance];
  }
  [[KartPadMotionSteering sharedSteering] stop];
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
  (void)notification;
  [[KartPadPhysicalControllers sharedControllers] reconcileControllers];
  [[KartPadMotionSteering sharedSteering] start];
  [self reattachOverlayIfNeeded];
  [_overlay refreshControllerVisibility];
  [_overlay applySettings];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  dispatch_async(dispatch_get_main_queue(), ^{
    [weakSelf reattachOverlayIfNeeded];
  });
}

- (void)showIntegrationAlert:(NSString *)title message:(NSString *)message {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  UIAlertController *alert =
      [UIAlertController alertControllerWithTitle:title
                                          message:message
                                   preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                            style:UIAlertActionStyleDefault
                                          handler:nil]];
  [self presentOverlayAlert:alert];
}

- (void)showExperimentalWiimoteInfo {
  [self showIntegrationAlert:@"Experimental Wii Remote + Nunchuk"
                     message:@"Direct Wii Remote pairing is currently available only in the macOS build. KartPad for iPhone and iPad keeps this option visible so the control layout remains consistent, but iOS does not expose the Bluetooth HID pairing path required by an original Wii Remote. No DolphinBar is required on macOS."];
}

- (void)presentMiiImportPicker {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  _choosingMiiImport = YES;
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc]
          initForOpeningContentTypes:@[UTTypeData, UTTypeItem] asCopy:YES];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [controller presentViewController:picker animated:YES completion:nil];
}

- (void)showMiiCreationHelp {
  [self showIntegrationAlert:@"Mii Appearance"
                     message:@"KartPad can set the online player name for its built-in Mii. To change the face or other appearance details, import a standard 74-byte .mii file made with a compatible tool. Player Identity can then rename it and update every linked Mario Kart Wii license."];
}

- (void)showPlayerNameEditorForRecord:(NSDictionary<NSString *, id> *)record {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  NSString *currentName = record[@"name"] ?: @"";
  NSUInteger slot = [record[@"slot"] unsignedIntegerValue];
  UIAlertController *editor = [UIAlertController
      alertControllerWithTitle:@"Edit Mii Name"
                       message:@"Use 1–10 characters. Fully close and reopen KartPad to update this Mii and its linked licenses, keeping friend codes and progress. To create a license, choose New inside the game and select this Mii."
                preferredStyle:UIAlertControllerStyleAlert];
  [editor addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.text = currentName;
    field.placeholder = @"Player name";
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    field.returnKeyType = UIReturnKeyDone;
  }];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [editor addAction:[UIAlertAction actionWithTitle:@"Save"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
    (void)action;
    NSString *name = editor.textFields.firstObject.text ?: @"";
    NSError *renameError = nil;
    NSUInteger updatedLicenses = 0;
    if (!KartPadStagePlayerName(slot, name, &updatedLicenses, &renameError)) {
      [weakSelf showIntegrationAlert:@"Mii Name Could Not Be Changed"
                             message:renameError.localizedDescription];
      return;
    }
    NSString *trimmed = [name stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *licenseDetail = updatedLicenses == 0
        ? @"To create a license with this name, choose New inside the game and select this Mii."
        : [NSString stringWithFormat:@"%lu linked license%@ will also be updated.",
            (unsigned long)updatedLicenses,
            updatedLicenses == 1 ? @"" : @"s"];
    [weakSelf showIntegrationAlert:@"Mii Name Scheduled"
                           message:[NSString stringWithFormat:
        @"Fully close KartPad from the app switcher and reopen it to apply %@. Returning to the KartPad menu and resuming does not apply pending edits. %@ A backup will be kept automatically.",
        trimmed, licenseDetail]];
  }]];
  [editor addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
  [controller presentViewController:editor animated:YES completion:nil];
}

- (void)showPlayerNameChoices {
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *records = KartPadMiiRecords(&error);
  if (error != nil) {
    [self showIntegrationAlert:@"Player Identity Could Not Be Read"
                       message:error.localizedDescription];
    return;
  }
  if (records.count == 1) {
    [self showPlayerNameEditorForRecord:records.firstObject];
    return;
  }
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *choices = [UIAlertController
      alertControllerWithTitle:@"Choose a Mii"
                       message:@"Choose which identity to rename. Every license linked to it will be updated."
                preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSDictionary<NSString *, id> *record in records) {
    [choices addAction:[UIAlertAction actionWithTitle:record[@"name"]
                                                style:UIAlertActionStyleDefault
                                              handler:^(UIAlertAction *action) {
      (void)action;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.35 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
        [weakSelf showPlayerNameEditorForRecord:record];
      });
    }]];
  }
  [choices addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  choices.popoverPresentationController.sourceView = _overlay;
  choices.popoverPresentationController.sourceRect = CGRectMake(
      CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:choices animated:YES completion:nil];
}

- (NSString *)licenseTitleForRecord:(NSDictionary<NSString *, id> *)record {
  NSString *pending = record[@"pendingOperation"];
  NSString *suffix = [pending isEqualToString:@"delete"] ? @" · deletion pending" :
      [pending isEqualToString:@"rename"] ? @" · name pending" :
      [pending isEqualToString:@"mii"] ? @" · Mii link pending" :
      [record[@"missingLinkedMii"] boolValue] ? @" · Mii missing" : @"";
  return [NSString stringWithFormat:@"%@ · Slot %lu · %@%@",
      record[@"profileTitle"] ?: @"Mario Kart Wii",
      (unsigned long)([record[@"slot"] unsignedIntegerValue] + 1),
      record[@"name"] ?: @"Unnamed", suffix];
}

- (void)chooseMiiForLicense:(NSDictionary<NSString *, id> *)record {
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *miis = KartPadMiiRecords(&error);
  if (error != nil || miis.count == 0) {
    [self showIntegrationAlert:@"No Miis Available"
        message:error.localizedDescription ?: @"Import a Mii appearance in Player Identity, then return here to link it to this license."];
    return;
  }
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *picker = [UIAlertController alertControllerWithTitle:@"Choose Mii for This License"
      message:@"Choose the name and appearance this license should use."
      preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSDictionary<NSString *, id> *mii in miis) {
    [picker addAction:[UIAlertAction actionWithTitle:mii[@"name"] ?: @"Unnamed"
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIAlertController *confirm = [UIAlertController alertControllerWithTitle:
            [NSString stringWithFormat:@"Use %@?", mii[@"name"] ?: @"this Mii"]
            message:[NSString stringWithFormat:@"%@, slot %lu, will use this Mii's name and appearance. Progress and friend code stay intact. Fully close KartPad from the app switcher and reopen to apply.",
                record[@"profileTitle"], (unsigned long)([record[@"slot"] unsignedIntegerValue] + 1)]
            preferredStyle:UIAlertControllerStyleAlert];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [confirm addAction:[UIAlertAction actionWithTitle:@"Save for Next Launch" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
          NSError *linkError = nil;
          if (!KartPadStageLicenseMii(record[@"profileIdentifier"], [record[@"slot"] unsignedIntegerValue], record[@"createId"],
                  [mii[@"slot"] unsignedIntegerValue], mii[@"createIdBytes"], &linkError)) {
            [weakSelf showIntegrationAlert:@"Mii Link Not Scheduled" message:linkError.localizedDescription];
            return;
          }
          [weakSelf showIntegrationAlert:@"Mii Link Scheduled"
              message:@"Fully close KartPad from the app switcher and reopen it. The game will then use the selected Mii. Your progress and friend code are kept, with an automatic backup."];
        }]];
        [controller presentViewController:confirm animated:YES completion:nil];
      });
    }]];
  }
  [picker addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  picker.popoverPresentationController.sourceView = _overlay;
  picker.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1, 1);
  [controller presentViewController:picker animated:YES completion:nil];
}

- (void)showLicenseNameEditorForRecord:(NSDictionary<NSString *, id> *)record {
  if ([record[@"missingLinkedMii"] boolValue]) { [self chooseMiiForLicense:record]; return; }
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *editor = [UIAlertController
      alertControllerWithTitle:@"Rename Existing License"
                       message:[NSString stringWithFormat:
          @"%@\n\nUse 1–10 characters. The selected license keeps its friend code, online account, records, and progress.",
          [self licenseTitleForRecord:record]]
                preferredStyle:UIAlertControllerStyleAlert];
  [editor addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.text = record[@"name"] ?: @"";
    field.placeholder = @"License name";
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    field.autocapitalizationType = UITextAutocapitalizationTypeWords;
    field.returnKeyType = UIReturnKeyDone;
  }];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [editor addAction:[UIAlertAction actionWithTitle:@"Save"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction *action) {
    (void)action;
    NSError *renameError = nil;
    if (!KartPadStageLicenseRename(record[@"profileIdentifier"],
            [record[@"slot"] unsignedIntegerValue], record[@"createId"],
            editor.textFields.firstObject.text ?: @"", &renameError)) {
      [weakSelf showIntegrationAlert:@"License Could Not Be Renamed"
                             message:renameError.localizedDescription];
      return;
    }
    [weakSelf showIntegrationAlert:@"License Rename Scheduled"
                           message:@"Fully close KartPad from the app switcher and reopen it to apply the rename. Returning to the KartPad menu and resuming does not apply pending edits. The live save and matching Mii are backed up automatically."];
  }]];
  [editor addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];
  [controller presentViewController:editor animated:YES completion:nil];
}

- (void)confirmLicenseDeletionForRecord:(NSDictionary<NSString *, id> *)record {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  NSString *name = record[@"name"] ?: @"Unnamed";
  UIAlertController *confirm = [UIAlertController
      alertControllerWithTitle:[NSString stringWithFormat:
          @"Delete “%@” from %@ Slot %lu?", name,
          record[@"profileTitle"] ?: @"Mario Kart Wii",
          (unsigned long)([record[@"slot"] unsignedIntegerValue] + 1)]
                       message:@"This permanently removes that license’s friend code, online account data, records, and progress. Its Mii appearance remains available. KartPad creates a save backup first."
                preferredStyle:UIAlertControllerStyleAlert];
  [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [confirm addAction:[UIAlertAction actionWithTitle:@"Delete License"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
    (void)action;
    NSError *deleteError = nil;
    if (!KartPadStageLicenseDeletion(record[@"profileIdentifier"],
            [record[@"slot"] unsignedIntegerValue], record[@"createId"],
            &deleteError)) {
      [weakSelf showIntegrationAlert:@"License Could Not Be Deleted"
                             message:deleteError.localizedDescription];
      return;
    }
    [weakSelf showIntegrationAlert:@"License Deletion Scheduled"
                           message:@"Fully close KartPad from the app switcher and reopen it to apply the deletion. Returning to the KartPad menu and resuming does not apply pending edits. Other licenses stay in their current slots. The live save is backed up automatically."];
  }]];
  [controller presentViewController:confirm animated:YES completion:nil];
}

- (void)showLicenseActionsForRecord:(NSDictionary<NSString *, id> *)record {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *actions = [UIAlertController
      alertControllerWithTitle:[self licenseTitleForRecord:record]
                       message:[record[@"missingLinkedMii"] boolValue]
          ? @"This license's Mii is missing. The game can show Player even when the saved name is correct. Choose a Mii to repair the link; progress and friend code are kept."
          : @"Rename the name shown in the game. Progress and friend code are kept. Changes apply after fully closing and reopening KartPad."
                preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [actions addAction:[UIAlertAction actionWithTitle:[record[@"missingLinkedMii"] boolValue] ? @"Choose Mii…" : @"Rename License…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [weakSelf showLicenseNameEditorForRecord:record];
    });
  }]];
  [actions addAction:[UIAlertAction actionWithTitle:@"Delete License…"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [weakSelf confirmLicenseDeletionForRecord:record];
    });
  }]];
  [actions addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  actions.popoverPresentationController.sourceView = _overlay;
  actions.popoverPresentationController.sourceRect = CGRectMake(
      CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:actions animated:YES completion:nil];
}

- (void)showLicenseChoices {
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *records = KartPadLicenseRecords(&error);
  if (error != nil) {
    [self showIntegrationAlert:@"Licenses Could Not Be Read"
                       message:error.localizedDescription];
    return;
  }
  if (records.count == 0) {
    [self showIntegrationAlert:@"No Existing Licenses"
                       message:@"Choose New on the license screen inside Mario Kart Wii or Retro Rewind, then select your Mii. Return here to rename or delete that license. Edit Mii Name changes your identity; it does not create a game license."];
    return;
  }
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *choices = [UIAlertController
      alertControllerWithTitle:@"Rename or Delete Licenses"
                       message:@"Choose the exact game profile and slot. A license with an established friend code should be renamed, not deleted."
                preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSDictionary<NSString *, id> *record in records) {
    [choices addAction:[UIAlertAction
        actionWithTitle:[self licenseTitleForRecord:record]
                    style:UIAlertActionStyleDefault
                  handler:^(UIAlertAction *action) {
      (void)action;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.35 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
        [weakSelf showLicenseActionsForRecord:record];
      });
    }]];
  }
  [choices addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  choices.popoverPresentationController.sourceView = _overlay;
  choices.popoverPresentationController.sourceRect = CGRectMake(
      CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:choices animated:YES completion:nil];
}

- (void)showMiiRemovalChoices {
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *records = KartPadMiiRecords(&error);
  NSArray<NSDictionary<NSString *, id> *> *licenses =
      error == nil ? KartPadLicenseRecords(&error) : @[];
  if (error != nil) {
    [self showIntegrationAlert:@"Miis Could Not Be Read"
                       message:error.localizedDescription];
    return;
  }
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *choices = [UIAlertController
      alertControllerWithTitle:@"Remove Mii Appearance"
                       message:@"This removes only an unused Mii appearance; it does not delete a Mario Kart license. Miis linked to a license must be changed or removed from Rename or Delete Licenses first."
                preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSDictionary<NSString *, id> *record in records) {
    NSUInteger linkedLicenses = 0;
    for (NSDictionary<NSString *, id> *license in licenses) {
      if ([license[@"createId"] isEqualToData:record[@"createIdBytes"]]) {
        ++linkedLicenses;
      }
    }
    NSString *title = linkedLicenses == 0 ? record[@"name"] :
        [NSString stringWithFormat:@"%@ — used by %lu license%@",
            record[@"name"], (unsigned long)linkedLicenses,
            linkedLicenses == 1 ? @"" : @"s"];
    NSUInteger slot = [record[@"slot"] unsignedIntegerValue];
    UIAlertActionStyle style = linkedLicenses == 0
        ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault;
    [choices addAction:[UIAlertAction actionWithTitle:title
                                                style:style
                                              handler:^(UIAlertAction *action) {
      (void)action;
      if (linkedLicenses > 0) {
        [weakSelf showIntegrationAlert:@"Mii Is In Use"
                               message:@"Open Rename or Delete Licenses to rename or delete the linked license first. Removing its Mii appearance here could leave the license unusable."];
        return;
      }
      NSError *removeError = nil;
      if (!KartPadStageMiiRemoval(slot, &removeError)) {
        [weakSelf showIntegrationAlert:@"Mii Could Not Be Removed"
                               message:removeError.localizedDescription];
        return;
      }
      [weakSelf showIntegrationAlert:@"Mii Removal Scheduled"
                             message:@"Fully close KartPad from the app switcher and reopen it to apply the appearance removal. Returning to the KartPad menu and resuming does not apply pending edits. A backup of the current Mii database will be kept automatically."];
    }]];
  }
  [choices addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  choices.popoverPresentationController.sourceView = _overlay;
  choices.popoverPresentationController.sourceRect = CGRectMake(
      CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:choices animated:YES completion:nil];
}

- (void)showMiiManager {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *records = KartPadMiiRecords(&error);
  NSArray<NSDictionary<NSString *, id> *> *licenses =
      error == nil ? KartPadLicenseRecords(&error) : @[];
  if (error != nil) {
    [self showIntegrationAlert:@"Miis Could Not Be Read"
                       message:error.localizedDescription];
    return;
  }
  NSMutableArray<NSString *> *names = [NSMutableArray array];
  for (NSDictionary<NSString *, id> *record in records) {
    [names addObject:record[@"name"]];
  }
  NSString *summary = names.count == 0 ? @"No Miis found."
      : [names componentsJoinedByString:@", "];
  NSString *pending = KartPadHasPendingMiiChanges()
      ? @"\n\nChange scheduled. Fully close KartPad from the app switcher and reopen to apply it." : @"";
  NSString *message = [NSString stringWithFormat:
      @"Choose your game license to change its displayed name. Original and Retro Rewind have separate saves.%@", pending];
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) return;
  UIAlertController *manager = [UIAlertController
      alertControllerWithTitle:@"Player Identity"
                       message:message
                preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [manager addAction:[UIAlertAction actionWithTitle:@"Rename or Delete Licenses…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf showLicenseChoices]; });
  }]];
  [manager addAction:[UIAlertAction actionWithTitle:@"Edit Mii Name…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf showPlayerNameChoices]; });
  }]];
  [manager addAction:[UIAlertAction actionWithTitle:@"Import Mii Appearance…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf presentMiiImportPicker]; });
  }]];
  [manager addAction:[UIAlertAction actionWithTitle:@"Remove Mii Appearance…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf showMiiRemovalChoices]; });
  }]];
  [manager addAction:[UIAlertAction actionWithTitle:@"About Mii Appearance…"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
    (void)action;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.35 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [weakSelf showMiiCreationHelp]; });
  }]];
  [manager addAction:[UIAlertAction actionWithTitle:@"Done"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
  manager.popoverPresentationController.sourceView = _overlay;
  manager.popoverPresentationController.sourceRect = CGRectMake(
      CGRectGetMidX(_overlay.bounds), CGRectGetMidY(_overlay.bounds), 1.0, 1.0);
  [controller presentViewController:manager animated:YES completion:nil];
}

- (void)presentGameDataFolderPicker {
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) {
    return;
  }
  UIDocumentPickerViewController *picker =
      [[UIDocumentPickerViewController alloc]
          initForOpeningContentTypes:KartPadGameDataContentTypes() asCopy:YES];
  picker.delegate = self;
  picker.allowsMultipleSelection = NO;
  [controller presentViewController:picker animated:YES completion:nil];
}

- (void)importExtractedGameDataFromURL:(NSURL *)url
                     deleteAfterwards:(BOOL)deleteAfterwards {
  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) {
    return;
  }
  UIAlertController *progress =
      [UIAlertController alertControllerWithTitle:@"Importing Game Data"
                                          message:@"Validating the extracted disc…"
                                   preferredStyle:UIAlertControllerStyleAlert];
  _gameDataProgressAlert = progress;
  [controller presentViewController:progress animated:YES completion:nil];

  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *workError = KartPadPerformGameDataImport(
        url, ^(NSString *status, double fraction) {
          KartPadRuntimeOverlayHost *strongSelf = weakSelf;
          if (strongSelf != nil && strongSelf->_gameDataProgressAlert != nil) {
            strongSelf->_gameDataProgressAlert.message =
                [NSString stringWithFormat:@"%@\n%.0f%%", status, fraction * 100.0];
          }
        });
    if (deleteAfterwards) {
      [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      KartPadRuntimeOverlayHost *strongSelf = weakSelf;
      if (strongSelf == nil) {
        return;
      }
      [strongSelf->_gameDataProgressAlert dismissViewControllerAnimated:YES completion:^{
        strongSelf->_gameDataProgressAlert = nil;
        if (workError != nil) {
          [strongSelf showIntegrationAlert:@"Game Data Import Failed"
                                   message:workError.localizedDescription];
          return;
        }
        [strongSelf showIntegrationAlert:@"Game Data Imported"
                                 message:@"The validated RMCP01 data is stored privately. Close and reopen KartPad to use the new copy."];
      }];
    });
  });
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
  (void)controller;
  NSURL *url = urls.firstObject;
  if (_saveImportProfile) {
    NSString *profile=_saveImportProfile;_saveImportProfile=nil;NSError *error=nil;
    NSNumber *size=nil;[url getResourceValue:&size forKey:NSURLFileSizeKey error:&error];
    NSData *data=size.unsignedLongLongValue==0x2bc000?[NSData dataWithContentsOfURL:url options:0 error:&error]:nil;
    BOOL staged=data&&KartPadStageSaveRestore(profile,data,&error);
    [self showIntegrationAlert:staged?@"Save Restore Scheduled":@"Save Restore Failed" message:staged?@"Quit and reopen KartPad to apply the restore. The current save will be backed up first.":(error.localizedDescription?:@"Choose a valid 2867200-byte rksys.dat file.")];
    return;
  }
  if (_choosingGhostImport) {
    _choosingGhostImport=NO;
    if(url==nil)return;
    NSNumber *size=nil;[url getResourceValue:&size forKey:NSURLFileSizeKey error:nil];
    NSError *error=nil;NSData *data=nil;
    if(size && size.unsignedLongLongValue<=0x2800)data=[NSData dataWithContentsOfURL:url options:0 error:&error];
    BOOL ok=data && KartPadStageOriginalGhost(data,_ghostLicense,&error);
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    [self showIntegrationAlert:ok ? @"Ghost Import Scheduled" : @"Ghost Import Failed"
        message:ok ? @"Fully quit and reopen KartPad now to apply the comparison ghost. Your save will be backed up; personal-best records stay unchanged." : (error.localizedDescription ?: @"The selected file is unavailable, too large, or invalid.")];
    return;
  }
  if (_choosingMiiImport) {
    _choosingMiiImport = NO;
    if (url == nil) return;
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:&readError];
    NSString *name = nil;
    NSError *importError = nil;
    BOOL imported = data != nil &&
        KartPadStageMiiImport(data, &name, &importError);
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    if (!imported) {
      NSError *shownError = readError ?: importError;
      [self showIntegrationAlert:@"Mii Import Failed"
                         message:shownError.localizedDescription ?: @"The selected file could not be imported."];
      return;
    }
    [self showIntegrationAlert:@"Mii Import Scheduled"
                       message:[NSString stringWithFormat:
        @"%@ will be added the next time KartPad launches. A backup of the current Mii database will be kept automatically.",
        name.length > 0 ? name : @"The selected Mii"]];
    return;
  }
  if (url != nil) {
    [self importExtractedGameDataFromURL:url deleteAfterwards:YES];
  }
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
  (void)controller;
  _choosingMiiImport = NO;
  _choosingGhostImport = NO;
  _saveImportProfile = nil;
}

- (void)gameOverlayRequestsGameDataChange:(SunPadGameOverlay *)overlay {
  (void)overlay;
  [self presentGameDataFolderPicker];
}

- (void)gameOverlayRequestsGameDataFolderImport:(SunPadGameOverlay *)overlay {
  (void)overlay;
  UIViewController *presenter=KartPadVisibleViewController(_window);if(!presenter)return;
  UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeFolder] asCopy:YES];picker.delegate=self;picker.allowsMultipleSelection=NO;
  [presenter presentViewController:picker animated:YES completion:nil];
}

- (void)gameOverlayRequestsGameDataRemoval:(SunPadGameOverlay *)overlay {
  (void)overlay;
  [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
  NSString *supportRoot = KartPadSupportRoot();
  NSError *error = nil;
  [NSFileManager.defaultManager createDirectoryAtPath:supportRoot
                          withIntermediateDirectories:YES
                                           attributes:@{NSFileProtectionKey:
      NSFileProtectionCompleteUntilFirstUserAuthentication}
                                                error:&error];
  if (error == nil) {
    [@"remove-on-next-launch\n" writeToFile:KartPadRemovalMarkerPath()
                                   atomically:YES encoding:NSUTF8StringEncoding
                                      error:&error];
  }
  if (error != nil) {
    [self showIntegrationAlert:@"Game Data Removal Failed"
                       message:error.localizedDescription];
    return;
  }

  UIViewController *controller = KartPadVisibleViewController(_window);
  if (controller == nil) {
    [NSFileManager.defaultManager removeItemAtPath:KartPadRemovalMarkerPath()
                                             error:nil];
    return;
  }
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  UIAlertController *alert = [UIAlertController
      alertControllerWithTitle:@"Game Data Removal Scheduled"
                       message:@"KartPad will remove the private game-data copy before emulation starts on the next launch. Saves and control settings are not affected."
                preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Undo"
                                             style:UIAlertActionStyleCancel
                                           handler:^(UIAlertAction *action) {
    (void)action;
    NSError *undoError = nil;
    if (![NSFileManager.defaultManager removeItemAtPath:KartPadRemovalMarkerPath()
                                                  error:&undoError]) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.35 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
        [weakSelf showIntegrationAlert:@"Undo Failed"
                               message:undoError.localizedDescription];
      });
    }
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                             style:UIAlertActionStyleDefault
                                           handler:nil]];
  [controller presentViewController:alert animated:YES completion:nil];
}

- (void)presentGhostPicker:(UIDocumentPickerViewController *)picker importing:(BOOL)importing {
  UIViewController *controller=KartPadVisibleViewController(_window);
  if(!controller)return;
  _choosingGhostImport=importing;
  if(importing)picker.delegate=self;
  [controller presentViewController:picker animated:YES completion:nil];
}

- (void)showGhostManager {
  NSError *error=nil;
  NSArray *licenses=KartPadLicenseRecords(&error);
  UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Original Time Trial Ghosts"
      message:@"Import comparison ghosts or export saved .rkg files. Retro Rewind custom-track ghosts use a different format association and are not supported here."
      preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf=self;
  NSUInteger count=0;
  for(NSDictionary *license in licenses) if([license[@"profileIdentifier"] isEqual:@"original"]){
    ++count;
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"License %lu: %@",[license[@"slot"] unsignedLongValue]+1,license[@"name"] ?: @"Player"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
      [weakSelf showGhostActionsForLicense:[license[@"slot"] unsignedIntegerValue]];
    }]];
  }
  if(KartPadHasPendingGhost()) [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel Pending Ghost Import" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
    NSError *cancelError=nil;
    if(!KartPadCancelPendingGhost(&cancelError))[weakSelf showIntegrationAlert:@"Cancel Failed" message:cancelError.localizedDescription];
  }]];
  if(count==0)sheet.message=error.localizedDescription ?: @"Create an Original Mario Kart Wii license first.";
  [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:sheet];
}

- (void)showRetroManager {
  NSString *version=[NSString stringWithContentsOfFile:[KartPadRetroRewindInstaller.installedRootPath stringByAppendingPathComponent:@"version.txt"] encoding:NSUTF8StringEncoding error:nil];
  UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Manage Retro Rewind" message:[NSString stringWithFormat:@"Installed version: %@\nRequired version: %@\n\nReturn to the KartPad menu and choose Retro Rewind to check its pack and install or update when required.",version?:@"Not installed",KartPadRetroRewindInstaller.requiredVersion] preferredStyle:UIAlertControllerStyleAlert];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Return to KartPad Menu" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){gKartPadMainMenuRequested=YES;}]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];[self presentOverlayAlert:sheet];
}
- (void)showSaveManager {
  UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Choose Save Profile" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
  NSArray *names=@[@"Original Mario Kart Wii",@"Retro Rewind",@"Retro Rewind (Separate Save)"];
  NSArray *profiles=@[@"original",@"retro_rewind",@"retro_rewind_separate"];
  __weak KartPadRuntimeOverlayHost *weakSelf=self;
  for(NSUInteger i=0;i<names.count;i++){NSString *profile=profiles[i];[sheet addAction:[UIAlertAction actionWithTitle:names[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[weakSelf showSaveActions:profile title:action.title];}]];}
  if(KartPadHasPendingSaveRestore())[sheet addAction:[UIAlertAction actionWithTitle:@"Cancel Pending Save Restore" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSError *error=nil;if(!KartPadCancelSaveRestore(&error))[weakSelf showIntegrationAlert:@"Cancel Failed" message:error.localizedDescription];}]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentOverlayAlert:sheet];
}
- (void)showSaveActions:(NSString *)profile title:(NSString *)title {
  UIAlertController *sheet=[UIAlertController alertControllerWithTitle:[@"Manage Saves • " stringByAppendingString:title] message:@"Export or restore this profile's rksys.dat. Saves do not include Miis or console identity. Use Separate Save only if enabled in Retro Rewind." preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf=self;
  if([profile isEqualToString:@"original"])[sheet addAction:[UIAlertAction actionWithTitle:@"Time Trial Ghosts (.rkg)…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[weakSelf showGhostManager];}]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Export Save Backup…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSError *error=nil;NSData *data=KartPadReadSave(profile,&error);if(!data){[weakSelf showIntegrationAlert:@"Save Unavailable" message:error.localizedDescription];return;}NSURL *dir=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];[NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:&error];NSURL *file=[dir URLByAppendingPathComponent:@"rksys.dat"];if(![data writeToURL:file options:NSDataWritingAtomic error:&error]){[weakSelf showIntegrationAlert:@"Export Failed" message:error.localizedDescription];return;}[weakSelf presentGhostPicker:[[UIDocumentPickerViewController alloc] initForExportingURLs:@[file] asCopy:YES] importing:NO];}]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Restore Save Backup…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[weakSelf confirmSaveRestore:profile];}]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];[self presentOverlayAlert:sheet];
}
- (void)confirmSaveRestore:(NSString *)profile {
  UIAlertController *confirm=[UIAlertController alertControllerWithTitle:@"Restore Save Backup?" message:@"On restart, the imported save replaces this profile's progress. The current save is backed up first. Miis and console identity are unchanged." preferredStyle:UIAlertControllerStyleAlert];
  __weak KartPadRuntimeOverlayHost *weakSelf=self;
  [confirm addAction:[UIAlertAction actionWithTitle:@"Choose rksys.dat…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){[weakSelf chooseSaveRestore:profile];}]];
  [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[self presentOverlayAlert:confirm];
}
- (void)chooseSaveRestore:(NSString *)profile {
  _saveImportProfile=profile;
  [self presentGhostPicker:[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES] importing:NO];
}

- (void)showGhostActionsForLicense:(NSUInteger)license {
  _ghostLicense=license;
  UIAlertController *sheet=[UIAlertController alertControllerWithTitle:@"Original Ghosts" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf=self;
  [sheet addAction:[UIAlertAction actionWithTitle:@"Export a Ghost…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
    NSError *error=nil;NSArray *records=KartPadOriginalGhosts(license,&error);
    if(records.count==0){[weakSelf showIntegrationAlert:error != nil ? @"Ghost Export Unavailable" : @"No Saved Ghosts" message:error.localizedDescription ?: @"This Original license has no saved personal-best or downloaded ghosts. Choose the license used for your time trial. Retro Rewind custom-track ghosts are not listed here."];return;}
    UIAlertController *choose=[UIAlertController alertControllerWithTitle:@"Choose Ghost" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    for(NSDictionary *record in records)[choose addAction:[UIAlertAction actionWithTitle:record[@"name"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *selected){
      NSURL *directory=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
      NSError *writeError=nil;
      [NSFileManager.defaultManager createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:nil error:&writeError];
      NSURL *file=[directory URLByAppendingPathComponent:@"KartPad-ghost.rkg"];
      if(![record[@"data"] writeToURL:file options:NSDataWritingAtomic error:&writeError]){[weakSelf showIntegrationAlert:@"Ghost Export Failed" message:writeError.localizedDescription];return;}
      UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForExportingURLs:@[file] asCopy:YES];
      [weakSelf presentGhostPicker:picker importing:NO];
    }]];
    [choose addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [weakSelf presentOverlayAlert:choose];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Import Comparison Ghost…" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
    UIAlertController *confirm=[UIAlertController alertControllerWithTitle:@"Import Original Ghost" message:@"The course is read from the file. Its downloaded comparison ghost will be replaced on restart, with a backup. Personal-best records stay unchanged." preferredStyle:UIAlertControllerStyleAlert];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Choose .rkg" style:UIAlertActionStyleDefault handler:^(UIAlertAction *selected){
      UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];
      [weakSelf presentGhostPicker:picker importing:YES];
    }]];
    [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [weakSelf presentOverlayAlert:confirm];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:sheet];
}

- (void)showControllerButtonAssignment:(uint16_t)gameButton title:(NSString *)title {
  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:title
      message:@"Choose a physical button or trigger. Touch controls keep their layout."
      preferredStyle:UIAlertControllerStyleActionSheet];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSUInteger index = 0; index < 12; ++index) {
    const auto physical = (SunPadPhysicalControllerButton)(1u << index);
    [sheet addAction:[UIAlertAction actionWithTitle:SunPadPhysicalControllerButtonName(physical)
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      UIAlertController *choice = [UIAlertController alertControllerWithTitle:title
          message:@"Swap assignments, or let this physical button perform both actions."
          preferredStyle:UIAlertControllerStyleAlert];
      [choice addAction:[UIAlertAction actionWithTitle:@"Swap Assignments" style:UIAlertActionStyleDefault
          handler:^(UIAlertAction *selected) {
        [SunPadControllerMappingStore setMapping:SunPadControllerButtonMappingByAssigning(
            [SunPadControllerMappingStore mapping], physical, gameButton)];
      }]];
      [choice addAction:[UIAlertAction actionWithTitle:@"Keep Both Actions" style:UIAlertActionStyleDefault
          handler:^(UIAlertAction *selected) {
        [SunPadControllerMappingStore setMapping:SunPadControllerButtonMappingBySharing(
            [SunPadControllerMappingStore mapping], physical, gameButton)];
      }]];
      [choice addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
      [weakSelf presentOverlayAlert:choice];
    }]];
  }
  [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:sheet];
}

- (void)showControllerButtonMapping {
  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Controller Button Mapping"
      message:@"Choose an action to reassign. Sticks and Menu remain direct. Trigger presses can be assigned like buttons."
      preferredStyle:UIAlertControllerStyleActionSheet];
  const SunPadControllerButtonMapping mapping = [SunPadControllerMappingStore mapping];
  NSArray<NSString *> *names = @[@"A — Accelerate / Confirm", @"B — Drift / Back",
      @"X — Rear View", @"Y", @"ZR — Rear View", @"R — Drift", @"L — Use Item",
      @"D-pad Up", @"D-pad Down", @"D-pad Left", @"D-pad Right"];
  const uint16_t buttons[] = {SunPadButtonA, SunPadButtonB, SunPadButtonX, SunPadButtonY, SunPadButtonZ, SunPadButtonR, SunPadButtonL,
      SunPadButtonDpadUp, SunPadButtonDpadDown, SunPadButtonDpadLeft, SunPadButtonDpadRight};
  const SunPadPhysicalControllerButton physical[] = {mapping.gameA, mapping.gameB,
      mapping.gameX, mapping.gameY, mapping.gameZ, mapping.gameR, mapping.gameL,
      mapping.gameUp, mapping.gameDown, mapping.gameLeft, mapping.gameRight};
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  for (NSUInteger index = 0; index < names.count; ++index) {
    NSString *name = names[index];
    const uint16_t gameButton = buttons[index];
    NSString *label = [NSString stringWithFormat:@"%@: %@", name,
        SunPadPhysicalControllerButtonName(physical[index])];
    [sheet addAction:[UIAlertAction actionWithTitle:label
        style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
      [weakSelf showControllerButtonAssignment:gameButton title:name];
    }]];
  }
  [sheet addAction:[UIAlertAction actionWithTitle:@"Use L1 for Items" style:UIAlertActionStyleDefault
      handler:^(UIAlertAction *action) {
    [SunPadControllerMappingStore setMapping:SunPadControllerButtonMappingByAssigning(
        [SunPadControllerMappingStore mapping], SunPadPhysicalControllerButtonLeftShoulder, SunPadButtonL)];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Reset Controller Mapping"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [SunPadControllerMappingStore reset];
    [weakSelf showMultiplayerMessage:@"Default Mapping Restored"
        message:@"The default controller mapping will apply to new controller input."];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:sheet];
}

- (void)gameOverlayRequestsControllerMapping:(SunPadGameOverlay *)overlay {
  (void)overlay;
  KartPadPhysicalControllers *controllers = [KartPadPhysicalControllers sharedControllers];
  [controllers reconcileControllers];
  NSString *players = [[controllers playerDescriptions] componentsJoinedByString:@"\n"];
  NSString *message = players;
  UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Controller Setup"
      message:message preferredStyle:UIAlertControllerStyleAlert];
  __weak KartPadRuntimeOverlayHost *weakSelf = self;
  [sheet addAction:[UIAlertAction actionWithTitle:@"Customize Buttons & Triggers…"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [weakSelf showControllerButtonMapping];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Pairing & Compatibility…"
      style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
    [weakSelf showMultiplayerMessage:@"Connect & Register Controllers"
        message:@"Pair pads in system Bluetooth settings. In the game, choose Multiplayer and press mapped A on each pad at Register Controllers. Touch shares Player 1.\n\nDualShock 4 / DualSense defaults: Cross = A, Circle = B, Square = X, Triangle = Y. GameCube-style pads need OS Extended Gamepad support. Original GameCube USB adapters are not supported on iPad."];
  }]];
  [sheet addAction:[UIAlertAction actionWithTitle:@"Done" style:UIAlertActionStyleCancel handler:nil]];
  [self presentOverlayAlert:sheet];
}

- (NSString *)gameOverlayDiagnosticContext:(SunPadGameOverlay *)overlay {
  (void)overlay;
  SunPadSettings *settings = SunPadSettings.sharedSettings;
  return KartPadDiagnosticContext(
      [KartPadRetroRewindInstaller.installedRootPath stringByAppendingPathComponent:@"version.txt"],
      KartPadRetroRewindInstaller.requiredVersion,
      gKartPadRetroRewindSelected ? @"retro_rewind" : @"base",
      settings.renderScaleFloat, settings.aspectRatioMode);
}

- (NSString *)gameOverlayPerformanceProfile:(SunPadGameOverlay *)overlay {
  (void)overlay;
  SunPadSettings *settings = SunPadSettings.sharedSettings;
  return [NSString stringWithFormat:@"%@; scale=%.2fx; aspect=%ld",
      gKartPadRetroRewindSelected ? @"retro_rewind" : @"base",
      settings.renderScaleFloat, (long)settings.aspectRatioMode];
}

@end

extern "C" bool KartPadMobileEnsureGameDataAvailable() {
  KartPadSystemDiagnosticsStart();
  KartPadApplyPrivateServerAtLaunch();
  NSError *miiError = nil;
  if (!KartPadApplyPendingMiiDatabase(&miiError)) {
    NSLog(@"[KartPad] pending Mii changes were not applied: %@",
          miiError.localizedDescription);
  }
  if (!NSThread.isMainThread) {
    __block BOOL available = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
      available = [[[KartPadFirstLaunchHost alloc] init] run];
    });
    return available;
  }
  return [[[KartPadFirstLaunchHost alloc] init] run];
}

extern "C" const char *KartPadMobileSelectedRuntimeProfile() {
  return gKartPadRetroRewindSelected ? "retro_rewind" : "base";
}

extern "C" void KartPadMobileServiceMainMenu() {
  static BOOL previewShown=![NSProcessInfo.processInfo.environment[@"KARTPAD_UI_PREVIEW"] isEqualToString:@"report"];
  if(!previewShown && gRuntimeOverlayHost && NSThread.isMainThread && g_gxFrameCount>120) {
    previewShown=YES;[gRuntimeOverlayHost showReportPreview];
  }
  if (gKartPadMainMenuRequested && gRuntimeOverlayHost != nil && NSThread.isMainThread) {
    [gRuntimeOverlayHost runMainMenu];
  }
}

extern "C" void KartPadMobileRuntimeHostInstall(void *sdlWindow) {
  if (sdlWindow == nullptr || !NSThread.isMainThread) {
    NSLog(@"[KartPad] refusing overlay installation away from UIKit's main thread");
    return;
  }
  [gRuntimeOverlayHost uninstall];
  gRuntimeOverlayHost =
      [[KartPadRuntimeOverlayHost alloc] initWithSDLWindow:(SDL_Window *)sdlWindow];
}

extern "C" void KartPadMobileRuntimeHostUninstall() {
  [gRuntimeOverlayHost uninstall];
  gRuntimeOverlayHost = nil;
}

extern "C" bool KartPadMobileReadRuntimeSettings(
    KartPadMobileRuntimeSettings *settings) {
  if (settings == nullptr) {
    return false;
  }
  SunPadSettings *source = [SunPadSettings sharedSettings];
  settings->aspectRatioMode = static_cast<int>(source.aspectRatioMode);
  settings->resolutionScale = source.renderScaleFloat;
  settings->showFps = source.showFPSCounter ? 1 : 0;
  return true;
}

extern "C" bool KartPadMobileReadClassicInput(
    KartPadMobileClassicInputSnapshot *snapshot) {
  return KartPadMobileReadClassicInputForPlayer(0, snapshot);
}

extern "C" bool KartPadMobileIsControllerConnected(unsigned int player) {
  return [[KartPadPhysicalControllers sharedControllers] isPlayerConnected:player];
}

extern "C" bool KartPadMobileReadClassicInputForPlayer(
    unsigned int player, KartPadMobileClassicInputSnapshot *snapshot) {
  if (snapshot == nullptr || gRuntimeOverlayHost == nil) {
    return false;
  }
  SunPadInputState source{};
  if (player == 0) {
    source = [[SunPadInputMixer sharedMixer] consumeMergedState];
  } else if (player < 4) {
    [[KartPadPhysicalControllers sharedControllers] consumePlayer:player
                                                            state:&source];
  } else {
    return false;
  }
  // Latch only physical-controller input. Player 1 also carries touch, whose A
  // button has its own lock, so it latches only while a controller is connected.
  auto &accelerateLatch = gKartPadControllerAccelerateLatches[player];
  const bool controllerActive = player == 0
      ? [KartPadPhysicalControllers sharedControllers].connectedControllerCount > 0
      : source.connected != 0;
  if (controllerActive) {
    const auto nowMs = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now().time_since_epoch()).count();
    if (accelerateLatch.Apply((source.buttons & SunPadButtonA) != 0,
                              static_cast<uint64_t>(nowMs),
                              gKartPadControllerAutoAccelerate.load(std::memory_order_relaxed))) {
      source.buttons |= SunPadButtonA;
    }
  } else {
    accelerateLatch.Reset();
  }
  KartPadClassicInputState adapted =
      kartpad::mobile::AdaptSunPadInput(source);
  KartPadMotionSteering *motion = [KartPadMotionSteering sharedSteering];
  const BOOL shakeTrick = player == 0 ? [motion consumeShakeTrick] : NO;
  if (player == 0 &&
      [KartPadPhysicalControllers sharedControllers].connectedControllerCount == 0) {
    kartpad::mobile::ApplyMotionInput(adapted, motion.currentSteering,
                                      shakeTrick);
  }
  snapshot->buttons = adapted.buttons;
  snapshot->leftStickX = std::clamp(static_cast<float>(adapted.leftStickX) / 127.0f,
                                   -1.0f, 1.0f);
  snapshot->leftStickY = std::clamp(static_cast<float>(adapted.leftStickY) / 127.0f,
                                   -1.0f, 1.0f);
  snapshot->connected = adapted.connected ? 1 : 0;
  return true;
}
