"""Exercise the real sound helper and resign-active handler against a temp Config.toml."""
import platform
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(platform.system() == "Darwin", "Requires Apple Foundation")
class SoundPersistence(unittest.TestCase):
    def test_background_saves_live_levels_without_closing_sheet(self):
        runtime = ROOT / "vendor/runtimes/ios/runtime"
        if not (runtime / "third_party/toml11/toml.hpp").is_file():
            self.skipTest("Initialize the maintained iOS runtime submodule")
        if not shutil.which("clang++"):
            self.skipTest("Requires Apple command-line tools")
        source = (ROOT / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        helper = source[source.index('static NSString *const kKartPadSoundCustomKey'):
                        source.index('@interface KartPadSoundSettingsController')]
        handler = source[source.index('- (void)applicationWillResignActive:'):
                         source.index('- (void)applicationDidBecomeActive:')]
        # Isolate preferences as well as the real runtime's portable config directory.
        helper = helper.replace('NSUserDefaults.standardUserDefaults', 'testDefaults')
        handler = handler.replace('NSUserDefaults.standardUserDefaults', 'testDefaults')
        program = '''#import <Foundation/Foundation.h>
#include "runtime_config.h"
static NSUserDefaults *testDefaults;
namespace MusicAttenuation {
static float music=1, effects=1, voices=1, ui=1;
void SetMusicVolume(float v){music=v;}
void SetSoundEffectsVolume(float v){effects=v;}
void SetVoicesVolume(float v){voices=v;}
void SetUiVolume(float v){ui=v;}
}
@interface SunPadInputMixer : NSObject
+ (instancetype)sharedMixer;
- (void)clearInputFromTouch:(BOOL)touch;
@end
@implementation SunPadInputMixer
+ (instancetype)sharedMixer { return nil; }
- (void)clearInputFromTouch:(BOOL)touch { (void)touch; }
@end
@interface KartPadMotionSteering : NSObject
+ (instancetype)sharedSteering;
- (void)stop;
@end
@implementation KartPadMotionSteering
+ (instancetype)sharedSteering { return nil; }
- (void)stop {}
@end
@interface KartPadGameOverlay : NSObject
- (void)resetKartPadControlAppearance;
@end
@implementation KartPadGameOverlay
- (void)resetKartPadControlAppearance {}
@end
''' + helper + '''
@interface SoundHost : NSObject { id _overlay; }
@end
@implementation SoundHost
''' + handler + '''
@end
int main() { @autoreleasepool {
 NSString *domain = [@"KartPadSoundTest." stringByAppendingString:NSUUID.UUID.UUIDString];
 testDefaults = [[NSUserDefaults alloc] initWithSuiteName:domain];
 SoundHost *host = [SoundHost new];
 auto *center = NSNotificationCenter.defaultCenter;
 [center addObserver:host selector:@selector(applicationWillResignActive:) name:@"Resign" object:nil];
 [center postNotificationName:@"Resign" object:nil];
 if (std::filesystem::exists(RuntimeConfigFile::ResolveConfigPath())) return 10;
 RuntimeConfigFile::EnsureConfigFile();
 RuntimeConfigFile::SetMusicVolume(1);
 RuntimeConfigFile::SetResolutionMultiplier(1.5f);
 [testDefaults setBool:YES forKey:kKartPadSoundCustomKey];
 [testDefaults setInteger:0 forKey:kKartPadSoundMusicKey];
 [testDefaults setInteger:25 forKey:kKartPadSoundGameKey];
 KartPadApplySoundLevels(NO);
 bool live = MusicAttenuation::music == 0 && MusicAttenuation::effects == .25f;
 RuntimeConfigFile::Reload();
 bool deferred = RuntimeConfigFile::Get().audioMusicVolume == 1;
 [center postNotificationName:@"Resign" object:nil];
 RuntimeConfigFile::Reload();
 bool saved = RuntimeConfigFile::Get().audioMusicVolume == 0 &&
     RuntimeConfigFile::Get().audioSoundEffectsVolume == .25f &&
     RuntimeConfigFile::Get().audioVoicesVolume == .25f &&
     RuntimeConfigFile::Get().audioUiVolume == .25f &&
     RuntimeConfigFile::Get().resolutionMultiplier == 1.5f;
 [testDefaults setBool:NO forKey:kKartPadSoundCustomKey];
 KartPadApplySoundLevels(NO);
 [center postNotificationName:@"Resign" object:nil];
 RuntimeConfigFile::Reload();
 bool off = RuntimeConfigFile::Get().audioMusicVolume == 1 &&
     RuntimeConfigFile::Get().audioSoundEffectsVolume == 1;
 [testDefaults removePersistentDomainForName:domain];
 [center removeObserver:host];
 if (!(live && deferred && saved && off)) {
   fprintf(stderr,"live=%d deferred=%d backgroundSaved=%d offSaved=%d\\n",live,deferred,saved,off);
   return 1;
 }
 return 0;
} }
'''
        with tempfile.TemporaryDirectory(prefix="kartpad-sound-") as temporary:
            directory = Path(temporary)
            (directory / "portable.txt").touch()
            file = directory / "probe.mm"
            file.write_text(program)
            executable = directory / "probe"
            build = subprocess.run(["clang++", "-std=c++20", "-fobjc-arc", "-framework", "Foundation",
                "-I", str(runtime / "include"), "-I", str(runtime / "third_party/toml11"),
                str(file), "-o", str(executable)], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(executable)], cwd=directory, capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
