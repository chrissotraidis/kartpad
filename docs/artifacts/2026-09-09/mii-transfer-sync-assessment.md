# Mii database and rating sync assessment

The #105 follow-up proposes Dolphin RFL_DB.dat transfer and Syncthing rating
synchronization. Independent Medium source review at427cc40 confirms the database
path. Android currently picks individual74-byte Miis. A bounded next feature is
selected missing-Mii import from a validated database, preserving all identity
bytes and existing records, with backups and startup-time merging. Existing
record duplicate detection uses four identity bytes while linked-license handling
uses eight; ambiguous collisions must be rejected rather than matched by name.
No importer was implemented or promised in this cycle.

Evidence: KartPadMiiStorage.kt validates managed NAND database size/header/CRC
and stages backed-up replacement; KartPadActivity.kt has the individual-file
picker; runtime/include/kartpad/mii/mii_database.h and player_identity.h define
record and license identity handling.

Pinned Retro93ba8c8 RatingSave.cpp loads once into a static cache and rewrites the
whole table. RatingSync.cpp includes server downloads/reports and downloaded
VR/BR writes. File timestamps alone cannot arbitrate per-profile conflicts;
live external replacement can be overwritten. Both Retro profiles share ratings.
The checked manual restore remains supported; automatic sync is not implemented.
No user files, identities or live NAND state were read or changed in this review.
Android owner retains implementation/build/device ownership; Apple parity would
need separate UI and acceptance work.
