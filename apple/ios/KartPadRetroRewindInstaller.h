#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^KartPadRetroRewindInstallProgress)(NSString *status,
                                                   double fraction);

@interface KartPadRetroRewindInstaller : NSObject

+ (NSString *)requiredVersion;
// Exact version.txt value inside the pinned pack; normally requiredVersion.
+ (NSString *)requiredPackVersion;
+ (NSURL *)officialVersionManifestURL;
+ (NSURL *)officialArchiveURL;
+ (uint64_t)officialArchiveBytes;
+ (NSString *)installedRootPath;
+ (nullable NSString *)installedVersion;
+ (BOOL)isInstalled;
+ (BOOL)validateInstalledRoot:(NSString *)root error:(NSError **)error;
+ (BOOL)installArchiveAtURL:(NSURL *)archiveURL
                   progress:(nullable KartPadRetroRewindInstallProgress)progress
                      error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
