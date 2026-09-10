"""Execute Android and Apple context formatters against synthetic version files."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ReportContextTests(unittest.TestCase):
    def test_apple_bounded_version_and_schema(self):
        if not shutil.which("xcrun"):
            self.skipTest("Apple SDK unavailable")
        source = r'''
#import "KartPadDiagnosticContext.h"
#include <cassert>
int main() { @autoreleasepool {
  NSString *buildText = @"{\"schema\":1,\"source_revision\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\",\"source_dirty\":false,\"scope\":\"source_inputs_only_not_dependency_or_binary_identity\",\"kartpad_source\":{\"sha256\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\",\"files\":12},\"prepared_runtime\":null,\"translation\":null,\"extra\":\"private-content-must-not-export\"}";
  NSData *buildData = [buildText dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *build = KartPadBuildProvenance(buildData);
  assert(build != nil && build[@"extra"] == nil);
  NSString *buildPath = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"kartpad-build.json"];
  assert([buildData writeToFile:buildPath atomically:YES]);
  assert(KartPadPackagedBuildProvenance() != nil);
  assert([[NSMutableData dataWithLength:8193] writeToFile:buildPath atomically:YES]);
  assert(KartPadPackagedBuildProvenance() == nil);
  assert([NSFileManager.defaultManager removeItemAtPath:buildPath error:nil]);
  assert(KartPadPackagedBuildProvenance() == nil);
  assert(KartPadBuildProvenance([@"{}" dataUsingEncoding:NSUTF8StringEncoding]) == nil);
  assert(KartPadBuildProvenance([NSMutableData dataWithLength:8193]) == nil);
  assert(KartPadBuildProvenance([[buildText stringByReplacingOccurrencesOfString:@"bbbb" withString:@"secret"] dataUsingEncoding:NSUTF8StringEncoding]) == nil);
  NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
  [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  NSString *path = [dir stringByAppendingPathComponent:@"version.txt"];
  auto report = [&]() {
    NSString *text = KartPadDiagnosticContext(path, @"6.12.8", @"retro_rewind", 1.0, 0);
    assert(![text containsString:dir]);
    return (NSDictionary *)[NSJSONSerialization JSONObjectWithData:[text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
  };
  assert([report()[@"retro_version_state"] isEqual:@"not_installed"]);
  for (NSString *value in @[@"6.12.8\n", @"6.12.7", @"private-user\nsecret=token", [@"1" stringByPaddingToLength:200 withString:@"1" startingAtIndex:0]]) {
    [value writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSDictionary *result = report();
    assert([result[@"schema"] intValue] == 1);
    assert([result[@"runtime_profile"] isEqual:@"retro_rewind"]);
    assert([result[@"monotonic_ms"] longLongValue] > 0);
    assert([result[@"captured_unix_ms"] longLongValue] > 0);
    assert([result[@"retro_code_validation"] isEqual:@"not_rechecked_for_report"]);
    if ([value isEqual:@"6.12.8\n"]) assert([result[@"retro_version_state"] isEqual:@"version_match_only"]);
    else if ([value isEqual:@"6.12.7"]) assert([result[@"retro_version_state"] isEqual:@"version_mismatch"]);
    else assert(result[@"retro_installed_version"] == NSNull.null);
  }
  [NSFileManager.defaultManager removeItemAtPath:dir error:nil];
} }
'''
        with tempfile.TemporaryDirectory() as temp:
            cpp = Path(temp) / "test.mm"
            bundle = Path(temp) / "Test.app/Contents"
            exe = bundle / "MacOS/test"
            exe.parent.mkdir(parents=True)
            (bundle / "Resources").mkdir()
            (bundle / "Info.plist").write_text('<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>test</string><key>CFBundleIdentifier</key><string>invalid.test.provenance</string></dict></plist>')
            cpp.write_text(source)
            subprocess.run(["xcrun", "clang++", "-std=c++17", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
                            "-framework", "Foundation", "-I", str(ROOT / "apple/ios"), str(cpp), "-o", str(exe)], check=True)
            subprocess.run([str(exe)], check=True)

    def test_android_bounded_version_and_schema(self):
        jdk = Path(os.environ.get("KARTPAD_TEST_JDK", str(ROOT / ".android-bootstrap/jdk-17.0.20.1+1/Contents/Home")))
        if not (jdk / "bin/java").is_file():
            self.skipTest("Set KARTPAD_TEST_JDK to the installed JDK")
        cache = Path.home() / ".gradle/caches/modules-2/files-2.1"
        def jar(package):
            return str(next((cache / package).rglob("*.jar")))
        stdlib = jar("org.jetbrains.kotlin/kotlin-stdlib/2.2.21")
        json = jar("org.json/json/20240303")
        compiler_cp = os.pathsep.join([stdlib, jar("org.jetbrains.kotlin/kotlin-compiler-embeddable/2.2.21"),
            jar("org.jetbrains/annotations/13.0"), jar("org.jetbrains.kotlin/kotlin-reflect/2.2.0"),
            jar("org.jetbrains.kotlinx/kotlinx-coroutines-core-jvm/1.8.0")])
        stubs = {
            "Context.kt": 'package android.content\nclass Context(val filesDir: java.io.File) { val assets = Assets(filesDir) }\nclass Assets(val root: java.io.File) { fun open(name: String): java.io.InputStream = java.io.File(root, "assets/$name").inputStream() }',
            "Clock.kt": 'package android.os\nobject SystemClock { fun elapsedRealtime() = 1234L }',
            "Settings.kt": '''package dev.kartpad.android
object BuildConfig { const val VERSION_NAME = "test"; const val VERSION_CODE = 1 }
object RetroRewindRelease { const val ROOT = "RetroRewind6"; const val VERSION = "6.12.8" }
object KartPadTouchSettings {
 fun resolutionScale(context: android.content.Context) = 1
 fun aspectMode(context: android.content.Context) = 0
}
object KartPadRendererDiagnostics { fun enabled(context: android.content.Context) = true }
''',
            "Test.kt": r'''package dev.kartpad.android
import java.nio.file.Files
import java.io.File
fun main() {
 val root = Files.createTempDirectory("kartpad-report-context-").toFile()
 try {
  val context = android.content.Context(root)
  val buildText = """{"schema":1,"source_revision":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","source_dirty":false,"scope":"source_inputs_only_not_dependency_or_binary_identity","kartpad_source":{"sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","files":12},"prepared_runtime":null,"translation":null,"extra":"private-content-must-not-export"}"""
  val build = KartPadReportContext.buildProvenance(buildText.toByteArray())!!
  check(!build.has("extra"))
  check(KartPadReportContext.buildProvenance("{}".toByteArray()) == null)
  check(KartPadReportContext.buildProvenance(ByteArray(8193)) == null)
  check(KartPadReportContext.buildProvenance(buildText.replace("bbbb", "secret").toByteArray()) == null)
  check(KartPadReportContext.snapshot(context, null).isNull("build_provenance"))
  val asset = File(root, "assets/kartpad-build.json")
  asset.parentFile.mkdirs()
  asset.writeText(buildText)
  check(KartPadReportContext.snapshot(context, null).getJSONObject("build_provenance").getString("source_revision") == "a".repeat(40))
  val path = File(root, "KartPad/RetroRewind/RetroRewind6/version.txt")
  check(KartPadReportContext.snapshot(context, null).getString("retro_version_state") == "not_installed")
  path.parentFile.mkdirs()
  for (value in listOf("6.12.8\n", "6.12.7", "private-user\nsecret=token", "1".repeat(200))) {
   path.writeText(value.replace("\\n", "\n"))
   val result = KartPadReportContext.snapshot(context, "retro_rewind")
   check(result.getInt("schema") == 1)
   check(result.getString("runtime_profile") == "retro_rewind")
   check(result.getLong("monotonic_ms") == 1234L)
   check(!result.toString().contains(root.path))
   check(!result.toString().contains("private-user"))
   check(result.getString("retro_code_validation") == "not_rechecked_for_report")
   if (value.startsWith("6.12.8")) check(result.getString("retro_version_state") == "version_match_only")
   else if (value == "6.12.7") check(result.getString("retro_version_state") == "version_mismatch")
   else check(result.isNull("retro_installed_version"))
  }
  check(KartPadReportContext.snapshot(context, "private-profile").getString("runtime_profile") == "unknown")
  val exported = KartPadReportContext.snapshot(context, null)
  check(exported.isNull("renderer_validation"))
  check(exported.getBoolean("renderer_validation_configured"))
  val inGame = KartPadReportContext.snapshot(context, "base", false)
  check(!inGame.getBoolean("renderer_validation"))
  check(inGame.getBoolean("renderer_validation_configured"))
 } finally { root.deleteRecursively() }
}
'''
        }
        with tempfile.TemporaryDirectory() as temp:
            files = []
            for name, contents in stubs.items():
                path = Path(temp) / name
                path.write_text(contents)
                files.append(str(path))
            output = str(Path(temp) / "test.jar")
            subprocess.run([str(jdk / "bin/java"), "-cp", compiler_cp, "org.jetbrains.kotlin.cli.jvm.K2JVMCompiler",
                "-no-stdlib", "-no-reflect", "-jvm-target", "17", "-classpath", stdlib + os.pathsep + json,
                "-d", output, *files, str(ROOT / "android/app/src/main/java/dev/kartpad/android/KartPadReportContext.kt")], check=True)
            subprocess.run([str(jdk / "bin/java"), "-cp", os.pathsep.join([output, stdlib, json]),
                            "dev.kartpad.android.TestKt"], check=True)


if __name__ == "__main__":
    unittest.main()
