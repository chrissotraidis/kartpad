// Shared iPhone, iPad and Mac release check, included once into each app's
// shell source. It asks GitHub for the latest KartPad release at most once an
// hour, sends nothing about the player or their game, and any failure stays
// silent: the notice simply does not appear. Apple builds come from PadMint,
// so the notice explains how to update rather than installing anything.

#import <Foundation/Foundation.h>

static NSString *const KartPadUpdateLatestURL =
    @"https://api.github.com/repos/chrissotraidis/kartpad/releases/latest";
static NSString *const KartPadUpdateReleasePrefix =
    @"https://github.com/chrissotraidis/kartpad/releases/tag/";
static NSString *const KartPadUpdateCheckedAtKey = @"KartPadUpdateCheckedAt";
static NSString *const KartPadUpdateVersionKey = @"KartPadUpdateVersion";
static NSString *const KartPadUpdatePageKey = @"KartPadUpdatePage";
static const NSTimeInterval KartPadUpdateInterval = 60 * 60;
static const NSUInteger KartPadUpdateMaximumBytes = 512 * 1024;

// "v0.8.1" or "0.8.1" become four numbers; nil for anything else.
[[maybe_unused]] static NSArray<NSNumber *> *KartPadReleaseParts(NSString *value) {
  if (![value isKindOfClass:NSString.class]) return nil;
  NSString *trimmed = [value stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if ([trimmed hasPrefix:@"v"]) trimmed = [trimmed substringFromIndex:1];
  NSArray<NSString *> *parts = [trimmed componentsSeparatedByString:@"."];
  if (parts.count < 2 || parts.count > 4) return nil;
  NSMutableArray<NSNumber *> *numbers = [NSMutableArray array];
  for (NSString *part in parts) {
    if (part.length == 0 || part.length > 6) return nil;
    for (NSUInteger i = 0; i < part.length; ++i) {
      unichar c = [part characterAtIndex:i];
      if (c < '0' || c > '9') return nil;
    }
    [numbers addObject:@(part.integerValue)];
  }
  while (numbers.count < 4) [numbers addObject:@0];
  return numbers;
}

[[maybe_unused]] static BOOL KartPadReleaseIsNewer(NSString *candidate, NSString *current) {
  NSArray<NSNumber *> *next = KartPadReleaseParts(candidate);
  NSArray<NSNumber *> *installed = KartPadReleaseParts(current);
  if (next == nil || installed == nil) return NO;
  for (NSUInteger i = 0; i < 4; ++i) {
    if (next[i].integerValue != installed[i].integerValue)
      return next[i].integerValue > installed[i].integerValue;
  }
  return NO;
}

// @{@"version", @"page"} for a published release, or nil.
[[maybe_unused]] static NSDictionary<NSString *, NSString *> *KartPadParseRelease(NSData *data) {
  if (data.length == 0 || data.length > KartPadUpdateMaximumBytes) return nil;
  id release = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![release isKindOfClass:NSDictionary.class]) return nil;
  if ([release[@"draft"] boolValue] || [release[@"prerelease"] boolValue]) return nil;
  NSArray<NSNumber *> *parts = KartPadReleaseParts(release[@"tag_name"]);
  NSString *page = release[@"html_url"];
  if (parts == nil || ![page isKindOfClass:NSString.class] ||
      ![page hasPrefix:KartPadUpdateReleasePrefix]) return nil;
  NSString *version = [release[@"tag_name"] stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if ([version hasPrefix:@"v"]) version = [version substringFromIndex:1];
  return @{@"version": version, @"page": page};
}

// The last release seen, if it is newer than this app. No network access.
[[maybe_unused]] static NSDictionary<NSString *, NSString *> *KartPadKnownUpdate(void) {
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  NSString *version = [defaults stringForKey:KartPadUpdateVersionKey];
  NSString *page = [defaults stringForKey:KartPadUpdatePageKey];
  NSString *installed = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  if (version == nil || page == nil || !KartPadReleaseIsNewer(version, installed)) return nil;
  return @{@"version": version, @"page": page};
}

// Refreshes the stored release (hourly unless forced) and reports on the main
// queue. checked is NO when the hourly limit skipped the request or it failed.
[[maybe_unused]] static void KartPadRefreshUpdate(BOOL force,
    void (^completion)(NSDictionary<NSString *, NSString *> *update, BOOL checked)) {
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  NSDate *now = NSDate.date;
  NSDate *last = [defaults objectForKey:KartPadUpdateCheckedAtKey];
  if (!force && [last isKindOfClass:NSDate.class] && [now timeIntervalSinceDate:last] >= 0 &&
      [now timeIntervalSinceDate:last] < KartPadUpdateInterval) {
    dispatch_async(dispatch_get_main_queue(), ^{ completion(KartPadKnownUpdate(), NO); });
    return;
  }
  [defaults setObject:now forKey:KartPadUpdateCheckedAtKey];
  NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
  configuration.timeoutIntervalForRequest = 10;
  configuration.timeoutIntervalForResource = 20;
  NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:
      [NSURL URLWithString:KartPadUpdateLatestURL]];
  [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
  [request setValue:@"KartPad-Apple" forHTTPHeaderField:@"User-Agent"];
  [[session dataTaskWithRequest:request completionHandler:
      ^(NSData *data, NSURLResponse *response, NSError *error) {
    BOOL ok = error == nil && [response isKindOfClass:NSHTTPURLResponse.class] &&
        ((NSHTTPURLResponse *)response).statusCode == 200;
    NSDictionary<NSString *, NSString *> *release = ok ? KartPadParseRelease(data) : nil;
    dispatch_async(dispatch_get_main_queue(), ^{
      if (release != nil) {
        [defaults setObject:release[@"version"] forKey:KartPadUpdateVersionKey];
        [defaults setObject:release[@"page"] forKey:KartPadUpdatePageKey];
      }
      completion(KartPadKnownUpdate(), release != nil);
    });
  }] resume];
  [session finishTasksAndInvalidate];
}
