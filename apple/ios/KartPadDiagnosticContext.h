#pragma once
#import <Foundation/Foundation.h>

static inline NSDictionary *KartPadBuildProvenance(NSData *data) {
  if (data == nil || data.length > 8192) return nil;
  id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
  if (![value isKindOfClass:NSDictionary.class]) return nil;
  NSDictionary *input = value;
  auto hex = [](id text, NSUInteger length) {
    if (![text isKindOfClass:NSString.class] || [text length] != length) return false;
    return [text rangeOfCharacterFromSet:
        [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet]].location == NSNotFound;
  };
  if (![input[@"schema"] isEqual:@1] ||
      !(hex(input[@"source_revision"], 40) || hex(input[@"source_revision"], 64)) ||
      CFGetTypeID((__bridge CFTypeRef)(input[@"source_dirty"] ?: NSNull.null)) != CFBooleanGetTypeID() ||
      ![input[@"scope"] isEqual:@"source_inputs_only_not_dependency_or_binary_identity"]) return nil;
  NSMutableDictionary *result = [@{@"schema": @1, @"source_revision": input[@"source_revision"],
      @"source_dirty": input[@"source_dirty"], @"scope": input[@"scope"]} mutableCopy];
  for (NSString *key in @[@"kartpad_source", @"prepared_runtime", @"translation"]) {
    id tree = input[key];
    if (tree == NSNull.null && ![key isEqual:@"kartpad_source"]) { result[key] = NSNull.null; continue; }
    if (![tree isKindOfClass:NSDictionary.class] || !hex(tree[@"sha256"], 64)) return nil;
    id count = tree[@"files"];
    if (![count isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)count) == CFBooleanGetTypeID() ||
        [count doubleValue] != [count longLongValue] || [count longLongValue] < 1 || [count longLongValue] > 10000000) return nil;
    result[key] = @{@"sha256": tree[@"sha256"], @"files": count};
  }
  return result;
}

static inline NSDictionary *KartPadPackagedBuildProvenance() {
  @try {
    NSString *path = [NSBundle.mainBundle pathForResource:@"kartpad-build" ofType:@"json"];
    if (path == nil) return nil;
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *data = [file readDataOfLength:8193];
    [file closeFile];
    return KartPadBuildProvenance(data);
  } @catch (NSException *exception) { (void)exception; return nil; }
}

// Same schema/field semantics as Android's KartPadReportContext. No network or raw file data.
static inline NSString *KartPadDiagnosticContext(NSString *versionPath, NSString *supported,
                                                NSString *profile, double resolution, NSInteger aspect) {
  NSString *installed = nil;
  @try {
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:versionPath];
    if (file != nil) {
      NSData *data = [file readDataOfLength:129];
      [file closeFile];
      if (data.length <= 128) {
        NSString *text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:
            @"^[0-9]+(\\.[0-9]+){1,3}$" options:0 error:nil];
        NSTextCheckingResult *match = [pattern firstMatchInString:text ?: @"" options:0
            range:NSMakeRange(0, text.length)];
        if (text.length <= 64 && match != nil && NSEqualRanges(match.range, NSMakeRange(0, text.length))) installed = text;
      }
    }
  } @catch (NSException *exception) { (void)exception; }
  NSString *state = ![NSFileManager.defaultManager fileExistsAtPath:versionPath] ? @"not_installed"
      : installed == nil ? @"unreadable_or_invalid"
      : [installed isEqualToString:supported] ? @"version_match_only" : @"version_mismatch";
  NSBundle *bundle = NSBundle.mainBundle;
  NSDictionary *context = @{
    @"schema": @1, @"platform": @"ios",
    @"diagnostic_contract": @2,
    @"context_scope": @"export_time_not_selected_session",
    @"capture_support": @{
      @"native_stacks": @"os_dependent",
      @"startup_boundaries": @"bounded_events_v2",
      @"frame_timings": @"bounded_events_v2",
      @"function_cpu": @"selected_functions_candidate_opt_in",
      @"graphics_draws": @"sampled_pnmtx_candidate_opt_in",
      @"network_payloads": @"not_collected", @"guest_memory": @"excluded"},
    @"app_version": [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"unknown",
    @"app_build": [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"unknown",
    @"build_provenance": KartPadPackagedBuildProvenance() ?: NSNull.null,
    @"runtime_profile": profile ?: @"unknown",
    @"captured_unix_ms": @((long long)(NSDate.date.timeIntervalSince1970 * 1000.0)),
    @"monotonic_ms": @((long long)(NSProcessInfo.processInfo.systemUptime * 1000.0)),
    @"monotonic_clock": @"apple_system_uptime",
    @"retro_supported_version": supported,
    @"retro_installed_version": installed ?: NSNull.null,
    @"retro_version_state": state,
    @"retro_code_validation": @"not_rechecked_for_report",
    @"resolution_scale": @(resolution), @"aspect_mode": @(aspect),
    @"renderer_validation": NSNull.null,
  };
  NSData *json = [NSJSONSerialization dataWithJSONObject:context options:NSJSONWritingSortedKeys error:nil];
  return json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"{\"schema\":1,\"error\":\"context_unavailable\"}";
}
