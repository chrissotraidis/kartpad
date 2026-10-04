#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString *const KartPadMiiManagerErrorDomain;

NSArray<NSDictionary<NSString *, id> *> *KartPadMiiRecords(NSError **error);
NSArray<NSDictionary<NSString *, id> *> *KartPadLicenseRecords(NSError **error);
BOOL KartPadStageMiiImport(NSData *miiData, NSString *_Nullable *_Nullable name,
                          NSError **error);
BOOL KartPadStageMiiRemoval(NSUInteger slot, NSError **error);
BOOL KartPadStagePlayerName(NSUInteger slot, NSString *name,
                           NSUInteger *_Nullable updatedLicenses,
                           NSError **error);
BOOL KartPadStageLicenseRename(NSString *profileIdentifier, NSUInteger slot,
                              NSData *createId, NSString *name,
                              NSError **error);
// Select an existing Mii; preserves the license account/progress and never edits the Mii.
BOOL KartPadStageLicenseMii(NSString *profileIdentifier, NSUInteger slot,
                           NSData *createId, NSUInteger miiSlot, NSData *miiCreateId,
                           NSError **error);
BOOL KartPadStageLicenseDeletion(NSString *profileIdentifier, NSUInteger slot,
                                NSData *createId, NSError **error);
BOOL KartPadApplyPendingMiiDatabase(NSError **error);
BOOL KartPadHasPendingMiiChanges(void);


// Original-course RKG exchange; imports use downloaded slots and preserve personal bests.
NSArray<NSDictionary<NSString *, id> *> *KartPadOriginalGhosts(NSUInteger license, NSError **error);
BOOL KartPadStageOriginalGhost(NSData *ghost, NSUInteger license, NSError **error);

BOOL KartPadHasPendingGhost(void);
BOOL KartPadCancelPendingGhost(NSError **error);

// Retro standalone comparison collection; selection binds track/variant/mode
// to the installed catalog and never writes a license save or leaderboard.
NSDictionary<NSString *, id> * _Nullable KartPadRetroGhostCatalog(NSError **error);
NSArray<NSDictionary<NSString *, id> *> * _Nullable KartPadRetroGhostFiles(NSDictionary *selection, NSError **error);
BOOL KartPadStageRetroGhost(NSData *ghost, NSDictionary *selection, NSError **error);
BOOL KartPadHasPendingRetroGhost(void);
BOOL KartPadCancelPendingRetroGhost(NSError **error);
BOOL KartPadApplyPendingRetroGhost(NSError **error);

FOUNDATION_EXPORT NSData * _Nullable KartPadReadSave(NSString *profile, NSError **error);
FOUNDATION_EXPORT BOOL KartPadStageSaveRestore(NSString *profile, NSData *data, NSError **error);
FOUNDATION_EXPORT BOOL KartPadCancelSaveRestore(NSError **error);
FOUNDATION_EXPORT BOOL KartPadHasPendingSaveRestore(void);
NS_ASSUME_NONNULL_END
