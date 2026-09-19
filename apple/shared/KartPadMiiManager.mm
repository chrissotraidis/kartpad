#import "KartPadMiiManager.h"
#import <TargetConditionals.h>

#if TARGET_OS_OSX && !defined(KARTPAD_MII_MANAGER_TESTING)
#include "runtime_config.h"
#endif

#include "kartpad/mii/mii_database.h"
#include "kartpad/mii/player_identity.h"

#include <span>
#include <cstdlib>
#include <vector>

NSString *const KartPadMiiManagerErrorDomain = @"dev.kartpad.mii-manager";

namespace {

NSString *SupportRoot() {
#if defined(KARTPAD_MII_MANAGER_TESTING)
  const char *root = std::getenv("KARTPAD_MII_TEST_SUPPORT_ROOT");
  if (root == nullptr || root[0] != '/') std::abort();
  return [NSString stringWithUTF8String:root];
#elif TARGET_OS_OSX
  // Match the shell and runtime, including portable.txt/UserData. Never apply
  // another installation's pending identity changes during portable startup.
  const auto root = RuntimeConfigFile::ApplicationDataDirectory().string();
  return [NSString stringWithUTF8String:root.c_str()];
#else
  return [[NSHomeDirectory() stringByAppendingPathComponent:
      @"Library/Application Support"] stringByAppendingPathComponent:@"KartPad"];
#endif
}

NSString *DatabasePath() {
  return [SupportRoot() stringByAppendingPathComponent:
      @"NAND/shared2/menu/FaceLib/RFL_DB.dat"];
}

NSString *PendingGhostPath() { return [SupportRoot() stringByAppendingPathComponent:@"PendingGhost.plist"]; }

NSString *PendingPath() {
  return [SupportRoot() stringByAppendingPathComponent:@"PendingRFL_DB.dat"];
}

NSArray<NSDictionary<NSString *, NSString *> *> *SaveLocations() {
  NSString *support = SupportRoot();
  return @[
    @{
      @"identifier": @"original",
      @"title": @"Original Mario Kart Wii",
      @"path": [support stringByAppendingPathComponent:
          @"NAND/title/00010004/524d4350/data/rksys.dat"],
      @"backup": @"rksys-nand",
    },
    @{
      @"identifier": @"retro_rewind",
      @"title": @"Retro Rewind",
      @"path": [support stringByAppendingPathComponent:
          @"RetroRewind/riivolution/save/RetroWFC/RMCP/rksys.dat"],
      @"backup": @"rksys-retro-rewind",
    },
    @{
      @"identifier": @"retro_rewind_separate",
      @"title": @"Retro Rewind (Separate Save)",
      @"path": [support stringByAppendingPathComponent:
          @"RetroRewind/riivolution/save/RetroWFC2/RMCP/rksys.dat"],
      @"backup": @"rksys-retro-rewind-separate",
    },
  ];
}

NSString *PendingIdentityPath() {
  return [SupportRoot() stringByAppendingPathComponent:
      @"PendingPlayerIdentity.plist"];
}

NSString *PendingLicensePath() {
  return [SupportRoot() stringByAppendingPathComponent:
      @"PendingLicenseChange.plist"];
}

NSDictionary<NSString *, NSString *> *SaveLocation(NSString *identifier) {
  for (NSDictionary<NSString *, NSString *> *location in SaveLocations()) {
    if ([location[@"identifier"] isEqualToString:identifier]) return location;
  }
  return nil;
}

NSError *ManagerError(NSInteger code, const std::string& message) {
  NSString *description = [NSString stringWithUTF8String:message.c_str()];
  if (description.length == 0) description = @"Unknown Mii database error.";
  return [NSError errorWithDomain:KartPadMiiManagerErrorDomain code:code
                         userInfo:@{NSLocalizedDescriptionKey: description}];
}

NSData *ReadWorkingDatabase(NSError **error) {
  NSString *path = [NSFileManager.defaultManager fileExistsAtPath:PendingPath()]
      ? PendingPath() : DatabasePath();
  NSData *data = [NSData dataWithContentsOfFile:path
                                       options:NSDataReadingMappedIfSafe
                                         error:error];
  if (data == nil && error != nullptr && *error == nil) {
    *error = ManagerError(1,
        "No Mii database exists yet. Start Mario Kart Wii once, then try again.");
  }
  return data;
}

std::span<const uint8_t> Bytes(NSData *data) {
  return {static_cast<const uint8_t *>(data.bytes), data.length};
}

BOOL WritePending(std::vector<uint8_t>& database, NSError **error) {
  NSData *data = [NSData dataWithBytes:database.data() length:database.size()];
  if (![NSFileManager.defaultManager createDirectoryAtPath:SupportRoot()
                                withIntermediateDirectories:YES
                                                 attributes:nil error:error]) {
    return NO;
  }
  return [data writeToFile:PendingPath() options:NSDataWritingAtomic error:error];
}

BOOL ValidateData(NSData *data, NSError **error) {
  const auto validation = kartpad::mii::ValidateDatabase(Bytes(data));
  if (!validation) {
    if (error != nullptr) *error = ManagerError(2, validation.message);
    return NO;
  }
  return YES;
}

BOOL ValidateSaveData(NSData *data, NSError **error) {
  const auto validation = kartpad::mii::ValidateRksys(Bytes(data));
  if (!validation) {
    if (error != nullptr) *error = ManagerError(5, validation.message);
    return NO;
  }
  return YES;
}

NSData *PlayerNameData(NSString *name, NSError **error) {
  NSString *trimmed = [name stringByTrimmingCharactersInSet:
      NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmed.length == 0 || trimmed.length > 10) {
    if (error != nullptr) {
      *error = ManagerError(6,
          "A player name must contain 1 to 10 characters.");
    }
    return nil;
  }
  NSData *encoded = [trimmed dataUsingEncoding:NSUTF16BigEndianStringEncoding
                           allowLossyConversion:NO];
  if (encoded == nil || encoded.length == 0 || encoded.length > 20) {
    if (error != nullptr) {
      *error = ManagerError(7,
          "The player name contains an unsupported character.");
    }
    return nil;
  }
  return encoded;
}

BOOL ReadCreateId(NSData *data,
                  std::array<uint8_t, kartpad::mii::kCreateIdByteSize>& result,
                  NSError **error) {
  if (data.length != result.size()) {
    if (error != nullptr) {
      *error = ManagerError(12, "The selected license identity is invalid.");
    }
    return NO;
  }
  std::copy_n(static_cast<const uint8_t *>(data.bytes), result.size(),
              result.begin());
  return YES;
}

BOOL BackupFile(NSString *source, NSString *folder, NSString *name,
                NSString *stamp, NSError **error) {
  NSFileManager *files = NSFileManager.defaultManager;
  if (![files fileExistsAtPath:source]) return YES;
  NSString *backups = [SupportRoot() stringByAppendingPathComponent:folder];
  if (![files createDirectoryAtPath:backups withIntermediateDirectories:YES
                         attributes:nil error:error]) {
    return NO;
  }
  NSString *backup = [backups stringByAppendingPathComponent:
      [NSString stringWithFormat:@"%@-%@.dat", name, stamp]];
  return [files copyItemAtPath:source toPath:backup error:error];
}

} // namespace

NSArray<NSDictionary<NSString *, id> *> *KartPadMiiRecords(NSError **error) {
  NSData *data = ReadWorkingDatabase(error);
  if (data == nil || !ValidateData(data, error)) return @[];

  NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
  for (const auto& record : kartpad::mii::ListMiis(Bytes(data))) {
    NSString *name = [NSString stringWithUTF8String:record.name.c_str()];
    NSString *creator = [NSString stringWithUTF8String:record.creatorName.c_str()];
    const auto createIdBytes = kartpad::mii::MiiCreateId(Bytes(data), record.slot);
    NSData *createIdData = [NSData dataWithBytes:createIdBytes.data()
                                          length:createIdBytes.size()];
    [result addObject:@{
      @"slot": @(record.slot),
      @"name": name.length > 0 ? name : @"Unnamed Mii",
      @"creator": creator.length > 0 ? creator : @"Unknown",
      @"favoriteColor": @(record.favoriteColor),
      @"createId": @(record.createId),
      @"createIdBytes": createIdData,
    }];
  }
  return result;
}

NSArray<NSDictionary<NSString *, id> *> *KartPadLicenseRecords(NSError **error) {
  NSMutableArray<NSDictionary<NSString *, id> *> *result = [NSMutableArray array];
  NSFileManager *files = NSFileManager.defaultManager;
  NSDictionary *identity = [NSDictionary dictionaryWithContentsOfFile:PendingIdentityPath()];
  NSDictionary *license = [NSDictionary dictionaryWithContentsOfFile:PendingLicensePath()];
  NSData *databaseData = [NSData dataWithContentsOfFile:DatabasePath()];
  const auto databaseBytes = Bytes(databaseData);
  const auto miis = kartpad::mii::ListMiis(databaseBytes);
  for (NSDictionary<NSString *, NSString *> *location in SaveLocations()) {
    NSString *path = location[@"path"];
    if (![files fileExistsAtPath:path]) continue;
    NSData *saveData = [NSData dataWithContentsOfFile:path
                                              options:NSDataReadingMappedIfSafe
                                                error:error];
    if (saveData == nil || !ValidateSaveData(saveData, error)) return @[];
    for (const auto& record : kartpad::mii::ListLicenses(Bytes(saveData))) {
      NSString *name = [NSString stringWithUTF8String:record.name.c_str()];
      NSData *createId = [NSData dataWithBytes:record.createId.data()
                                        length:record.createId.size()];
      NSString *pendingOperation = @"";
      NSData *pendingName = nil;
      if ([identity[@"createId"] isEqual:createId]) {
        pendingOperation = @"rename";
        pendingName = identity[@"name"];
      }
      if ([license[@"profileIdentifier"] isEqual:location[@"identifier"]] &&
          [license[@"slot"] isEqual:@(record.slot)] &&
          [license[@"createId"] isEqual:createId]) {
        pendingOperation = license[@"operation"] ?: @"";
        pendingName = license[@"name"];
      }
      if (![pendingOperation isKindOfClass:NSString.class]) pendingOperation = @"";
      if ([pendingName isKindOfClass:NSData.class] &&
          kartpad::mii::ValidateUtf16BigEndianName(Bytes(pendingName))) {
        name = [[NSString alloc] initWithData:pendingName
                                    encoding:NSUTF16BigEndianStringEncoding];
      }
      [result addObject:@{
        @"profileIdentifier": location[@"identifier"],
        @"profileTitle": location[@"title"],
        @"slot": @(record.slot),
        @"name": name.length > 0 ? name : @"Unnamed",
        @"createId": createId,
        @"pendingOperation": pendingOperation,
        @"missingLinkedMii": @(!std::any_of(miis.begin(), miis.end(), [&](const auto& mii) {
          return kartpad::mii::MiiCreateId(databaseBytes, mii.slot) == record.createId;
        })),
      }];
    }
  }
  return result;
}

BOOL KartPadStageMiiImport(NSData *miiData, NSString **name, NSError **error) {
  NSData *databaseData = ReadWorkingDatabase(error);
  if (databaseData == nil || !ValidateData(databaseData, error)) return NO;

  std::vector<uint8_t> database(
      static_cast<const uint8_t *>(databaseData.bytes),
      static_cast<const uint8_t *>(databaseData.bytes) + databaseData.length);
  const auto mii = Bytes(miiData);
  const auto result = kartpad::mii::ImportMii(database, mii);
  if (!result) {
    if (error != nullptr) *error = ManagerError(3, result.message);
    return NO;
  }
  if (name != nullptr) {
    const std::string decoded = kartpad::mii::ReadMiiName(mii, 0x02);
    *name = [NSString stringWithUTF8String:decoded.c_str()];
  }
  return WritePending(database, error);
}

BOOL KartPadStageMiiRemoval(NSUInteger slot, NSError **error) {
  NSData *databaseData = ReadWorkingDatabase(error);
  if (databaseData == nil || !ValidateData(databaseData, error)) return NO;
  const auto createId = kartpad::mii::MiiCreateId(Bytes(databaseData), slot);
  NSData *identity = [NSData dataWithBytes:createId.data() length:createId.size()];
  NSError *licenseError = nil;
  for (NSDictionary *license in KartPadLicenseRecords(&licenseError)) {
    if ([license[@"createId"] isEqual:identity]) {
      if (error != nullptr) *error = ManagerError(20,
          "This Mii is linked to an existing license. Change the license first.");
      return NO;
    }
  }
  if (licenseError != nil) {
    if (error != nullptr) *error = licenseError;
    return NO;
  }

  std::vector<uint8_t> database(
      static_cast<const uint8_t *>(databaseData.bytes),
      static_cast<const uint8_t *>(databaseData.bytes) + databaseData.length);
  const auto result = kartpad::mii::RemoveMii(database, slot);
  if (!result) {
    if (error != nullptr) *error = ManagerError(4, result.message);
    return NO;
  }
  return WritePending(database, error);
}

BOOL KartPadStagePlayerName(NSUInteger slot, NSString *name,
                           NSUInteger *updatedLicenses, NSError **error) {
  if (updatedLicenses != nullptr) *updatedLicenses = 0;
  if (KartPadHasPendingMiiChanges()) {
    if (error != nullptr) *error = ManagerError(13,
        "Fully close and reopen KartPad to apply the pending identity change first.");
    return NO;
  }
  NSData *nameData = PlayerNameData(name, error);
  if (nameData == nil) return NO;

  NSData *databaseData = ReadWorkingDatabase(error);
  if (databaseData == nil || !ValidateData(databaseData, error)) return NO;
  std::vector<uint8_t> database(
      static_cast<const uint8_t *>(databaseData.bytes),
      static_cast<const uint8_t *>(databaseData.bytes) + databaseData.length);
  if (slot >= kartpad::mii::kMaximumMiiSlots) {
    if (error != nullptr) {
      *error = ManagerError(8, "The selected Mii slot is invalid.");
    }
    return NO;
  }
  const auto createId = kartpad::mii::MiiCreateId(database, slot);
  const auto renamed = kartpad::mii::RenameMii(
      database, slot, Bytes(nameData));
  if (!renamed) {
    if (error != nullptr) *error = ManagerError(8, renamed.message);
    return NO;
  }

  std::size_t changed = 0;
  for (NSDictionary<NSString *, NSString *> *location in SaveLocations()) {
    NSString *path = location[@"path"];
    if (![NSFileManager.defaultManager fileExistsAtPath:path]) continue;
    NSData *saveData = [NSData dataWithContentsOfFile:path
                                             options:NSDataReadingMappedIfSafe
                                               error:error];
    if (saveData == nil || !ValidateSaveData(saveData, error)) return NO;
    std::vector<uint8_t> save(
        static_cast<const uint8_t *>(saveData.bytes),
        static_cast<const uint8_t *>(saveData.bytes) + saveData.length);
    std::size_t saveChanged = 0;
    const auto saveResult = kartpad::mii::RenameMatchingLicenses(
        save, createId, Bytes(nameData), saveChanged);
    if (!saveResult) {
      if (error != nullptr) *error = ManagerError(9, saveResult.message);
      return NO;
    }
    changed += saveChanged;
  }

  NSData *createIdData = [NSData dataWithBytes:createId.data()
                                         length:createId.size()];
  NSDictionary *identity = @{
    @"createId": createIdData,
    @"name": nameData,
  };
  NSData *identityData = [NSPropertyListSerialization
      dataWithPropertyList:identity format:NSPropertyListBinaryFormat_v1_0
                   options:0 error:error];
  if (identityData == nil ||
      ![identityData writeToFile:PendingIdentityPath()
                         options:NSDataWritingAtomic error:error]) return NO;
  if (!WritePending(database, error)) {
    [NSFileManager.defaultManager removeItemAtPath:PendingIdentityPath()
                                             error:nil];
    return NO;
  }
  if (updatedLicenses != nullptr) *updatedLicenses = changed;
  return YES;
}

static NSData *SelectedMiiName(NSUInteger slot, NSData *expectedId, NSError **error) {
  std::array<uint8_t, kartpad::mii::kCreateIdByteSize> identity{};
  if (!ReadCreateId(expectedId, identity, error)) return nil;
  NSData *data = [NSData dataWithContentsOfFile:DatabasePath() options:0 error:error];
  if (data == nil || !ValidateData(data, error)) return nil;
  for (const auto& record : kartpad::mii::ListMiis(Bytes(data))) {
    if (record.slot == slot && kartpad::mii::MiiCreateId(Bytes(data), slot) == identity) {
      NSData *name = [[NSString stringWithUTF8String:record.name.c_str()]
          dataUsingEncoding:NSUTF16BigEndianStringEncoding];
      const auto validation = kartpad::mii::ValidateUtf16BigEndianName(Bytes(name));
      if (!validation) {
        if (error != nullptr) *error = ManagerError(21, validation.message);
        return nil;
      }
      return name;
    }
  }
  if (error != nullptr) *error = ManagerError(20,
      "The selected Mii changed. Reopen Player Identity and choose it again.");
  return nil;
}

static BOOL KartPadStageLicenseChange(NSString *profileIdentifier,
                                     NSUInteger slot, NSData *createIdData,
                                     NSString *operation, NSString *name,
                                     NSError **error,
                                     NSUInteger selectedSlot = NSNotFound,
                                     NSData *selectedId = nil) {
  NSFileManager *files = NSFileManager.defaultManager;
  if (KartPadHasPendingSaveRestore() || [files fileExistsAtPath:PendingGhostPath()] || [files fileExistsAtPath:PendingPath()] ||
      [files fileExistsAtPath:PendingIdentityPath()] ||
      [files fileExistsAtPath:PendingLicensePath()]) {
    if (error != nullptr) {
      *error = ManagerError(13,
          "Restart KartPad to apply the pending identity change first.");
    }
    return NO;
  }
  NSDictionary<NSString *, NSString *> *location =
      SaveLocation(profileIdentifier);
  if (location == nil || slot >= kartpad::mii::kRksysLicenseCount) {
    if (error != nullptr) {
      *error = ManagerError(14, "The selected license location is invalid.");
    }
    return NO;
  }
  std::array<uint8_t, kartpad::mii::kCreateIdByteSize> createId{};
  if (!ReadCreateId(createIdData, createId, error)) return NO;

  NSData *nameData = nil;
  if ([operation isEqualToString:@"rename"]) {
    nameData = PlayerNameData(name, error);
    if (nameData == nil) return NO;
  } else if ([operation isEqualToString:@"mii"]) {
    nameData = SelectedMiiName(selectedSlot, selectedId, error);
    if (nameData == nil) return NO;
  } else if (![operation isEqualToString:@"delete"]) {
    if (error != nullptr) {
      *error = ManagerError(15, "The requested license change is invalid.");
    }
    return NO;
  }

  NSData *saveData = [NSData dataWithContentsOfFile:location[@"path"]
                                            options:NSDataReadingMappedIfSafe
                                              error:error];
  if (saveData == nil || !ValidateSaveData(saveData, error)) return NO;
  BOOL found = NO;
  for (const auto& record : kartpad::mii::ListLicenses(Bytes(saveData))) {
    if (record.slot == slot && record.createId == createId) {
      found = YES;
      break;
    }
  }
  if (!found) {
    if (error != nullptr) {
      *error = ManagerError(16,
          "The selected license changed. Reopen Player Identity and try again.");
    }
    return NO;
  }

  NSMutableDictionary *intent = [@{
    @"operation": operation,
    @"profileIdentifier": profileIdentifier,
    @"slot": @(slot),
    @"createId": createIdData,
  } mutableCopy];
  if (nameData != nil) intent[@"name"] = nameData;
  if ([operation isEqualToString:@"mii"]) {
    intent[@"miiSlot"] = @(selectedSlot);
    intent[@"miiCreateId"] = selectedId;
  }
  NSData *intentData = [NSPropertyListSerialization
      dataWithPropertyList:intent format:NSPropertyListBinaryFormat_v1_0
                   options:0 error:error];
  if (intentData == nil ||
      ![files createDirectoryAtPath:SupportRoot()
         withIntermediateDirectories:YES attributes:nil error:error] ||
      ![intentData writeToFile:PendingLicensePath()
                        options:NSDataWritingAtomic error:error]) return NO;

  if ([operation isEqualToString:@"rename"] && [files fileExistsAtPath:DatabasePath()]) {
    NSData *databaseData = [NSData dataWithContentsOfFile:DatabasePath()
                                                   options:NSDataReadingMappedIfSafe
                                                     error:error];
    if (databaseData == nil || !ValidateData(databaseData, error)) {
      [files removeItemAtPath:PendingLicensePath() error:nil];
      return NO;
    }
    std::vector<uint8_t> database(
        static_cast<const uint8_t *>(databaseData.bytes),
        static_cast<const uint8_t *>(databaseData.bytes) + databaseData.length);
    BOOL renamedMii = NO;
    for (const auto& record : kartpad::mii::ListMiis(database)) {
      if (kartpad::mii::MiiCreateId(database, record.slot) != createId) continue;
      const auto renamed = kartpad::mii::RenameMii(
          database, record.slot, Bytes(nameData));
      if (!renamed) {
        [files removeItemAtPath:PendingLicensePath() error:nil];
        if (error != nullptr) *error = ManagerError(17, renamed.message);
        return NO;
      }
      renamedMii = YES;
      break;
    }
    if (renamedMii && !WritePending(database, error)) {
      [files removeItemAtPath:PendingLicensePath() error:nil];
      return NO;
    }
  }
  return YES;
}

BOOL KartPadStageLicenseRename(NSString *profileIdentifier, NSUInteger slot,
                              NSData *createId, NSString *name,
                              NSError **error) {
  return KartPadStageLicenseChange(profileIdentifier, slot, createId,
                                   @"rename", name, error);
}

BOOL KartPadStageLicenseMii(NSString *profileIdentifier, NSUInteger slot,
                           NSData *createId, NSUInteger miiSlot, NSData *miiCreateId,
                           NSError **error) {
  return KartPadStageLicenseChange(profileIdentifier, slot, createId,
                                   @"mii", nil, error, miiSlot, miiCreateId);
}

BOOL KartPadStageLicenseDeletion(NSString *profileIdentifier, NSUInteger slot,
                                NSData *createId, NSError **error) {
  return KartPadStageLicenseChange(profileIdentifier, slot, createId,
                                   @"delete", nil, error);
}

static BOOL KartPadApplyPendingGhost(NSError **error);
static BOOL KartPadApplyPendingSaveRestore(NSError **error);

BOOL KartPadApplyPendingMiiDatabase(NSError **error) {
  if (!KartPadApplyPendingSaveRestore(error)) return NO;
  if (!KartPadApplyPendingGhost(error)) return NO;
  NSString *pending = PendingPath();
  NSString *pendingIdentity = PendingIdentityPath();
  NSString *pendingLicense = PendingLicensePath();
  NSFileManager *files = NSFileManager.defaultManager;
  const BOOL hasDatabase = [files fileExistsAtPath:pending];
  const BOOL hasIdentity = [files fileExistsAtPath:pendingIdentity];
  const BOOL hasLicense = [files fileExistsAtPath:pendingLicense];
  if (!hasDatabase && !hasIdentity && !hasLicense) return YES;

  NSData *pendingData = nil;
  if (hasDatabase) {
    pendingData = [NSData dataWithContentsOfFile:pending
                                         options:NSDataReadingMappedIfSafe
                                           error:error];
    if (pendingData == nil || !ValidateData(pendingData, error)) return NO;
  }
  NSMutableArray<NSDictionary<NSString *, id> *> *saveChanges =
      [NSMutableArray array];
  if (hasIdentity) {
    NSData *identityData = [NSData dataWithContentsOfFile:pendingIdentity
                                                  options:0 error:error];
    id propertyList = identityData == nil ? nil :
        [NSPropertyListSerialization propertyListWithData:identityData
                                                  options:0 format:nil
                                                    error:error];
    NSDictionary *identity = [propertyList isKindOfClass:NSDictionary.class]
        ? propertyList : nil;
    NSData *createId = [identity[@"createId"] isKindOfClass:NSData.class]
        ? identity[@"createId"] : nil;
    NSData *name = [identity[@"name"] isKindOfClass:NSData.class]
        ? identity[@"name"] : nil;
    if (createId.length != kartpad::mii::kCreateIdByteSize ||
        name.length == 0 || name.length > kartpad::mii::kMiiNameByteSize ||
        (name.length % 2) != 0) {
      if (error != nullptr) {
        *error = ManagerError(10, "The pending player identity is invalid.");
      }
      return NO;
    }
    std::array<uint8_t, kartpad::mii::kCreateIdByteSize> createIdBytes{};
    std::copy_n(static_cast<const uint8_t *>(createId.bytes),
                createIdBytes.size(), createIdBytes.begin());
    for (NSDictionary<NSString *, NSString *> *location in SaveLocations()) {
      NSString *path = location[@"path"];
      if (![files fileExistsAtPath:path]) continue;
      NSData *saveData = [NSData dataWithContentsOfFile:path
                                                options:NSDataReadingMappedIfSafe
                                                  error:error];
      if (saveData == nil || !ValidateSaveData(saveData, error)) return NO;
      std::vector<uint8_t> updatedSave(
          static_cast<const uint8_t *>(saveData.bytes),
          static_cast<const uint8_t *>(saveData.bytes) + saveData.length);
      std::size_t changedLicenses = 0;
      const auto renameResult = kartpad::mii::RenameMatchingLicenses(
          updatedSave, createIdBytes, Bytes(name), changedLicenses);
      if (!renameResult) {
        if (error != nullptr) *error = ManagerError(11, renameResult.message);
        return NO;
      }
      if (changedLicenses > 0) {
        [saveChanges addObject:@{
          @"path": path,
          @"backup": location[@"backup"],
          @"data": [NSData dataWithBytes:updatedSave.data()
                                    length:updatedSave.size()],
        }];
      }
    }
  }
  if (hasLicense) {
    NSData *intentData = [NSData dataWithContentsOfFile:pendingLicense
                                                options:0 error:error];
    id propertyList = intentData == nil ? nil :
        [NSPropertyListSerialization propertyListWithData:intentData
                                                  options:0 format:nil
                                                    error:error];
    NSDictionary *intent = [propertyList isKindOfClass:NSDictionary.class]
        ? propertyList : nil;
    NSString *operation = [intent[@"operation"] isKindOfClass:NSString.class]
        ? intent[@"operation"] : nil;
    NSString *profileIdentifier =
        [intent[@"profileIdentifier"] isKindOfClass:NSString.class]
            ? intent[@"profileIdentifier"] : nil;
    NSNumber *slotNumber = [intent[@"slot"] isKindOfClass:NSNumber.class]
        ? intent[@"slot"] : nil;
    NSData *createIdData = [intent[@"createId"] isKindOfClass:NSData.class]
        ? intent[@"createId"] : nil;
    NSData *nameData = [intent[@"name"] isKindOfClass:NSData.class]
        ? intent[@"name"] : nil;
    NSDictionary<NSString *, NSString *> *location =
        SaveLocation(profileIdentifier);
    std::array<uint8_t, kartpad::mii::kCreateIdByteSize> createId{};
    if (operation == nil || location == nil || slotNumber == nil ||
        slotNumber.unsignedIntegerValue >= kartpad::mii::kRksysLicenseCount ||
        !ReadCreateId(createIdData, createId, error) ||
        ([operation isEqualToString:@"rename"] &&
         (nameData.length == 0 || nameData.length > kartpad::mii::kMiiNameByteSize ||
          (nameData.length % 2) != 0)) ||
        (![operation isEqualToString:@"rename"] &&
         ![operation isEqualToString:@"mii"] &&
         ![operation isEqualToString:@"delete"])) {
      if (error != nullptr && *error == nil) {
        *error = ManagerError(18, "The pending license change is invalid.");
      }
      return NO;
    }
    NSString *path = location[@"path"];
    NSData *saveData = [NSData dataWithContentsOfFile:path
                                              options:NSDataReadingMappedIfSafe
                                                error:error];
    if (saveData == nil || !ValidateSaveData(saveData, error)) return NO;
    std::vector<uint8_t> updatedSave(
        static_cast<const uint8_t *>(saveData.bytes),
        static_cast<const uint8_t *>(saveData.bytes) + saveData.length);
    std::array<uint8_t, kartpad::mii::kCreateIdByteSize> selectedId{};
    if ([operation isEqualToString:@"mii"]) {
      NSNumber *selectedSlot = [intent[@"miiSlot"] isKindOfClass:NSNumber.class] ? intent[@"miiSlot"] : nil;
      NSData *selectedData = [intent[@"miiCreateId"] isKindOfClass:NSData.class] ? intent[@"miiCreateId"] : nil;
      if (selectedSlot == nil || !ReadCreateId(selectedData, selectedId, error)) return NO;
      nameData = SelectedMiiName(selectedSlot.unsignedIntegerValue, selectedData, error);
      if (nameData == nil) return NO;
    }
    const auto result = [operation isEqualToString:@"mii"]
        ? kartpad::mii::SetLicenseMii(updatedSave,
              slotNumber.unsignedIntegerValue, createId, selectedId, Bytes(nameData))
        : [operation isEqualToString:@"rename"]
        ? kartpad::mii::RenameLicense(updatedSave,
              slotNumber.unsignedIntegerValue, createId, Bytes(nameData))
        : kartpad::mii::DeleteLicense(updatedSave,
              slotNumber.unsignedIntegerValue, createId);
    if (!result) {
      if (error != nullptr) *error = ManagerError(19, result.message);
      return NO;
    }
    [saveChanges addObject:@{
      @"path": path,
      @"backup": location[@"backup"],
      @"data": [NSData dataWithBytes:updatedSave.data()
                                length:updatedSave.size()],
    }];
  }

  NSString *database = DatabasePath();
  NSString *stamp = [NSString stringWithFormat:@"%.0f-%@",
      NSDate.date.timeIntervalSince1970, NSUUID.UUID.UUIDString];
  if (hasDatabase &&
      !BackupFile(database, @"MiiBackups", @"RFL_DB", stamp, error)) return NO;
  for (NSDictionary<NSString *, id> *change in saveChanges) {
    if (!BackupFile(change[@"path"], @"SaveBackups", change[@"backup"],
                    stamp, error)) return NO;
  }

  if (hasDatabase) {
    NSString *parent = database.stringByDeletingLastPathComponent;
    if (![files createDirectoryAtPath:parent withIntermediateDirectories:YES
                           attributes:nil error:error] ||
        ![pendingData writeToFile:database options:NSDataWritingAtomic error:error]) {
      return NO;
    }
  }
  for (NSDictionary<NSString *, id> *change in saveChanges) {
    NSString *save = change[@"path"];
    NSString *parent = save.stringByDeletingLastPathComponent;
    NSData *saveData = change[@"data"];
    if (![files createDirectoryAtPath:parent withIntermediateDirectories:YES
                           attributes:nil error:error] ||
        ![saveData writeToFile:save options:NSDataWritingAtomic error:error]) {
      return NO;
    }
  }
  if (hasDatabase && ![files removeItemAtPath:pending error:error]) return NO;
  if (hasIdentity &&
      ![files removeItemAtPath:pendingIdentity error:error]) return NO;
  if (hasLicense &&
      ![files removeItemAtPath:pendingLicense error:error]) return NO;
  return YES;
}

BOOL KartPadHasPendingMiiChanges(void) {
  return KartPadHasPendingSaveRestore() || [NSFileManager.defaultManager fileExistsAtPath:PendingGhostPath()] || [NSFileManager.defaultManager fileExistsAtPath:PendingPath()] ||
      [NSFileManager.defaultManager fileExistsAtPath:PendingIdentityPath()] ||
      [NSFileManager.defaultManager fileExistsAtPath:PendingLicensePath()];
}

#include "kartpad/ghost/rkg.h"

NSArray<NSDictionary<NSString *, id> *> *KartPadOriginalGhosts(NSUInteger license, NSError **error) {
  NSData *save = [NSData dataWithContentsOfFile:SaveLocation(@"original")[@"path"] options:0 error:error];
  if (save == nil) return nil;
  try {
    std::span<const uint8_t> bytes((const uint8_t *)save.bytes, save.length);
    kartpad::ghost::ValidateSave(bytes, (unsigned)license);
    NSMutableArray *records = [NSMutableArray array];
    std::string firstGhostError;
    for (bool downloaded : {false, true}) {
      const auto bits = kartpad::ghost::Read32(bytes, 8 + license * 0x8cc0 + (downloaded ? 8 : 4));
      for (unsigned slot = 0; slot < 32; ++slot) if (bits & (1u << slot)) {
        try {
          auto data = kartpad::ghost::Export(bytes, (unsigned)license, slot, downloaded);
          [records addObject:@{@"name": [NSString stringWithFormat:@"%s — %@", kartpad::ghost::CourseNames[slot], downloaded ? @"Downloaded" : @"Personal Best"],
              @"data": [NSData dataWithBytes:data.data() length:data.size()]}];
        } catch (const std::exception& failure) {
          // A corrupt ghost must not prevent exporting another valid slot.
          if (firstGhostError.empty()) firstGhostError = failure.what();
        }
      }
    }
    if (records.count == 0 && !firstGhostError.empty()) {
      if (error) *error = ManagerError(40, ("This license lists saved ghosts, but they could not be exported. " + firstGhostError + ". Your save has not been changed.").c_str());
      return nil;
    }
    return records;
  } catch (const std::exception& e) {
    if (error) *error = ManagerError(40, e.what());
    return nil;
  }
}

BOOL KartPadStageOriginalGhost(NSData *ghost, NSUInteger license, NSError **error) {
  if (KartPadHasPendingMiiChanges()) {
    if(error) *error=ManagerError(41,"Restart to apply the pending data change first.");
    return NO;
  }
  NSString *path=SaveLocation(@"original")[@"path"];
  NSData *save=[NSData dataWithContentsOfFile:path options:0 error:error];
  if(!save)return NO;
  try {
    auto result=kartpad::ghost::Import(std::span<const uint8_t>((const uint8_t*)save.bytes,save.length),
        std::span<const uint8_t>((const uint8_t*)ghost.bytes,ghost.length),(unsigned)license);
    (void)result;
    NSDictionary *request=@{@"ghost":ghost,@"license":@(license),
        @"identity":[save subdataWithRange:NSMakeRange(8+license*0x8cc0+0x28,8)]};
    NSData *plist=[NSPropertyListSerialization dataWithPropertyList:request format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
    return plist && [plist writeToFile:PendingGhostPath() options:NSDataWritingAtomic error:error];
  }catch(const std::exception& e){if(error)*error=ManagerError(42,e.what());return NO;}
}

static BOOL KartPadApplyPendingGhost(NSError **error) {
  NSString *pending=PendingGhostPath();
  NSFileManager *files=NSFileManager.defaultManager;
  if(![files fileExistsAtPath:pending])return YES;
  if([files fileExistsAtPath:PendingPath()]||[files fileExistsAtPath:PendingIdentityPath()]||[files fileExistsAtPath:PendingLicensePath()]) {
    if(error)*error=ManagerError(43,"Conflicting pending changes. Existing saves and requests were retained.");return NO;
  }
  NSDictionary *attrs=[files attributesOfItemAtPath:pending error:error];
  if(!attrs || [attrs fileSize]>32*1024){if(error)*error=ManagerError(44,"Invalid pending ghost request.");return NO;}
  NSData *data=[NSData dataWithContentsOfFile:pending options:0 error:error];
  id request=data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:nil error:error] : nil;
  if(![request isKindOfClass:NSDictionary.class]||![request[@"ghost"] isKindOfClass:NSData.class]||![request[@"identity"] isKindOfClass:NSData.class]||![request[@"license"] isKindOfClass:NSNumber.class])return NO;
  NSString *active=SaveLocation(@"original")[@"path"];
  NSData *current=[NSData dataWithContentsOfFile:active options:0 error:error];
  const NSUInteger license=[request[@"license"] unsignedIntegerValue];
  if(license>=4 || current.length!=kartpad::ghost::SaveBytes || ![[current subdataWithRange:NSMakeRange(8+license*0x8cc0+0x28,8)] isEqual:request[@"identity"]]){
    if(error)*error=ManagerError(45,"The selected license changed. Cancel the pending ghost import and choose the license again.");return NO;
  }
  NSData *after=nil;
  try {
    NSData *ghost=request[@"ghost"];
    auto result=kartpad::ghost::Import(std::span<const uint8_t>((const uint8_t*)current.bytes,current.length),std::span<const uint8_t>((const uint8_t*)ghost.bytes,ghost.length),(unsigned)license);
    after=[NSData dataWithBytes:result.data() length:result.size()];
  }catch(const std::exception& e){if(error)*error=ManagerError(46,e.what());return NO;}
  if(![current isEqualToData:after]) {
    if(!BackupFile(active,@"SaveBackups",@"rksys-ghost",NSUUID.UUID.UUIDString,error))return NO;
    if(![after writeToFile:active options:NSDataWritingAtomic error:error])return NO;
  }
  return [files removeItemAtPath:pending error:error];
}

BOOL KartPadHasPendingGhost(void) { return [NSFileManager.defaultManager fileExistsAtPath:PendingGhostPath()]; }
BOOL KartPadCancelPendingGhost(NSError **error) { return !KartPadHasPendingGhost() || [NSFileManager.defaultManager removeItemAtPath:PendingGhostPath() error:error]; }

static NSString *RawSavePendingPath(){return [SupportRoot() stringByAppendingPathComponent:@"PendingSaveRestore.plist"];}
static BOOL ValidateRawSave(NSData *data,NSError **error){
  auto b=std::span<const uint8_t>((const uint8_t*)data.bytes,data.length);
  try{kartpad::ghost::Require(b.size()==kartpad::ghost::SaveBytes,"A save must be exactly 2867200 bytes.");kartpad::ghost::Require(kartpad::ghost::Read32(b,0)==0x524b5344&&kartpad::ghost::Read32(b,4)==0x30303036,"Unsupported save format.");kartpad::ghost::Require(kartpad::ghost::Read32(b,0x27ffc)==kartpad::ghost::Crc(b.first(0x27ffc)),"Save checksum mismatch.");return YES;}catch(const std::exception &e){if(error)*error=ManagerError(50,e.what());return NO;}
}
NSData *KartPadReadSave(NSString *profile,NSError **error){
  NSDictionary *location=SaveLocation(profile);if(!location){if(error)*error=ManagerError(51,"Unknown save profile.");return nil;}
  NSDictionary *attrs=[NSFileManager.defaultManager attributesOfItemAtPath:location[@"path"] error:error];if(!attrs)return nil;
  if([attrs fileSize]!=kartpad::ghost::SaveBytes){if(error)*error=ManagerError(52,"Unsupported save size.");return nil;}
  NSData *data=[NSData dataWithContentsOfFile:location[@"path"] options:0 error:error];return data&&ValidateRawSave(data,error)?data:nil;
}
BOOL KartPadHasPendingSaveRestore(void){return [NSFileManager.defaultManager fileExistsAtPath:RawSavePendingPath()];}
BOOL KartPadCancelSaveRestore(NSError **error){return !KartPadHasPendingSaveRestore()||[NSFileManager.defaultManager removeItemAtPath:RawSavePendingPath() error:error];}
BOOL KartPadStageSaveRestore(NSString *profile,NSData *data,NSError **error){
  if(KartPadHasPendingMiiChanges()){if(error)*error=ManagerError(53,"Apply or cancel the pending data change first.");return NO;}
  if(!SaveLocation(profile)||!ValidateRawSave(data,error))return NO;
  NSData *request=[NSPropertyListSerialization dataWithPropertyList:@{@"profile":profile,@"data":data} format:NSPropertyListBinaryFormat_v1_0 options:0 error:error];
  return request&&[request writeToFile:RawSavePendingPath() options:NSDataWritingAtomic error:error];
}
static BOOL KartPadApplyPendingSaveRestore(NSError **error){
  if(!KartPadHasPendingSaveRestore())return YES;
  NSFileManager *files=NSFileManager.defaultManager;
  if([files fileExistsAtPath:PendingPath()]||[files fileExistsAtPath:PendingIdentityPath()]||[files fileExistsAtPath:PendingLicensePath()]||KartPadHasPendingGhost()){if(error)*error=ManagerError(54,"Conflicting pending data changes.");return NO;}
  NSDictionary *attrs=[files attributesOfItemAtPath:RawSavePendingPath() error:error];if(!attrs||[attrs fileSize]>kartpad::ghost::SaveBytes+4096)return NO;
  NSData *request=[NSData dataWithContentsOfFile:RawSavePendingPath() options:0 error:error];
  NSDictionary *plist=[NSPropertyListSerialization propertyListWithData:request options:NSPropertyListImmutable format:nil error:error];
  if(![plist isKindOfClass:NSDictionary.class]||![plist[@"profile"] isKindOfClass:NSString.class]||![plist[@"data"] isKindOfClass:NSData.class])return NO;
  NSDictionary *location=SaveLocation(plist[@"profile"]);if(!location||!ValidateRawSave(plist[@"data"],error))return NO;
  NSString *active=location[@"path"];
  if([files fileExistsAtPath:active]){NSData *current=KartPadReadSave(plist[@"profile"],error);if(!current)return NO;if(![current isEqual:plist[@"data"]]&&!BackupFile(active,@"SaveBackups",@"rksys-restore",NSUUID.UUID.UUIDString,error))return NO;}
  if(![files createDirectoryAtPath:active.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error])return NO;
  if(![plist[@"data"] writeToFile:active options:NSDataWritingAtomic error:error])return NO;
  return KartPadCancelSaveRestore(error);
}
