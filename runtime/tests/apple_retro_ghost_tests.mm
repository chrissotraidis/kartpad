#import "KartPadMiiManager.h"
#include "retro_catalog_fixture.h"
#include "retro_ghost_fixture.h"
#include "kartpad/mii/player_identity.h"
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
    auto database = kartpad::mii::CreateSeedDatabase({0x02, 0x17, 0xab, 0x10, 0x20, 0x30});
    const auto identity = kartpad::mii::MiiCreateId(database, 0);
    Write([support stringByAppendingPathComponent:@"NAND/shared2/menu/FaceLib/RFL_DB.dat"], database);
    std::vector<uint8_t> save(kartpad::mii::kRksysSize, 0);
    std::copy_n("RKSD0006", 8, save.begin());
    const auto offset = kartpad::mii::kRksysLicenseOffset;
    std::copy_n("RKPD", 4, save.begin() + offset);
    std::copy(identity.begin(), identity.end(), save.begin() + offset + kartpad::mii::kRksysCreateIdOffset);
    kartpad::mii::WriteMiiName(save, offset + kartpad::mii::kRksysMiiNameOffset, "Player");
    kartpad::mii::UpdateRksysCrc(save);
    NSString *savePath = [support stringByAppendingPathComponent:@"NAND/title/00010004/524d4350/data/rksys.dat"];
    Write(savePath, save);
    NSData *saveBefore = [NSData dataWithContentsOfFile:savePath];
    NSData *createId = [NSData dataWithBytes:identity.data() length:identity.size()];
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
    Require(!KartPadStageLicenseRename(@"original", 0, createId, @"Racer", &error) && error,
        "license rename overlapped pending Retro");
    Require(![NSFileManager.defaultManager fileExistsAtPath:[support stringByAppendingPathComponent:@"PendingLicenseChange.plist"]],
        "blocked rename left a pending license change");
    error = nil;
    Require(KartPadApplyPendingRetroGhost(&error) && !KartPadHasPendingRetroGhost(), "Apple apply failed");
    Require([saveBefore isEqual:[NSData dataWithContentsOfFile:savePath]], "Retro import changed Original save");
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
    error = nil;
    Require(KartPadStageLicenseRename(@"original", 0, createId, @"Racer", &error), "license rename remained blocked");
    Require(KartPadApplyPendingMiiDatabase(&error), "license rename could not apply after Retro completion");
    std::cout << "Apple Retro catalog, stage/apply/export, pending conflicts, duplicates, cancel and stale selections passed\n";
    std::filesystem::remove_all(root);
  }
}
