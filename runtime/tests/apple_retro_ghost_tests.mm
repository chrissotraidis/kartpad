#import "KartPadMiiManager.h"
#include "retro_catalog_fixture.h"
#include "retro_ghost_fixture.h"
#include <filesystem>
#include <iostream>

using namespace kartpad::ghost;
static void Write(NSString *path, const std::vector<uint8_t>& bytes) {
  Require([NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
      withIntermediateDirectories:YES attributes:nil error:nil], "fixture directory failed");
  Require([[NSData dataWithBytes:bytes.data() length:bytes.size()] writeToFile:path options:NSDataWritingAtomic error:nil], "fixture write failed");
}
int main() {
  @autoreleasepool {
    char temporary[] = "/tmp/kartpad-apple-retro-ghost.XXXXXX";
    const char* root = ::mkdtemp(temporary); Require(root, "test root unavailable");
    ::setenv("KARTPAD_MII_TEST_SUPPORT_ROOT", root, 1);
    NSString *support = [NSString stringWithUTF8String:root];
    auto [rt, ct] = retro_fixture::Fixtures();
    Write([support stringByAppendingPathComponent:@"RetroRewind/RetroRewind6/Binaries/ConfigRT.pul"], rt);
    Write([support stringByAppendingPathComponent:@"RetroRewind/RetroRewind6/Binaries/ConfigCT.pul"], ct);
    auto bytes = retro_fixture::Ghost(true);
    NSData *ghost = [NSData dataWithBytes:bytes.data() length:bytes.size()];
    NSError *error = nil;
    NSDictionary *catalog = KartPadRetroGhostCatalog(&error);
    Require(catalog && [catalog[@"tracks"] count] == 8 && !error, "Apple catalog conversion failed");
    NSDictionary *selection = @{@"identity": catalog[@"identity"], @"track": @0x100, @"variant": @1, @"mode": @3};
    Require(KartPadStageRetroGhost(ghost, selection, &error), "Apple staging failed");
    Require(KartPadHasPendingRetroGhost() && KartPadHasPendingMiiChanges(), "pending state omitted");
    Require([KartPadRetroGhostFiles(selection, &error) count] == 0, "staging changed live files");
    error = nil;
    Require(!KartPadStageOriginalGhost(ghost, 0, &error) && error, "Original import overlapped pending Retro");
    error = nil;
    Require(KartPadApplyPendingRetroGhost(&error) && !KartPadHasPendingRetroGhost(), "Apple apply failed");
    NSArray *records = KartPadRetroGhostFiles(selection, &error);
    Require(records.count == 1 && [records[0][@"data"] isEqual:ghost] && [records[0][@"filename"] length] == 10, "Apple export changed bytes");
    error = nil;
    Require(!KartPadStageRetroGhost(ghost, selection, &error) && error, "duplicate accepted");
    NSMutableDictionary *other = [selection mutableCopy]; other[@"mode"] = @2;
    error = nil;
    Require(KartPadStageRetroGhost(ghost, other, &error), "second mode staging failed");
    Require(KartPadCancelPendingRetroGhost(&error) && !KartPadHasPendingRetroGhost(), "cancel failed");
    Require([KartPadRetroGhostFiles(other, &error) count] == 0, "cancel applied a ghost");
    other[@"identity"] = @"stale"; error = nil;
    Require(!KartPadStageRetroGhost(ghost, other, &error) && error, "stale selection accepted");
    error = nil;
    Require(!KartPadStageRetroGhost(ghost, @{}, &error) && error, "missing selection accepted");
    std::cout << "Apple Retro catalog, stage/apply/export, pending conflicts, duplicates, cancel and stale selections passed\n";
    std::filesystem::remove_all(root);
  }
}
