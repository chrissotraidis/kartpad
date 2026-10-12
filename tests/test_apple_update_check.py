"""The shared iPhone/iPad/Mac release check: version order and trusted releases only."""
from pathlib import Path
import platform
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "apple/shared/KartPadUpdateCheck.inc.mm"

PROBE = r'''
#include "%s"
#include <cassert>
static NSData *json(NSString *text) { return [text dataUsingEncoding:NSUTF8StringEncoding]; }
int main() {
  @autoreleasepool {
    assert(KartPadReleaseIsNewer(@"v0.8.1", @"0.8.0"));
    assert(KartPadReleaseIsNewer(@"0.10.0", @"0.9.9"));
    assert(KartPadReleaseIsNewer(@"v1.0", @"0.8.0"));
    assert(!KartPadReleaseIsNewer(@"v0.8.0", @"0.8.0"));
    assert(!KartPadReleaseIsNewer(@"v0.7.15", @"0.8.0"));
    assert(!KartPadReleaseIsNewer(@"v0.8.1-beta", @"0.8.0"));
    assert(!KartPadReleaseIsNewer(@"v0.8.1", nil));
    assert(!KartPadReleaseIsNewer(@"0.8.1.1.1", @"0.8.0"));
    NSString *page = @"https://github.com/chrissotraidis/kartpad/releases/tag/v0.8.1";
    NSDictionary *release = KartPadParseRelease(json([NSString stringWithFormat:
        @"{\"tag_name\":\"v0.8.1\",\"html_url\":\"%%@\",\"draft\":false,\"prerelease\":false}", page]));
    assert([release[@"version"] isEqualToString:@"0.8.1"] && [release[@"page"] isEqualToString:page]);
    assert(KartPadParseRelease(json(@"{\"tag_name\":\"v0.8.1\",\"html_url\":\"https://example.com/releases/tag/v0.8.1\"}")) == nil);
    assert(KartPadParseRelease(json([NSString stringWithFormat:
        @"{\"tag_name\":\"v0.8.1\",\"html_url\":\"%%@\",\"prerelease\":true}", page])) == nil);
    assert(KartPadParseRelease(json([NSString stringWithFormat:
        @"{\"tag_name\":\"v0.8.1\",\"html_url\":\"%%@\",\"draft\":true}", page])) == nil);
    assert(KartPadParseRelease(json(@"[]")) == nil);
    assert(KartPadParseRelease(json(@"not json")) == nil);
    assert(KartPadParseRelease([NSMutableData dataWithLength:KartPadUpdateMaximumBytes + 1]) == nil);
  }
  return 0;
}
'''


@unittest.skipUnless(platform.system() == "Darwin", "needs Foundation")
class AppleUpdateCheck(unittest.TestCase):
    def test_version_order_and_trusted_releases(self):
        with tempfile.TemporaryDirectory() as directory:
            probe, exe = Path(directory) / "probe.mm", Path(directory) / "probe"
            probe.write_text(PROBE % SOURCE)
            build = subprocess.run(["clang++", "-std=c++20", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
                                    "-UNDEBUG", str(probe), "-framework", "Foundation", "-o", str(exe)],
                                   capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            result = subprocess.run([str(exe)], capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_both_apple_shells_include_the_check(self):
        ios = (ROOT / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        mac = (ROOT / "apple/macos/KartPadMacShell.mm").read_text()
        for text in (ios, mac):
            self.assertIn('#include "KartPadUpdateCheck.inc.mm"', text)
            self.assertIn("KartPadRefreshUpdate(NO,", text)
        self.assertIn('@"kartpad.setup.update"', ios)
        self.assertIn("@selector(checkForUpdates:)", mac)


if __name__ == "__main__":
    unittest.main()
