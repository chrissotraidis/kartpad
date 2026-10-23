"""Execute production picker callbacks with Foundation and small UIKit stand-ins."""
from pathlib import Path
import platform
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(platform.system() == "Darwin", "Requires Apple Foundation")
class AppleGhostPickerRouting(unittest.TestCase):
    def test_import_picker_routing_and_mii_size_bounds(self):
        source = (ROOT / "apple/ios/KartPadRuntimeOverlayHost.mm").read_text()
        source = source[source.index("@implementation KartPadRuntimeOverlayHost {"):]
        methods = []
        for signature in (
            "- (void)chooseSaveRestore:",
            "- (void)presentGhostPicker:",
            "- (void)documentPickerWasCancelled:",
            "- (void)documentPicker:(UIDocumentPickerViewController *)controller\n",
        ):
            start = source.index(signature)
            methods.append(source[start:source.index("\n}", start) + 2])
        program = r'''
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <cassert>
#include <initializer_list>
@class UIDocumentPickerViewController;
@protocol PickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)picker didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls;
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)picker;
@end
@interface UIViewController : NSObject
- (void)presentViewController:(id)picker animated:(BOOL)animated completion:(id)completion;
@end
@interface UIDocumentPickerViewController : NSObject
@property(nonatomic, weak) id<PickerDelegate> delegate;
- (instancetype)initForOpeningContentTypes:(NSArray *)types asCopy:(BOOL)copy;
@end
static UIDocumentPickerViewController *activePicker;
@implementation UIViewController
- (void)presentViewController:(id)picker animated:(BOOL)animated completion:(id)completion {
  (void)animated; (void)completion; activePicker=picker;
}
@end
@implementation UIDocumentPickerViewController
- (instancetype)initForOpeningContentTypes:(NSArray *)types asCopy:(BOOL)copy {
  (void)types; (void)copy; return [super init];
}
@end
static UIViewController *presenter;
static UIViewController *KartPadVisibleViewController(id) { return presenter; }
static NSString *UTTypeData=@"data";
static unsigned saveCalls, retroCalls, originalCalls, musicCalls, gameDataCalls;
static unsigned miiCalls, documentReads;
static NSString *lastMessage;
@interface NSData (PickerReadProbe)
+ (instancetype)pickerProbeRead:(NSURL *)url options:(NSDataReadingOptions)options error:(NSError **)error;
@end
@implementation NSData (PickerReadProbe)
+ (instancetype)pickerProbeRead:(NSURL *)url options:(NSDataReadingOptions)options error:(NSError **)error {
  ++documentReads;
  return [self pickerProbeRead:url options:options error:error];
}
@end
static BOOL KartPadStageSaveRestore(NSString *, NSData *, NSError **) { ++saveCalls; return YES; }
[[maybe_unused]] static BOOL KartPadStageRetroGhost(NSData *, NSDictionary *, NSError **) { ++retroCalls; return YES; }
static BOOL KartPadStageOriginalGhost(NSData *, NSUInteger, NSError **) { ++originalCalls; return YES; }
static BOOL KartPadStageMiiImport(NSData *, NSString **, NSError **) { ++miiCalls; return YES; }
@interface KartPadRuntimeOverlayHost : NSObject <PickerDelegate> {
@public
  id _window;
  BOOL _choosingMusicImport, _choosingGhostImport, _choosingMiiImport;
  NSString *_saveImportProfile;
  NSDictionary *_retroGhostSelection;
  NSUInteger _ghostLicense;
}
- (void)chooseSaveRestore:(NSString *)profile;
- (void)presentGhostPicker:(UIDocumentPickerViewController *)picker importing:(BOOL)importing;
- (void)showIntegrationAlert:(NSString *)title message:(NSString *)message;
- (void)importRetroMusicFromURLs:(NSArray<NSURL *> *)urls;
- (void)importExtractedGameDataFromURL:(NSURL *)url deleteAfterwards:(BOOL)remove;
@end
@implementation KartPadRuntimeOverlayHost
- (void)showIntegrationAlert:(NSString *)title message:(NSString *)message { (void)title; lastMessage=message; }
- (void)importRetroMusicFromURLs:(NSArray<NSURL *> *)urls { (void)urls; ++musicCalls; }
- (void)importExtractedGameDataFromURL:(NSURL *)url deleteAfterwards:(BOOL)remove {
  (void)url; (void)remove; ++gameDataCalls;
}
''' + "\n".join(methods) + "\n@end\nstatic constexpr bool HasRetroGhosts = " + str("KartPadStageRetroGhost" in source).lower() + r''';
static void ImportGhost(KartPadRuntimeOverlayHost *host, NSURL *url, BOOL retro) {
  assert([[NSMutableData dataWithLength:32] writeToURL:url atomically:YES]);
  host->_retroGhostSelection=retro ? @{@"track":@256} : nil;
  [host presentGhostPicker:[UIDocumentPickerViewController new] importing:YES];
  assert(activePicker.delegate==host);
  [activePicker.delegate documentPicker:activePicker didPickDocumentsAtURLs:@[url]];
  assert(retroCalls==unsigned(retro) && originalCalls==unsigned(!retro) && musicCalls==0 && gameDataCalls==0);
  assert(!host->_choosingGhostImport && host->_retroGhostSelection==nil);
}
int main(int argc, char **argv) { @autoreleasepool {
  assert(argc==2);
  method_exchangeImplementations(
      class_getClassMethod(NSData.class,@selector(dataWithContentsOfURL:options:error:)),
      class_getClassMethod(NSData.class,@selector(pickerProbeRead:options:error:)));
  presenter=[UIViewController new];
  NSURL *directory=[NSURL fileURLWithPath:@(argv[1])];
  NSURL *save=[directory URLByAppendingPathComponent:@"rksys.dat"];
  NSURL *ghost=[directory URLByAppendingPathComponent:@"ghost.rkg"];
  assert([[NSMutableData dataWithLength:0x2bc000] writeToURL:save atomically:YES]);
  for (BOOL retro : {NO, YES}) {
   if (retro && !HasRetroGhosts) continue;
   for (BOOL complete : {NO, YES}) {
    saveCalls=retroCalls=originalCalls=0;
    KartPadRuntimeOverlayHost *host=[KartPadRuntimeOverlayHost new];
    [host chooseSaveRestore:@"original"];
    assert(activePicker.delegate==host);
    if (complete) [activePicker.delegate documentPicker:activePicker didPickDocumentsAtURLs:@[save]];
    else [activePicker.delegate documentPickerWasCancelled:activePicker];
    assert(saveCalls==unsigned(complete) && host->_saveImportProfile==nil);
    ImportGhost(host,ghost,retro);
    assert(saveCalls==unsigned(complete));
  }
  saveCalls=retroCalls=originalCalls=0;
  KartPadRuntimeOverlayHost *host=[KartPadRuntimeOverlayHost new];
  host->_choosingMusicImport=YES;
  if (HasRetroGhosts) host->_retroGhostSelection=@{@"track":@256};
  UIDocumentPickerViewController *music=[UIDocumentPickerViewController new];
  music.delegate=host;
  [music.delegate documentPickerWasCancelled:music];
  assert(!host->_choosingMusicImport && host->_retroGhostSelection==nil);
  ImportGhost(host,ghost,retro);
  [host presentGhostPicker:[UIDocumentPickerViewController new] importing:NO];
  assert(activePicker.delegate==nil); // Export completion must not enter an import callback.
  }
  // Manager format validation is separate; the picker must not read wrong-sized files.
  for (NSUInteger length : {1024u*1024u,0u,73u,74u,75u}) {
    NSURL *mii=[directory URLByAppendingPathComponent:[NSString stringWithFormat:@"selected-%lu.mii",(unsigned long)length]];
    assert([[NSMutableData dataWithLength:length] writeToURL:mii atomically:YES]);
    KartPadRuntimeOverlayHost *host=[KartPadRuntimeOverlayHost new];
    host->_choosingMiiImport=YES;
    documentReads=miiCalls=0;
    [host documentPicker:[UIDocumentPickerViewController new] didPickDocumentsAtURLs:@[mii]];
    assert(!host->_choosingMiiImport);
    assert(documentReads==unsigned(length==74) && miiCalls==unsigned(length==74));
    if (length!=74) assert([lastMessage containsString:@"74"]);
    assert(![NSFileManager.defaultManager fileExistsAtPath:mii.path]);
  }
} }
'''
        with tempfile.TemporaryDirectory(prefix="kartpad-apple-picker-") as temporary:
            probe = Path(temporary) / "picker.mm"
            executable = Path(temporary) / "picker"
            probe.write_text(program)
            build = subprocess.run([
                "clang++", "-std=c++20", "-fobjc-arc", "-Wall", "-Wextra", "-Werror",
                "-framework", "Foundation", str(probe), "-o", str(executable),
            ], capture_output=True, text=True)
            self.assertEqual(build.returncode, 0, build.stderr)
            run = subprocess.run([str(executable), temporary], capture_output=True, text=True)
            self.assertEqual(run.returncode, 0, run.stderr)


if __name__ == "__main__":
    unittest.main()
