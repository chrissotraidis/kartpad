#import "KartPadRetroRewindInstaller.h"

#import <CommonCrypto/CommonDigest.h>
#import <TargetConditionals.h>

#include "kartpad/retro_rewind/archive_path.h"
#include "kartpad/retro_rewind/archive_scan.h"
#include "kartpad_retro_rewind_release.h"
#include "mz.h"
#include "mz_strm.h"
#include "mz_zip.h"
#include "mz_zip_rw.h"

namespace {

NSString *const kKartPadRetroRewindErrorDomain = @"dev.kartpad.retro-rewind";

NSError *KartPadRetroRewindError(NSInteger code, NSString *message) {
  return [NSError errorWithDomain:kKartPadRetroRewindErrorDomain code:code
                         userInfo:@{NSLocalizedDescriptionKey : message}];
}

BOOL KartPadRetroRewindFail(NSError **error, NSInteger code,
                            NSString *message) {
  if (error != nullptr) *error = KartPadRetroRewindError(code, message);
  return NO;
}

NSString *KartPadRetroRewindSupportRoot() {
#if TARGET_OS_TV
  return [[NSSearchPathForDirectoriesInDomains(
      NSCachesDirectory, NSUserDomainMask, YES) firstObject]
      stringByAppendingPathComponent:@"KartPad"];
#else
  return [[NSHomeDirectory() stringByAppendingPathComponent:
      @"Library/Application Support"] stringByAppendingPathComponent:@"KartPad"];
#endif
}

NSString *KartPadHexDigest(const unsigned char *digest, size_t length) {
  NSMutableString *result = [NSMutableString stringWithCapacity:length * 2];
  for (size_t index = 0; index < length; ++index) {
    [result appendFormat:@"%02x", digest[index]];
  }
  return result;
}

NSString *KartPadSHA256ForLargeFile(NSString *path,
                                    KartPadRetroRewindInstallProgress progress,
                                    double progressStart, double progressEnd,
                                    NSError **error) {
  NSDictionary<NSFileAttributeKey, id> *attributes =
      [NSFileManager.defaultManager attributesOfItemAtPath:path error:error];
  if (attributes == nil) return nil;
  const uint64_t expected = [attributes fileSize];
  NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
  [stream open];
  CC_SHA256_CTX context;
  CC_SHA256_Init(&context);
  // Dispatch worker threads have a much smaller stack than the main thread on
  // physical iOS devices. Keep the streaming chunk on the heap so validating a
  // multi-gigabyte archive cannot overflow that worker stack.
  NSMutableData *bufferStorage = [NSMutableData dataWithLength:1024 * 1024];
  if (bufferStorage == nil) {
    if (error != nullptr) {
      *error = KartPadRetroRewindError(
          2, @"KartPad could not allocate the Retro Rewind verification buffer.");
    }
    [stream close];
    return nil;
  }
  uint8_t *buffer = static_cast<uint8_t *>(bufferStorage.mutableBytes);
  uint64_t consumed = 0;
  int lastReportedPercent = -1;
  while (true) {
    NSInteger count = [stream read:buffer maxLength:bufferStorage.length];
    if (count < 0) {
      if (error != nullptr) {
        *error = stream.streamError ?: KartPadRetroRewindError(
            2, @"The Retro Rewind archive could not be read.");
      }
      [stream close];
      return nil;
    }
    if (count == 0) break;
    CC_SHA256_Update(&context, buffer, (CC_LONG)count);
    consumed += (uint64_t)count;
    if (progress != nil && expected > 0) {
      const double fraction = progressStart +
          (progressEnd - progressStart) * ((double)consumed / (double)expected);
      const int percent = (int)(fraction * 100.0);
      if (percent != lastReportedPercent) {
        lastReportedPercent = percent;
        progress(@"Verifying the official download…", fraction);
      }
    }
  }
  [stream close];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256_Final(digest, &context);
  return KartPadHexDigest(digest, sizeof(digest));
}

NSArray<NSString *> *KartPadSafeArchiveComponents(const char *nameBytes,
                                                   size_t nameLength,
                                                   NSString **decodedName,
                                                   kartpad::retro_rewind::ArchiveMemberPath
                                                       *portablePath,
                                                   NSError **error) {
  const std::string_view bytes{nameBytes, nameLength};
  const kartpad::retro_rewind::ArchiveMemberPath validated =
      kartpad::retro_rewind::ValidateArchiveMemberPath(bytes);
  NSString *name = [[NSString alloc] initWithBytes:nameBytes
                                            length:nameLength
                                          encoding:NSUTF8StringEncoding];
  if (!validated || name == nil) {
    KartPadRetroRewindFail(error, 3,
        [NSString stringWithFormat:@"The archive contains an unsafe path: %@",
                                   name ?: @"(invalid)"]);
    return nil;
  }
  if (decodedName != nullptr) *decodedName = name;
  if (portablePath != nullptr) *portablePath = validated;

  NSMutableArray<NSString *> *parts =
      [NSMutableArray arrayWithCapacity:validated.components.size()];
  for (const std::string& component : validated.components) {
    NSString *part = [[NSString alloc] initWithBytes:component.data()
                                              length:component.size()
                                            encoding:NSUTF8StringEncoding];
    if (part == nil) {
      KartPadRetroRewindFail(error, 3,
          [NSString stringWithFormat:@"The archive contains an unsafe path: %@",
                                     name ?: @"(invalid)"]);
      return nil;
    }
    [parts addObject:part];
  }
  return parts;
}

void KartPadRecoverRetroRewindInstall() {
  NSFileManager *files = NSFileManager.defaultManager;
  NSString *supportRoot = KartPadRetroRewindSupportRoot();
  NSString *installed = [supportRoot stringByAppendingPathComponent:@"RetroRewind"];
  NSArray<NSString *> *entries =
      [files contentsOfDirectoryAtPath:supportRoot error:nil] ?: @[];
  NSMutableArray<NSString *> *rollbacks = [NSMutableArray array];
  for (NSString *entry in entries) {
    NSString *path = [supportRoot stringByAppendingPathComponent:entry];
    if ([entry hasPrefix:@"RetroRewind.import-"]) {
      [files removeItemAtPath:path error:nil];
    } else if ([entry hasPrefix:@"RetroRewind.rollback-"]) {
      [rollbacks addObject:entry];
    }
  }
  [rollbacks sortUsingSelector:@selector(compare:)];
  if (![files fileExistsAtPath:installed] && rollbacks.count == 1) {
    [files moveItemAtPath:[supportRoot stringByAppendingPathComponent:
                              rollbacks.firstObject]
                    toPath:installed error:nil];
  }
}

void KartPadRemoveRetroRewindRollbacks() {
  NSFileManager *files = NSFileManager.defaultManager;
  NSString *supportRoot = KartPadRetroRewindSupportRoot();
  for (NSString *entry in
       [files contentsOfDirectoryAtPath:supportRoot error:nil] ?: @[]) {
    if ([entry hasPrefix:@"RetroRewind.rollback-"]) {
      [files removeItemAtPath:[supportRoot stringByAppendingPathComponent:entry]
                        error:nil];
    }
  }
}

BOOL KartPadFileMatches(NSString *path, uint64_t expectedBytes,
                        const char *expectedHash, NSError **error) {
  NSDictionary<NSFileAttributeKey, id> *attributes =
      [NSFileManager.defaultManager attributesOfItemAtPath:path error:error];
  if (attributes == nil || [attributes fileSize] != expectedBytes) return NO;
  NSString *hash = KartPadSHA256ForLargeFile(path, nil, 0, 0, error);
  return hash != nil &&
      [hash isEqualToString:[NSString stringWithUTF8String:expectedHash]];
}

}  // namespace

@implementation KartPadRetroRewindInstaller

+ (NSString *)requiredVersion {
  return [NSString stringWithUTF8String:KARTPAD_RR_VERSION];
}

+ (NSURL *)officialVersionManifestURL {
  return [NSURL URLWithString:
      [NSString stringWithUTF8String:KARTPAD_RR_VERSION_MANIFEST_URL]];
}

+ (NSURL *)officialArchiveURL {
  return [NSURL URLWithString:
      [NSString stringWithUTF8String:KARTPAD_RR_ARCHIVE_URL]];
}

+ (uint64_t)officialArchiveBytes {
  return KARTPAD_RR_ARCHIVE_BYTES;
}

+ (NSString *)installedRootPath {
  return [[[KartPadRetroRewindSupportRoot()
      stringByAppendingPathComponent:@"RetroRewind"]
      stringByAppendingPathComponent:
          [NSString stringWithUTF8String:KARTPAD_RR_ROOT]] stringByStandardizingPath];
}

+ (NSString *)installedVersion {
  NSString *version = [NSString stringWithContentsOfFile:
      [self.installedRootPath stringByAppendingPathComponent:@"version.txt"]
                                            encoding:NSUTF8StringEncoding
                                               error:nil];
  NSString *trimmed = [version
      stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  return trimmed.length == 0 ? nil : trimmed;
}

+ (BOOL)validateInstalledRoot:(NSString *)root error:(NSError **)error {
  BOOL directory = NO;
  if (root.length == 0 ||
      ![NSFileManager.defaultManager fileExistsAtPath:root
                                           isDirectory:&directory] ||
      !directory) {
    return KartPadRetroRewindFail(error, 10,
        [NSString stringWithFormat:@"Retro Rewind %@ is not installed.",
                                   self.requiredVersion]);
  }
  NSError *readError = nil;
  NSString *version = [NSString stringWithContentsOfFile:
      [root stringByAppendingPathComponent:@"version.txt"]
                                            encoding:NSUTF8StringEncoding
                                               error:&readError];
  if (version == nil ||
      ![[version stringByTrimmingCharactersInSet:
          NSCharacterSet.whitespaceAndNewlineCharacterSet]
          isEqualToString:self.requiredVersion]) {
    if (error != nullptr) {
      *error = readError ?: KartPadRetroRewindError(11,
          [NSString stringWithFormat:
              @"The installed Retro Rewind content is not version %@.",
              self.requiredVersion]);
    }
    return NO;
  }
  NSString *codePath = [root stringByAppendingPathComponent:
      [NSString stringWithUTF8String:KARTPAD_RR_CODE_PUL_PATH]];
  if (!KartPadFileMatches(codePath, KARTPAD_RR_CODE_PUL_BYTES,
                          KARTPAD_RR_CODE_PUL_SHA256, error)) {
    if (error != nullptr && *error == nil) {
      *error = KartPadRetroRewindError(12,
          @"Retro Rewind Code.pul does not match this KartPad build.");
    }
    return NO;
  }
  NSString *xmlPath = [root stringByAppendingPathComponent:
      [NSString stringWithUTF8String:KARTPAD_RR_XML_PATH]];
  if (!KartPadFileMatches(xmlPath, KARTPAD_RR_XML_BYTES,
                          KARTPAD_RR_XML_SHA256, error)) {
    if (error != nullptr && *error == nil) {
      *error = KartPadRetroRewindError(13,
          @"Retro Rewind's XML does not match this KartPad build.");
    }
    return NO;
  }
  return YES;
}

+ (BOOL)isInstalled {
  KartPadRecoverRetroRewindInstall();
  NSError *error = nil;
  BOOL valid = [self validateInstalledRoot:self.installedRootPath error:&error];
  if (valid) KartPadRemoveRetroRewindRollbacks();
  return valid;
}

+ (BOOL)installArchiveAtURL:(NSURL *)archiveURL
                   progress:(KartPadRetroRewindInstallProgress)progress
                      error:(NSError **)error {
  if (archiveURL == nil || !archiveURL.isFileURL) {
    return KartPadRetroRewindFail(error, 20,
                                  @"Choose a Retro Rewind ZIP archive.");
  }
  BOOL securityScoped = [archiveURL startAccessingSecurityScopedResource];
  NSString *archivePath = archiveURL.path;
  NSDictionary<NSFileAttributeKey, id> *attributes =
      [NSFileManager.defaultManager attributesOfItemAtPath:archivePath error:error];
  if (attributes == nil || [attributes fileSize] != KARTPAD_RR_ARCHIVE_BYTES) {
    if (securityScoped) [archiveURL stopAccessingSecurityScopedResource];
    return KartPadRetroRewindFail(error, 21,
        [NSString stringWithFormat:
            @"This ZIP is not the official Retro Rewind %@ full download.",
            self.requiredVersion]);
  }
  NSString *archiveHash = KartPadSHA256ForLargeFile(
      archivePath, progress, 0.0, 0.18, error);
  if (archiveHash == nil ||
      ![archiveHash isEqualToString:
          [NSString stringWithUTF8String:KARTPAD_RR_ARCHIVE_SHA256]]) {
    if (securityScoped) [archiveURL stopAccessingSecurityScopedResource];
    if (error != nullptr && *error == nil) {
      *error = KartPadRetroRewindError(22,
          @"The Retro Rewind ZIP failed its pinned SHA-256 check.");
    }
    return NO;
  }

  NSFileManager *files = NSFileManager.defaultManager;
  NSString *supportRoot = KartPadRetroRewindSupportRoot();
  NSError *workError = nil;
  [files createDirectoryAtPath:supportRoot withIntermediateDirectories:YES
                    attributes:@{NSFileProtectionKey :
                        NSFileProtectionCompleteUntilFirstUserAuthentication}
                         error:&workError];
  KartPadRecoverRetroRewindInstall();
  NSString *stageParent = [supportRoot stringByAppendingPathComponent:
      [NSString stringWithFormat:@"RetroRewind.import-%@",
                                 NSUUID.UUID.UUIDString]];
  NSString *stageRoot = [stageParent stringByAppendingPathComponent:
      [NSString stringWithUTF8String:KARTPAD_RR_ROOT]];
  if (workError == nil) {
    [files createDirectoryAtPath:stageParent withIntermediateDirectories:NO
                      attributes:@{NSFileProtectionKey :
                          NSFileProtectionCompleteUntilFirstUserAuthentication}
                           error:&workError];
  }

  void *reader = nullptr;
  kartpad::retro_rewind::ArchiveScan archiveScan{
      KARTPAD_RR_ROOT, 10000, KARTPAD_RR_MAXIMUM_EXPANDED_BYTES};
  if (workError == nil) {
    reader = mz_zip_reader_create();
    if (reader == nullptr ||
        mz_zip_reader_open_file(reader, archivePath.fileSystemRepresentation) != MZ_OK) {
      workError = KartPadRetroRewindError(23,
                                          @"The Retro Rewind ZIP could not be opened.");
    }
  }
  if (securityScoped) [archiveURL stopAccessingSecurityScopedResource];

  int32_t status = workError == nil ? mz_zip_reader_goto_first_entry(reader)
                                    : MZ_END_OF_LIST;
  while (workError == nil && status == MZ_OK) {
    mz_zip_file *info = nullptr;
    if (mz_zip_reader_entry_get_info(reader, &info) != MZ_OK ||
        info == nullptr || info->filename == nullptr) {
      workError = KartPadRetroRewindError(24,
                                          @"The ZIP directory is malformed.");
      break;
    }
    NSString *name = nil;
    kartpad::retro_rewind::ArchiveMemberPath portablePath;
    NSArray<NSString *> *parts = KartPadSafeArchiveComponents(
        info->filename, info->filename_size, &name, &portablePath, &workError);
    if (parts == nil) break;
    const auto observation = archiveScan.Observe(
        portablePath, info->uncompressed_size,
        mz_zip_attrib_is_symlink(info->external_fa,
                                 info->version_madeby) == MZ_OK,
        (info->flag & MZ_ZIP_FLAG_ENCRYPTED) != 0);
    if (!observation) {
      if (observation.error ==
          kartpad::retro_rewind::ArchiveScanError::UnsupportedEntry) {
        workError = KartPadRetroRewindError(25,
            [NSString stringWithFormat:
                @"The ZIP contains an unsupported entry: %@", name]);
      } else if (observation.error ==
                 kartpad::retro_rewind::ArchiveScanError::DuplicateEntry) {
        workError = KartPadRetroRewindError(31,
                                            @"The ZIP contains duplicate files.");
      } else {
        workError = KartPadRetroRewindError(26,
            @"The ZIP expands beyond this build's safety limits.");
      }
      break;
    }
    status = mz_zip_reader_goto_next_entry(reader);
  }
  if (workError == nil && status != MZ_END_OF_LIST) {
    workError = KartPadRetroRewindError(27,
                                        @"The ZIP directory could not be read.");
  }
  if (workError == nil && archiveScan.selected_entries() == 0) {
    workError = KartPadRetroRewindError(28,
        [NSString stringWithFormat:@"The ZIP does not contain %@.",
            [NSString stringWithUTF8String:KARTPAD_RR_ROOT]]);
  }

  uint64_t extractedBytes = 0;
  int lastExtractionPercent = -1;
  if (workError == nil) status = mz_zip_reader_goto_first_entry(reader);
  while (workError == nil && status == MZ_OK) {
    mz_zip_file *info = nullptr;
    if (mz_zip_reader_entry_get_info(reader, &info) != MZ_OK ||
        info == nullptr || info->filename == nullptr) {
      workError = KartPadRetroRewindError(29, @"A ZIP entry could not be read.");
      break;
    }
    NSString *name = nil;
    NSArray<NSString *> *parts = KartPadSafeArchiveComponents(
        info->filename, info->filename_size, &name, nullptr, &workError);
    if (parts == nil) break;
    if ([parts.firstObject isEqualToString:
            [NSString stringWithUTF8String:KARTPAD_RR_ROOT]]) {
      NSArray<NSString *> *relative =
          parts.count > 1 ? [parts subarrayWithRange:NSMakeRange(1, parts.count - 1)]
                          : @[];
      if (relative.count > 0) {
        NSString *output = stageRoot;
        for (NSString *part in relative) {
          output = [output stringByAppendingPathComponent:part];
        }
        output = output.stringByStandardizingPath;
        NSString *safePrefix = [stageRoot.stringByStandardizingPath
            stringByAppendingString:@"/"];
        if (![output hasPrefix:safePrefix]) {
          workError = KartPadRetroRewindError(30,
                                              @"The ZIP escaped its staging folder.");
          break;
        }
        const BOOL isDirectory =
            mz_zip_attrib_is_dir(info->external_fa, info->version_madeby) == MZ_OK;
        if (isDirectory) {
          [files createDirectoryAtPath:output withIntermediateDirectories:YES
                            attributes:nil error:&workError];
        } else {
          NSString *parent = output.stringByDeletingLastPathComponent;
          [files createDirectoryAtPath:parent withIntermediateDirectories:YES
                            attributes:nil error:&workError];
          if (workError == nil && [files fileExistsAtPath:output]) {
            workError = KartPadRetroRewindError(31,
                                                @"The ZIP contains duplicate files.");
          }
          if (workError == nil &&
              mz_zip_reader_entry_save_file(reader,
                  output.fileSystemRepresentation) != MZ_OK) {
            workError = KartPadRetroRewindError(32,
                [NSString stringWithFormat:@"Could not extract %@.", name]);
          }
        }
      }
      extractedBytes += (uint64_t)info->uncompressed_size;
      if (progress != nil && archiveScan.selected_bytes() > 0) {
        const double fraction =
            0.18 + 0.77 * ((double)extractedBytes /
                           (double)archiveScan.selected_bytes());
        const int percent = (int)(fraction * 100.0);
        if (percent != lastExtractionPercent) {
          lastExtractionPercent = percent;
          progress(@"Installing Retro Rewind content…", fraction);
        }
      }
    }
    status = mz_zip_reader_goto_next_entry(reader);
  }
  if (reader != nullptr) {
    mz_zip_reader_close(reader);
    mz_zip_reader_delete(&reader);
  }
  if (workError == nil && status != MZ_END_OF_LIST) {
    workError = KartPadRetroRewindError(33,
                                        @"The ZIP extraction stopped early.");
  }
  if (workError == nil &&
      ![self validateInstalledRoot:stageRoot error:&workError]) {
    if (workError == nil) {
      workError = KartPadRetroRewindError(34,
                                          @"The installed content is incomplete.");
    }
  }

  NSString *installedParent =
      [supportRoot stringByAppendingPathComponent:@"RetroRewind"];
  NSString *rollback = [supportRoot stringByAppendingPathComponent:
      [NSString stringWithFormat:@"RetroRewind.rollback-%@",
                                 NSUUID.UUID.UUIDString]];
  BOOL movedExisting = NO;
  if (workError == nil && [files fileExistsAtPath:installedParent]) {
    movedExisting = [files moveItemAtPath:installedParent toPath:rollback
                                    error:&workError];
  }
  if (workError == nil) {
    [files moveItemAtPath:stageParent toPath:installedParent error:&workError];
  }
  if (workError != nil && movedExisting &&
      ![files fileExistsAtPath:installedParent]) {
    [files moveItemAtPath:rollback toPath:installedParent error:nil];
  } else if (workError == nil && movedExisting) {
    [files removeItemAtPath:rollback error:nil];
  }
  if (workError != nil) {
    [files removeItemAtPath:stageParent error:nil];
    if (error != nullptr) *error = workError;
    return NO;
  }
  NSURL *installedURL = [NSURL fileURLWithPath:installedParent isDirectory:YES];
  [installedURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
  [files setAttributes:@{NSFileProtectionKey :
      NSFileProtectionCompleteUntilFirstUserAuthentication}
             ofItemAtPath:installedParent error:nil];
  KartPadRemoveRetroRewindRollbacks();
  if (progress != nil) progress(@"Retro Rewind is ready.", 1.0);
  return YES;
}

@end
