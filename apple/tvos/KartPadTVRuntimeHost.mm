#import "kartpad_mobile_runtime_host.h"

#import "KartPadClassicInput.h"
#import "KartPadPhysicalControllers.h"
#import "KartPadRetroRewindInstaller.h"
#import "SunPadDiagnostics.h"
#import "SunPadSettings.h"

#import <CommonCrypto/CommonDigest.h>
#import <UIKit/UIKit.h>

#include <algorithm>
#include <cstring>

namespace {

NSString *const kKartPadTVProfileKey = @"KartPadTVRuntimeProfile";
NSString *const kKartPadSupportedDOLHash =
    @"80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05";

BOOL gKartPadTVRuntimeActive = NO;
BOOL gKartPadTVRetroRewindSelected = NO;

NSString *KartPadTVCacheRoot() {
  return [[NSSearchPathForDirectoriesInDomains(
      NSCachesDirectory, NSUserDomainMask, YES) firstObject]
      stringByAppendingPathComponent:@"KartPad"];
}

NSString *KartPadTVSupportRoot() {
  // tvOS permits only purgeable local files outside its small preferences
  // allowance. Keep all filesystem-backed runtime state in Library/Caches.
  return KartPadTVCacheRoot();
}

NSString *KartPadTVGameDataRoot() {
  return [KartPadTVCacheRoot() stringByAppendingPathComponent:@"GameData"];
}

NSString *KartPadTVSHA256(NSString *path, NSError **error) {
  NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
  if (stream == nil) return nil;
  [stream open];
  CC_SHA256_CTX context;
  CC_SHA256_Init(&context);
  NSMutableData *storage = [NSMutableData dataWithLength:1024 * 1024];
  while (true) {
    NSInteger count = [stream read:static_cast<uint8_t *>(storage.mutableBytes)
                         maxLength:storage.length];
    if (count < 0) {
      if (error != nullptr) *error = stream.streamError;
      [stream close];
      return nil;
    }
    if (count == 0) break;
    CC_SHA256_Update(&context, storage.bytes, static_cast<CC_LONG>(count));
  }
  [stream close];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256_Final(digest, &context);
  NSMutableString *result =
      [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; ++index) {
    [result appendFormat:@"%02x", digest[index]];
  }
  return result;
}

NSString *KartPadTVValidateGameData(NSError **error) {
  NSString *root = KartPadTVGameDataRoot();
  NSArray<NSString *> *required = @[
    @"sys/boot.bin", @"sys/bi2.bin", @"sys/apploader.img", @"sys/fst.bin",
    @"sys/main.dol", @"files/rel/StaticR.rel",
  ];
  for (NSString *relative in required) {
    if (![NSFileManager.defaultManager
            fileExistsAtPath:[root stringByAppendingPathComponent:relative]]) {
      return [NSString stringWithFormat:@"Missing %@.", relative];
    }
  }
  NSData *boot = [NSData dataWithContentsOfFile:
      [root stringByAppendingPathComponent:@"sys/boot.bin"]
                                           options:0 error:error];
  if (boot.length < 0x20) return @"sys/boot.bin is missing or truncated.";
  const uint8_t *bytes = static_cast<const uint8_t *>(boot.bytes);
  if (std::memcmp(bytes, "RMCP01", 6) != 0 || bytes[6] != 0 || bytes[7] != 0) {
    return @"KartPad supports RMCP01 (PAL), disc 0, revision 0 only.";
  }
  const uint32_t magic = (static_cast<uint32_t>(bytes[0x18]) << 24) |
                         (static_cast<uint32_t>(bytes[0x19]) << 16) |
                         (static_cast<uint32_t>(bytes[0x1a]) << 8) |
                         static_cast<uint32_t>(bytes[0x1b]);
  if (magic != 0x5d1c9ea3u) return @"The Wii disc header is invalid.";
  NSString *hash = KartPadTVSHA256(
      [root stringByAppendingPathComponent:@"sys/main.dol"], error);
  if (![hash isEqualToString:kKartPadSupportedDOLHash]) {
    return @"sys/main.dol does not match the supported RMCP01 revision 0.";
  }
  return nil;
}

NSString *KartPadTVEscapedTOMLPath(NSString *path) {
  return [[path stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"]
      stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
}

BOOL KartPadTVWriteRuntimePaths(NSError **error) {
  NSFileManager *files = NSFileManager.defaultManager;
  NSString *support = KartPadTVSupportRoot();
  NSString *cache = KartPadTVCacheRoot();
  NSString *logs = [support stringByAppendingPathComponent:@"Logs"];
  if (![files createDirectoryAtPath:support withIntermediateDirectories:YES
                         attributes:nil error:error] ||
      ![files createDirectoryAtPath:cache withIntermediateDirectories:YES
                         attributes:nil error:error] ||
      ![files createDirectoryAtPath:logs withIntermediateDirectories:YES
                         attributes:nil error:error]) {
    return NO;
  }
  NSString *configPath = [support stringByAppendingPathComponent:@"Config.toml"];
  NSString *config = [NSString stringWithContentsOfFile:configPath
                                                encoding:NSUTF8StringEncoding
                                                   error:nil] ?: @"";
  NSArray<NSString *> *keys = @[@"dvd_root", @"retro_rewind_root"];
  for (NSString *key in keys) {
    NSString *pattern = [NSString stringWithFormat:@"(?m)^\\s*#?\\s*%@\\s*=.*(?:\\n|$)",
        [NSRegularExpression escapedPatternForString:key]];
    NSRegularExpression *expression =
        [NSRegularExpression regularExpressionWithPattern:pattern options:0
                                                     error:error];
    if (expression == nil) return NO;
    config = [expression stringByReplacingMatchesInString:config options:0
        range:NSMakeRange(0, config.length) withTemplate:@""];
  }
  NSString *paths = [NSString stringWithFormat:
      @"\n[paths]\ndvd_root = \"%@\"\nretro_rewind_root = \"%@\"\n",
      KartPadTVEscapedTOMLPath(KartPadTVGameDataRoot()),
      KartPadTVEscapedTOMLPath(KartPadRetroRewindInstaller.installedRootPath)];
  NSRegularExpression *existingPaths = [NSRegularExpression
      regularExpressionWithPattern:@"(?m)^\\s*\\[paths\\]\\s*$" options:0
                           error:error];
  if (existingPaths == nil) return NO;
  NSTextCheckingResult *match = [existingPaths firstMatchInString:config options:0
      range:NSMakeRange(0, config.length)];
  if (match != nil) {
    NSString *entries = [paths stringByReplacingOccurrencesOfString:@"\n[paths]" withString:@""];
    config = [config stringByReplacingCharactersInRange:
        NSMakeRange(NSMaxRange(match.range), 0) withString:entries];
  } else {
    config = [config stringByAppendingString:paths];
  }
  NSError *atomicError = nil;
  if ([config writeToFile:configPath atomically:YES
                 encoding:NSUTF8StringEncoding error:&atomicError]) {
    return YES;
  }
  NSError *directError = nil;
  if ([config writeToFile:configPath atomically:NO
                 encoding:NSUTF8StringEncoding error:&directError]) {
    return YES;
  }
  if (error != nullptr) *error = directError ?: atomicError;
  return NO;
}

UIButton *KartPadTVButton(NSString *title, UIColor *color,
                          void (^handler)(void)) {
  UIButtonConfiguration *configuration =
      [UIButtonConfiguration filledButtonConfiguration];
  configuration.title = title;
  configuration.baseBackgroundColor = color;
  configuration.baseForegroundColor = UIColor.whiteColor;
  configuration.cornerStyle = UIButtonConfigurationCornerStyleLarge;
  configuration.contentInsets = NSDirectionalEdgeInsetsMake(22, 34, 22, 34);
  UIButton *button = [UIButton buttonWithConfiguration:configuration
      primaryAction:[UIAction actionWithHandler:^(__kindof UIAction *action) {
    (void)action;
    if (handler != nil) handler();
  }]];
  return button;
}

}  // namespace

@interface KartPadTVSetupViewController : UIViewController
@property(nonatomic, strong) UILabel *statusLabel;
@property(nonatomic, strong) UIStackView *actions;
@property(nonatomic, strong) CAGradientLayer *gradient;
- (void)showStatus:(NSString *)status buttons:(NSArray<UIButton *> *)buttons;
@end

@implementation KartPadTVSetupViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.blackColor;
  CAGradientLayer *gradient = CAGradientLayer.layer;
  gradient.colors = @[
    (__bridge id)[UIColor colorWithRed:0.02 green:0.06 blue:0.14 alpha:1].CGColor,
    (__bridge id)[UIColor colorWithRed:0.12 green:0.04 blue:0.18 alpha:1].CGColor,
  ];
  gradient.startPoint = CGPointMake(0, 0);
  gradient.endPoint = CGPointMake(1, 1);
  [self.view.layer insertSublayer:gradient atIndex:0];
  self.gradient = gradient;

  UILabel *title = [[UILabel alloc] init];
  title.text = @"KartPad for Apple TV";
  title.font = [UIFont systemFontOfSize:54 weight:UIFontWeightBold];
  title.textColor = UIColor.whiteColor;
  title.textAlignment = NSTextAlignmentCenter;

  UILabel *status = [[UILabel alloc] init];
  status.font = [UIFont systemFontOfSize:28 weight:UIFontWeightRegular];
  status.textColor = [UIColor colorWithWhite:1 alpha:0.78];
  status.textAlignment = NSTextAlignmentCenter;
  status.numberOfLines = 0;
  self.statusLabel = status;

  UIStackView *actions = [[UIStackView alloc] init];
  actions.axis = UILayoutConstraintAxisHorizontal;
  actions.alignment = UIStackViewAlignmentCenter;
  actions.distribution = UIStackViewDistributionFillEqually;
  actions.spacing = 30;
  self.actions = actions;

  UIStackView *content = [[UIStackView alloc]
      initWithArrangedSubviews:@[title, status, actions]];
  content.translatesAutoresizingMaskIntoConstraints = NO;
  content.axis = UILayoutConstraintAxisVertical;
  content.spacing = 34;
  [self.view addSubview:content];
  [NSLayoutConstraint activateConstraints:@[
    [content.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    [content.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    [content.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor
                                                multiplier:0.78],
    [content.widthAnchor constraintGreaterThanOrEqualToConstant:720],
  ]];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  self.gradient.frame = self.view.bounds;
}

- (void)showStatus:(NSString *)status buttons:(NSArray<UIButton *> *)buttons {
  self.statusLabel.text = status;
  for (UIView *view in self.actions.arrangedSubviews) {
    [self.actions removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  for (UIButton *button in buttons) [self.actions addArrangedSubview:button];
  [self setNeedsFocusUpdate];
  [self updateFocusIfNeeded];
}

@end

@interface KartPadTVLaunchHost : NSObject
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) KartPadTVSetupViewController *root;
@property(nonatomic, strong) NSURLSessionDownloadTask *downloadTask;
@property(nonatomic, assign) BOOL finished;
@property(nonatomic, assign) BOOL succeeded;
- (BOOL)run;
- (void)showGameDataState;
- (void)selectRetroRewind:(BOOL)retroRewind;
- (void)finishWithRetroRewind:(BOOL)retroRewind;
- (void)downloadRetroRewind;
- (void)installArchiveAtPath:(NSString *)archivePath;
- (UIWindowScene *)availableScene;
- (void)showFailure:(NSString *)title error:(NSError *)error
              retry:(void (^)(void))retry;
@end

@implementation KartPadTVLaunchHost

- (UIWindowScene *)availableScene {
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if ([scene isKindOfClass:UIWindowScene.class] &&
        scene.activationState != UISceneActivationStateUnattached) {
      return (UIWindowScene *)scene;
    }
  }
  return nil;
}

- (void)showGameDataState {
  NSError *error = nil;
  NSString *problem = KartPadTVValidateGameData(&error);
  if (problem != nil || error != nil) {
    NSString *detail = problem ?: error.localizedDescription;
    NSString *message = [NSString stringWithFormat:
        @"Game data is not included. Stage your own validated RMCP01 DATA folder from a Mac, then choose Retry.\n\n%@",
        detail];
    __weak KartPadTVLaunchHost *weakSelf = self;
    UIButton *retry = KartPadTVButton(@"Retry", UIColor.systemBlueColor, ^{
      [weakSelf showGameDataState];
    });
    [self.root showStatus:message buttons:@[retry]];
    return;
  }
  NSString *profile =
      [NSUserDefaults.standardUserDefaults stringForKey:kKartPadTVProfileKey];
  [self selectRetroRewind:[profile isEqualToString:@"retro_rewind"]];
}

- (void)finishWithRetroRewind:(BOOL)retroRewind {
  NSError *error = nil;
  if (!KartPadTVWriteRuntimePaths(&error)) {
    [self showFailure:@"KartPad could not prepare its runtime paths."
               error:error retry:^{ [self finishWithRetroRewind:retroRewind]; }];
    return;
  }
  gKartPadTVRetroRewindSelected = retroRewind;
  [NSUserDefaults.standardUserDefaults setObject:
      retroRewind ? @"retro_rewind" : @"base" forKey:kKartPadTVProfileKey];
  self.succeeded = YES;
  self.finished = YES;
}

- (void)showFailure:(NSString *)title error:(NSError *)error
               retry:(void (^)(void))retry {
  __weak KartPadTVLaunchHost *weakSelf = self;
  NSString *message = error.localizedDescription ?: title;
  UIButton *again = KartPadTVButton(@"Try Again", UIColor.systemBlueColor, retry);
  UIButton *back = KartPadTVButton(@"Back", UIColor.systemGrayColor, ^{
    [weakSelf showGameDataState];
  });
  [self.root showStatus:message buttons:@[again, back]];
}

- (void)installArchiveAtPath:(NSString *)archivePath {
  [self.root showStatus:@"Verifying and installing the official Retro Rewind pack…"
                    buttons:@[]];
  __weak KartPadTVLaunchHost *weakSelf = self;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSError *installError = nil;
    BOOL installed = [KartPadRetroRewindInstaller
        installArchiveAtURL:[NSURL fileURLWithPath:archivePath]
                    progress:^(NSString *status, double fraction) {
      dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf.root showStatus:[NSString stringWithFormat:@"%@\n%.0f%%",
            status, fraction * 100.0] buttons:@[]];
      });
    } error:&installError];
    [NSFileManager.defaultManager removeItemAtPath:archivePath error:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
      if (installed) {
        [weakSelf finishWithRetroRewind:YES];
      } else {
        [weakSelf showFailure:@"Retro Rewind installation failed."
                         error:installError retry:^{ [weakSelf downloadRetroRewind]; }];
      }
    });
  });
}

- (void)downloadRetroRewind {
  [self.root showStatus:[NSString stringWithFormat:
      @"Downloading the official Retro Rewind %@ full pack…",
      KartPadRetroRewindInstaller.requiredVersion] buttons:@[]];
  __weak KartPadTVLaunchHost *weakSelf = self;
  self.downloadTask = [NSURLSession.sharedSession
      downloadTaskWithURL:KartPadRetroRewindInstaller.officialArchiveURL
        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
    NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class]
        ? (NSHTTPURLResponse *)response : nil;
    NSError *requestError = error;
    NSString *stagedArchive = nil;
    if (requestError == nil && location != nil && http.statusCode == 200) {
      stagedArchive = [NSTemporaryDirectory() stringByAppendingPathComponent:
          [NSString stringWithFormat:@"KartPad-RetroRewind-%@.zip",
                                     NSUUID.UUID.UUIDString]];
      NSError *moveError = nil;
      if (![NSFileManager.defaultManager moveItemAtURL:location
          toURL:[NSURL fileURLWithPath:stagedArchive] error:&moveError]) {
        requestError = moveError;
        stagedArchive = nil;
      }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      weakSelf.downloadTask = nil;
      if (requestError != nil || stagedArchive == nil || http.statusCode != 200) {
        NSError *shownError = requestError ?: [NSError errorWithDomain:@"dev.kartpad.tv"
            code:http.statusCode userInfo:@{NSLocalizedDescriptionKey:
                @"The official Retro Rewind download did not return a valid response."}];
        [weakSelf showFailure:@"Retro Rewind download failed." error:shownError
                         retry:^{ [weakSelf downloadRetroRewind]; }];
        return;
      }
      [weakSelf installArchiveAtPath:stagedArchive];
    });
  }];
  [self.downloadTask resume];
}

- (void)selectRetroRewind:(BOOL)retroRewind {
  if (!retroRewind) {
    [self finishWithRetroRewind:NO];
    return;
  }
  NSError *error = nil;
  if ([KartPadRetroRewindInstaller validateInstalledRoot:
          KartPadRetroRewindInstaller.installedRootPath error:&error]) {
    [self finishWithRetroRewind:YES];
    return;
  }
  __weak KartPadTVLaunchHost *weakSelf = self;
  UIButton *download = KartPadTVButton(@"Download Official Pack",
                                       UIColor.systemPinkColor, ^{
    [weakSelf downloadRetroRewind];
  });
  UIButton *back = KartPadTVButton(@"Back", UIColor.systemGrayColor, ^{
    [weakSelf showGameDataState];
  });
  double gib = (double)KartPadRetroRewindInstaller.officialArchiveBytes /
               (1024.0 * 1024.0 * 1024.0);
  [self.root showStatus:[NSString stringWithFormat:
      @"Retro Rewind %@ is not installed. KartPad will download, hash-check, and install the official %.2f GiB full pack. The pack may be purged by tvOS and can be downloaded again.",
      KartPadRetroRewindInstaller.requiredVersion, gib]
                    buttons:@[download, back]];
}

- (BOOL)run {
  NSError *error = nil;
  [NSFileManager.defaultManager createDirectoryAtPath:KartPadTVSupportRoot()
      withIntermediateDirectories:YES attributes:nil error:&error];
  [NSFileManager.defaultManager createDirectoryAtPath:
      [KartPadTVSupportRoot() stringByAppendingPathComponent:@"Logs"]
      withIntermediateDirectories:YES attributes:nil error:&error];
  [NSFileManager.defaultManager createDirectoryAtPath:KartPadTVCacheRoot()
      withIntermediateDirectories:YES attributes:nil error:&error];
  UIWindowScene *scene = [self availableScene];
  if (scene == nil) {
    NSLog(@"[KartPad] no tvOS UIWindowScene is available");
    return NO;
  }
  self.root = [[KartPadTVSetupViewController alloc] init];
  self.window = [[UIWindow alloc] initWithWindowScene:scene];
  self.window.windowLevel = UIWindowLevelAlert + 1;
  self.window.rootViewController = self.root;
  [self.window makeKeyAndVisible];
  [self.root loadViewIfNeeded];
  [self showGameDataState];
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

extern "C" bool KartPadMobileEnsureGameDataAvailable() {
  SunPadDiagnosticsStart();
  if (!NSThread.isMainThread) {
    __block BOOL available = NO;
    dispatch_sync(dispatch_get_main_queue(), ^{
      available = [[[KartPadTVLaunchHost alloc] init] run];
    });
    return available;
  }
  return [[[KartPadTVLaunchHost alloc] init] run];
}

extern "C" const char *KartPadMobileSelectedRuntimeProfile() {
  return gKartPadTVRetroRewindSelected ? "retro_rewind" : "base";
}

extern "C" void KartPadMobileRuntimeHostInstall(void *sdlWindow) {
  (void)sdlWindow;
  gKartPadTVRuntimeActive = YES;
  [[KartPadPhysicalControllers sharedControllers] start];
}

extern "C" void KartPadMobileRuntimeHostUninstall() {
  [[KartPadPhysicalControllers sharedControllers] stop];
  gKartPadTVRuntimeActive = NO;
}

extern "C" bool KartPadMobileReadRuntimeSettings(
    KartPadMobileRuntimeSettings *settings) {
  if (settings == nullptr) return false;
  SunPadSettings *source = SunPadSettings.sharedSettings;
  settings->aspectRatioMode = static_cast<int>(source.aspectRatioMode);
  settings->resolutionScale = source.renderScaleFloat;
  settings->showFps = source.showFPSCounter ? 1 : 0;
  return true;
}

extern "C" bool KartPadMobileReadClassicInput(
    KartPadMobileClassicInputSnapshot *snapshot) {
  return KartPadMobileReadClassicInputForPlayer(0, snapshot);
}

extern "C" bool KartPadMobileReadClassicInputForPlayer(
    unsigned int player, KartPadMobileClassicInputSnapshot *snapshot) {
  if (snapshot == nullptr || !gKartPadTVRuntimeActive || player >= 4) return false;
  SunPadInputState source{};
  [[KartPadPhysicalControllers sharedControllers] consumePlayer:player state:&source];
  const KartPadClassicInputState adapted =
      kartpad::mobile::AdaptSunPadInput(source);
  snapshot->buttons = adapted.buttons;
  snapshot->leftStickX = std::clamp(static_cast<float>(adapted.leftStickX) / 127.0f,
                                   -1.0f, 1.0f);
  snapshot->leftStickY = std::clamp(static_cast<float>(adapted.leftStickY) / 127.0f,
                                   -1.0f, 1.0f);
  snapshot->connected = adapted.connected ? 1 : 0;
  return true;
}
