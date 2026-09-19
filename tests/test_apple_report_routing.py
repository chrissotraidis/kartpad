"""Execute the Apple report-copy and draft construction against Foundation."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AppleReportRoutingTests(unittest.TestCase):
    def test_export_copy_and_mac_draft(self):
        if not shutil.which('xcrun'):
            self.skipTest('Apple SDK unavailable')
        ios = (ROOT / 'apple/ios/KartPadRuntimeOverlayHost.mm').read_text()
        start = ios.index('  NSString *report = reportURL ?', ios.index('- (void)createDiagnosticReportFromPrompt:'))
        export = ios[start:ios.index('  dispatch_async(dispatch_get_main_queue()', start)]
        mac = (ROOT / 'apple/macos/KartPadMacShell.mm').read_text()
        start = mac.index('  NSBundle *bundle', mac.index('- (void)reportProblem:'))
        draft = mac[start:mac.index('  NSAlert *choice', start)]
        start = mac.index('    draft = [NSURLComponents', mac.index('- (void)reportProblem:'))
        upstream = mac[start:mac.index('\n  }', start)]
        log_start = mac.index('static NSString *RedactedSessionTail(')
        log_code = mac[log_start:mac.index('static NSString *SHA256ForFile', log_start)]
        up_start = ios.index('    NSString *reportTemplate =', ios.index('- (void)openGitHubReportWithID:', ios.index('- (void)chooseReportDestinationWithID:', 10000)))
        ios_up = ios[up_start:ios.index('\n  }', up_start)]
        source = '''#import <Foundation/Foundation.h>
#include <cassert>
// This fixture tests report routing, not the platform diagnostic collector.
static NSString *KartPadSystemDiagnosticsReport() { return @"System diagnostic fixture"; }
''' + log_code + '''
static NSURL *IOSUpstream(NSString *selectedTemplate) {
  NSDictionary *answers = @{ @"upstreamTemplate": selectedTemplate, @"problem": @"crashed after a race", @"diagnostics": @"reviewed log retained" };
  NSString *problem = answers[@"problem"], *version = @"1", *build = @"2", *reportID = @"KP-test", *platform = @"iPadOS";
  NSURLComponents *components = nil;
''' + ios_up + '''
  return components.URL;
}
static NSURL *Export(NSURL *reportURL) {
  NSError *error = nil;
''' + export + '''
  return reportURL;
}
static NSURL *Draft() {
''' + draft + '''
  return draft.URL;
}
static NSURL *Upstream() {
  NSURLComponents *draft = [NSURLComponents componentsWithURL:Draft() resolvingAgainstBaseURL:NO];
''' + upstream + '''
  return draft.URL;
}
int main() { @autoreleasepool {
  NSURL *dir = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
  assert([NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil]);
  NSURL *original = [dir URLByAppendingPathComponent:@"SunPad-report.txt"];
  NSString *input = @"SunPad Diagnostic Report v2\\nissuesURL=https://github.com/chrissotraidis/sunpad/issues\\nreviewed log";
  assert([input writeToURL:original atomically:YES encoding:NSUTF8StringEncoding error:nil]);
  NSURL *output = Export(original);
  assert([output.lastPathComponent isEqual:@"Latest-KartPad-Diagnostic.log"]);
  NSString *text = [NSString stringWithContentsOfURL:output encoding:NSUTF8StringEncoding error:nil];
  assert([text containsString:@"KartPad Diagnostic Report v2"]);
  assert([text containsString:@"reportOrigin=KartPad"]);
  assert([text containsString:@"issuesURL=https://github.com/chrissotraidis/kartpad/issues"]);
  assert([text containsString:@"reviewed log"]);
  assert([text containsString:@"System diagnostic fixture"]);
  assert([[NSString stringWithContentsOfURL:original encoding:NSUTF8StringEncoding error:nil] isEqual:input]);
  assert(Export(nil) == nil);
  NSMutableString *longLog = [NSMutableString stringWithString:@"WiiCompiled startup version\\n"];
  for (NSUInteger i = 0; i < 100000; ++i) [longLog appendString:@"x"];
  [longLog appendString:@"\\ncrash tail /Users/person/Library/test"];
  assert([longLog writeToURL:original atomically:YES encoding:NSUTF8StringEncoding error:nil]);
  NSString *bounded = RedactedSessionTail(original);
  assert([bounded containsString:@"WiiCompiled startup version"]);
  assert([bounded containsString:@"crash tail"]);
  assert(![bounded containsString:@"/Users/person"]);
  assert(bounded.length < 83000);
  for (NSString *reportTemplate in @[@"1-crash-report.yml", @"2-bug-report.yml", @"4-performance.yml"]) {
    NSURLComponents *typed = [NSURLComponents componentsWithURL:IOSUpstream(reportTemplate) resolvingAgainstBaseURL:NO];
    NSMutableDictionary *typedFields = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *item in typed.queryItems) typedFields[item.name] = item.value;
    assert([typedFields[@"template"] isEqual:reportTemplate]);
    assert([typedFields[@"doing"] containsString:@"crashed after a race"]);
    assert([typedFields[@"logs"] isEqual:@"reviewed log retained"]);
    assert(typedFields[@"preflight"] == nil);
  }
  assert([NSFileManager.defaultManager removeItemAtURL:dir error:nil]);
  NSURLComponents *url = [NSURLComponents componentsWithURL:Draft() resolvingAgainstBaseURL:NO];
  assert([url.host isEqual:@"github.com"]);
  assert([url.path isEqual:@"/chrissotraidis/kartpad/issues/new"]);
  NSMutableDictionary *fields = [NSMutableDictionary dictionary];
  for (NSURLQueryItem *item in url.queryItems) fields[item.name] = item.value;
  assert([fields[@"template"] isEqual:@"bug_report.yml"]);
  assert([fields[@"platform"] containsString:NSProcessInfo.processInfo.operatingSystemVersionString]);
  assert([fields[@"context"] containsString:@"KartPad (modified WiiCompiled"]);
  assert([fields[@"diagnostics"] containsString:@"No diagnostic file has been uploaded"]);
  assert([fields[@"diagnostics"] containsString:@"attach it manually"]);
  NSURLComponents *up = [NSURLComponents componentsWithURL:Upstream() resolvingAgainstBaseURL:NO];
  assert([up.path isEqual:@"/patchzyy/Wiicompiled/issues/new/choose"]);
  assert(up.queryItems.count == 0);
} }
'''
        with tempfile.TemporaryDirectory() as temp:
            cpp = Path(temp) / 'report.mm'
            exe = Path(temp) / 'report'
            cpp.write_text(source)
            subprocess.run(['xcrun', 'clang++', '-std=c++17', '-fobjc-arc', '-Wall', '-Wextra', '-Werror', '-framework', 'Foundation', str(cpp), '-o', str(exe)], check=True)
            subprocess.run([str(exe)], check=True)
