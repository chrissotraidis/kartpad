"""Run the production Apple save-copy and activation code with isolated player data."""
import platform
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(platform.system() == 'Darwin', 'Requires Apple Foundation')
class RetroSaveUpgrade(unittest.TestCase):
    def test_upgrade_preserves_saves_and_rejects_failed_copy(self):
        source = (ROOT / 'apple/ios/KartPadRetroRewindInstaller.mm').read_text()
        errors = source[source.index('NSString *const kKartPadRetroRewindErrorDomain'):
                        source.index('NSString *KartPadRetroRewindSupportRoot')]
        helpers = source[source.index('BOOL KartPadCopyRetroSaveTree'):
                         source.index('BOOL KartPadFileMatches')]
        activation = source[source.index('  NSString *installedParent =', source.index('+ (BOOL)installArchiveAtURL:')):
                            source.index('  NSURL *installedURL =', source.index('+ (BOOL)installArchiveAtURL:'))]
        program = r'''#import <Foundation/Foundation.h>
''' + errors + helpers + r'''
static BOOL activate(NSString *supportRoot, NSString *stageParent, NSError **error) {
  NSFileManager *files = NSFileManager.defaultManager;
  NSError *workError = nil;
''' + activation + r'''
  return YES;
}
static void put(NSString *root, NSString *relative, NSData *bytes) {
  NSString *path = [root stringByAppendingPathComponent:relative];
  [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
      withIntermediateDirectories:YES attributes:nil error:nil];
  assert([bytes writeToFile:path atomically:YES]);
}
int main(int argc, char **argv) { @autoreleasepool {
  assert(argc == 2);
  NSString *root = @(argv[1]);
  NSData *save = [@"player rating and licenses" dataUsingEncoding:NSUTF8StringEncoding];
  NSData *ghost = [@"personal ghost bytes" dataUsingEncoding:NSUTF8StringEncoding];
  NSArray *paths = @[@"RetroRewind/riivolution/save/RetroWFC/RMCP/rksys.dat",
      @"RetroRewind/riivolution/save/RetroWFC2/RMCP/rksys.dat",
      @"SaveBackups/retained.dat", @"NAND/rksys.dat"];
  for (NSString *path in paths) put(root,path,save);
  NSString *ghostPath = @"RetroRewind/riivolution/save/RetroWFC/RMCP/ghosts/1.rkg";
  put(root,ghostPath,ghost);
  put(root,@"RetroRewind/RetroRewind6/version.txt",[@"6.12.8" dataUsingEncoding:NSUTF8StringEncoding]);
  NSString *stage = [root stringByAppendingPathComponent:@"RetroRewind.import-test"];
  NSData *version = [@"6.13.1" dataUsingEncoding:NSUTF8StringEncoding];
  put(stage,@"RetroRewind6/version.txt",version);
  NSError *error = nil;
  assert(activate(root,stage,&error)); assert(error == nil);
  for (NSString *path in paths) assert([[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:path]] isEqual:save]);
  assert([[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:ghostPath]] isEqual:ghost]);
  assert([[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"RetroRewind/RetroRewind6/version.txt"]] isEqual:version]);
  // A destination conflict must not replace the live pack or any of its saves.
  put(stage,@"RetroRewind6/version.txt",ghost);
  put(stage,@"riivolution/save",ghost);
  error = nil; assert(!activate(root,stage,&error)); assert(error != nil);
  assert([[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:ghostPath]] isEqual:ghost]);
  assert([[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:@"RetroRewind/RetroRewind6/version.txt"]] isEqual:version]);
  // Never follow a symlink from the player save tree during an upgrade.
  NSString *link = [root stringByAppendingPathComponent:@"RetroRewind/riivolution/save/unsafe"];
  assert([NSFileManager.defaultManager createSymbolicLinkAtPath:link withDestinationPath:root error:nil]);
  put(stage,@"RetroRewind6/version.txt",ghost);
  error = nil; assert(!activate(root,stage,&error)); assert(error != nil);
  assert([[NSData dataWithContentsOfFile:[root stringByAppendingPathComponent:ghostPath]] isEqual:ghost]);
  // Fresh installs have no save folder and must still activate normally.
  NSString *fresh = [root stringByAppendingPathComponent:@"fresh"];
  NSString *freshStage = [fresh stringByAppendingPathComponent:@"RetroRewind.import-test"];
  put(freshStage,@"RetroRewind6/version.txt",version);
  error = nil; assert(activate(fresh,freshStage,&error)); assert(error == nil);
  return 0;
} }
'''
        with tempfile.TemporaryDirectory(prefix='kartpad-retro-save-upgrade-') as temporary:
            directory = Path(temporary)
            probe = directory / 'probe.mm'
            probe.write_text(program)
            binary = directory / 'probe'
            build = subprocess.run(['clang++', '-std=c++20', '-fobjc-arc', '-framework', 'Foundation',
                                    str(probe), '-o', str(binary)], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(binary), str(directory / 'state')], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)
