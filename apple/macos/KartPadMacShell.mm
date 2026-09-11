#import "../mobile/KartPadPrivateServerSettings.h"
#import "KartPadMacShell.h"
#import "KartPadMiiManager.h"
#import "KartPadWiimotePairing.h"

#import <AppKit/AppKit.h>
#import <CommonCrypto/CommonDigest.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>


#include <cstdlib>

#include "runtime_config.h"
#if defined(KARTPAD_RUNTIME_PRODUCT_DUAL)
#include "kartpad_retro_rewind_release.h"
#endif

static NSString *KPControllerDiagnostics();
extern "C" void KartPadRequestSettingsReload();
extern "C" void KartPadRequestControllerCompatibility();

static constexpr NSInteger kKartPadMenuTag = 0x4b505344;
static NSString *const kKartPadRuntimeProfileDefaultsKey = @"KartPadRuntimeProfile";
static NSString *const kKartPadBaseProfile = @"base";
static NSString *const kKartPadRetroProfile = @"retro_rewind";

static NSURL *DirectoryURL(const std::filesystem::path &path) {
  const std::string value = path.lexically_normal().string();
  return [NSURL fileURLWithPath:[NSString stringWithUTF8String:value.c_str()]
                   isDirectory:YES];
}

static NSURL *ApplicationSupportURL() {
  return DirectoryURL(RuntimeConfigFile::ApplicationDataDirectory());
}

static NSURL *CacheURL() {
  return DirectoryURL(RuntimeConfigFile::CacheDataDirectory());
}

static NSString *YesNo(BOOL value) { return value ? @"yes" : @"no"; }

static NSString *ActiveRuntimeProfileLabel() {
  const char *profile = std::getenv("KARTPAD_RUNTIME_PROFILE");
  return profile != nullptr && strcmp(profile, "retro_rewind") == 0
      ? @"RMCP01-r0-retro-rewind" : @"RMCP01-r0-base";
}

static NSURL *SessionLogsURL() {
  return [ApplicationSupportURL() URLByAppendingPathComponent:@"Logs"
                                                   isDirectory:YES];
}

static NSURL *CurrentSessionURL() {
  return [SessionLogsURL() URLByAppendingPathComponent:@"session-current.log"];
}

static NSURL *PreviousSessionURL() {
  return [SessionLogsURL() URLByAppendingPathComponent:@"session-previous.log"];
}

static NSURL *ActiveSessionMarkerURL() {
  return [SessionLogsURL() URLByAppendingPathComponent:@".session-active"];
}

static NSString *SessionTimestamp() {
  return [NSISO8601DateFormatter stringFromDate:NSDate.date
                                       timeZone:NSTimeZone.localTimeZone
                                  formatOptions:NSISO8601DateFormatWithInternetDateTime];
}

static void AppendSessionLine(NSString *line) {
  if (line.length == 0) return;
  NSFileHandle *handle = [NSFileHandle fileHandleForWritingToURL:CurrentSessionURL()
                                                          error:nil];
  if (handle == nil) return;
  [handle seekToEndOfFile];
  [handle writeData:[[line stringByAppendingString:@"\n"]
                        dataUsingEncoding:NSUTF8StringEncoding]];
  [handle closeFile];
}

static void MarkSessionClean() {
  @autoreleasepool {
    if (![NSFileManager.defaultManager
            fileExistsAtPath:ActiveSessionMarkerURL().path]) {
      return;
    }
    AppendSessionLine([NSString stringWithFormat:@"ended=%@", SessionTimestamp()]);
    AppendSessionLine(@"endedCleanly=yes");
    [NSFileManager.defaultManager removeItemAtURL:ActiveSessionMarkerURL()
                                            error:nil];
  }
}

static void MarkSessionCleanAtExit() { MarkSessionClean(); }

static void BeginSession() {
  NSFileManager *files = NSFileManager.defaultManager;
  NSURL *logs = SessionLogsURL();
  [files createDirectoryAtURL:logs
  withIntermediateDirectories:YES
                   attributes:nil
                        error:nil];
  const BOOL hadCurrent = [files fileExistsAtPath:CurrentSessionURL().path];
  const BOOL previousWasActive =
      [files fileExistsAtPath:ActiveSessionMarkerURL().path];
  if (hadCurrent) {
    [files removeItemAtURL:PreviousSessionURL() error:nil];
    [files moveItemAtURL:CurrentSessionURL()
                   toURL:PreviousSessionURL()
                   error:nil];
  }

  NSString *previousClean = hadCurrent ? YesNo(!previousWasActive) : @"unknown";
  NSString *manifest = [NSString stringWithFormat:
      @"KartPad bounded session log\n"
       "schema=1\n"
       "started=%@\n"
       "productProfile=%@\n"
       "rendererBackend=Metal\n"
       "guestMemoryStrategy=flat-mach-vm\n"
       "schedulerStrategy=cooperative-fibers\n"
       "previousSessionClean=%@\n"
       "currentSessionState=active\n",
      SessionTimestamp(), ActiveRuntimeProfileLabel(), previousClean];
  [manifest writeToURL:CurrentSessionURL()
            atomically:YES
              encoding:NSUTF8StringEncoding
                 error:nil];
  [@"active\n" writeToURL:ActiveSessionMarkerURL()
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:nil];
  static dispatch_once_t once;
  dispatch_once(&once, ^{ std::atexit(MarkSessionCleanAtExit); });
}

static NSString *RedactedSessionTail(NSURL *url) {
  static constexpr NSUInteger kMaximumTailBytes = 4096;
  NSData *data = [NSData dataWithContentsOfURL:url
                                      options:NSDataReadingMappedIfSafe
                                        error:nil];
  if (data == nil) return @"unavailable";
  const NSUInteger offset = data.length > kMaximumTailBytes
      ? data.length - kMaximumTailBytes : 0;
  NSData *tailData = [data subdataWithRange:NSMakeRange(offset, data.length - offset)];
  NSString *tail = [[NSString alloc] initWithData:tailData
                                         encoding:NSUTF8StringEncoding];
  if (tail == nil) return @"unreadable";

  NSMutableString *redacted = [tail mutableCopy];
  NSArray<NSString *> *patterns = @[
    @"/Users/[^/\\s]+", @"/home/[^/\\s]+", @"[A-Za-z]:\\\\Users\\\\[^\\\\\\s]+"
  ];
  for (NSString *pattern in patterns) {
    NSRegularExpression *expression =
        [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    [expression replaceMatchesInString:redacted
                               options:0
                                 range:NSMakeRange(0, redacted.length)
                          withTemplate:@"<personal-path>"];
  }
  NSString *user = NSUserName();
  if (user.length > 0) {
    [redacted replaceOccurrencesOfString:user
                              withString:@"<user>"
                                 options:0
                                   range:NSMakeRange(0, redacted.length)];
  }
  return [redacted stringByTrimmingCharactersInSet:
      NSCharacterSet.newlineCharacterSet];
}

static NSString *SHA256ForFile(NSString *path, NSError **error) {
  NSData *data = [NSData dataWithContentsOfFile:path
                                       options:NSDataReadingMappedIfSafe
                                         error:error];
  if (data == nil || data.length > UINT32_MAX) return nil;
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, static_cast<CC_LONG>(data.length), digest);
  NSMutableString *result =
      [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (NSUInteger index = 0; index < CC_SHA256_DIGEST_LENGTH; ++index) {
    [result appendFormat:@"%02x", digest[index]];
  }
  return result;
}

static NSString *ResolvedExtractedRoot(NSURL *selectedURL) {
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
        [files fileExistsAtPath:
            [candidate stringByAppendingPathComponent:@"sys/fst.bin"]]) {
      return candidate;
    }
  }
  return nil;
}

static NSString *ValidateExtractedRoot(NSString *root, NSError **error) {
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
      return [NSString stringWithFormat:
          @"The extracted game data is incomplete (missing %@).", relative];
    }
  }

  NSData *boot = [NSData dataWithContentsOfFile:
      [root stringByAppendingPathComponent:@"sys/boot.bin"]
                                             options:0
                                               error:error];
  if (boot == nil) return @"KartPad could not read sys/boot.bin.";
  if (boot.length < 0x20) return @"The selected sys/boot.bin is truncated.";
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

  NSString *hash = SHA256ForFile(
      [root stringByAppendingPathComponent:@"sys/main.dol"], error);
  if (hash == nil) return @"KartPad could not hash sys/main.dol.";
  if (![hash isEqualToString:
      @"80d18895b39c63bd80f457398bfcbb91b7d16ac116a41a88967e954080155b05"]) {
    return @"sys/main.dol does not match the supported RMCP01 revision 0 profile.";
  }
  return nil;
}

static NSString *ConfiguredGameDataRoot() {
  const RuntimeUserConfig config = RuntimeConfigFile::LoadConfigFile();
  if (!config.dvdRoot || config.dvdRoot->empty()) return nil;
  std::filesystem::path root(*config.dvdRoot);
  if (root.is_relative()) root = RuntimeConfigFile::ResolveConfigPath().parent_path() / root;
  return [NSString stringWithUTF8String:root.lexically_normal().string().c_str()];
}

static BOOL WriteGameDataRoot(NSString *root) {
  if (root.length == 0) return NO;
  const bool wrote = RuntimeConfigFile::WriteSetting(
      "paths", "dvd_root",
      RuntimeConfigFile::FormatString(root.fileSystemRepresentation));
  if (wrote) RuntimeConfigFile::Reload();
  return wrote;
}

#if defined(KARTPAD_RUNTIME_PRODUCT_DUAL)
static NSString *ConfiguredRetroRewindRoot() {
  const RuntimeUserConfig config = RuntimeConfigFile::LoadConfigFile();
  if (!config.retroRewindRoot || config.retroRewindRoot->empty()) return nil;
  std::filesystem::path root(*config.retroRewindRoot);
  if (root.is_relative()) root = RuntimeConfigFile::ResolveConfigPath().parent_path() / root;
  return [NSString stringWithUTF8String:root.lexically_normal().string().c_str()];
}

static NSString *ValidateRetroRewindRoot(NSString *root, NSError **error) {
  if (root.length == 0) {
    return [NSString stringWithFormat:
        @"Choose the RetroRewind6 folder from Retro Rewind %@.", @KARTPAD_RR_VERSION];
  }
  NSDictionary<NSString *, NSDictionary<NSString *, id> *> *required = @{
    @KARTPAD_RR_CODE_PUL_PATH: @{
      @"bytes": @(KARTPAD_RR_CODE_PUL_BYTES), @"sha256": @KARTPAD_RR_CODE_PUL_SHA256},
    @KARTPAD_RR_XML_PATH: @{
      @"bytes": @(KARTPAD_RR_XML_BYTES), @"sha256": @KARTPAD_RR_XML_SHA256},
  };
  NSFileManager *files = NSFileManager.defaultManager;
  for (NSString *relative in required) {
    NSString *path = [root stringByAppendingPathComponent:relative];
    NSDictionary *attributes = [files attributesOfItemAtPath:path error:error];
    if (attributes == nil) {
      return [NSString stringWithFormat:@"The Retro Rewind folder is missing %@.", relative];
    }
    if ([attributes fileSize] != [required[relative][@"bytes"] unsignedLongLongValue]) {
      return [NSString stringWithFormat:@"%@ is not from Retro Rewind %@.", relative,
                                        @KARTPAD_RR_VERSION];
    }
    NSString *hash = SHA256ForFile(path, error);
    if (hash == nil || ![hash isEqualToString:required[relative][@"sha256"]]) {
      return [NSString stringWithFormat:@"%@ failed the Retro Rewind %@ integrity check.",
                                        relative, @KARTPAD_RR_VERSION];
    }
  }
  return nil;
}

static BOOL WriteRetroRewindRoot(NSString *root) {
  if (root.length == 0) return NO;
  const bool wrote = RuntimeConfigFile::WriteSetting(
      "paths", "retro_rewind_root",
      RuntimeConfigFile::FormatString(root.fileSystemRepresentation));
  if (wrote) RuntimeConfigFile::Reload();
  return wrote;
}

static NSString *ChooseAndValidateRetroRewindData() {
  NSOpenPanel *panel = NSOpenPanel.openPanel;
  panel.title = @"Choose Retro Rewind";
  panel.message = [NSString stringWithFormat:
      @"Choose the RetroRewind6 folder from the exact supported %@ pack.",
      @KARTPAD_RR_VERSION];
  panel.prompt = @"Choose Retro Rewind";
  panel.canChooseFiles = NO;
  panel.canChooseDirectories = YES;
  panel.allowsMultipleSelection = NO;
  if ([panel runModal] != NSModalResponseOK || panel.URL == nil) return nil;

  NSString *root = panel.URL.path;
  if ([[root lastPathComponent] isEqualToString:@"riivolution"]) {
    root = [root stringByAppendingPathComponent:@KARTPAD_RR_ROOT];
  }
  NSError *error = nil;
  NSString *validation = ValidateRetroRewindRoot(root, &error);
  if (validation == nil && error == nil) return root;
  NSAlert *alert = [NSAlert new];
  alert.messageText = @"Unsupported Retro Rewind Data";
  alert.informativeText = error.localizedDescription.length > 0
      ? error.localizedDescription : validation;
  [alert runModal];
  return @"";
}
#endif

static NSString *ChooseAndValidateGameData() {
  NSOpenPanel *panel = NSOpenPanel.openPanel;
  panel.title = @"Choose Extracted Mario Kart Wii Data";
  panel.message = @"Choose your own extracted RMCP01 DATA folder containing files/ and sys/.";
  panel.prompt = @"Choose Game Data";
  panel.canChooseFiles = NO;
  panel.canChooseDirectories = YES;
  panel.allowsMultipleSelection = NO;
  if ([panel runModal] != NSModalResponseOK || panel.URL == nil) return nil;

  NSError *error = nil;
  NSString *root = ResolvedExtractedRoot(panel.URL);
  NSString *validation = ValidateExtractedRoot(root, &error);
  if (validation == nil && error == nil) return root;

  NSAlert *alert = [NSAlert new];
  alert.messageText = @"Unsupported Game Data";
  alert.informativeText = error.localizedDescription.length > 0
      ? error.localizedDescription : validation;
  [alert runModal];
  return @"";
}

static NSString *DiagnosticsReport() {
  NSFileManager *files = NSFileManager.defaultManager;
  NSURL *support = ApplicationSupportURL();
  NSURL *cache = CacheURL();
  NSURL *config = [support URLByAppendingPathComponent:@"Config.toml"];
  NSURL *logs = [support URLByAppendingPathComponent:@"Logs"];
  NSURL *save = [support
      URLByAppendingPathComponent:
          @"NAND/title/00010004/524d4350/data/rksys.dat"];
  NSBundle *bundle = NSBundle.mainBundle;
  NSString *version =
      [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  if (version.length == 0) version = @"unknown";
  NSString *build = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
  if (build.length == 0) build = @"unknown";
  NSString *generated = [NSISO8601DateFormatter stringFromDate:NSDate.date
                                                     timeZone:NSTimeZone.localTimeZone
                                                formatOptions:NSISO8601DateFormatWithInternetDateTime];
  NSDictionary *fingerprint = nil;
  NSURL *fingerprintURL = [NSBundle.mainBundle.executableURL.URLByDeletingLastPathComponent
      URLByAppendingPathComponent:@"build-fingerprint.json"];
  NSData *fingerprintData = [NSData dataWithContentsOfURL:fingerprintURL];
  if (fingerprintData != nil) {
    id object = [NSJSONSerialization JSONObjectWithData:fingerprintData
                                                options:0
                                                  error:nil];
    if ([object isKindOfClass:NSDictionary.class]) fingerprint = object;
  }
  NSString *sourceCommit = fingerprint[@"SourceCommit"];
  if (![sourceCommit isKindOfClass:NSString.class] || sourceCommit.length != 40) {
    sourceCommit = @"unknown";
  }
  NSString *runtimeHash = fingerprint[@"UnsignedRuntimeSHA256"];
  if (![runtimeHash isKindOfClass:NSString.class] || runtimeHash.length != 64) {
    runtimeHash = @"unknown";
  }

  const RuntimeUserConfig runtime = RuntimeConfigFile::LoadConfigFile();
  NSError *gameDataError = nil;
  NSString *gameDataRoot = ConfiguredGameDataRoot();
  const BOOL gameDataValid =
      ValidateExtractedRoot(gameDataRoot, &gameDataError) == nil && gameDataError == nil;
  const BOOL currentSessionActive =
      [files fileExistsAtPath:ActiveSessionMarkerURL().path];
  NSString *currentSessionTail = RedactedSessionTail(CurrentSessionURL());
  NSString *previousSessionTail = RedactedSessionTail(PreviousSessionURL());
  NSUInteger mappingCount = 0;
  for (const auto &mapping : runtime.controllerButtons) {
    if (mapping && !mapping->empty()) ++mappingCount;
  }
  const float resolution = runtime.resolutionMultiplier.value_or(1.0f);
  const uint32_t interpolation = runtime.frameInterpolationFps.value_or(0);
  const NSInteger volume = lroundf(
      std::clamp(runtime.audioVolume.value_or(1.0f), 0.0f, 1.0f) * 100.0f);
  NSString *displayMode = @"windowed";
  if (runtime.displayMode == "borderless") displayMode = @"borderless";
  if (runtime.displayMode == "fullscreen") displayMode = @"fullscreen";
  return [NSString stringWithFormat:
      @"KartPad diagnostics\n"
       "schema=3\n"
       "generated=%@\n"
       "appVersion=%@\n"
       "appBuild=%@\n"
       "sourceCommit=%@\n"
       "unsignedRuntimeSHA256=%@\n"
       "os=%@\n"
       "architecture=arm64\n"
       "productProfile=%@\n"
       "rendererBackend=Metal\n"
       "guestMemoryStrategy=flat-mach-vm\n"
       "schedulerStrategy=cooperative-fibers\n"
       "displayMode=%@\n"
       "resolutionMultiplier=%.2f\n"
       "frameInterpolationFPS=%u\n"
       "audioVolumePercent=%ld\n"
       "audioMuted=%@\n"
       "networkEnabled=%@\n"
       "controllerMappingsConfigured=%lu\n%@"
       "gameDataConfigured=%@\n"
       "gameDataValidated=%@\n"
       "applicationSupportExists=%@\n"
       "cacheExists=%@\n"
       "configExists=%@\n"
       "logsExist=%@\n"
       "saveExists=%@\n"
       "currentSessionActive=%@\n"
       "sessionTailLimitBytes=4096\n"
       "currentSessionTailBegin\n%@\ncurrentSessionTailEnd\n"
       "previousSessionTailBegin\n%@\npreviousSessionTailEnd\n"
       "reviewWarning=Review this report before sharing. Arbitrary runtime text may still require review.\n"
       "privacy=personal paths are replaced; game data, translated code, save contents, credentials, device identifiers, signing material, and unbounded logs are omitted\n",
      generated, version, build, sourceCommit, runtimeHash,
      NSProcessInfo.processInfo.operatingSystemVersionString,
      ActiveRuntimeProfileLabel(), displayMode, resolution,
      interpolation, (long)volume, YesNo(runtime.audioMuted.value_or(false)),
      YesNo(runtime.networkEnabled.value_or(true)), (unsigned long)mappingCount, KPControllerDiagnostics(),
      YesNo(gameDataRoot.length > 0), YesNo(gameDataValid),
      YesNo([files fileExistsAtPath:support.path]),
      YesNo([files fileExistsAtPath:cache.path]),
      YesNo([files fileExistsAtPath:config.path]),
      YesNo([files fileExistsAtPath:logs.path]),
      YesNo([files fileExistsAtPath:save.path]), YesNo(currentSessionActive),
      currentSessionTail, previousSessionTail];
}

static bool KPFullscreenAcrossNotch() {
  try {
    const auto document=toml::parse(RuntimeConfigFile::ResolveConfigPath().string());
    return RuntimeConfigFile::FindConfigValue<bool>(document,"video","fullscreen_across_notch").value_or(false);
  } catch (const std::exception &) { return false; }
}

#include "KartPadControllers.inc.mm"

@interface KartPadMacShellController : NSObject <NSTabViewDelegate>
@property(nonatomic, strong) NSPanel *settingsPanel;
@property(nonatomic, strong) NSPanel *controlsPanel;
@property(nonatomic, strong) id settingsShortcutMonitor;
@property(nonatomic, strong) NSTabView *settingsTabs;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSControl *> *settingControls;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSArray *> *settingChoices;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSTextField *> *settingValues;
@property(nonatomic, strong) NSTextField *settingsStatus;
@property(nonatomic, weak) NSTextField *playerNameField;
@end

@implementation KartPadMacShellController

- (void)showSimpleAlert:(NSString *)title message:(NSString *)message {
  NSAlert *alert = [NSAlert new];
  alert.messageText = title;
  alert.informativeText = message ?: @"";
  [alert runModal];
}

- (void)quitKartPad:(id)sender {
  for (NSWindow *window in NSApp.windows) {
    if (![window isKindOfClass:NSPanel.class] && window.isVisible) {
      // Let Aurora observe the native close event. Its window-close path
      // flushes placement state and exits without running C++ teardown from a
      // translated guest fiber. That direct exit does not run atexit handlers,
      // so persist the clean marker immediately before handing off.
      MarkSessionClean();
      [window performClose:sender];
      return;
    }
  }
  MarkSessionClean();
  [NSApp terminate:sender];
}

- (void)chooseGameData:(id)sender {
  (void)sender;
  NSString *root = ChooseAndValidateGameData();
  if (root == nil || root.length == 0) return;
  if (!WriteGameDataRoot(root)) {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Game Data Could Not Be Saved";
    alert.informativeText = @"KartPad could not update Config.toml.";
    [alert runModal];
    return;
  }
  NSAlert *alert = [NSAlert new];
  alert.messageText = @"Game Data Ready";
  alert.informativeText =
      @"KartPad validated the RMCP01 data. Quit and reopen KartPad to use it.";
  [alert runModal];
}

#if defined(KARTPAD_RUNTIME_PRODUCT_DUAL)
- (void)chooseRetroRewindData:(id)sender {
  (void)sender;
  NSString *root = ChooseAndValidateRetroRewindData();
  if (root == nil || root.length == 0) return;
  if (!WriteRetroRewindRoot(root)) {
    [self showSimpleAlert:@"Retro Rewind Data Could Not Be Saved"
                  message:@"KartPad could not update Config.toml."];
    return;
  }
  [self showSimpleAlert:@"Retro Rewind Ready"
                message:@"KartPad validated the exact supported pack. Choose Retro Rewind from the Game menu, then reopen KartPad."];
}

- (void)selectRuntimeProfile:(NSString *)profile title:(NSString *)title {
  [NSUserDefaults.standardUserDefaults setObject:profile
                                           forKey:kKartPadRuntimeProfileDefaultsKey];
  [self showSimpleAlert:[NSString stringWithFormat:@"%@ Selected", title]
                message:@"Quit and reopen KartPad to switch games. Your saves and settings are preserved."];
}

- (void)useOriginalGame:(id)sender {
  (void)sender;
  [self selectRuntimeProfile:kKartPadBaseProfile title:@"Original Mario Kart Wii"];
}

- (void)useRetroRewind:(id)sender {
  (void)sender;
  NSError *error = nil;
  NSString *validation = ValidateRetroRewindRoot(ConfiguredRetroRewindRoot(), &error);
  if (validation != nil || error != nil) {
    NSAlert *required = [NSAlert new];
    required.messageText = @"Retro Rewind Data Required";
    required.informativeText = [NSString stringWithFormat:
        @"KartPad needs the exact Retro Rewind %@ RetroRewind6 folder before it can switch games.",
        @KARTPAD_RR_VERSION];
    [required addButtonWithTitle:@"Choose Folder…"];
    [required addButtonWithTitle:@"Cancel"];
    if ([required runModal] != NSAlertFirstButtonReturn) return;
    NSString *root = ChooseAndValidateRetroRewindData();
    if (root == nil || root.length == 0 || !WriteRetroRewindRoot(root)) return;
  }
  [self selectRuntimeProfile:kKartPadRetroProfile title:@"Retro Rewind"];
}
#endif

- (void)showMiiManager:(id)sender {
  (void)sender;
  while (true) {
    NSAlert *manager = [NSAlert new];
    manager.messageText = @"Player Identity";
    manager.informativeText = KartPadHasPendingMiiChanges()
        ? @"Changes are pending. Quit and reopen KartPad to apply them before making another change. Your friend codes and progress are preserved when renaming."
        : @"Set the name used by your Mii and its linked licenses, manage an existing license, or change Mii appearance.";
    [manager addButtonWithTitle:@"Set Player Name…"];
    [manager addButtonWithTitle:@"Existing Licenses…"];
    [manager addButtonWithTitle:@"Mii Appearance…"];
    [manager addButtonWithTitle:@"Done"];
    NSModalResponse response = [manager runModal];
    if (response == NSAlertFirstButtonReturn) [self showPlayerNameEditor];
    else if (response == NSAlertSecondButtonReturn) [self showLicenseManager];
    else if (response == NSAlertThirdButtonReturn) [self showMiiAppearanceManager:nil];
    else return;
  }
}

- (void)playerMiiSelectionChanged:(NSPopUpButton *)sender {
  self.playerNameField.stringValue = sender.selectedItem.representedObject[@"name"];
  [self.playerNameField selectText:nil];
}

- (void)showPlayerNameEditor {
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *records = KartPadMiiRecords(&error);
  if (error != nil || records.count == 0) {
    [self showSimpleAlert:@"Player Identity Unavailable"
                  message:error.localizedDescription ?: @"Start the game once to create its Mii database."];
    return;
  }
  NSPopUpButton *choices = [[NSPopUpButton alloc]
      initWithFrame:NSMakeRect(0, 38, 320, 26) pullsDown:NO];
  for (NSDictionary *record in records) {
    [choices addItemWithTitle:[NSString stringWithFormat:@"Mii %lu · %@",
        (unsigned long)([record[@"slot"] unsignedIntegerValue] + 1), record[@"name"]]];
    choices.lastItem.representedObject = record;
  }
  NSTextField *name = [NSTextField textFieldWithString:records.firstObject[@"name"]];
  self.playerNameField = name;
  choices.target = self;
  choices.action = @selector(playerMiiSelectionChanged:);
  name.placeholderString = @"Player name";
  name.frame = NSMakeRect(0, 0, 320, 26);
  NSView *fields = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 320, 64)];
  [fields addSubview:choices];
  [fields addSubview:name];
  NSAlert *editor = [NSAlert new];
  editor.messageText = @"Set Player Name";
  editor.informativeText = @"Choose the Mii and enter 1–10 characters. On the next launch, its linked licenses will use this name without changing friend codes or progress.";
  editor.accessoryView = fields;
  [editor addButtonWithTitle:@"Save for Next Launch"];
  [editor addButtonWithTitle:@"Cancel"];
  editor.window.initialFirstResponder = name;
  if ([editor runModal] != NSAlertFirstButtonReturn) return;
  NSUInteger index = choices.indexOfSelectedItem;
  if (index >= records.count) return;
  NSUInteger count = 0;
  if (!KartPadStagePlayerName([records[index][@"slot"] unsignedIntegerValue],
                              name.stringValue, &count, &error)) {
    [self showSimpleAlert:@"Player Name Could Not Be Changed" message:error.localizedDescription];
    return;
  }
  [self showSimpleAlert:@"Player Name Scheduled"
                message:@"Quit and reopen KartPad to apply the new name. KartPad backs up the current Mii database and affected saves first."];
}

- (void)showLicenseManager {
  NSError *error = nil;
  NSArray<NSDictionary<NSString *, id> *> *records = KartPadLicenseRecords(&error);
  if (error != nil || records.count == 0) {
    [self showSimpleAlert:@"Existing Licenses"
                  message:error.localizedDescription ?: @"Create a license in the game first, then return here to rename or delete it."];
    return;
  }
  NSPopUpButton *choices = [[NSPopUpButton alloc]
      initWithFrame:NSMakeRect(0, 0, 430, 26) pullsDown:NO];
  for (NSDictionary *record in records) {
    NSString *pending = [record[@"pendingOperation"] length] > 0 ? @" · pending restart" : @"";
    [choices addItemWithTitle:[NSString stringWithFormat:@"%@ · Slot %lu · %@%@",
        record[@"profileTitle"], (unsigned long)([record[@"slot"] unsignedIntegerValue] + 1),
        record[@"name"], pending]];
  }
  NSAlert *actions = [NSAlert new];
  actions.messageText = @"Manage Existing Licenses";
  actions.informativeText = @"Choose the exact game profile and slot. Changes apply after quitting and reopening KartPad. Rename keeps its account and progress; deletion requires another confirmation.";
  actions.accessoryView = choices;
  [actions addButtonWithTitle:@"Rename…"];
  [actions addButtonWithTitle:@"Delete…"];
  [actions addButtonWithTitle:@"Cancel"];
  NSModalResponse response = [actions runModal];
  if (response != NSAlertFirstButtonReturn && response != NSAlertSecondButtonReturn) return;
  NSUInteger index = choices.indexOfSelectedItem;
  if (index >= records.count) return;
  NSDictionary *record = records[index];
  NSAlert *confirm = [NSAlert new];
  confirm.messageText = choices.titleOfSelectedItem;
  BOOL renamed = response == NSAlertFirstButtonReturn;
  NSTextField *name = [NSTextField textFieldWithString:record[@"name"]];
  if (renamed) {
    confirm.informativeText = @"Enter 1–10 characters. Friend code, online account, records and progress are preserved.";
    name.frame = NSMakeRect(0, 0, 320, 26);
    confirm.accessoryView = name;
    [confirm addButtonWithTitle:@"Save for Next Launch"];
    confirm.window.initialFirstResponder = name;
  } else {
    confirm.informativeText = @"Delete only this license? Its friend code, account, records and progress will be removed. The Mii appearance remains. A backup is created before applying the deletion on the next launch.";
    [confirm addButtonWithTitle:@"Delete License"];
  }
  [confirm addButtonWithTitle:@"Cancel"];
  if ([confirm runModal] != NSAlertFirstButtonReturn) return;
  BOOL succeeded = renamed
      ? KartPadStageLicenseRename(record[@"profileIdentifier"], [record[@"slot"] unsignedIntegerValue],
                                  record[@"createId"], name.stringValue, &error)
      : KartPadStageLicenseDeletion(record[@"profileIdentifier"], [record[@"slot"] unsignedIntegerValue],
                                    record[@"createId"], &error);
  [self showSimpleAlert:succeeded ? @"License Change Scheduled" : @"License Could Not Be Changed"
                message:succeeded ? @"Quit and reopen KartPad to apply the change. Your live save is backed up first."
                                  : error.localizedDescription];
}

- (void)showMiiAppearanceManager:(id)sender {
  (void)sender;
  while (true) {
    NSError *error = nil;
    NSArray<NSDictionary<NSString *, id> *> *records = KartPadMiiRecords(&error);
    if (error != nil) {
      [self showSimpleAlert:@"Miis Could Not Be Read"
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
        ? @"\n\nPending changes will be applied on the next launch." : @"";
    NSAlert *manager = [NSAlert new];
    manager.messageText = @"Mii Appearance";
    manager.informativeText = [NSString stringWithFormat:
        @"%lu Mii%@ available: %@%@",
        (unsigned long)records.count, records.count == 1 ? @"" : @"s",
        summary, pending];
    [manager addButtonWithTitle:@"Import Mii…"];
    [manager addButtonWithTitle:@"Remove a Mii…"];
    [manager addButtonWithTitle:@"Create a Mii…"];
    [manager addButtonWithTitle:@"Done"];
    NSModalResponse response = [manager runModal];
    if (response == NSAlertFirstButtonReturn) {
      NSOpenPanel *panel = NSOpenPanel.openPanel;
      panel.title = @"Import Mii";
      panel.message = @"Choose a standard 74-byte .mii file.";
      panel.prompt = @"Import";
      panel.canChooseFiles = YES;
      panel.canChooseDirectories = NO;
      panel.allowsMultipleSelection = NO;
      UTType *miiType = [UTType typeWithFilenameExtension:@"mii"
                                        conformingToType:UTTypeData];
      panel.allowedContentTypes = miiType != nil ? @[miiType] : @[UTTypeData];
      if ([panel runModal] != NSModalResponseOK || panel.URL == nil) continue;
      NSData *data = [NSData dataWithContentsOfURL:panel.URL options:0 error:&error];
      NSString *name = nil;
      if (data == nil || !KartPadStageMiiImport(data, &name, &error)) {
        [self showSimpleAlert:@"Mii Import Failed"
                      message:error.localizedDescription ?: @"The selected file could not be imported."];
        continue;
      }
      [self showSimpleAlert:@"Mii Import Scheduled"
                    message:[NSString stringWithFormat:
          @"%@ will be added the next time KartPad launches. The current database will be backed up automatically.",
          name.length > 0 ? name : @"The selected Mii"]];
      continue;
    }
    if (response == NSAlertSecondButtonReturn) {
      if (records.count == 0) continue;
      NSPopUpButton *choices = [[NSPopUpButton alloc]
          initWithFrame:NSMakeRect(0, 0, 300, 26) pullsDown:NO];
      for (NSDictionary<NSString *, id> *record in records) {
        [choices addItemWithTitle:record[@"name"]];
      }
      NSAlert *remove = [NSAlert new];
      remove.messageText = @"Remove a Mii?";
      remove.informativeText = @"The removal will be applied on the next launch. KartPad always retains at least one Mii.";
      remove.accessoryView = choices;
      [remove addButtonWithTitle:@"Remove"];
      [remove addButtonWithTitle:@"Cancel"];
      if ([remove runModal] != NSAlertFirstButtonReturn) continue;
      NSUInteger index = choices.indexOfSelectedItem;
      if (index >= records.count) continue;
      NSUInteger slot = [records[index][@"slot"] unsignedIntegerValue];
      if (!KartPadStageMiiRemoval(slot, &error)) {
        [self showSimpleAlert:@"Mii Could Not Be Removed"
                      message:error.localizedDescription];
        continue;
      }
      [self showSimpleAlert:@"Mii Removal Scheduled"
                    message:@"Close and reopen KartPad to apply the change. The current database will be backed up automatically."];
      continue;
    }
    if (response == NSAlertThirdButtonReturn) {
      [self showSimpleAlert:@"Create a Mii"
                    message:@"KartPad does not include the Wii Menu or Mii Channel, so it cannot create a new Mii yet. Create or export a standard 74-byte .mii file with a compatible tool, then import it here. After restarting, choose it from Mario Kart Wii's License Settings → Change Mii screen."];
      continue;
    }
    return;
  }
}

- (void)toggleExperimentalWiimote:(NSMenuItem *)sender {
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  const BOOL enabled = ![defaults boolForKey:KartPadExperimentalWiimoteDefaultsKey];
  if (enabled) {
    NSAlert *warning = [NSAlert new];
    warning.messageText = @"Enable Experimental Wii Remote Support?";
    warning.informativeText =
        @"This direct Bluetooth path is intended for original Wii Remote and Wii Remote Plus hardware with a Nunchuk. It uses a private macOS pairing interface, may change across macOS updates, and can conflict with DolphinBar controller mode.";
    [warning addButtonWithTitle:@"Enable and Pair"];
    [warning addButtonWithTitle:@"Cancel"];
    if ([warning runModal] != NSAlertFirstButtonReturn) return;
  }
  [defaults setBool:enabled forKey:KartPadExperimentalWiimoteDefaultsKey];
  sender.state = enabled ? NSControlStateValueOn : NSControlStateValueOff;
  KartPadApplyExperimentalWiimotePreference();
  if (enabled) KartPadShowWiimotePairing();
}

- (void)pairWiimote:(id)sender {
  (void)sender;
  [NSUserDefaults.standardUserDefaults setBool:YES
      forKey:KartPadExperimentalWiimoteDefaultsKey];
  KartPadApplyExperimentalWiimotePreference();
  KartPadShowWiimotePairing();
}

- (void)showControllerSettings:(id)sender {
  (void)sender;
  [self showSettings:sender];
  [self.settingsTabs selectTabViewItemWithIdentifier:@"Controllers"];
}

- (void)showMultiplayer:(id)sender {
  (void)sender;
  NSAlert *alert = [NSAlert new];
  alert.messageText = @"KartPad Multiplayer";
  alert.informativeText = @"Local: choose Multiplayer in either game, then register each controller with A. Use Controls → Controller Settings to assign players.\n\nPrivate friend rooms: use the same game, content version, and service. In Nintendo WFC → Friends, exchange friend codes; the host creates a room and friends join from their roster. Original Mario Kart Wii requires a compatible private Wii server. MeleePad room codes and chat are not available.";
  [alert addButtonWithTitle:@"Done"];
  [alert addButtonWithTitle:@"Private Wii Server…"];
  if ([alert runModal] == NSAlertSecondButtonReturn) [self showPrivateServer:sender];
}

- (void)showPrivateServer:(id)sender {
  (void)sender;
  NSAlert *alert = [NSAlert new];
  alert.messageText = @"Private Wii Server";
  alert.informativeText = @"Experimental setup for both games. Enter a compatible Wii WFC server's hostname or IPv4 address. Everyone must use the same server. Legacy Wii traffic is unencrypted. Changes apply after quitting and reopening KartPad.";
  NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 340, 26)];
  field.stringValue = KartPadPrivateServerHost();
  field.placeholderString = @"Server hostname or IPv4 address";
  field.accessibilityLabel = @"Private Wii server address";
  alert.accessoryView = field;
  [alert addButtonWithTitle:@"Save for Next Launch"];
  [alert addButtonWithTitle:@"Cancel"];
  [alert addButtonWithTitle:@"Use Default Service Next Launch"];
  [alert.window setInitialFirstResponder:field];
  NSModalResponse response = [alert runModal];
  if (response == NSAlertSecondButtonReturn) return;
  if (response == NSAlertThirdButtonReturn) {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"KartPadPrivateWfcHost"];
  } else {
    NSString *host = [field.stringValue stringByTrimmingCharactersInSet:
        NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!KartPad::Network::ValidPrivateWfcHost(host.UTF8String)) {
      NSAlert *error = [NSAlert new];
      error.messageText = @"Invalid Server Address";
      error.informativeText = @"Enter a hostname or IPv4 address without a URL scheme, path, port, or spaces.";
      [error runModal];
      return;
    }
    [NSUserDefaults.standardUserDefaults setObject:host forKey:@"KartPadPrivateWfcHost"];
  }
  NSAlert *saved = [NSAlert new];
  saved.messageText = @"Online Service Saved";
  saved.informativeText = @"Quit and reopen KartPad to apply the change. Private-server compatibility and complete races still need testing.";
  [saved runModal];
}

- (void)showControls:(id)sender {
  (void)sender;
  if (self.controlsPanel == nil) {
    self.controlsPanel = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(0, 0, 560, 430)
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable)
                    backing:NSBackingStoreBuffered
                      defer:NO];
    self.controlsPanel.title = @"KartPad Controls";
    self.controlsPanel.releasedWhenClosed = NO;

    NSTextField *intro = [self label:
        @"Player 1 can use the keyboard or any mapped game controller. Keyboard holds are analog-aware during races."];
    intro.maximumNumberOfLines = 2;
    intro.lineBreakMode = NSLineBreakByWordWrapping;

    NSArray<NSArray<NSString *> *> *bindings = @[
      @[@"Steer", @"W A S D"],
      @[@"Accelerate / confirm", @"U or Return"],
      @[@"Brake / reverse / back", @"M or Delete"],
      @[@"Drift / manual hop", @"E"],
      @[@"Use item", @"Left Shift (Classic L)"],
      @[@"Tricks / menu directions", @"Arrow keys"],
      @[@"Start / pause", @"Space"],
      @[@"Select / minus", @"Tab"],
      @[@"Classic X / Y", @"X / C"],
      @[@"Classic ZL / ZR", @"Z / V"],
      @[@"Settings (also in fullscreen)", @"⌘, or F10 / Fn–F10"],
    ];
    NSMutableArray<NSView *> *rows = [NSMutableArray array];
    for (NSArray<NSString *> *binding in bindings) {
      NSTextField *action = [self label:binding[0]];
      action.font = [NSFont systemFontOfSize:NSFont.systemFontSize
                                      weight:NSFontWeightMedium];
      [action.widthAnchor constraintEqualToConstant:205.0].active = YES;
      NSTextField *keys = [self label:binding[1]];
      NSStackView *row = [NSStackView stackViewWithViews:@[action, keys]];
      row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
      row.alignment = NSLayoutAttributeFirstBaseline;
      row.spacing = 18.0;
      [rows addObject:row];
    }

    NSTextField *more = [self label:
        @"Use Controller Settings… to assign connected controllers, customize buttons and sticks, or manage Players 2–4."];
    more.textColor = NSColor.secondaryLabelColor;
    more.maximumNumberOfLines = 2;
    more.lineBreakMode = NSLineBreakByWordWrapping;

    NSMutableArray<NSView *> *views = [NSMutableArray arrayWithObject:intro];
    [views addObjectsFromArray:rows];
    [views addObject:more];
    NSStackView *content = [NSStackView stackViewWithViews:views];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.orientation = NSUserInterfaceLayoutOrientationVertical;
    content.alignment = NSLayoutAttributeLeading;
    content.spacing = 12.0;
    self.controlsPanel.contentView = [NSView new];
    [self.controlsPanel.contentView addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
      [content.leadingAnchor constraintEqualToAnchor:self.controlsPanel.contentView.leadingAnchor
                                             constant:24.0],
      [content.trailingAnchor constraintEqualToAnchor:self.controlsPanel.contentView.trailingAnchor
                                              constant:-24.0],
      [content.topAnchor constraintEqualToAnchor:self.controlsPanel.contentView.topAnchor
                                         constant:24.0],
      [content.bottomAnchor constraintLessThanOrEqualToAnchor:self.controlsPanel.contentView.bottomAnchor
                                                      constant:-20.0],
      [intro.widthAnchor constraintEqualToAnchor:content.widthAnchor],
      [more.widthAnchor constraintEqualToAnchor:content.widthAnchor]
    ]];
  }

  [self.controlsPanel center];
  [self.controlsPanel makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (NSTextField *)label:(NSString *)text {
  NSTextField *label = [NSTextField labelWithString:text];
  label.font = [NSFont systemFontOfSize:NSFont.systemFontSize];
  return label;
}

- (NSStackView *)rowWithLabel:(NSString *)label control:(NSView *)control {
  NSTextField *title = [self label:label];
  [title.widthAnchor constraintEqualToConstant:122.0].active = YES;
  NSStackView *row = [NSStackView stackViewWithViews:@[title, control]];
  row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
  row.alignment = NSLayoutAttributeCenterY;
  row.spacing = 12.0;
  return row;
}

#include "KartPadMacSettings.inc.mm"

- (void)showApplicationSupport:(id)sender {
  (void)sender;
  NSURL *url = ApplicationSupportURL();
  [NSFileManager.defaultManager createDirectoryAtURL:url
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  [NSWorkspace.sharedWorkspace openURL:url];
}

- (void)showCache:(id)sender {
  (void)sender;
  NSURL *url = CacheURL();
  [NSFileManager.defaultManager createDirectoryAtURL:url
                         withIntermediateDirectories:YES
                                          attributes:nil
                                               error:nil];
  [NSWorkspace.sharedWorkspace openURL:url];
}

- (void)saveDiagnostics:(id)sender {
  (void)sender;
  NSSavePanel *panel = NSSavePanel.savePanel;
  panel.title = @"Save KartPad Diagnostics";
  panel.nameFieldStringValue = @"KartPad-Diagnostics.txt";
  panel.allowedContentTypes = @[UTTypePlainText];
  [panel beginWithCompletionHandler:^(NSModalResponse response) {
    if (response != NSModalResponseOK || panel.URL == nil) return;
    NSError *error = nil;
    if (![DiagnosticsReport() writeToURL:panel.URL
                              atomically:YES
                                encoding:NSUTF8StringEncoding
                                   error:&error]) {
      NSAlert *alert = [NSAlert new];
      alert.messageText = @"Diagnostics Could Not Be Saved";
      NSString *description = error.localizedDescription;
      alert.informativeText =
          description.length == 0 ? @"Unknown write error." : description;
      [alert runModal];
    }
  }];
}

@end

static KartPadMacShellController *Controller() {
  static KartPadMacShellController *controller;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ controller = [KartPadMacShellController new]; });
  return controller;
}

extern "C" void KartPadOpenSettingsFromShortcut() {
  // SDL event handling can run inside a guest fiber. Open AppKit UI on the
  // next native run-loop turn rather than re-entering the event pump here.
  dispatch_async(dispatch_get_main_queue(), ^{ [Controller() showSettings:nil]; });
}

static void InstallSettingsShortcutMonitor() {
  KartPadMacShellController *controller = Controller();
  if (controller.settingsShortcutMonitor != nil) return;
  controller.settingsShortcutMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
      handler:^NSEvent *(NSEvent *event) {
        const NSEventModifierFlags modifiers = event.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask;
        const bool functionKey = event.keyCode == 109;
        const bool commandComma = event.keyCode == 47 && (modifiers & NSEventModifierFlagCommand) &&
            !(modifiers & (NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagShift));
        if ((functionKey && !(modifiers & (NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand))) ||
            commandComma) {
          KartPadOpenSettingsFromShortcut();
          return nil;
        }
        return event;
      }];
}

static void InstallMenu() {
  NSMenu *mainMenu = NSApp.mainMenu;
  if (mainMenu == nil) {
    mainMenu = [NSMenu new];
    NSApp.mainMenu = mainMenu;
  }

  NSMenuItem *appItem = mainMenu.itemArray.firstObject;
  if (appItem == nil) {
    appItem = [[NSMenuItem alloc] initWithTitle:@"KartPad" action:nil keyEquivalent:@""];
    [mainMenu addItem:appItem];
  }
  NSMenu *appMenu = appItem.submenu;
  if (appMenu == nil) {
    appMenu = [[NSMenu alloc] initWithTitle:@"KartPad"];
    appItem.submenu = appMenu;
  }
  if ([mainMenu itemWithTag:kKartPadMenuTag] != nil) return;

  bool hasStandardApplicationMenu = false;
  for (NSMenuItem *item in appMenu.itemArray) {
    if ([item.title hasPrefix:@"About "] ||
        item.action == @selector(orderFrontStandardAboutPanel:)) {
      hasStandardApplicationMenu = true;
      break;
    }
  }
  if (!hasStandardApplicationMenu) {
    [appMenu removeAllItems];

    NSMenuItem *about = [[NSMenuItem alloc]
        initWithTitle:@"About KartPad"
               action:@selector(orderFrontStandardAboutPanel:)
        keyEquivalent:@""];
    about.target = NSApp;
    [appMenu addItem:about];
    [appMenu addItem:NSMenuItem.separatorItem];

    NSMenuItem *settings = [[NSMenuItem alloc]
        initWithTitle:@"Settings…"
               action:@selector(showSettings:)
        keyEquivalent:@","];
    settings.target = Controller();
    [appMenu addItem:settings];
    [appMenu addItem:NSMenuItem.separatorItem];

    NSMenuItem *services = [[NSMenuItem alloc]
        initWithTitle:@"Services" action:nil keyEquivalent:@""];
    services.submenu = [[NSMenu alloc] initWithTitle:@"Services"];
    NSApp.servicesMenu = services.submenu;
    [appMenu addItem:services];
    [appMenu addItem:NSMenuItem.separatorItem];

    NSMenuItem *hide = [[NSMenuItem alloc]
        initWithTitle:@"Hide KartPad" action:@selector(hide:) keyEquivalent:@"h"];
    hide.target = NSApp;
    [appMenu addItem:hide];
    NSMenuItem *hideOthers = [[NSMenuItem alloc]
        initWithTitle:@"Hide Others"
               action:@selector(hideOtherApplications:)
        keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask =
        NSEventModifierFlagOption | NSEventModifierFlagCommand;
    hideOthers.target = NSApp;
    [appMenu addItem:hideOthers];
    NSMenuItem *showAll = [[NSMenuItem alloc]
        initWithTitle:@"Show All"
               action:@selector(unhideAllApplications:)
        keyEquivalent:@""];
    showAll.target = NSApp;
    [appMenu addItem:showAll];
    [appMenu addItem:NSMenuItem.separatorItem];

    NSMenuItem *quit = [[NSMenuItem alloc]
        initWithTitle:@"Quit KartPad"
               action:@selector(quitKartPad:)
        keyEquivalent:@"q"];
    quit.target = Controller();
    [appMenu addItem:quit];
  }

  for (NSMenuItem *item in appMenu.itemArray) {
    if ([item.title hasPrefix:@"Settings"] ||
        [item.title hasPrefix:@"Preferences"]) {
      item.target = Controller();
      item.action = @selector(showSettings:);
      item.enabled = YES;
    } else if (item.action == @selector(terminate:)) {
      item.target = Controller();
      item.action = @selector(quitKartPad:);
    }
  }

  NSInteger productMenuIndex = mainMenu.numberOfItems;
  for (NSInteger index = 0; index < mainMenu.numberOfItems; ++index) {
    if ([[mainMenu itemAtIndex:index].title isEqualToString:@"Window"]) {
      productMenuIndex = index;
      break;
    }
  }
  NSMenuItem *gameMenuItem = [[NSMenuItem alloc]
      initWithTitle:@"Game" action:nil keyEquivalent:@""];
  gameMenuItem.tag = kKartPadMenuTag;
  NSMenu *gameMenu = [[NSMenu alloc] initWithTitle:@"Game"];
#if defined(KARTPAD_RUNTIME_PRODUCT_DUAL)
  NSString *activeProfile = NSUserDefaults.standardUserDefaults
      ? [NSUserDefaults.standardUserDefaults stringForKey:kKartPadRuntimeProfileDefaultsKey]
      : nil;
  if (activeProfile.length == 0) activeProfile = kKartPadBaseProfile;
  NSMenuItem *original = [[NSMenuItem alloc]
      initWithTitle:@"Original Mario Kart Wii"
             action:@selector(useOriginalGame:) keyEquivalent:@"1"];
  original.target = Controller();
  original.state = [activeProfile isEqualToString:kKartPadBaseProfile]
      ? NSControlStateValueOn : NSControlStateValueOff;
  [gameMenu addItem:original];
  NSMenuItem *retro = [[NSMenuItem alloc]
      initWithTitle:@"Retro Rewind"
             action:@selector(useRetroRewind:) keyEquivalent:@"2"];
  retro.target = Controller();
  retro.state = [activeProfile isEqualToString:kKartPadRetroProfile]
      ? NSControlStateValueOn : NSControlStateValueOff;
  [gameMenu addItem:retro];
  [gameMenu addItem:NSMenuItem.separatorItem];
#endif
  NSMenuItem *settings = [[NSMenuItem alloc]
      initWithTitle:@"Game Settings…" action:@selector(showSettings:)
      keyEquivalent:@""];
  settings.target = Controller();
  [gameMenu addItem:settings];
  gameMenuItem.submenu = gameMenu;
  [mainMenu insertItem:gameMenuItem atIndex:productMenuIndex++];

  NSMenuItem *dataMenuItem = [[NSMenuItem alloc]
      initWithTitle:@"Data" action:nil keyEquivalent:@""];
  NSMenu *dataMenu = [[NSMenu alloc] initWithTitle:@"Data"];
  NSMenuItem *gameData = [[NSMenuItem alloc]
      initWithTitle:@"Choose Mario Kart Wii Data…" action:@selector(chooseGameData:)
      keyEquivalent:@""];
  gameData.target = Controller();
  [dataMenu addItem:gameData];
#if defined(KARTPAD_RUNTIME_PRODUCT_DUAL)
  NSMenuItem *retroData = [[NSMenuItem alloc]
      initWithTitle:@"Choose Retro Rewind Data…"
             action:@selector(chooseRetroRewindData:) keyEquivalent:@""];
  retroData.target = Controller();
  [dataMenu addItem:retroData];
#endif
  NSMenuItem *miis = [[NSMenuItem alloc]
      initWithTitle:@"Player Identity…" action:@selector(showMiiManager:)
      keyEquivalent:@""];
  miis.target = Controller();
  [dataMenu addItem:miis];
  [dataMenu addItem:NSMenuItem.separatorItem];
  NSMenuItem *data = [[NSMenuItem alloc]
      initWithTitle:@"Show KartPad Data"
             action:@selector(showApplicationSupport:) keyEquivalent:@""];
  data.target = Controller();
  [dataMenu addItem:data];
  NSMenuItem *cache = [[NSMenuItem alloc]
      initWithTitle:@"Show KartPad Cache"
             action:@selector(showCache:) keyEquivalent:@""];
  cache.target = Controller();
  [dataMenu addItem:cache];
  dataMenuItem.submenu = dataMenu;
  [mainMenu insertItem:dataMenuItem atIndex:productMenuIndex++];

  NSMenuItem *controlsMenuItem = [[NSMenuItem alloc]
      initWithTitle:@"Controls" action:nil keyEquivalent:@""];
  NSMenu *controlsMenu = [[NSMenu alloc] initWithTitle:@"Controls"];
  NSMenuItem *multiplayer = [[NSMenuItem alloc]
      initWithTitle:@"Multiplayer…" action:@selector(showMultiplayer:) keyEquivalent:@""];
  multiplayer.target = Controller();
  [controlsMenu addItem:multiplayer];

  NSMenuItem *controllerSettings = [[NSMenuItem alloc]
      initWithTitle:@"Controller Settings…"
             action:@selector(showControllerSettings:) keyEquivalent:@""];
  controllerSettings.target = Controller();
  [controlsMenu addItem:controllerSettings];
  NSMenuItem *controls = [[NSMenuItem alloc]
      initWithTitle:@"Control Reference…" action:@selector(showControls:)
      keyEquivalent:@"/"];
  controls.keyEquivalentModifierMask = NSEventModifierFlagCommand;
  controls.target = Controller();
  [controlsMenu addItem:controls];
  [controlsMenu addItem:NSMenuItem.separatorItem];
  NSMenuItem *experimentalWiimote = [[NSMenuItem alloc]
      initWithTitle:@"Experimental Wii Remote + Nunchuk"
             action:@selector(toggleExperimentalWiimote:) keyEquivalent:@""];
  experimentalWiimote.target = Controller();
  experimentalWiimote.state = [NSUserDefaults.standardUserDefaults
      boolForKey:KartPadExperimentalWiimoteDefaultsKey]
      ? NSControlStateValueOn : NSControlStateValueOff;
  [controlsMenu addItem:experimentalWiimote];
  NSMenuItem *pairWiimote = [[NSMenuItem alloc]
      initWithTitle:@"Pair Wii Remote…" action:@selector(pairWiimote:)
      keyEquivalent:@""];
  pairWiimote.target = Controller();
  [controlsMenu addItem:pairWiimote];
  controlsMenuItem.submenu = controlsMenu;
  [mainMenu insertItem:controlsMenuItem atIndex:productMenuIndex];

  NSMenuItem *helpMenuItem = [[NSMenuItem alloc]
      initWithTitle:@"Help" action:nil keyEquivalent:@""];
  NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
  NSString *diagnosticsTitle =
      [@"Save Diagnostics Report" stringByAppendingString:@"…"];
  NSMenuItem *diagnostics = [[NSMenuItem alloc]
      initWithTitle:diagnosticsTitle
             action:@selector(saveDiagnostics:)
      keyEquivalent:@""];
  diagnostics.target = Controller();
  [helpMenu addItem:diagnostics];
  helpMenuItem.submenu = helpMenu;
  [mainMenu addItem:helpMenuItem];
}

void KartPadMacShellInstall(void) {
  if (KPFullscreenAcrossNotch()) {
    SDL_SetHint(SDL_HINT_VIDEO_MAC_FULLSCREEN_SPACES, "0");
    SDL_SetHint(SDL_HINT_VIDEO_MAC_FULLSCREEN_MENU_VISIBILITY, "never");
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    [NSApplication sharedApplication];
    InstallSettingsShortcutMonitor();
    InstallMenu();
  });
}

bool KartPadMacShellPrepareGameData(void) {
  KartPadApplyPrivateServerAtLaunch();
  @autoreleasepool {
    const std::filesystem::path configPath = RuntimeConfigFile::ResolveConfigPath();
    const bool hadConfig = std::filesystem::exists(configPath);
    NSError *miiError = nil;
    if (!KartPadApplyPendingMiiDatabase(&miiError)) {
      NSLog(@"[KartPad] pending Mii changes were not applied: %@",
            miiError.localizedDescription);
    }
    KartPadApplyExperimentalWiimotePreference();
    RuntimeConfigFile::EnsureConfigFile();
    const RuntimeUserConfig initialConfig = RuntimeConfigFile::LoadConfigFile();
    const bool unconfigured = !initialConfig.dvdRoot && !initialConfig.retroRewindRoot;
    if (!hadConfig || unconfigured) {
      RuntimeConfigFile::WriteSetting("video", "resolution_multiplier", "2.0");
      RuntimeConfigFile::Reload();
    }
#if defined(KARTPAD_RUNTIME_PRODUCT_DUAL)
    NSString *selectedProfile = [NSUserDefaults.standardUserDefaults
        stringForKey:kKartPadRuntimeProfileDefaultsKey];
    if (![selectedProfile isEqualToString:kKartPadRetroProfile]) {
      selectedProfile = kKartPadBaseProfile;
    }
    if ([selectedProfile isEqualToString:kKartPadRetroProfile]) {
      NSError *retroError = nil;
      if (ValidateRetroRewindRoot(ConfiguredRetroRewindRoot(), &retroError) != nil ||
          retroError != nil) {
        selectedProfile = kKartPadBaseProfile;
        [NSUserDefaults.standardUserDefaults setObject:selectedProfile
                                                 forKey:kKartPadRuntimeProfileDefaultsKey];
      }
    }
    setenv("KARTPAD_RUNTIME_PROFILE", selectedProfile.UTF8String, 1);
#endif
    BeginSession();

    // The command-line self-build has already extracted and validated the
    // supplied WBFS. Let it hand that private tree to the app without forcing
    // the user through an unrelated folder picker on first launch.
    if (const char *prepared = std::getenv("KARTPAD_SELF_BUILD_GAME_DATA_ROOT");
        prepared != nullptr && *prepared != '\0') {
      NSString *root = [NSString stringWithUTF8String:prepared];
      NSError *preparedError = nil;
      NSString *validation = ValidateExtractedRoot(root, &preparedError);
      BOOL configured = validation == nil && preparedError == nil &&
                        WriteGameDataRoot(root);
#if defined(KARTPAD_RUNTIME_PRODUCT_DUAL)
      const char *preparedRetro =
          std::getenv("KARTPAD_SELF_BUILD_RETRO_REWIND_ROOT");
      if (configured && preparedRetro != nullptr && *preparedRetro != '\0') {
        NSString *retroRoot = [NSString stringWithUTF8String:preparedRetro];
        NSError *retroError = nil;
        NSString *retroValidation = ValidateRetroRewindRoot(retroRoot, &retroError);
        configured = retroValidation == nil && retroError == nil &&
                     WriteRetroRewindRoot(retroRoot);
      }
#endif
      if (configured) {
        std::cout << "[kartpad-macos] Configured validated self-build game data."
                  << std::endl;
      } else {
        std::cerr << "[kartpad-macos] Unable to configure self-build game data: "
                  << (preparedError.localizedDescription.UTF8String ?:
                      validation.UTF8String ?: "unknown error")
                  << std::endl;
      }
      MarkSessionClean();
      return false;
    }

    NSError *error = nil;
    NSString *configured = ConfiguredGameDataRoot();
    if (ValidateExtractedRoot(configured, &error) == nil && error == nil) {
      return true;
    }

    NSApplication *app = [NSApplication sharedApplication];
    [app setActivationPolicy:NSApplicationActivationPolicyRegular];
    [app finishLaunching];
    [app activateIgnoringOtherApps:YES];
    NSMenu *temporaryMainMenu = nil;
    if (app.mainMenu == nil) {
      temporaryMainMenu = [NSMenu new];
      NSMenuItem *applicationItem =
          [[NSMenuItem alloc] initWithTitle:@"KartPad" action:nil keyEquivalent:@""];
      applicationItem.submenu = [[NSMenu alloc] initWithTitle:@"KartPad"];
      [temporaryMainMenu addItem:applicationItem];
      app.mainMenu = temporaryMainMenu;
    }
    auto finishFirstRunMenu = [&] {
      if (temporaryMainMenu != nil && app.mainMenu == temporaryMainMenu) {
        app.mainMenu = nil;
      }
    };
    dispatch_async(dispatch_get_main_queue(), ^{
      [NSApp activateIgnoringOtherApps:YES];
    });
    for (;;) {
      NSAlert *required = [NSAlert new];
      required.messageText = @"Game Data Required";
      required.informativeText =
          @"KartPad does not include Mario Kart Wii. Choose your own extracted RMCP01 DATA folder to continue. Disc-image extraction and translation remain part of the Mac self-build workflow.";
      [required addButtonWithTitle:@"Choose Extracted Folder…"];
      [required addButtonWithTitle:@"Quit"];
      if ([required runModal] != NSAlertFirstButtonReturn) {
        finishFirstRunMenu();
        return false;
      }

      NSString *root = ChooseAndValidateGameData();
      if (root == nil) {
        finishFirstRunMenu();
        return false;
      }
      if (root.length == 0) continue;
      if (WriteGameDataRoot(root)) {
        finishFirstRunMenu();
        return true;
      }

      NSAlert *writeError = [NSAlert new];
      writeError.messageText = @"Game Data Could Not Be Saved";
      writeError.informativeText = @"KartPad could not update Config.toml.";
      [writeError runModal];
    }
  }
}
