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

// Player-added music (#441): .brstm files in RetroRewind6/MyStuff, which the
// pack's "My Stuff → RR Music" option lays over the game's music after a
// restart. Pack updates keep them.
+ (NSUInteger)customMusicCount;
// Adds one .brstm, or every .brstm inside a .zip, replacing same-named tracks.
+ (BOOL)importMusicFromURL:(NSURL *)url
                     added:(NSUInteger *)added
                   skipped:(NSUInteger *)skipped
                     error:(NSError **)error;
+ (NSUInteger)removeCustomMusic;

@end

NS_ASSUME_NONNULL_END
